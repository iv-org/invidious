require "./item_store"

module Invidious::Cache
  class NullItemStore < ItemStore
    def initialize
    end

    def fetch(key : String) : String?
      return nil
    end

    def store(key : String, value : CacheableItem | String, expires : Time::Span)
    end

    def delete(key : String)
    end

    def delete(keys : Array(String))
    end

    def clear
    end
  end
end
