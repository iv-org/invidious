class TCPSocket
  def initialize(host, port, dns_timeout = nil, connect_timeout = nil, family = Socket::Family::UNSPEC)
    Addrinfo.tcp(host, port, timeout: dns_timeout, family: family) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)
      connect(addrinfo, timeout: connect_timeout) do |error|
        close
        error
      end
    end
  end
end

class HTTP::Client
  property family : Socket::Family = Socket::Family::UNSPEC

  private def socket
    socket = @socket
    return socket if socket

    hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
    socket = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout, @family
    socket.read_timeout = @read_timeout if @read_timeout
    socket.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        socket = OpenSSL::SSL::Socket::Client.new(socket, context: tls, sync_close: true, hostname: @host)
      end
    {% end %}

    @socket = socket
  end
end

class HTTP::Server::Response
  class Output
    private def unbuffered_flush
      @io.flush
    rescue ex : IO::Error
      unbuffered_close
    end
  end
end

class PG::ResultSet
  def field(index = @column_index)
    @fields.not_nil![index]
  end
end
