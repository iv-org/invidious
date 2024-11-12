module Invidious::ConnectionPool
  # The base connection pool that provides the underlying logic that all connection pools are based around
  #
  # Uses `DB::Pool` for the pooling logic
  abstract struct BaseConnectionPool(PoolClient)
    # Returns the max size of the connection pool
    getter max_capacity : Int32

    # Returns the configured checkout time out
    getter timeout : Float64

    # Creates a connection pool with the provided options
    def initialize(
      @max_capacity : Int32 = 5,
      @idle_capacity : Int32? = nil,
      @timeout : Float64 = 5.0,
    )
      @pool = build_pool()
    end

    # Returns the idle capacity for the connection pool; if unset this is the same as `max_capacity`.
    #
    # This means that when idle capacity is unset the pool will keep all connections around forever, all the
    # way until it reaches max capacity.
    def idle_capacity : Int32
      if (idle = @idle_capacity).nil?
        return @max_capacity
      end

      return idle
    end

    # Returns the underlying `DB::Pool` object
    abstract def pool : DB::Pool(PoolClient)

    # Checks out a client from the pool
    def client(&)
      pool.checkout do |http_client|
        # Proxy needs to be reinstated every time we get a client from the pool
        http_client.proxy = make_configured_http_proxy_client() if CONFIG.http_proxy

        response = yield http_client

        return response
      rescue ex
        # Prevent broken client from being checked back into the pool
        pool.delete(http_client)
        raise ConnectionPool::Error.new(ex.message, cause: ex)
      end
    rescue ex : DB::PoolTimeout
      # Failed to checkout a client
      raise ConnectionPool::Error.new(ex.message, cause: ex)
    end

    # Builds a connection pool
    private abstract def build_pool : DB::Pool(PoolClient)

    # Creates a `DB::Pool::Options` used for constructing `DB::Pool`
    private def pool_options : DB::Pool::Options
      return DB::Pool::Options.new(
        initial_pool_size: 0,
        max_pool_size: max_capacity,
        max_idle_pool_size: idle_capacity,
        checkout_timeout: timeout
      )
    end
  end

  # A basic connection pool where each client within is set to connect to a single resource
  struct Pool < BaseConnectionPool(HTTP::Client)
    # The url each client within the pool will connect to
    getter url : URI
    getter pool : DB::Pool(HTTP::Client)

    # Creates a pool of clients that connects to the given url, with the provided options.
    def initialize(
      url : URI,
      *,
      @max_capacity : Int32 = 5,
      @idle_capacity : Int32? = nil,
      @timeout : Float64 = 5.0,
    )
      @url = url
      @pool = build_pool()
    end

    # :inherit:
    private def build_pool : DB::Pool(HTTP::Client)
      return DB::Pool(HTTP::Client).new(pool_options) do
        make_client(url, force_resolve: true)
      end
    end
  end

  # A modified connection pool for the interacting with Invidious companion.
  #
  # The main difference is that clients in this pool are created with different urls
  # based on what is randomly selected from the configured list of companions
  struct CompanionPool < BaseConnectionPool(HTTP::Client)
    getter pool : DB::Pool(HTTP::Client)

    # :inherit:
    private def build_pool : DB::Pool(HTTP::Client)
      return DB::Pool(HTTP::Client).new(pool_options) do
        companion = CONFIG.invidious_companion.sample
        make_client(companion.private_url, use_http_proxy: false)
      end
    end
  end

  class Error < Exception
  end

  # Mapping of subdomain => Invidious::ConnectionPool::Pool
  # This is needed as we may need to access arbitrary subdomains of ytimg
  private YTIMG_POOLS = {} of String => Invidious::ConnectionPool::Pool

  # Fetches a HTTP pool for the specified subdomain of ytimg.com
  #
  # Creates a new one when the specified pool for the subdomain does not exist
  def self.get_ytimg_pool(subdomain)
    if pool = YTIMG_POOLS[subdomain]?
      return pool
    else
      LOGGER.info("ytimg_pool: Creating a new HTTP pool for \"https://#{subdomain}.ytimg.com\"")
      pool = Invidious::ConnectionPool::Pool.new(
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
