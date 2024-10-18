# Override of the TCPSocket and HTTP::Client classes in order to allow an
# IP family to be selected for domains that resolve to both IPv4 and
# IPv6 addresses.
#
class TCPSocket
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil, blocking = false, family = Socket::Family::UNSPEC)
    Addrinfo.tcp(host, port, timeout: dns_timeout, family: family) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol, blocking)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end
end

# :ditto:
class HTTP::Client
  property family : Socket::Family = Socket::Family::UNSPEC

  # Override stdlib to automatically initialize proxy if configured
  #
  # Accurate as of crystal 1.12.1

  def initialize(@host : String, port = nil, tls : TLSContext = nil)
    check_host_only(@host)

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

    @port = (port || (@tls ? 443 : 80)).to_i

    self.proxy = make_configured_http_proxy_client() if CONFIG.http_proxy
  end

  def initialize(@io : IO, @host = "", @port = 80)
    @reconnect = false

    self.proxy = make_configured_http_proxy_client() if CONFIG.http_proxy
  end

  private def io
    io = @io
    return io if io
    unless @reconnect
      raise "This HTTP::Client cannot be reconnected"
    end

    hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
    io = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout, family: @family
    io.read_timeout = @read_timeout if @read_timeout
    io.write_timeout = @write_timeout if @write_timeout
    io.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        tcp_socket = io
        begin
          io = OpenSSL::SSL::Socket::Client.new(tcp_socket, context: tls, sync_close: true, hostname: @host.rchop('.'))
        rescue exc
          # don't leak the TCP socket when the SSL connection failed
          tcp_socket.close
          raise exc
        end
      end
    {% end %}

    @io = io
  end
end

# Mute the ClientError exception raised when a connection is flushed.
# This happends when the connection is unexpectedly closed by the client.
#
class HTTP::Server::Response
  class Output
    private def unbuffered_flush
      @io.flush
    rescue ex : IO::Error
      unbuffered_close
    end
  end
end

# TODO: Document this override
#
class PG::ResultSet
  def field(index = @column_index)
    @fields.not_nil![index]
  end
end
