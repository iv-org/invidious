require "./item_store"
require "json"
require "redis"

module Invidious::Cache
  class RedisItemStore < ItemStore
    @redis : Redis::PooledClient

    def initialize(url : URI)
      @redis = Redis::PooledClient.new(url: url.to_s)
    end

    def fetch(key : String) : String?
      return @redis.get(key)
    end

    def store(key : String, value : CacheableItem | String, expires : Time::Span)
      value = value.to_json if value.is_a?(CacheableItem)
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
