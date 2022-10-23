require "json"

module Invidious::Cache
  # Including this module allows the includer object to be cached.
  # The object will automatically inherit from JSON::Serializable.
  module CacheableItem
    include JSON::Serializable
  end
end
