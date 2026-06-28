# HTTP Proxy route for SABR streaming
# This is a "dumb" proxy that forwards requests to googlevideo.com and other YouTube services
# Used by the client-side SABR player to proxy segment requests

module Invidious::Routes::Proxy
  ALLOWED_HEADERS = [
    "origin",
    "x-requested-with",
    "content-type",
    "accept",
    "authorization",
    "x-goog-visitor-id",
    "x-goog-api-key",
    "x-origin",
    "x-youtube-client-version",
    "x-youtube-client-name",
    "x-goog-api-format-version",
    "x-goog-authuser",
    "x-user-agent",
    "accept-language",
    "x-goog-fieldmask",
    "range",
    "referer",
  ]

  CONTENT_HEADERS = [
    "content-length",
    "content-type",
    "content-disposition",
    "accept-ranges",
    "content-range",
  ]

  # Allowed hosts for proxying (security measure)
  ALLOWED_HOST_PATTERNS = [
    /\.googlevideo\.com$/,
    /\.youtube\.com$/,
    /\.ytimg\.com$/,
    /\.ggpht\.com$/,
    /^redirector\.googlevideo\.com$/,
    /^jnn-pa\.googleapis\.com$/,
    /^play\.googleapis\.com$/,
  ]

  def self.is_host_allowed?(host : String) : Bool
    ALLOWED_HOST_PATTERNS.any? { |pattern| host.matches?(pattern) }
  end

  # OPTIONS /proxy
  def self.options(env)
    origin = env.request.headers["Origin"]? || "*"

    env.response.headers["Access-Control-Allow-Origin"] = origin
    env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = ALLOWED_HEADERS.join(", ")
    env.response.headers["Access-Control-Max-Age"] = "86400"
    env.response.headers["Access-Control-Allow-Credentials"] = "true"

    env.response.status_code = 200
    ""
  end

  # GET /proxy
  # POST /proxy
  def self.proxy(env)
    origin = env.request.headers["Origin"]? || "*"
    query_params = env.params.query

    # Get target host from __host parameter
    target_host = query_params["__host"]?

    if target_host.nil? || target_host.empty?
      env.response.status_code = 400
      return "Request is formatted incorrectly. Please include __host in the query string."
    end

    # Security check: only allow proxying to known YouTube/Google domains
    if !is_host_allowed?(target_host)
      env.response.status_code = 403
      return "Proxying to this host is not allowed."
    end

    # Parse custom headers from __headers parameter
    custom_headers = HTTP::Headers.new
    if headers_param = query_params["__headers"]?
      begin
        headers_array = JSON.parse(headers_param).as_a
        headers_array.each do |header|
          # header is a JSON::Any, need to extract as array
          header_array = header.as_a
          name = header_array[0]?.try &.as_s
          value = header_array[1]?.try &.as_s
          if name && value
            custom_headers[name] = value
          end
        end
      rescue ex
        # Ignore malformed headers
        puts "[WARN] Proxy: Failed to parse __headers: #{ex.message}"
      end
    end

    # Get target path from __path parameter, or fall back to the request path
    target_path = query_params["__path"]? || env.request.path.sub("/proxy", "")
    if target_path.empty?
      target_path = "/"
    end

    # Build the target URL
    target_url = URI.new(
      scheme: "https",
      host: target_host,
      port: 443,
      path: target_path,
      query: build_query_without_proxy_params(query_params)
    )

    # Build request headers
    request_headers = HTTP::Headers.new

    # Copy custom headers
    custom_headers.each do |key, values|
      value = values.is_a?(Array) ? values.first : values.to_s
      request_headers[key] = value
    end

    # Copy range header from original request
    if range = env.request.headers["Range"]?
      request_headers["Range"] = range
    end

    # Copy content-type header for POST requests
    if content_type = env.request.headers["Content-Type"]?
      if !request_headers["Content-Type"]?
        request_headers["Content-Type"] = content_type
      end
    end

    # Copy user-agent if not already set
    if !request_headers["User-Agent"]? && env.request.headers["User-Agent"]?
      request_headers["User-Agent"] = env.request.headers["User-Agent"]
    end

    # Set origin/referer for YouTube and Google domains (only if not already set)
    if target_host.includes?("youtube") || target_host.includes?("googlevideo") || target_host.includes?("googleapis")
      if !request_headers["Origin"]?
        request_headers["Origin"] = "https://www.youtube.com"
      end
      if !request_headers["Referer"]?
        request_headers["Referer"] = "https://www.youtube.com/"
      end
    end

    # CRITICAL: Set Content-Type for POST requests to videoplayback (SABR protocol)
    # YouTube requires application/x-protobuf for SABR videoplayback requests
    if env.request.method == "POST" && target_url.path.includes?("videoplayback")
      request_headers["Content-Type"] = "application/x-protobuf"
    end

    # The SABR scheme plugin reads UMP parts incrementally from the response
    # stream, so make sure the upstream sends us raw bytes (no gzip/deflate).
    if !request_headers["Accept-Encoding"]?
      request_headers["Accept-Encoding"] = "identity"
    end

    # Copy authorization if present
    if auth = env.request.headers["Authorization"]?
      request_headers["Authorization"] = auth
    end

    # Make the proxied request, streaming the upstream body straight to the
    # client instead of buffering response.body. This is required so the SABR
    # scheme plugin can read UMP parts incrementally and abort a fetch
    # mid-stream (backoff / reload / seek).
    begin
      client = HTTP::Client.new(target_url.host.not_nil!, tls: true)
      client.connect_timeout = 10.seconds
      client.read_timeout = 30.seconds
      # Don't let HTTP::Client advertise its own Accept-Encoding; we forward the
      # plugin's identity header and stream raw bytes.
      client.compress = false

      method = env.request.method
      case method
      when "GET", "POST"
        # Build a raw request so we control streaming + binary POST body.
        request = HTTP::Request.new(method, target_url.request_target, request_headers)
        if method == "POST"
          body_io = env.request.body
          body_bytes : Bytes? = nil
          if body_io
            body_bytes = body_io.getb_to_end
          end
          if body_bytes
            request.body = body_bytes
            request.content_length = body_bytes.size
          end
        end

        client.exec(request) do |response|
          env.response.status_code = response.status_code

          CONTENT_HEADERS.each do |header|
            if value = response.headers[header]?
              env.response.headers[header] = value
            end
          end

          env.response.headers["Access-Control-Allow-Origin"] = origin
          env.response.headers["Access-Control-Allow-Headers"] = ALLOWED_HEADERS.join(", ")
          env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
          env.response.headers["Access-Control-Allow-Credentials"] = "true"

          # Stream the upstream body through without buffering, so the client's
          # UmpReader can consume parts as they arrive and so backoff/abort
          # actually cancels the transfer.
          begin
            IO.copy(response.body_io, env.response.output)
            env.response.output.flush
          rescue ex : IO::Error
            # Client disconnected mid-stream (seek / quality change / abort).
            # This is expected, just stop copying.
          end
        end
      else
        env.response.status_code = 405
        return "Method not allowed"
      end
    rescue ex
      env.response.status_code = 502
      "Proxy error: #{ex.message}"
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
