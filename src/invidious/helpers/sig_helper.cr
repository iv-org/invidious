require "uri"
require "socket"
require "socket/tcp_socket"
require "socket/unix_socket"

{% if flag?(:advanced_debug) %}
  require "io/hexdump"
{% end %}

private alias NetworkEndian = IO::ByteFormat::NetworkEndian

module Invidious::SigHelper
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
    getter string : String

    def initialize(str : String)
      raise Exception.new("SigHelper: String can't be empty") if str.empty?
      @string = str
    end

    def self.from_bytes(slice : Bytes)
      size = IO::ByteFormat::NetworkEndian.decode(UInt16, slice)
      if size == 0 # Error code
        raise Exception.new("SigHelper: Server encountered an error")
      end

      if (slice.bytesize - 2) != size
        raise Exception.new("SigHelper: String size mismatch")
      end

      if str = String.new(slice[2..])
        return self.new(str)
      else
        raise Exception.new("SigHelper: Can't read string from socket")
      end
    end

    def to_io(io)
      # `.to_u16` raises if there is an overflow during the conversion
      io.write_bytes(@string.bytesize.to_u16, NetworkEndian)
      io.write(@string.to_slice)
    end
  end

  private enum Opcode
    FORCE_UPDATE            = 0
    DECRYPT_N_SIGNATURE     = 1
    DECRYPT_SIGNATURE       = 2
    GET_SIGNATURE_TIMESTAMP = 3
    GET_PLAYER_STATUS       = 4
    PLAYER_UPDATE_TIMESTAMP = 5
  end

  private record Request,
    opcode : Opcode,
    payload : Payload?

  # ----------------------
  #  High-level functions
  # ----------------------

  class Client
    @mux : Multiplexor

    def initialize(uri_or_path)
      @mux = Multiplexor.new(uri_or_path)
    end

    # Forces the server to re-fetch the YouTube player, and extract the necessary
    # components from it (nsig function code, sig function code, signature timestamp).
    def force_update : UpdateStatus
      request = Request.new(Opcode::FORCE_UPDATE, nil)

      value = send_request(request) do |bytes|
        IO::ByteFormat::NetworkEndian.decode(UInt16, bytes)
      end

      case value
      when 0x0000 then return UpdateStatus::Error
      when 0xFFFF then return UpdateStatus::UpdateNotRequired
      when 0xF44F then return UpdateStatus::Updated
      else
        code = value.nil? ? "nil" : value.to_s(base: 16)
        raise Exception.new("SigHelper: Invalid status code received #{code}")
      end
    end

    # Decrypt a provided n signature using the server's current nsig function
    # code, and return the result (or an error).
    def decrypt_n_param(n : String) : String?
      request = Request.new(Opcode::DECRYPT_N_SIGNATURE, StringPayload.new(n))

      n_dec = self.send_request(request) do |bytes|
        StringPayload.from_bytes(bytes).string
      end

      return n_dec
    end

    # Decrypt a provided s signature using the server's current sig function
    # code, and return the result (or an error).
    def decrypt_sig(sig : String) : String?
      request = Request.new(Opcode::DECRYPT_SIGNATURE, StringPayload.new(sig))

      sig_dec = self.send_request(request) do |bytes|
        StringPayload.from_bytes(bytes).string
      end

      return sig_dec
    end

    # Return the signature timestamp from the server's current player
    def get_signature_timestamp : UInt64?
      request = Request.new(Opcode::GET_SIGNATURE_TIMESTAMP, nil)

      return self.send_request(request) do |bytes|
        IO::ByteFormat::NetworkEndian.decode(UInt64, bytes)
      end
    end

    # Return the current player's version
    def get_player : UInt32?
      request = Request.new(Opcode::GET_PLAYER_STATUS, nil)

      return self.send_request(request) do |bytes|
        has_player = (bytes[0] == 0xFF)
        player_version = IO::ByteFormat::NetworkEndian.decode(UInt32, bytes[1..4])
        has_player ? player_version : nil
      end
    end

    # Return when the player was last updated
    def get_player_timestamp : UInt64?
      request = Request.new(Opcode::PLAYER_UPDATE_TIMESTAMP, nil)

      return self.send_request(request) do |bytes|
        IO::ByteFormat::NetworkEndian.decode(UInt64, bytes)
      end
    end

    private def send_request(request : Request, &)
      channel = @mux.send(request)
      slice = channel.receive
      return yield slice
    rescue ex
      LOGGER.debug("SigHelper: Error when sending a request")
      LOGGER.trace(ex.inspect_with_backtrace)
      return nil
    end
  end

  # ---------------------
  #  Low level functions
  # ---------------------

  class Multiplexor
    alias TransactionID = UInt32
    record Transaction, channel = ::Channel(Bytes).new

    @prng = Random.new
    @mutex = Mutex.new
    @queue = {} of TransactionID => Transaction

    @conn : Connection
    @uri_or_path : String

    def initialize(@uri_or_path)
      @conn = Connection.new(uri_or_path)
      listen
    end

    def listen : Nil
      raise "Socket is closed" if @conn.closed?

      LOGGER.debug("SigHelper: Multiplexor listening")

      spawn do
        loop do
          begin
            receive_data
          rescue ex
            LOGGER.info("SigHelper: Connection to helper died with '#{ex.message}' trying to reconnect...")
            # We close the socket because for some reason is not closed.
            @conn.close
            loop do
              begin
                @conn = Connection.new(@uri_or_path)
                LOGGER.info("SigHelper: Reconnected to SigHelper!")
              rescue ex
                LOGGER.debug("SigHelper: Reconnection to helper unsuccessful with error '#{ex.message}'. Retrying")
                sleep 500.milliseconds
                next
              end
              break if !@conn.closed?
            end
          end
          Fiber.yield
        end
      end
    end

    def send(request : Request)
      transaction = Transaction.new
      transaction_id = @prng.rand(TransactionID)

      # Add transaction to queue
      @mutex.synchronize do
        # On a 32-bits random integer, this should never happen. Though, just in case, ...
        if @queue[transaction_id]?
          raise Exception.new("SigHelper: Duplicate transaction ID! You got a shiny pokemon!")
        end

        @queue[transaction_id] = transaction
      end

      write_packet(transaction_id, request)

      return transaction.channel
    end

    def receive_data
      transaction_id, slice = read_packet

      @mutex.synchronize do
        if transaction = @queue.delete(transaction_id)
          # Remove transaction from queue and send data to the channel
          transaction.channel.send(slice)
          LOGGER.trace("SigHelper: Transaction unqueued and data sent to channel")
        else
          raise Exception.new("SigHelper: Received transaction was not in queue")
        end
      end
    end

    # Read a single packet from the socket
    private def read_packet : {TransactionID, Bytes}
      # Header
      transaction_id = @conn.read_bytes(UInt32, NetworkEndian)
      length = @conn.read_bytes(UInt32, NetworkEndian)

      LOGGER.trace("SigHelper: Recv transaction 0x#{transaction_id.to_s(base: 16)} / length #{length}")

      if length > 67_000
        raise Exception.new("SigHelper: Packet longer than expected (#{length})")
      end

      # Payload
      slice = Bytes.new(length)
      @conn.read(slice) if length > 0

      LOGGER.trace("SigHelper: payload = #{slice}")
      LOGGER.trace("SigHelper: Recv transaction 0x#{transaction_id.to_s(base: 16)} - Done")

      return transaction_id, slice
    end

    # Write a single packet to the socket
    private def write_packet(transaction_id : TransactionID, request : Request)
      LOGGER.trace("SigHelper: Send transaction 0x#{transaction_id.to_s(base: 16)} / opcode #{request.opcode}")

      io = IO::Memory.new(1024)
      io.write_bytes(request.opcode.to_u8, NetworkEndian)
      io.write_bytes(transaction_id, NetworkEndian)

      if payload = request.payload
        payload.to_io(io)
      end

      @conn.send(io)
      @conn.flush

      LOGGER.trace("SigHelper: Send transaction 0x#{transaction_id.to_s(base: 16)} - Done")
    end
  end

  class Connection
    @socket : UNIXSocket | TCPSocket

    {% if flag?(:advanced_debug) %}
      @io : IO::Hexdump
    {% end %}

    def initialize(host_or_path : String)
      case host_or_path
      when .starts_with?('/')
        # Make sure that the file exists
        if File.exists?(host_or_path)
          @socket = UNIXSocket.new(host_or_path)
        else
          raise Exception.new("SigHelper: '#{host_or_path}' no such file")
        end
      when .starts_with?("tcp://")
        uri = URI.parse(host_or_path)
        @socket = TCPSocket.new(uri.host.not_nil!, uri.port.not_nil!)
      else
        uri = URI.parse("tcp://#{host_or_path}")
        @socket = TCPSocket.new(uri.host.not_nil!, uri.port.not_nil!)
      end
      LOGGER.info("SigHelper: Using helper at '#{host_or_path}'")

      {% if flag?(:advanced_debug) %}
        @io = IO::Hexdump.new(@socket, output: STDERR, read: true, write: true)
      {% end %}

      @socket.sync = false
      @socket.blocking = false
    end

    def closed? : Bool
      return @socket.closed?
    end

    def close : Nil
      @socket.close if !@socket.closed?
    end

    def flush(*args, **options)
      @socket.flush(*args, **options)
    end

    def send(*args, **options)
      @socket.send(*args, **options)
    end

    # Wrap IO functions, with added debug tooling if needed
    {% for function in %w(read read_bytes write write_bytes) %}
      def {{function.id}}(*args, **options)
        {% if flag?(:advanced_debug) %}
          @io.{{function.id}}(*args, **options)
        {% else %}
          @socket.{{function.id}}(*args, **options)
        {% end %}
      end
    {% end %}
  end
end
