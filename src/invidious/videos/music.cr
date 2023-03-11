require "json"

struct VideoMusic
  include JSON::Serializable

  property album : String
  property artist : String
  property license : String

  def initialize(@album : String, @artist : String, @license : String)
  end
end
