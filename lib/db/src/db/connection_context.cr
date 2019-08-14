module DB
  module ConnectionContext
    # Returns the uri with the connection settings to the database
    abstract def uri : URI

    # Return whether the statements should be prepared by default
    abstract def prepared_statements? : Bool

    # Indicates that the *connection* was permanently closed
    # and should not be used in the future.
    abstract def discard(connection : Connection)

    # Indicates that the *connection* is no longer needed
    # and can be reused in the future.
    abstract def release(connection : Connection)
  end

  # :nodoc:
  class SingleConnectionContext
    include ConnectionContext

    getter uri : URI
    getter? prepared_statements : Bool

    def initialize(@uri : URI)
      params = HTTP::Params.parse(uri.query || "")
      @prepared_statements = DB.fetch_bool(params, "prepared_statements", true)
    end

    def discard(connection : Connection)
    end

    def release(connection : Connection)
    end
  end
end
