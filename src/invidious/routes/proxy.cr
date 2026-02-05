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
        puts "[DEBUG] Proxy: Parsing __headers parameter: #{headers_param}"
        headers_array = JSON.parse(headers_param).as_a
        headers_array.each do |header|
          # header is a JSON::Any, need to extract as array
          header_array = header.as_a
          name = header_array[0]?.try &.as_s
          value = header_array[1]?.try &.as_s
          if name && value
            custom_headers[name] = value
            puts "[DEBUG] Proxy: Adding custom header #{name}: #{value}"
          end
        end
      rescue ex
        # Ignore malformed headers but log the error
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
    puts "[DEBUG] Proxy: custom_headers size: #{custom_headers.size}"
    custom_headers.each do |key, values|
      # HTTP::Headers stores values as arrays, get the first value
      value = values.is_a?(Array) ? values.first : values.to_s
      puts "[DEBUG] Proxy: Forwarding header #{key}: #{value}"
      request_headers[key] = value
    end
    puts "[DEBUG] Proxy: request_headers size after copying: #{request_headers.size}"

    # Copy range header from original request
    if range = env.request.headers["Range"]?
      request_headers["Range"] = range
    end

    # Copy content-type header for POST requests
    if content_type = env.request.headers["Content-Type"]?
      if !request_headers["Content-Type"]?
        request_headers["Content-Type"] = content_type
        puts "[DEBUG] Proxy: Copied Content-Type from request: #{content_type}"
      end
    end

    # Copy user-agent if not already set
    if !request_headers["User-Agent"]? && env.request.headers["User-Agent"]?
      request_headers["User-Agent"] = env.request.headers["User-Agent"]
      puts "[DEBUG] Proxy: Copied User-Agent from request: #{request_headers["User-Agent"]}"
    end

    # Set origin/referer for YouTube and Google domains (only if not already set)
    if target_host.includes?("youtube") || target_host.includes?("googlevideo") || target_host.includes?("googleapis")
      if !request_headers["Origin"]?
        request_headers["Origin"] = "https://www.youtube.com"
        puts "[DEBUG] Proxy: Set Origin header"
      end
      if !request_headers["Referer"]?
        request_headers["Referer"] = "https://www.youtube.com/"
        puts "[DEBUG] Proxy: Set Referer header"
      end
    end

    # CRITICAL: Set Content-Type for POST requests to videoplayback (SABR protocol)
    # YouTube requires application/x-protobuf for SABR videoplayback requests
    if env.request.method == "POST" && target_url.path.includes?("videoplayback")
      request_headers["Content-Type"] = "application/x-protobuf"
      puts "[DEBUG] Proxy: Set Content-Type: application/x-protobuf for videoplayback POST"
    end

    # Copy authorization if present
    if auth = env.request.headers["Authorization"]?
      request_headers["Authorization"] = auth
    end

    # Final debug output showing all headers being sent
    puts "[DEBUG] Proxy: Final headers to send: #{request_headers.to_a.map { |k, v| "#{k}: #{v[0..50]}..." }.join(", ")}"

    # Make the proxied request
    begin
      client = HTTP::Client.new(target_url.host.not_nil!, tls: true)
      client.connect_timeout = 10.seconds
      client.read_timeout = 30.seconds

      case env.request.method
      when "GET"
        response = client.get(target_url.request_target, headers: request_headers)
      when "POST"
        # Read body as binary Slice to preserve protobuf data integrity
        body_io = env.request.body
        body_bytes : Bytes? = nil
        if body_io
          body_bytes = body_io.getb_to_end
        end
        body_size = body_bytes.try(&.size) || 0
        puts "[DEBUG] Proxy: POST body size: #{body_size} bytes (binary)"
        puts "[DEBUG] Proxy: POST target: #{target_url.request_target[0..200]}"
        response = client.post(target_url.request_target, headers: request_headers, body: body_bytes)
        puts "[DEBUG] Proxy: Response status: #{response.status_code}, content-type: #{response.headers["content-type"]?}"
      else
        env.response.status_code = 405
        return "Method not allowed"
      end

      # Set response status
      env.response.status_code = response.status_code

      # Copy content headers
      CONTENT_HEADERS.each do |header|
        if value = response.headers[header]?
          env.response.headers[header] = value
        end
      end

      # Add CORS headers
      env.response.headers["Access-Control-Allow-Origin"] = origin
      env.response.headers["Access-Control-Allow-Headers"] = ALLOWED_HEADERS.join(", ")
      env.response.headers["Access-Control-Allow-Methods"] = "GET, POST, OPTIONS"
      env.response.headers["Access-Control-Allow-Credentials"] = "true"

      # Return the response body
      # Wrap in error handling to suppress "Broken pipe" errors when client disconnects
      begin
        response.body
      rescue ex : IO::Error
        # Client disconnected (common during seeking/quality changes) - this is expected
        puts "[DEBUG] Proxy: Client disconnected (#{ex.message})"
        ""
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
