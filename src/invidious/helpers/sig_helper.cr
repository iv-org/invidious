require "uri"
require "socket"
require "socket/tcp_socket"
require "socket/unix_socket"

private alias NetworkEndian = IO::ByteFormat::NetworkEndian

class Invidious::SigHelper
  enum UpdateStatus
    Updated
    UpdateNotRequired
    Error
  end

  # -------------------
  #  Payload types
  # -------------------

  abstract struct Payload
  end

  struct StringPayload < Payload
    getter value : String

    def initialize(str : String)
      raise Exception.new("SigHelper: String can't be empty") if str.empty?
      @value = str
    end

    def self.from_io(io : IO)
      size = io.read_bytes(UInt16, NetworkEndian)
      if size == 0 # Error code
        raise Exception.new("SigHelper: Server encountered an error")
      end

      if str = io.gets(limit: size)
        return self.new(str)
      else
        raise Exception.new("SigHelper: Can't read string from socket")
      end
    end

    def self.to_io(io : IO)
      # `.to_u16` raises if there is an overflow during the conversion
      io.write_bytes(@value.bytesize.to_u16, NetworkEndian)
      io.write(@value.to_slice)
    end
  end

  private enum Opcode
    FORCE_UPDATE = 0
    DECRYPT_N_SIGNATURE = 1
    DECRYPT_SIGNATURE = 2
    GET_SIGNATURE_TIMESTAMP = 3
    GET_PLAYER_STATUS = 4
  end

  private struct Request
    def initialize(@opcode : Opcode, @payload : Payload?)
    end
  end

  # ----------------------
  #  High-level functions
  # ----------------------

  module Client
    # Forces the server to re-fetch the YouTube player, and extract the necessary
    # components from it (nsig function code, sig function code, signature timestamp).
    def force_update : UpdateStatus
      request = Request.new(Opcode::FORCE_UPDATE, nil)

      value = send_request(request) do |io|
        io.read_bytes(UInt16, NetworkEndian)
      end

      case value
      when 0x0000 then return UpdateStatus::Error
      when 0xFFFF then return UpdateStatus::UpdateNotRequired
      when 0xF44F then return UpdateStatus::Updated
      else
        raise Exception.new("SigHelper: Invalid status code received")
      end
    end

    # Decrypt a provided n signature using the server's current nsig function
    # code, and return the result (or an error).
    def decrypt_n_param(n : String) : String
      request = Request.new(Opcode::DECRYPT_N_SIGNATURE, StringPayload.new(n))

      n_dec = send_request(request) do |io|
        StringPayload.from_io(io).string
      rescue ex
        LOGGER.debug(ex.message)
        nil
      end

      return n_dec
    end

    # Decrypt a provided s signature using the server's current sig function
    # code, and return the result (or an error).
    def decrypt_sig(sig : String) : String?
      request = Request.new(Opcode::DECRYPT_SIGNATURE, StringPayload.new(sig))

      sig_dec = send_request(request) do |io|
        StringPayload.from_io(io).string
      rescue ex
        LOGGER.debug(ex.message)
        nil
      end

      return sig_dec
    end

    # Return the signature timestamp from the server's current player
    def get_sts : UInt64?
      request = Request.new(Opcode::GET_SIGNATURE_TIMESTAMP, nil)

      return send_request(request) do |io|
        io.read_bytes(UInt64, NetworkEndian)
      end
    end

    # Return the signature timestamp from the server's current player
    def get_player : UInt32?
      request = Request.new(Opcode::GET_PLAYER_STATUS, nil)

      send_request(request) do |io|
        has_player = io.read_bytes(UInt8) == 0xFF
        player_version = io.read_bytes(UInt32, NetworkEndian)
      end

      return has_player ? player_version : nil
    end

    private def send_request(request : Request, &block : IO)
      channel = Multiplexor.send(request)
      data_io = channel.receive
      return yield data_io
    rescue ex
      LOGGER.debug(ex.message)
      return nil
    end
  end

  # ---------------------
  #  Low level functions
  # ---------------------

  class Multiplexor
    alias TransactionID = UInt32
    record Transaction, channel = ::Channel(Bytes).new

    @prng  = Random.new
    @mutex = Mutex.new
    @queue = {} of TransactionID => Transaction

    @conn : Connection

    INSTANCE = new

    def initialize
      @conn = Connection.new
      listen
    end

    def initialize(url : String)
      @conn = Connection.new(url)
      listen
    end

    def listen : Nil
      raise "Socket is closed" if @conn.closed?

      # TODO: reopen socket if unexpectedly closed
      spawn do
        loop do
          receive_data
          Fiber.sleep
        end
      end
    end

    def self.send(request : Request)
      transaction = Transaction.new
      transaction_id = @prng.rand(TransactionID)

      # Add transaction to queue
      @mutex.synchronize do
        # On a 64-bits random integer, this should never happen. Though, just in case, ...
        if @queue[transaction_id]?
          raise Exception.new("SigHelper: Duplicate transaction ID! You got a shiny pokemon!")
        end

        @queue[transaction_id] = transaction
      end

      write_packet(transaction_id, request)

      return transaction.channel
    end

    def receive_data : Payload
      # Read a single packet from socker
      transaction_id, data_io = read_packet

      # Remove transaction from queue
      @mutex.synchronize do
        transaction = @queue.delete(transaction_id)
      end

      # Send data to the channel
      transaction.channel.send(data)
    end

    # Read a single packet from the socket
    private def read_packet : {TransactionID, IO}
      # Header
      transaction_id = @conn.read_u32
      length = conn.read_u32

      if length > 67_000
        raise Exception.new("SigHelper: Packet longer than expected (#{length})")
      end

      # Payload
      data_io = IO::Memory.new(1024)
      IO.copy(@conn, data_io, limit: length)

      # data = Bytes.new()
      # conn.read(data)

      return transaction_id, data_io
    end

    # Write a single packet to the socket
    private def write_packet(transaction_id : TransactionID, request : Request)
      @conn.write_int(request.opcode)
      @conn.write_int(transaction_id)
      request.payload.to_io(@conn)
    end
  end

  class Connection
    @socket : UNIXSocket | TCPSocket
    @mutex = Mutex.new

    def initialize(host_or_path : String)
      if host_or_path.empty?
        host_or_path = default_path

      begin
        case host_or_path
        when.starts_with?('/')
          @socket = UNIXSocket.new(host_or_path)
        when .starts_with?("tcp://")
          uri = URI.new(host_or_path)
          @socket = TCPSocket.new(uri.host, uri.port)
        else
          uri = URI.new("tcp://#{host_or_path}")
          @socket = TCPSocket.new(uri.host, uri.port)
        end

        socket.sync = false
      rescue ex
        raise ConnectionError.new("Connection error", cause: ex)
      end
    end

    private default_path
      return "/tmp/inv_sig_helper.sock"
    end

    def closed? : Bool
      return @socket.closed?
    end

    def close : Nil
      if @socket.closed?
        raise Exception.new("SigHelper: Can't close socket, it's already closed")
      else
        @socket.close
      end
    end

    def gets(*args, **options)
      @socket.gets(*args, **options)
    end

    def read_bytes(*args, **options)
      @socket.read_bytes(*args, **options)
    end

    def write(*args, **options)
      @socket.write(*args, **options)
    end

    def write_bytes(*args, **options)
      @socket.write_bytes(*args, **options)
    end
  end
end
