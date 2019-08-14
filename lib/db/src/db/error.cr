module DB
  class Error < Exception
  end

  class MappingException < Error
  end

  class PoolTimeout < Error
  end

  class PoolRetryAttemptsExceeded < Error
  end

  # Raised when an established connection is lost
  # probably due to socket/network issues.
  # It is used by the connection pool retry logic.
  class ConnectionLost < Error
    getter connection : Connection

    def initialize(@connection)
    end
  end

  # Raised when a connection is unable to be established
  # probably due to socket/network or configuration issues.
  # It is used by the connection pool retry logic.
  class ConnectionRefused < Error
  end

  class Rollback < Error
  end
end
