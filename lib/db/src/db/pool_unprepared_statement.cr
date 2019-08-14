module DB
  # Represents a statement to be executed in any of the connections
  # of the pool. The statement is not be executed in a non prepared fashion.
  # The execution of the statement is retried according to the pool configuration.
  #
  # See `PoolStatement`
  class PoolUnpreparedStatement < PoolStatement
    def initialize(db : Database, query : String)
      super
    end

    protected def do_close
      # unprepared statements do not need to be release in each connection
    end

    # builds a statement over a real connection
    private def build_statement : Statement
      conn = @db.pool.checkout
      begin
        conn.unprepared.build(@query)
      rescue ex
        conn.release
        raise ex
      end
    end
  end
end
