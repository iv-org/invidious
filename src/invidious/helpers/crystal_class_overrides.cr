# Override of the TCPSocket and HTTP::Client classes in order to allow an
# IP family to be selected for domains that resolve to both IPv4 and
# IPv6 addresses.
#
class TCPSocket
  def initialize(host : String, port, dns_timeout = nil, connect_timeout = nil, family = Socket::Family::UNSPEC)
    Addrinfo.tcp(host, port, timeout: dns_timeout, family: family) do |addrinfo|
      super(addrinfo.family, addrinfo.type, addrinfo.protocol)
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

  private def io
    io = @io
    return io if io
    unless @reconnect
      raise "This HTTP::Client cannot be reconnected"
    end

    hostname = @host.starts_with?('[') && @host.ends_with?(']') ? @host[1..-2] : @host
    io = TCPSocket.new hostname, @port, @dns_timeout, @connect_timeout, @family
    io.read_timeout = @read_timeout if @read_timeout
    io.write_timeout = @write_timeout if @write_timeout
    io.sync = false

    {% if !flag?(:without_openssl) %}
      if tls = @tls
        tcp_socket = io
        begin
          io = OpenSSL::SSL::Socket::Client.new(tcp_socket, context: tls, sync_close: true, hostname: @host)
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

# Mute the ClientError exception raised when a
# connection is unexpectedly closed by the client.
#
class HTTP::Server::Response
  class Output
    # Run unbuffered_write() from stdlib but catch IO::Error
    # HTTP::Server::ClientError exceptions.
    private def unbuffered_write(slice : Bytes)
      begin
        previous_def
      rescue ex : IO::Error
      rescue ex : HTTP::Server::ClientError
      end
    end

    # Same for unbuffered_flush()
    private def unbuffered_flush
      begin
        previous_def
      rescue ex : IO::Error
      rescue ex : HTTP::Server::ClientError
      end
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
