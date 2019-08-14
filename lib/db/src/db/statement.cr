module DB
  # Common interface for connection based statements
  # and for connection pool statements.
  module StatementMethods
    include Disposable

    protected def do_close
    end

    # See `QueryMethods#scalar`
    def scalar(*args)
      query(*args) do |rs|
        rs.each do
          return rs.read
        end
      end

      raise "no results"
    end

    # See `QueryMethods#query`
    def query(*args)
      rs = query(*args)
      yield rs ensure rs.close
    end

    # See `QueryMethods#exec`
    abstract def exec : ExecResult
    # See `QueryMethods#exec`
    abstract def exec(*args) : ExecResult
    # See `QueryMethods#exec`
    abstract def exec(args : Array) : ExecResult

    # See `QueryMethods#query`
    abstract def query : ResultSet
    # See `QueryMethods#query`
    abstract def query(*args) : ResultSet
    # See `QueryMethods#query`
    abstract def query(args : Array) : ResultSet
  end

  # Represents a query in a `Connection`.
  # It should be created by `QueryMethods`.
  #
  # ### Note to implementors
  #
  # 1. Subclass `Statements`
  # 2. `Statements` are created from a custom driver `Connection#prepare` method.
  # 3. `#perform_query` executes a query that is expected to return a `ResultSet`
  # 4. `#perform_exec` executes a query that is expected to return an `ExecResult`
  # 6. `#do_close` is called to release the statement resources.
  abstract class Statement
    include StatementMethods

    # :nodoc:
    getter connection

    def initialize(@connection : Connection)
    end

    def release_connection
      @connection.release_from_statement
    end

    # See `QueryMethods#exec`
    def exec : DB::ExecResult
      perform_exec_and_release(Slice(Any).empty)
    end

    # See `QueryMethods#exec`
    def exec(args : Array) : DB::ExecResult
      perform_exec_and_release(args)
    end

    # See `QueryMethods#exec`
    def exec(*args)
      # TODO better way to do it
      perform_exec_and_release(args)
    end

    # See `QueryMethods#query`
    def query : DB::ResultSet
      perform_query_with_rescue Tuple.new
    end

    # See `QueryMethods#query`
    def query(args : Array) : DB::ResultSet
      perform_query_with_rescue args
    end

    # See `QueryMethods#query`
    def query(*args)
      perform_query_with_rescue args
    end

    private def perform_exec_and_release(args : Enumerable) : ExecResult
      return perform_exec(args)
    ensure
      release_connection
    end

    private def perform_query_with_rescue(args : Enumerable) : ResultSet
      return perform_query(args)
    rescue e : Exception
      # Release connection only when an exception occurs during the query
      # execution since we need the connection open while the ResultSet is open
      release_connection
      raise e
    end

    protected abstract def perform_query(args : Enumerable) : ResultSet
    protected abstract def perform_exec(args : Enumerable) : ExecResult
  end
end
