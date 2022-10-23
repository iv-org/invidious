require "./item_store"
require "json"
require "redis"

module Invidious::Cache
  class RedisItemStore < ItemStore
    @redis : Redis::PooledClient
    @node_name : String

    def initialize(url : URI, @node_name = "")
      @redis = Redis::PooledClient.new url
    end

    def fetch(key : String, *, as : T.class) : (T | Nil) forall T
      value = @redis.get(key)
      return nil if value.nil?
      return T.from_json(JSON::PullParser.new(value))
    end

    def store(key : String, value : CacheableItem, expires : Time::Span)
      @redis.set(key, value, ex: expires.to_i)
    end

    def delete(key : String)
      @redis.del(key)
    end

    def delete(keys : Array(String))
      @redis.del(keys)
    end

    def clear
      @redis.flushdb
    end
  end
end
