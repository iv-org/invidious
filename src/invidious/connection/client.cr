module Invidious
  class IVTCPSocket < TCPSocket
    def initialize(host : String, port, dns_timeout = nil, connect_timeout = nil, blocking = false, family = Socket::Family::UNSPEC)
      Addrinfo.tcp(host, port, timeout: dns_timeout, family: family) do |addrinfo|
        super(addrinfo.family, addrinfo.type, addrinfo.protocol, blocking)
        connect(addrinfo, timeout: connect_timeout) do |error|
          close
          error
        end
      end
    end
  end

  class HTTPClient < HTTP::Client
    def initialize(uri : URI, tls : TLSContext = nil, allow_auto_reconnect : Bool = true)
      tls = HTTP::Client.tls_flag(uri, tls)
      host = HTTP::Client.validate_host(uri)

      super(host, uri.port, tls)

      @reconnect = allow_auto_reconnect
    end

    def initialize(uri : URI, tls : TLSContext = nil, force_resolve : Socket::Family = Socket::Family::UNSPEC)
      tls = HTTP::Client.tls_flag(uri, tls)

      {% if flag?(:without_openssl) %}
        if tls
          raise "HTTP::Client TLS is disabled because `-D without_openssl` was passed at compile time"
        end
        @tls = nil
      {% else %}
        @tls = case tls
               when true
                 OpenSSL::SSL::Context::Client.new
               when OpenSSL::SSL::Context::Client
                 tls
               when false, nil
                 nil
               end
      {% end %}

      @host = HTTP::Client.validate_host(uri)
      @port = (uri.port || (@tls ? 443 : 80)).to_i

      tcp_socket = IVTCPSocket.new(
        host: @host,
        port: @port,
        family: force_resolve,
      )

      if tls = @tls
        begin
          @io = OpenSSL::SSL::Socket::Client.new(tcp_socket, context: tls, sync_close: true, hostname: @host.rchop('.'))
        rescue ex
          # Don't leak the TCP socket when the SSL connection failed
          tcp_socket.close
          raise ex
        end
      else
        @io = tcp_socket
      end

      @reconnect = false
    end
  end
end

def add_yt_headers(request)
  request.headers.delete("User-Agent") if request.headers["User-Agent"] == "Crystal"
  request.headers["User-Agent"] ||= "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/128.0.0.0 Safari/537.36"

  request.headers["Accept-Charset"] ||= "ISO-8859-1,utf-8;q=0.7,*;q=0.7"
  request.headers["Accept"] ||= "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
  request.headers["Accept-Language"] ||= "en-us,en;q=0.5"

  # Preserve original cookies and add new YT consent cookie for EU servers
  request.headers["Cookie"] = "#{request.headers["cookie"]?}; CONSENT=PENDING+#{Random.rand(100..999)}"
  if !CONFIG.cookies.empty?
    request.headers["Cookie"] = "#{(CONFIG.cookies.map { |c| "#{c.name}=#{c.value}" }).join("; ")}; #{request.headers["cookie"]?}"
  end
end

def make_client(
  url : URI,
  region = nil,
  force_resolve : Bool = false,
  force_youtube_headers : Bool = true,
  use_http_proxy : Bool = true,
  allow_auto_reconnect : Bool = true,
)
  if CONFIG.http_proxy && use_http_proxy
    client = Invidious::HTTPClient.new(url)
    client.proxy = make_configured_http_proxy_client() if CONFIG.http_proxy && use_http_proxy
  elsif force_resolve
    client = Invidious::HTTPClient.new(url, force_resolve: CONFIG.force_resolve)
  else
    client = Invidious::HTTPClient.new(url, allow_auto_reconnect: allow_auto_reconnect)
  end

  client.before_request { |r| add_yt_headers(r) } if url.host.try &.ends_with?("youtube.com") || force_youtube_headers
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds

  return client
end

def make_client(url : URI, region = nil, force_resolve : Bool = false, use_http_proxy : Bool = true, &)
  client = make_client(url, region, force_resolve: force_resolve, use_http_proxy: use_http_proxy)
  begin
    yield client
  ensure
    client.close
  end
end

def make_configured_http_proxy_client
  # This method is only called when configuration for an HTTP proxy are set
  config_proxy = CONFIG.http_proxy.not_nil!

  return HTTP::Proxy::Client.new(
    config_proxy.host,
    config_proxy.port,

    username: config_proxy.user,
    password: config_proxy.password,
  )
end
