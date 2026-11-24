# HTTP Proxy route for SABR streaming
# This is a "dumb" proxy that forwards requests to googlevideo.com and other YouTube services
# Used by the client-side SABR player to proxy segment requests.
#
# The SABR player runs on the same origin, so no CORS headers are sent: other
# websites can't read the responses of this route.

module Invidious::Routes::Proxy
  # Request headers that the client may forward upstream through `__headers`.
  # These are the headers set by youtubei.js, googlevideo, bgutils-js and the
  # SABR player. Anything else (Cookie, Host, Connection, X-Forwarded-*,
  # Proxy-*, Authorization, ...) is dropped.
  ALLOWED_REQUEST_HEADERS = Set{
    "accept",
    "accept-language",
    "content-type",
    "origin",
    "range",
    "referer",
    "user-agent",
    "x-origin",
    "x-user-agent",
  }

  # Prefixes of the Google/YouTube specific headers (e.g. `x-goog-visitor-id`,
  # `x-goog-api-key`, `x-youtube-client-name`, `x-youtube-client-version`).
  ALLOWED_REQUEST_HEADER_PREFIXES = {"x-goog-", "x-youtube-"}

  CONTENT_HEADERS = [
    "content-length",
    "content-type",
    "content-disposition",
    "accept-ranges",
    "content-range",
  ]

  # Allowed hosts for proxying (security measure).
  # Anchored with \A and \z: `$` would also match before a trailing newline.
  ALLOWED_HOST_PATTERNS = [
    /\A[a-z0-9-]+(\.[a-z0-9-]+)*\.googlevideo\.com\z/,
    /\A[a-z0-9-]+(\.[a-z0-9-]+)*\.youtube\.com\z/,
    /\A[a-z0-9-]+(\.[a-z0-9-]+)*\.ytimg\.com\z/,
    /\A[a-z0-9-]+(\.[a-z0-9-]+)*\.ggpht\.com\z/,
    /\Ajnn-pa\.googleapis\.com\z/,
    /\Aplay\.googleapis\.com\z/,
    # BotGuard interpreter JS is served from www.google.com / gstatic (session-bound
    # PO token attestation via the InnerTube att/get flow).
    /\A([a-z0-9-]+\.)*google\.com\z/,
    /\A([a-z0-9-]+\.)*gstatic\.com\z/,
  ]

  # Characters allowed in the upstream path (RFC 3986 `pchar` and `/`).
  # Rejects whitespace and control characters (request splitting).
  VALID_PATH = /\A\/[A-Za-z0-9\-._~!$&'()*+,;=:@%\/]*\z/

  # RFC 7230 token, as used for header names
  VALID_HEADER_NAME = /\A[A-Za-z0-9!#$%&'*+\-.^_`|~]+\z/

  # Visible ASCII characters, spaces and tabs (no CR/LF or other control characters)
  VALID_HEADER_VALUE = /\A[\x20-\x7E\t]*\z/

  # Maximum size of a POST body (SABR/Innertube requests are a few KB)
  MAX_BODY_SIZE = 2 * 1024 * 1024

  def self.host_allowed?(host : String) : Bool
    ALLOWED_HOST_PATTERNS.any?(&.matches?(host))
  end

  def self.header_allowed?(name : String) : Bool
    name = name.downcase
    ALLOWED_REQUEST_HEADERS.includes?(name) ||
      ALLOWED_REQUEST_HEADER_PREFIXES.any? { |prefix| name.starts_with?(prefix) }
  end

  def self.valid_header?(name : String, value : String) : Bool
    VALID_HEADER_NAME.matches?(name) && VALID_HEADER_VALUE.matches?(value)
  end

  # SABR streams video through this route, like DASH does through
  # /videoplayback, so it obeys the same `disable_proxy` setting.
  def self.disabled? : Bool
    CONFIG.disabled?("dash")
  end

  # OPTIONS /proxy
  def self.options(env)
    if disabled?
      env.response.status_code = 403
      return "Proxying is disabled on this instance."
    end

    env.response.headers["Allow"] = "GET, POST, OPTIONS"
    env.response.status_code = 204
    ""
  end

  # GET /proxy
  # POST /proxy
  def self.proxy(env)
    if disabled?
      env.response.status_code = 403
      return "Proxying is disabled on this instance."
    end

    query_params = env.params.query

    # Get target host from __host parameter
    target_host = query_params["__host"]?

    if target_host.nil? || target_host.empty?
      env.response.status_code = 400
      return "Request is formatted incorrectly. Please include __host in the query string."
    end

    # Security check: only allow proxying to known YouTube/Google domains
    if !host_allowed?(target_host)
      env.response.status_code = 403
      return "Proxying to this host is not allowed."
    end

    # Get target path from __path parameter, or fall back to the request path
    target_path = query_params["__path"]? || env.request.path.sub("/proxy", "")
    if target_path.empty?
      target_path = "/"
    end

    if !VALID_PATH.matches?(target_path)
      env.response.status_code = 400
      return "Invalid __path."
    end

    # Build request headers
    request_headers = HTTP::Headers.new

    # Copy the allowed custom headers from the __headers parameter
    if headers_param = query_params["__headers"]?
      begin
        JSON.parse(headers_param).as_a.each do |header|
          name = header[0]?.try &.as_s?
          value = header[1]?.try &.as_s?
          next if name.nil? || value.nil?

          if !valid_header?(name, value)
            env.response.status_code = 400
            return "Invalid header in __headers."
          end

          request_headers[name] = value if header_allowed?(name)
        end
      rescue ex
        # Ignore malformed headers (not a JSON array of [name, value] pairs)
        LOGGER.debug("Proxy: Failed to parse __headers: #{ex.message}")
      end
    end

    # Copy range header from original request
    if range = env.request.headers["Range"]?
      request_headers["Range"] = range if VALID_HEADER_VALUE.matches?(range)
    end

    # Copy content-type header for POST requests
    if content_type = env.request.headers["Content-Type"]?
      if !request_headers["Content-Type"]? && VALID_HEADER_VALUE.matches?(content_type)
        request_headers["Content-Type"] = content_type
      end
    end

    # Use Invidious' own User-Agent unless the client set one explicitly, instead
    # of forwarding the viewer's browser User-Agent. For a Firefox User-Agent,
    # www.youtube.com answers with more than 16 KB of headers, which exceeds
    # HTTP::MAX_HEADERS_SIZE and fails with "Unexpected end of http response".
    request_headers["User-Agent"] ||= YT_DEFAULT_USER_AGENT

    # Set origin/referer for YouTube and Google domains (only if not already set)
    if target_host.includes?("youtube") || target_host.includes?("googlevideo") || target_host.includes?("googleapis")
      if !request_headers["Origin"]?
        request_headers["Origin"] = "https://www.youtube.com"
      end
      if !request_headers["Referer"]?
        request_headers["Referer"] = "https://www.youtube.com/"
      end
    end

    # Build the target URL
    target_url = URI.new(
      scheme: "https",
      host: target_host,
      port: 443,
      path: target_path,
      query: build_query_without_proxy_params(query_params)
    )

    # CRITICAL: Set Content-Type for POST requests to videoplayback (SABR protocol)
    # YouTube requires application/x-protobuf for SABR videoplayback requests
    if env.request.method == "POST" && target_url.path.includes?("videoplayback")
      request_headers["Content-Type"] = "application/x-protobuf"
    end

    # The SABR scheme plugin reads UMP parts incrementally from the response
    # stream, so make sure the upstream sends us raw bytes (no gzip/deflate).
    # The upstream Content-Encoding isn't forwarded, so this can't be changed.
    request_headers["Accept-Encoding"] = "identity"

    method = env.request.method
    if method != "GET" && method != "POST"
      env.response.status_code = 405
      return "Method not allowed"
    end

    # Build a raw request so we control streaming + binary POST body.
    request = HTTP::Request.new(method, target_url.request_target, request_headers)

    if method == "POST" && (body_io = env.request.body)
      if (env.request.content_length || 0) > MAX_BODY_SIZE
        env.response.status_code = 413
        return "Request body too large."
      end

      body = IO::Memory.new
      IO.copy(body_io, body, MAX_BODY_SIZE + 1)
      if body.size > MAX_BODY_SIZE
        env.response.status_code = 413
        return "Request body too large."
      end

      request.body = body.to_slice
      request.content_length = body.size
    end

    # Make the proxied request, streaming the upstream body straight to the
    # client instead of buffering response.body. This is required so the SABR
    # scheme plugin can read UMP parts incrementally and abort a fetch
    # mid-stream (backoff / reload / seek).
    streaming = false
    client = HTTP::Client.new(target_host, tls: true)
    begin
      # Use the configured IP family (`force_resolve`), defaulting to IPv4 like
      # make_client does for the rest of the backend.
      client.family = CONFIG.force_resolve
      client.family = Socket::Family::INET if client.family == Socket::Family::UNSPEC
      # Route the googlevideo/youtubei egress through the configured proxy when set
      # (HTTP CONNECT or SOCKS5, e.g. to bypass a YouTube IP block on the instance's
      # own address). Uses the same dispatcher as the rest of the codebase.
      configure_proxy(client) if CONFIG.http_proxy
      client.connect_timeout = 10.seconds
      client.read_timeout = 30.seconds
      # Don't let HTTP::Client advertise its own Accept-Encoding; we forward the
      # plugin's identity header and stream raw bytes.
      client.compress = false

      client.exec(request) do |response|
        env.response.status_code = response.status_code

        CONTENT_HEADERS.each do |header|
          if value = response.headers[header]?
            env.response.headers[header] = value
          end
        end

        # Stream the upstream body through without buffering, so the client's
        # UmpReader can consume parts as they arrive and so backoff/abort
        # actually cancels the transfer.
        # From here on the response headers may have been sent.
        streaming = true
        IO.copy(response.body_io, env.response.output)
        env.response.output.flush
      end
      nil
    rescue ex
      if streaming
        # The status and headers may already be sent: the status can't be
        # changed and no error body can be written anymore. Either the client
        # disconnected mid-stream (seek / quality change / abort, which is
        # expected), or the upstream failed. Close the connection after this
        # response, so that a truncated body can't be mistaken for a complete one.
        LOGGER.debug("Proxy: stream to #{target_host} interrupted: #{ex.message}")
        env.response.headers["Connection"] = "close"
        nil
      else
        LOGGER.warn("Proxy: request to #{target_host} failed: #{ex.message}")
        env.response.status_code = 502
        "Proxy error"
      end
    ensure
      client.close
    end
  end

  private def self.build_query_without_proxy_params(params : HTTP::Params) : String?
    filtered = HTTP::Params.new
    params.each do |key, value|
      next if key == "__host" || key == "__headers" || key == "__path"
      filtered.add(key, value)
    end
    filtered.empty? ? nil : filtered.to_s
  end
end
