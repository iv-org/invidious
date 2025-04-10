module Invidious::ConnectionPool
  # A connection pool to reuse `HTTP::Client` connections
  struct Pool
    getter pool : DB::Pool(HTTP::Client)

    # Creates a connection pool with the provided options, and client factory block.
    def initialize(
      *,
      max_capacity : Int32 = 5,
      timeout : Float64 = 5.0,
      @reinitialize_proxy : Bool = true, # Whether or not http-proxy should be reinitialized on checkout
      &client_factory : -> HTTP::Client
    )
      pool_options = DB::Pool::Options.new(
        initial_pool_size: 0,
        max_pool_size: max_capacity,
        max_idle_pool_size: max_capacity,
        checkout_timeout: timeout
      )

      @pool = DB::Pool(HTTP::Client).new(pool_options, &client_factory)
    end

    {% for method in %w[get post put patch delete head options] %}
      # Streaming API for {{method.id.upcase}} request.
      # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
      def {{method.id}}(*args, **kwargs, &)
        self.checkout_with_retry do | client |
          client.{{method.id}}(*args, **kwargs) do | response |
            return yield response
          ensure
            response.body_io?.try &.skip_to_end
          end
        end
      end

      # Executes a {{method.id.upcase}} request.
      # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
      def {{method.id}}(*args, **kwargs)
        self.checkout_with_retry do | client |
          return client.{{method.id}}(*args, **kwargs)
        end
      end
    {% end %}

    # Checks out a client in the pool
    #
    # This method will NOT delete a client that has errored from the pool.
    # Use `#checkout_with_retry` to ensure that the pool does not get poisoned.
    def checkout(&)
      pool.checkout do |client|
        # When the HTTP::Client connection is closed, the automatic reconnection
        # feature will create a new IO to connect to the server with
        #
        # This new TCP IO will be a direct connection to the server and will not go
        # through the proxy. As such we'll need to reinitialize the proxy connection
        client.proxy = make_configured_http_proxy_client() if @reinitialize_proxy && CONFIG.http_proxy

        response = yield client

        return response
      rescue ex : DB::PoolTimeout
        # Failed to checkout a client
        raise ConnectionPool::PoolCheckoutError.new(ex.message)
      end
    end

    # Checks out a client from the pool; retries only if a connection is lost or refused
    #
    # Will cycle through all of the existing connections at no delay, but any new connections
    # that is created will be subject to a delay.
    #
    # The first attempt to make a new connection will not have the delay, but all subsequent
    # attempts will.
    #
    # To `DB::Pool#retry`:
    #   - `DB::PoolResourceLost` means that the connection has been lost
    #     and should be deleted from the pool.
    #
    #   - `DB::PoolResourceRefused` means a new connection was intended to be created but failed
    #     but the client can be safely released back into the pool to try again later with
    #
    # See the following code of `crystal-db` for more information
    #
    # https://github.com/crystal-lang/crystal-db/blob/023dc5de90c11927656fc747601c5f08ea3c906f/src/db/pool.cr#L191
    # https://github.com/crystal-lang/crystal-db/blob/023dc5de90c11927656fc747601c5f08ea3c906f/src/db/pool_statement.cr#L41
    # https://github.com/crystal-lang/crystal-db/blob/023dc5de90c11927656fc747601c5f08ea3c906f/src/db/pool_prepared_statement.cr#L13
    #
    def checkout_with_retry(&)
      @pool.retry do
        self.checkout do |client|
          begin
            return yield client
          rescue ex : IO::TimeoutError
            LOGGER.trace("Client: #{client} has failed to complete the request. Retrying with a new client")
            raise DB::PoolResourceRefused.new
          rescue ex : InfoException
            raise ex
          rescue ex : Exception
            # Any other errors should cause the client to be deleted from the pool

            # This means that the client is closed and needs to be deleted from the pool
            # due its inability to reconnect
            if ex.message == "This HTTP::Client cannot be reconnected"
              LOGGER.trace("Checked out client is closed and cannot be reconnected. Trying the next retry attempt...")
            else
              LOGGER.error("Client: #{client} has encountered an error: #{ex} #{ex.message} and will be removed from the pool")
            end

            raise DB::PoolResourceLost(HTTP::Client).new(client)
          end
        end
      rescue ex : DB::PoolRetryAttemptsExceeded
        raise PoolRetryAttemptsExceeded.new
      end
    end
  end

  class Error < Exception
  end

  # Raised when the pool failed to get a client in time
  class PoolCheckoutError < Error
  end

  # Raised when too many retries
  class PoolRetryAttemptsExceeded < Error
  end

  # Mapping of subdomain => Invidious::ConnectionPool::Pool
  # This is needed as we may need to access arbitrary subdomains of ytimg
  private YTIMG_POOLS = {} of String => ConnectionPool::Pool

  # Fetches a HTTP pool for the specified subdomain of ytimg.com
  #
  # Creates a new one when the specified pool for the subdomain does not exist
  def self.get_ytimg_pool(subdomain)
    if pool = YTIMG_POOLS[subdomain]?
      return pool
    else
      LOGGER.info("ytimg_pool: Creating a new HTTP pool for \"https://#{subdomain}.ytimg.com\"")
      url = URI.parse("https://#{subdomain}.ytimg.com")

      pool = ConnectionPool::Pool.new(
        max_capacity: CONFIG.pool_size,
        timeout: CONFIG.pool_checkout_timeout
      ) do
        next make_client(url, force_resolve: true)
      end

      YTIMG_POOLS[subdomain] = pool

      return pool
    end
  end
end
