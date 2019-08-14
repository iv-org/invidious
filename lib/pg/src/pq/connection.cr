require "uri"
require "digest/md5"
require "socket"
require "socket/tcp_socket"
require "socket/unix_socket"
require "openssl"
require "openssl/hmac"

module PQ
  record Notification, pid : Int32, channel : String, payload : String

  # :nodoc:
  class Connection
    getter soc : UNIXSocket | TCPSocket | OpenSSL::SSL::Socket::Client
    getter server_parameters : Hash(String, String)
    property notice_handler : Notice ->
    property notification_handler : Notification ->

    def initialize(@conninfo : ConnInfo)
      @mutex = Mutex.new
      @server_parameters = Hash(String, String).new
      @established = false
      @notice_handler = Proc(Notice, Void).new { }
      @notification_handler = Proc(Notification, Void).new { }

      begin
        if @conninfo.host[0] == '/'
          soc = UNIXSocket.new(@conninfo.host)
        else
          soc = TCPSocket.new(@conninfo.host, @conninfo.port)
        end
        soc.sync = false
      rescue e
        raise ConnectionError.new("Cannot establish connection", cause: e)
      end

      @soc = soc
      negotiate_ssl if @soc.is_a?(TCPSocket)
    end

    private def negotiate_ssl
      write_i32 8
      write_i32 80877103
      @soc.flush
      serv_ssl = case c = @soc.read_char
                 when 'S' then true
                 when 'N' then false
                 else
                   raise ConnectionError.new(
                     "Unexpected SSL response from server: #{c.inspect}")
                 end

      if serv_ssl
        ctx = OpenSSL::SSL::Context::Client.new
        ctx.verify_mode = OpenSSL::SSL::VerifyMode::NONE # currently emulating sslmode 'require' not verify_ca or verify_full
        if sslcert = @conninfo.sslcert
          ctx.certificate_chain = sslcert
        end
        if sslkey = @conninfo.sslkey
          ctx.private_key = sslkey
        end
        if sslrootcert = @conninfo.sslrootcert
          ctx.ca_certificates = sslrootcert
        end
        @soc = OpenSSL::SSL::Socket::Client.new(@soc, context: ctx, sync_close: true)
      end

      if @conninfo.sslmode == :require && !@soc.is_a?(OpenSSL::SSL::Socket::Client)
        close
        raise ConnectionError.new("sslmode=require and server did not establish SSL")
      end
    end

    def close
      synchronize do
        return if @soc.closed?
        send_terminate_message
        @soc.close
      end
    end

    def synchronize
      @mutex.synchronize { yield }
    end

    private def write_i32(i : Int32)
      soc.write_bytes i, IO::ByteFormat::NetworkEndian
    end

    private def write_i32(i)
      write_i32 i.to_i32
    end

    private def write_i16(i : Int16)
      soc.write_bytes i, IO::ByteFormat::NetworkEndian
    end

    private def write_i16(i)
      write_i16 i.to_i16
    end

    private def write_null
      soc.write_byte 0_u8
    end

    private def write_byte(byte)
      soc.write_byte byte
    end

    private def write_chr(chr : Char)
      soc.write_byte chr.ord.to_u8
    end

    def read_i32
      soc.read_bytes(Int32, IO::ByteFormat::NetworkEndian)
    end

    def read_i16
      soc.read_bytes(Int16, IO::ByteFormat::NetworkEndian)
    end

    def read_bytes(count)
      data = Slice(UInt8).new(count)
      soc.read_fully(data)
      data
    end

    def skip_bytes(count)
      soc.skip(count)
    end

    def startup(args)
      len = args.reduce(0) { |acc, arg| acc + arg.size + 1 }
      write_i32 len + 8 + 1
      write_i32 0x30000
      args.each { |arg| soc << arg << '\0' }
      write_null
      soc.flush
    end

    def read_data_row
      size = read_i32
      ncols = read_i16
      row = Array(Slice(UInt8)?).new(ncols.to_i32) do
        col_size = read_i32
        if col_size == -1
          nil
        else
          read_bytes(col_size)
        end
      end

      yield row
    end

    def read
      read(soc.read_char)
    end

    def read(frame_type)
      frame = read_one_frame(frame_type)
      handle_async_frames(frame) ? read : frame
    end

    def read_async_frame_loop
      loop do
        break if @soc.closed?
        begin
          handle_async_frames(read_one_frame(soc.read_char))
        rescue e : Errno
          e.errno == Errno::EBADF && @soc.closed? ? break : raise e
        end
      end
    end

    private def read_one_frame(frame_type)
      size = read_i32
      slice = read_bytes(size - 4)
      Frame.new(frame_type.not_nil!, slice) # .tap { |f| p f }
    end

    private def handle_async_frames(frame)
      if frame.is_a?(Frame::ErrorResponse)
        handle_error frame
        true
      elsif frame.is_a?(Frame::NotificationResponse)
        handle_notification frame
        true
      elsif frame.is_a?(Frame::NoticeResponse)
        handle_notice frame
        true
      elsif frame.is_a?(Frame::ParameterStatus)
        handle_parameter frame
        true
      else
        false
      end
    end

    private def handle_error(error_frame : Frame::ErrorResponse)
      expect_frame Frame::ReadyForQuery if @established
      notice_handler.call(error_frame.as_notice)
      raise PQError.new(error_frame.fields)
    end

    private def handle_notice(frame : Frame::NoticeResponse)
      notice_handler.call(frame.as_notice)
    end

    private def handle_notification(frame : Frame::NotificationResponse)
      notification_handler.call(frame.as_notification)
    end

    private def handle_parameter(frame : Frame::ParameterStatus)
      @server_parameters[frame.key] = frame.value
      case frame.key
      when "client_encoding"
        if frame.value.upcase != "UTF8"
          raise ConnectionError.new(
            "Only UTF8 is supported for client_encoding, got: #{frame.value.inspect}")
        end
      when "integer_datetimes"
        if frame.value != "on"
          raise ConnectionError.new(
            "Only on is supported for integer_datetimes, got: #{frame.value.inspect}")
        end
      end
    end

    def connect
      startup_args = [
        "user", @conninfo.user,
        "database", @conninfo.database,
        "application_name", "crystal",
        "client_encoding", "utf8",
      ]

      startup startup_args

      auth_frame = expect_frame Frame::Authentication
      handle_auth auth_frame

      loop do
        case frame = read
        when Frame::BackendKeyData
          # do nothing
        when Frame::ReadyForQuery
          break
        else
          raise "Expected BackendKeyData or ReadyForQuery but was #{frame}"
        end
      end

      @established = true
    end

    private def handle_auth(auth_frame)
      case auth_frame.type
      when Frame::Authentication::Type::OK
        # no op
      when Frame::Authentication::Type::CleartextPassword
        raise "Cleartext auth is not supported"
      when Frame::Authentication::Type::SASL
        handle_auth_sasl auth_frame.body
      when Frame::Authentication::Type::MD5Password
        handle_auth_md5 auth_frame.body
      else
        raise ConnectionError.new(
          "unsupported authentication method: #{auth_frame.type}"
        )
      end
    end

    struct SamlContext
      property client_first_msg : String
      property client_first_msg_size : Int32

      def initialize(@password : String)
        @client_nonce = Random::Secure.urlsafe_base64(18)
        @client_first_msg = "n,,n=,r=#{@client_nonce}"
        @client_first_msg_size = @client_first_msg.bytesize
      end

      def generate_client_final_message(body)
        server_first_msg = String.new(body)
        params = server_first_msg.split(',')
        r = params.find { |p| p[0] == 'r' }.not_nil![2..-1]
        s = params.find { |p| p[0] == 's' }.not_nil![2..-1]
        i = params.find { |p| p[0] == 'i' }.not_nil![2..-1].to_i
        raise ConnectionError.new("SASL: scram server nonce does not start with client nonce") unless r.starts_with?(@client_nonce)

        client_final_msg_without_proof = "c=biws,r=#{r}"
        salted_pass = OpenSSL::PKCS5.pbkdf2_hmac(@password, Base64.decode(s), i, algorithm: OpenSSL::Algorithm::SHA256, key_size: 32)
        server_key = OpenSSL::HMAC.digest(:sha256, salted_pass, "Server Key")
        client_key = OpenSSL::HMAC.digest(:sha256, salted_pass, "Client Key")
        auth_msg = "n=,r=#{@client_nonce},#{server_first_msg},#{client_final_msg_without_proof}"
        client_sig = OpenSSL::HMAC.digest(:sha256, sha256(client_key), auth_msg)
        @server_sig = OpenSSL::HMAC.digest(:sha256, server_key, auth_msg)
        proof = Base64.strict_encode Slice.new(32) { |i| client_key[i].as(UInt8) ^ client_sig[i].as(UInt8) }
        "#{client_final_msg_without_proof},p=#{proof}"
      end

      def verify_server_signature(server_message)
        server_sig = Base64.strict_encode @server_sig.not_nil!
        raise ConnectionError.new("server signature does not match") unless server_message[2..-1] == server_sig.to_slice
      end

      private def sha256(key)
        OpenSSL::Digest.new("SHA256").update(key).digest
      end
    end

    private def handle_auth_sasl(mechanism_list)
      # it is possible in the future for postgres to send something other than
      # SCRAM-SHA-265, but for now ignore the mechanism_list

      ctx = SamlContext.new(@conninfo.password || "")

      # send client-first-message
      write_chr 'p' # SASLInitialResponse
      write_i32 4 + 13 + 1 + 4 + ctx.client_first_msg_size
      soc << "SCRAM-SHA-256"
      write_null
      write_i32 ctx.client_first_msg_size
      soc << ctx.client_first_msg
      soc.flush

      # receive server-first-message
      continue = expect_frame Frame::Authentication
      final_msg = ctx.generate_client_final_message(continue.body)

      # send client-final-message
      write_chr 'p'
      write_i32 4 + final_msg.bytesize
      soc << final_msg
      soc.flush

      # receive server-final-message
      final = expect_frame Frame::Authentication
      ctx.verify_server_signature(final.body)
      # receive OK
      expect_frame Frame::Authentication
    end

    private def handle_auth_md5(salt)
      inner = Digest::MD5.hexdigest("#{@conninfo.password}#{@conninfo.user}")

      pass = Digest::MD5.hexdigest do |ctx|
        ctx.update(inner.to_unsafe, inner.bytesize.to_u32)
        ctx.update(salt.to_unsafe, salt.bytesize.to_u32)
      end

      send_password_message "md5#{pass}"
      expect_frame Frame::Authentication
    end

    def read_next_row_start
      type = soc.read_char

      while type == 'N'
        # NoticeResponse
        frame = read_one_frame('N')
        handle_async_frames(frame)
        type = soc.read_char
      end

      if type == 'D'
        true
      else
        expect_frame Frame::CommandComplete, type
        false
      end
    end

    def read_all_data_rows
      type = soc.read_char
      loop do
        break unless type == 'D'
        read_data_row { |row| yield row }
        type = soc.read_char
      end
      expect_frame Frame::CommandComplete, type
    end

    def expect_frame(frame_class, type = nil)
      f = type ? read(type) : read
      raise "Expected #{frame_class} but got #{f}" unless frame_class === f
      frame_class.cast(f)
    end

    def send_password_message(password)
      write_chr 'p'
      if password
        write_i32 password.size + 4 + 1
        soc << password
      else
        write_i32 4 + 1
      end
      write_null
      soc.flush
    end

    def send_query_message(query)
      write_chr 'Q'
      write_i32 query.bytesize + 4 + 1
      soc << query
      write_null
      soc.flush
    end

    def send_parse_message(query)
      write_chr 'P'
      write_i32 query.bytesize + 4 + 1 + 2 + 1
      write_null # prepared statment name
      soc << query
      write_i16 0 # don't give any param types
      write_null
    end

    def send_bind_message(params)
      nparams = params.size
      total_size = params.reduce(0) do |acc, p|
        acc + 4 + (p.size == -1 ? 0 : p.size)
      end

      write_chr 'B'
      write_i32 4 + 1 + 1 + 2 + (2*nparams) + 2 + total_size + 2 + 2
      write_null        # unnamed destination portal
      write_null        # unnamed prepared statment
      write_i16 nparams # number of params format codes to follow
      params.each { |p| write_i16 p.format }
      write_i16 nparams # number of params to follow
      params.each do |p|
        write_i32 p.size
        p.slice.each { |byte| write_byte byte }
      end
      write_i16 1 # number of following return types (1 means apply next for all)
      write_i16 1 # all results as binary
    end

    def send_describe_portal_message
      write_chr 'D'
      write_i32 4 + 1 + 1
      write_chr 'P'
      write_null
    end

    def send_execute_message
      write_chr 'E'
      write_i32 4 + 1 + 4
      write_null  # unnamed portal
      write_i32 0 # unlimited maximum rows
    end

    def send_sync_message
      write_chr 'S'
      write_i32 4
      soc.flush
    end

    def send_terminate_message
      write_chr 'X'
      write_i32 4
    end
  end
end
