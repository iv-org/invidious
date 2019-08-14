require "../pq/*"

module PG
  class Connection < ::DB::Connection
    protected getter connection

    def initialize(context)
      super
      @connection = uninitialized PQ::Connection

      begin
        conn_info = PQ::ConnInfo.new(context.uri)
        @connection = PQ::Connection.new(conn_info)
        @connection.connect
      rescue ex
        raise DB::ConnectionRefused.new(cause: ex)
      end
    end

    def build_prepared_statement(query) : Statement
      Statement.new(self, query)
    end

    def build_unprepared_statement(query) : Statement
      Statement.new(self, query)
    end

    # Execute several statements. No results are returned.
    def exec_all(query : String) : Nil
      PQ::SimpleQuery.new(@connection, query)
      nil
    end

    # Set the callback block for notices and errors.
    def on_notice(&on_notice_proc : PQ::Notice ->)
      @connection.notice_handler = on_notice_proc
    end

    # Set the callback block for notifications from Listen/Notify.
    def on_notification(&on_notification_proc : PQ::Notification ->)
      @connection.notification_handler = on_notification_proc
    end

    protected def listen(channels : Enumerable(String))
      channels.each { |c| exec_all("LISTEN " + escape_identifier(c)) }
      listen
    end

    protected def listen
      spawn { @connection.read_async_frame_loop }
    end

    def version
      vers = connection.server_parameters["server_version"].partition(' ').first.split('.').map(&.to_i)
      {major: vers[0], minor: vers[1], patch: vers[2]? || 0}
    end

    protected def do_close
      super

      begin
        @connection.close
      rescue
      end
    end
  end
end
