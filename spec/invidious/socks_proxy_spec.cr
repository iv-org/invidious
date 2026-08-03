require "http/client"
require "socket"
require "openssl"
require "spectator"
require "../../src/invidious/yt_backend/socks_proxy"

# A minimal in-process SOCKS5 server used to assert exactly what bytes our
# client emits (auth negotiation, CONNECT address type, target host/port) and
# that the returned IO is a usable tunnel. It handles a single connection.
class MockSocksServer
  record Captured,
    methods : Array(UInt8),
    username : String?,
    password : String?,
    atyp : UInt8,
    address : Bytes,
    port : UInt16

  # Every server registers itself so specs can close all of them in after_each,
  # even when an assertion fails before an explicit close.
  @@instances = [] of MockSocksServer

  def self.close_all
    @@instances.each(&.close)
    @@instances.clear
  end

  getter port : Int32

  def initialize(@require_auth : Bool = false,
                 @valid_user : String? = nil,
                 @valid_pass : String? = nil,
                 @echo : Bool = false,
                 @http_reply : String? = nil)
    @server = TCPServer.new("127.0.0.1", 0)
    @port = @server.local_address.port
    @captured = Channel(Captured | Exception).new(1)
    @@instances << self
    spawn run
  end

  # Blocks until the handshake completed, returning what the server observed.
  def wait : Captured
    result = @captured.receive
    raise result if result.is_a?(Exception)
    result
  end

  def close
    @server.close
  end

  private def run
    socket = @server.accept
    begin
      captured = handshake(socket)
      @captured.send(captured)

      if reply = @http_reply
        # Drain the request headers, then send a canned HTTP response.
        while (line = socket.gets) && line != ""
        end
        socket << reply
        socket.flush
      elsif @echo
        if line = socket.gets
          socket << "PONG:#{line}\n"
          socket.flush
        end
      end
    rescue ex
      @captured.send(ex)
    ensure
      socket.close
    end
  end

  private def handshake(io : IO) : Captured
    raise "unexpected version" unless io.read_byte == 0x05_u8
    nmethods = io.read_byte.not_nil!
    method_bytes = Bytes.new(nmethods)
    io.read_fully(method_bytes)
    methods = method_bytes.to_a

    username = nil
    password = nil

    if @require_auth
      unless methods.includes?(0x02_u8)
        io.write(Bytes[0x05_u8, 0xFF_u8]); io.flush
        raise "no acceptable auth methods offered"
      end

      io.write(Bytes[0x05_u8, 0x02_u8]); io.flush

      raise "unexpected auth version" unless io.read_byte == 0x01_u8
      ulen = io.read_byte.not_nil!
      ubuf = Bytes.new(ulen); io.read_fully(ubuf); username = String.new(ubuf)
      plen = io.read_byte.not_nil!
      pbuf = Bytes.new(plen); io.read_fully(pbuf); password = String.new(pbuf)

      ok = username == @valid_user && password == @valid_pass
      io.write(Bytes[0x01_u8, ok ? 0x00_u8 : 0x01_u8]); io.flush
      raise "authentication rejected" unless ok
    else
      io.write(Bytes[0x05_u8, 0x00_u8]); io.flush
    end

    raise "unexpected request version" unless io.read_byte == 0x05_u8
    raise "expected CONNECT command" unless io.read_byte == 0x01_u8
    io.read_byte # RSV
    atyp = io.read_byte.not_nil!

    address =
      case atyp
      when 0x01_u8
        buf = Bytes.new(4); io.read_fully(buf); buf
      when 0x04_u8
        buf = Bytes.new(16); io.read_fully(buf); buf
      when 0x03_u8
        dlen = io.read_byte.not_nil!
        buf = Bytes.new(dlen); io.read_fully(buf); buf
      else
        raise "unknown address type"
      end

    port_bytes = Bytes.new(2); io.read_fully(port_bytes)
    port = IO::ByteFormat::BigEndian.decode(UInt16, port_bytes)

    # Reply: success, BND.ADDR/PORT = 0.0.0.0:0
    io.write(Bytes[0x05_u8, 0x00_u8, 0x00_u8, 0x01_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8, 0_u8])
    io.flush

    Captured.new(methods, username, password, atyp, address, port)
  end
end

Spectator.describe SOCKS5::ProxyClient do
  after_each { MockSocksServer.close_all }

  it "sends a hostname target as a domain-type address (ATYP 0x03) for proxy-side resolution" do
    server = MockSocksServer.new
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    io = client.open("www.youtube.com", 443)
    captured = server.wait

    expect(captured.methods).to eq([0x00_u8]) # only no-auth offered
    expect(captured.atyp).to eq(0x03_u8)
    expect(String.new(captured.address)).to eq("www.youtube.com")
    expect(captured.port).to eq(443_u16)

    io.close
  end

  it "encodes an IPv4 literal target as ATYP 0x01" do
    server = MockSocksServer.new
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    io = client.open("142.250.72.174", 80)
    captured = server.wait

    expect(captured.atyp).to eq(0x01_u8)
    expect(captured.address.to_a).to eq([142_u8, 250_u8, 72_u8, 174_u8])
    expect(captured.port).to eq(80_u16)

    io.close
  end

  it "encodes an IPv6 literal target as ATYP 0x04 (with :: zero-compression)" do
    server = MockSocksServer.new
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    io = client.open("2607:f8b0::200e", 443)
    captured = server.wait

    expected = Bytes[0x26, 0x07, 0xf8, 0xb0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0x20, 0x0e]
    expect(captured.atyp).to eq(0x04_u8)
    expect(captured.address.to_a).to eq(expected.to_a)
    expect(captured.port).to eq(443_u16)

    io.close
  end

  it "offers username/password auth and authenticates (RFC 1929)" do
    server = MockSocksServer.new(require_auth: true, valid_user: "alice", valid_pass: "s3cret")
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port, username: "alice", password: "s3cret")

    io = client.open("example.com", 80)
    captured = server.wait

    expect(captured.methods.includes?(0x02_u8)).to be_true
    expect(captured.username).to eq("alice")
    expect(captured.password).to eq("s3cret")

    io.close
  end

  it "raises when the proxy rejects the supplied credentials" do
    server = MockSocksServer.new(require_auth: true, valid_user: "alice", valid_pass: "s3cret")
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port, username: "alice", password: "wrong")

    expect { client.open("example.com", 80) }.to raise_error(SOCKS5::Error, /authentication failed/)
  end

  it "raises when the proxy requires auth but no credentials are configured" do
    server = MockSocksServer.new(require_auth: true, valid_user: "alice", valid_pass: "s3cret")
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    expect { client.open("example.com", 80) }.to raise_error(SOCKS5::Error)
  end

  it "returns a usable tunnel IO after the handshake" do
    server = MockSocksServer.new(echo: true)
    client = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    io = client.open("example.com", 80)
    server.wait

    io << "hi\n"
    io.flush
    expect(io.gets).to eq("PONG:hi")

    io.close
  end

  it "drives a real HTTP::Client request through the SOCKS tunnel via #socks_proxy=" do
    server = MockSocksServer.new(http_reply: "HTTP/1.1 204 No Content\r\nContent-Length: 0\r\n\r\n")

    client = HTTP::Client.new("example.com", 80)
    client.socks_proxy = SOCKS5::ProxyClient.new("127.0.0.1", server.port)

    response = client.get("/")
    captured = server.wait

    expect(captured.atyp).to eq(0x03_u8)
    expect(String.new(captured.address)).to eq("example.com")
    expect(captured.port).to eq(80_u16)
    expect(response.status_code).to eq(204)

    client.close
  end
end
