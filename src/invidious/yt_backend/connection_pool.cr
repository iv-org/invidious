require "lsquic"

struct YoutubeConnectionPool
  property! url : URI
  property! capacity : Int32
  property! timeout : Float64
  property pool : DB::Pool(QUIC::Client | HTTP::Client)

  def initialize(url : URI, @capacity = 5, @timeout = 5.0, use_quic = true)
    @url = url
    @pool = build_pool(use_quic)
  end

  def client(region = nil, &block)
    if region
      conn = make_client(url, region)
      response = yield conn
    else
      conn = pool.checkout
      begin
        response = yield conn
      rescue ex
        conn.close
        conn = QUIC::Client.new(url)
        conn.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::INET
        conn.family = Socket::Family::INET if conn.family == Socket::Family::UNSPEC
        conn.before_request { |r| add_yt_headers(r) } if url.host == "www.youtube.com"
        response = yield conn
      ensure
        pool.release(conn)
      end
    end

    response
  end

  private def build_pool(use_quic)
    DB::Pool(QUIC::Client | HTTP::Client).new(initial_pool_size: 0, max_pool_size: capacity, max_idle_pool_size: capacity, checkout_timeout: timeout) do
      if use_quic
        conn = QUIC::Client.new(url)
      else
        conn = HTTP::Client.new(url)
      end
      conn.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::INET
      conn.family = Socket::Family::INET if conn.family == Socket::Family::UNSPEC
      conn.before_request { |r| add_yt_headers(r) } if url.host == "www.youtube.com"
      conn
    end
  end
end

def make_client(url : URI, region = nil)
  # TODO: Migrate any applicable endpoints to QUIC
  client = HTTPClient.new(url, OpenSSL::SSL::Context::Client.insecure)
  client.family = (url.host == "www.youtube.com") ? CONFIG.force_resolve : Socket::Family::UNSPEC
  client.before_request { |r| add_yt_headers(r) } if url.host == "www.youtube.com"
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds

  if region
    PROXY_LIST[region]?.try &.sample(40).each do |proxy|
      begin
        proxy = HTTPProxy.new(proxy_host: proxy[:ip], proxy_port: proxy[:port])
        client.set_proxy(proxy)
        break
      rescue ex
      end
    end
  end

  return client
end

def make_client(url : URI, region = nil, &block)
  client = make_client(url, region)
  begin
    yield client
  ensure
    client.close
  end
end
