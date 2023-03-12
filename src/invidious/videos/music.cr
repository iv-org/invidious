require "json"

struct VideoMusic
  include JSON::Serializable

  property song : String
  property album : String
  property artist : String
  property license : String

  def initialize(@song : String, @album : String, @artist : String, @license : String)
  end
end
