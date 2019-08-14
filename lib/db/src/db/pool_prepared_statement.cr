module DB
  # Represents a statement to be executed in any of the connections
  # of the pool. The statement is not be executed in a prepared fashion.
  # The execution of the statement is retried according to the pool configuration.
  #
  # See `PoolStatement`
  class PoolPreparedStatement < PoolStatement
    # connections where the statement was prepared
    @connections = Set(WeakRef(Connection)).new

    def initialize(db : Database, query : String)
      super
      # Prepares a statement on some connection
      # otherwise the preparation is delayed until the first execution.
      # After the first initialization the connection must be released
      # it will be checked out when executing it.
      statement_with_retry &.release_connection
      # TODO use a round-robin selection in the pool so multiple sequentially
      #      initialized statements are assigned to different connections.
    end

    protected def do_close
      # TODO close all statements on all connections.
      # currently statements are closed when the connection is closed.

      # WHAT-IF the connection is busy? Should each statement be able to
      # deallocate itself when the connection is free.
      @connections.clear
    end

    # builds a statement over a real connection
    # the connection is registered in `@connections`
    private def build_statement : Statement
      clean_connections
      conn, existing = @db.checkout_some(@connections)
      begin
        stmt = conn.prepared.build(@query)
      rescue ex
        conn.release
        raise ex
      end
      @connections << WeakRef.new(conn) unless existing
      stmt
    end

    private def clean_connections
      # remove disposed or closed connections
      @connections.each do |ref|
        conn = ref.value
        if !conn || conn.closed?
          @connections.delete ref
        end
      end
    end
  end
end
