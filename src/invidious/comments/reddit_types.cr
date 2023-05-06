class RedditThing
  include JSON::Serializable

  property kind : String
  property data : RedditComment | RedditLink | RedditMore | RedditListing
end

class RedditComment
  include JSON::Serializable

  property author : String
  property body_html : String
  property replies : RedditThing | String
  property score : Int32
  property depth : Int32
  property permalink : String

  @[JSON::Field(converter: RedditComment::TimeConverter)]
  property created_utc : Time

  module TimeConverter
    def self.from_json(value : JSON::PullParser) : Time
      Time.unix(value.read_float.to_i)
    end

    def self.to_json(value : Time, json : JSON::Builder)
      json.number(value.to_unix)
    end
  end
end

struct RedditLink
  include JSON::Serializable

  property author : String
  property score : Int32
  property subreddit : String
  property num_comments : Int32
  property id : String
  property permalink : String
  property title : String
end

struct RedditMore
  include JSON::Serializable

  property children : Array(String)
  property count : Int32
  property depth : Int32
end

class RedditListing
  include JSON::Serializable

  property children : Array(RedditThing)
  property modhash : String
end
