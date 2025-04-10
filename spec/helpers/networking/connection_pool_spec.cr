# Due to the way that specs are handled this file cannot be run
# together with everything else without causing a compile time error
#
# TODO: Allow running different isolated spec through make
#
# For now run this with `crystal spec -p spec/helpers/networking/connection_pool_spec.cr -Drunning_by_self`
{% skip_file unless flag?(:running_by_self) %}

# Based on https://github.com/jgaskins/http_client/blob/958cf56064c0d31264a117467022b90397eb65d7/spec/http_client_spec.cr
require "wait_group"
require "uri"
require "http"
require "http/server"
require "http_proxy"

require "db"
require "pg"
require "spectator"

require "../../load_config"
require "../../../src/invidious/helpers/crystal_class_overrides"
require "../../../src/invidious/connection/*"

server = HTTP::Server.new do |context|
  request = context.request
  response = context.response

  case {request.method, request.path}
  when {"GET", "/get"}
    response << "get"
  when {"POST", "/post"}
    response.status = :created
    response << "post"
  when {"GET", "/sleep"}
    duration = request.query_params["duration_sec"].to_i.seconds
    sleep duration
  end
end

spawn server.listen 12345

Fiber.yield

Spectator.describe Invidious::ConnectionPool do
  describe "Pool" do
    it "Can make a requests through standard HTTP methods" do
      pool = Invidious::ConnectionPool::Pool.new(URI.parse("http://localhost:12345"), max_capacity: 100)

      expect(pool.get("/get").body).to eq("get")
      expect(pool.post("/post").body).to eq("post")
    end

    it "Can make streaming requests" do
      pool = Invidious::ConnectionPool::Pool.new(URI.parse("http://localhost:12345"), max_capacity: 100)

      expect(pool.get("/get") { |r| r.body_io.gets_to_end }).to eq("get")
      expect(pool.get("/post") { |r| r.body }).to eq("")
      expect(pool.post("/post") { |r| r.body_io.gets_to_end }).to eq("post")
    end

    # it "Can checkout a client" do
    # end

    it "Allows concurrent requests" do
      pool = Invidious::ConnectionPool::Pool.new(URI.parse("http://localhost:12345"), max_capacity: 100)
      responses = [] of HTTP::Client::Response

      WaitGroup.wait do |wg|
        100.times do
          wg.spawn { responses << pool.get("/get") }
        end
      end

      expect(responses.map(&.body)).to eq(["get"] * 100)
    end

    it "Raises on checkout timeout" do
      pool = Invidious::ConnectionPool::Pool.new(URI.parse("http://localhost:12345"), max_capacity: 2, timeout: 0.01)

      # Long running requests
      2.times do
        spawn { pool.get("/sleep?duration_sec=2") }
      end

      Fiber.yield

      expect { pool.get("/get") }.to raise_error(Invidious::ConnectionPool::Error)
    end

    it "Raises when an error is encounter" do
      pool = Invidious::ConnectionPool::Pool.new(URI.parse("http://localhost:12345"), max_capacity: 100, timeout: 0.01)
      expect { pool.get("/get") { raise IO::Error.new } }.to raise_error(Invidious::ConnectionPool::Error)
    end
  end
end
