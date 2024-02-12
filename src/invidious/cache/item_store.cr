require "./cacheable_item"

module Invidious::Cache
  # Abstract class from which any cached element should inherit
  # Note: class is used here, instead of a module, in order to benefit
  # from various compiler checks (e.g methods must be implemented)
  abstract class ItemStore
    # Retrieves an item from the store
    # Returns nil if item wasn't found or is expired
    abstract def fetch(key : String)

    # Stores a given item into cache
    abstract def store(key : String, value : String, expires : Time::Span)

    # Prematurely deletes item(s) from the cache
    abstract def delete(key : String)
    abstract def delete(keys : Array(String))

    # Removes all the items stored in the cache
    abstract def clear
  end
end
