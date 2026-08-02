# Minimal SOCKS5 (RFC 1928) client proxy support.
#
# Invidious already tunnels outbound requests through an HTTP CONNECT proxy via
# the `http_proxy` shard, which works by giving `HTTP::Client` a socket factory
# whose `#open(host, port, tls, ...)` returns a connected `IO`. This provides
# the same contract for SOCKS5 so it can be wired in the exact same way (see
# `configure_proxy` in `connection_pool.cr`).
#
# Supported: TCP CONNECT, IPv4/IPv6/hostname targets, optional username/password
# authentication (RFC 1929). Hostnames are sent as domain-type addresses so the
# proxy performs DNS resolution (SOCKS5h semantics) — this is what Invidious
# wants for region/geo handling. BIND and UDP ASSOCIATE are not implemented.
module SOCKS5
  VERSION = 0x05_u8

  # A SOCKS-level failure (bad handshake, rejected auth, refused CONNECT, ...).
  # Subclasses IO::Error so callers that rescue transport failures — including
  # Invidious's connection pool — treat it like any other connection error.
  class Error < IO::Error
  end

  class ProxyClient
    getter host : String
    getter port : Int32
    getter username : String?
    getter password : String?

    def initialize(@host : String, @port : Int32, *,
                   username : String? = nil, password : String? = nil)
      @username = username.presence
      @password = password.presence
    end

    # Opens a TCP connection to the SOCKS server, negotiates the tunnel to
    # `host`:`port`, and returns the resulting `IO` (TLS-wrapped when `tls` is
    # set). Mirrors `HTTP::Proxy::Client#open`.
    def open(host : String, port : Int32, tls = nil, *,
             dns_timeout = nil, connect_timeout = nil,
             read_timeout = nil, write_timeout = nil) : IO
      socket = TCPSocket.new(@host, @port, dns_timeout, connect_timeout)
      socket.read_timeout = read_timeout if read_timeout
      socket.write_timeout = write_timeout if write_timeout
      socket.sync = false

      begin
        negotiate(socket)
        request_connect(socket, host, port)
      rescue ex
        socket.close
        raise ex
      end

      {% if !flag?(:without_openssl) %}
        if tls
          socket = OpenSSL::SSL::Socket::Client.new(socket, context: tls, sync_close: true, hostname: host)
        end
      {% end %}

      socket
    end

    # Method-selection handshake, followed by username/password auth if the
    # server selects it.
    private def negotiate(socket : IO) : Nil
      methods = @username ? Bytes[0x00_u8, 0x02_u8] : Bytes[0x00_u8]

      socket.write Bytes[VERSION, methods.size.to_u8]
      socket.write methods
      socket.flush

      reply = uninitialized UInt8[2]
      socket.read_fully(reply.to_slice)
      raise Error.new("Unexpected SOCKS version in method reply") unless reply[0] == VERSION

      case reply[1]
      when 0x00_u8 then return # no authentication
      when 0x02_u8 then authenticate(socket)
      when 0xFF_u8 then raise Error.new("SOCKS proxy rejected all offered auth methods (credentials required?)")
      else              raise Error.new("SOCKS proxy selected unsupported auth method 0x#{reply[1].to_s(16)}")
      end
    end

    private def authenticate(socket : IO) : Nil
      user = @username
      raise Error.new("SOCKS proxy requested username/password auth but none is configured") unless user
      pass = @password || ""

      raise Error.new("SOCKS username exceeds 255 bytes") if user.bytesize > 255
      raise Error.new("SOCKS password exceeds 255 bytes") if pass.bytesize > 255

      io = IO::Memory.new
      io.write_byte 0x01_u8 # auth sub-negotiation version
      io.write_byte user.bytesize.to_u8
      io << user
      io.write_byte pass.bytesize.to_u8
      io << pass
      socket.write io.to_slice
      socket.flush

      reply = uninitialized UInt8[2]
      socket.read_fully(reply.to_slice)
      raise Error.new("Unexpected auth sub-negotiation version 0x#{reply[0].to_s(16)}") unless reply[0] == 0x01_u8
      raise Error.new("SOCKS authentication failed") unless reply[1] == 0x00_u8
    end

    private def request_connect(socket : IO, host : String, port : Int32) : Nil
      io = IO::Memory.new
      io.write_byte VERSION
      io.write_byte 0x01_u8 # CMD = CONNECT
      io.write_byte 0x00_u8 # RSV
      write_address(io, host)
      io.write_bytes(port.to_u16, IO::ByteFormat::BigEndian)
      socket.write io.to_slice
      socket.flush

      # Reply: VER REP RSV ATYP BND.ADDR BND.PORT
      header = uninitialized UInt8[4]
      socket.read_fully(header.to_slice)
      raise Error.new("Unexpected SOCKS version in connect reply") unless header[0] == VERSION
      raise Error.new(reply_message(header[1])) unless header[1] == 0x00_u8

      # BND.ADDR length depends on ATYP; drain it plus the 2-byte BND.PORT.
      # Invidious does not use the server-bound address.
      bnd_len =
        case header[3]
        when 0x01_u8 then 4  # IPv4
        when 0x04_u8 then 16 # IPv6
        when 0x03_u8         # domain: 1 length byte + N
          len = uninitialized UInt8[1]
          socket.read_fully(len.to_slice)
          len[0].to_i
        else
          raise Error.new("Unknown address type 0x#{header[3].to_s(16)} in SOCKS reply")
        end
      socket.skip(bnd_len + 2)
    end

    private def write_address(io : IO, host : String) : Nil
      if addr = parse_ip(host)
        case addr.family
        when .inet?
          io.write_byte 0x01_u8
          addr.address.split('.').each { |octet| io.write_byte octet.to_u8 }
          return
        when .inet6?
          io.write_byte 0x04_u8
          io.write ipv6_bytes(addr.address)
          return
        end
      end

      # Hostname: let the proxy resolve it (SOCKS5h).
      raise Error.new("Hostname exceeds 255 bytes: #{host}") if host.bytesize > 255
      io.write_byte 0x03_u8
      io.write_byte host.bytesize.to_u8
      io << host
    end

    # Returns the parsed address only for IP literals; hostnames return nil and
    # are sent as domain-type addresses. `.valid?` gates construction so we do
    # not raise (and catch) an exception on every hostname request.
    private def parse_ip(host : String) : Socket::IPAddress?
      Socket::IPAddress.new(host, 0) if Socket::IPAddress.valid?(host)
    end

    # Converts an IPv6 address string (possibly using "::" zero-compression)
    # into its 16 raw bytes. Embedded-IPv4 forms (e.g. "::ffff:1.2.3.4") are
    # not handled — they are rare as connection targets in Invidious.
    private def ipv6_bytes(addr : String) : Bytes
      head, sep, tail = addr.partition("::")
      head_groups = head.empty? ? [] of String : head.split(':')
      tail_groups = tail.empty? ? [] of String : tail.split(':')
      groups =
        if sep.empty?
          head_groups
        else
          head_groups + Array.new(8 - head_groups.size - tail_groups.size, "0") + tail_groups
        end
      raise Error.new("Malformed IPv6 address: #{addr}") unless groups.size == 8

      bytes = Bytes.new(16)
      groups.each_with_index do |group, i|
        value = group.to_u16(16)
        bytes[i * 2] = (value >> 8).to_u8
        bytes[i * 2 + 1] = (value & 0xff).to_u8
      end
      bytes
    end

    private def reply_message(code : UInt8) : String
      reason =
        case code
        when 0x01_u8 then "general SOCKS server failure"
        when 0x02_u8 then "connection not allowed by ruleset"
        when 0x03_u8 then "network unreachable"
        when 0x04_u8 then "host unreachable"
        when 0x05_u8 then "connection refused"
        when 0x06_u8 then "TTL expired"
        when 0x07_u8 then "command not supported"
        when 0x08_u8 then "address type not supported"
        else              "unknown error 0x#{code.to_s(16)}"
        end
      "SOCKS connect failed: #{reason}"
    end
  end
end

# Plug a `SOCKS5::ProxyClient` into an `HTTP::Client`, mirroring the `#proxy=`
# setter that the `http_proxy` shard adds for HTTP CONNECT proxies. SOCKS auth
# is performed in-band during the handshake, so (unlike the HTTP variant) no
# `Proxy-Authorization` request header is added.
class HTTP::Client
  def socks_proxy=(proxy_client : SOCKS5::ProxyClient) : Nil
    @io = proxy_client.open(
      host: @host,
      port: @port,
      tls: @tls,
      dns_timeout: @dns_timeout,
      connect_timeout: @connect_timeout,
      read_timeout: @read_timeout,
      write_timeout: @write_timeout,
    )
  rescue ex : IO::Error
    raise IO::Error.new("Failed to open SOCKS connection to #{@host}:#{@port} (#{ex.message})", cause: ex)
  end
end
