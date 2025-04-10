module Invidious::ConnectionPool
  # The base connection pool that provides the underlying logic that all connection pools are based around
  #
  # Uses `DB::Pool` for the pooling logic
  abstract struct BaseConnectionPool(PoolClient)
    # Creates a connection pool with the provided options, and client factory block.
    def initialize(
      *,
      max_capacity : Int32 = 5,
      idle_capacity : Int32? = nil,
      timeout : Float64 = 5.0,
      &client_factory : -> PoolClient
    )
      if idle_capacity.nil?
        idle_capacity = max_capacity
      end

      pool_options = DB::Pool::Options.new(
        initial_pool_size: 0,
        max_pool_size: max_capacity,
        max_idle_pool_size: idle_capacity,
        checkout_timeout: timeout
      )

      @pool = DB::Pool(PoolClient).new(pool_options, &client_factory)
    end

    # Returns the underlying `DB::Pool` object
    abstract def pool : DB::Pool(PoolClient)

    {% for method in %w[get post put patch delete head options] %}
      # Streaming API for {{method.id.upcase}} request.
      # The response will have its body as an `IO` accessed via `HTTP::Client::Response#body_io`.
      def {{method.id}}(*args, **kwargs, &)
        self.checkout do | client |
          client.{{method.id}}(*args, **kwargs) do | response |

            result = yield response
            return result

          ensure
            response.body_io?.try &. skip_to_end
          end
        end
      end

      # Executes a {{method.id.upcase}} request.
      # The response will have its body as a `String`, accessed via `HTTP::Client::Response#body`.
      def {{method.id}}(*args, **kwargs)
        self.checkout do | client |
          return client.{{method.id}}(*args, **kwargs)
        end
      end
    {% end %}

    # Checks out a client in the pool
    def checkout(&)
      # If a client has been deleted from the pool
      # we won't try to release it
      client_exists_in_pool = true

      http_client = pool.checkout

      # When the HTTP::Client connection is closed, the automatic reconnection
      # feature will create a new IO to connect to the server with
      #
      # This new TCP IO will be a direct connection to the server and will not go
      # through the proxy. As such we'll need to reinitialize the proxy connection

      http_client.proxy = make_configured_http_proxy_client() if CONFIG.http_proxy

      response = yield http_client
    rescue ex : DB::PoolTimeout
      # Failed to checkout a client
      raise ConnectionPool::PoolCheckoutError.new(ex.message)
    rescue ex
      # An error occurred with the client itself.
      # Delete the client from the pool and close the connection
      if http_client
        client_exists_in_pool = false
        @pool.delete(http_client)
        http_client.close
      end

      # Raise exception for outer methods to handle
      raise ConnectionPool::Error.new(ex.message, cause: ex)
    ensure
      pool.release(http_client) if http_client && client_exists_in_pool
    end
  end

  # A basic connection pool where each client within is set to connect to a single resource
  struct Pool < BaseConnectionPool(HTTP::Client)
    getter pool : DB::Pool(HTTP::Client)

    # Creates a pool of clients that connects to the given url, with the provided options.
    def initialize(
      url : URI,
      *,
      max_capacity : Int32 = 5,
      idle_capacity : Int32? = nil,
      timeout : Float64 = 5.0,
    )
      super(max_capacity: max_capacity, idle_capacity: idle_capacity, timeout: timeout) do
        next make_client(url, force_resolve: true)
      end
    end
  end

  # A modified connection pool for the interacting with Invidious companion.
  #
  # The main difference is that clients in this pool are created with different urls
  # based on what is randomly selected from the configured list of companions
  struct CompanionPool < BaseConnectionPool(HTTP::Client)
    getter pool : DB::Pool(HTTP::Client)

    # Creates a pool of clients with the provided options.
    def initialize(
      *,
      max_capacity : Int32 = 5,
      idle_capacity : Int32? = nil,
      timeout : Float64 = 5.0,
    )
      super(max_capacity: max_capacity, idle_capacity: idle_capacity, timeout: timeout) do
        companion = CONFIG.invidious_companion.sample
        next make_client(companion.private_url, use_http_proxy: false)
      end
    end
  end

  class Error < Exception
  end

  # Raised when the pool failed to get a client in time
  class PoolCheckoutError < Error
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
      pool = ConnectionPool::Pool.new(
        URI.parse("https://#{subdomain}.ytimg.com"),
        max_capacity: CONFIG.pool_size,
        idle_capacity: CONFIG.idle_pool_size,
        timeout: CONFIG.pool_checkout_timeout
      )
      YTIMG_POOLS[subdomain] = pool

      return pool
    end
  end
end
