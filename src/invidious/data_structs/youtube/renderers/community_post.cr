module YouTubeStructs
  struct CommunityPoll
    include DB::Serializable

    property choices : Array(String) # Pull questions
    property total_votes : Int32

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "type", "community_poll"
        json.field "choices", self.choices.to_json
        json.field "total_votes", self.total_votes
      end
    end

    def to_json(locale, json : JSON::Builder | Nil = nil)
      if json
        to_json(locale, json)
      else
        JSON.build do |json|
          to_json(locale, json)
        end
      end
    end
  end

  struct CommunityPost
    include DB::Serializable

    # Author information
    property author : String
    property author_thumbnail : String
    property author_id : String

    # Community post data
    property post_id : String
    property contents : String
    property attachment : (VideoRenderer | PlaylistRenderer | CommunityPoll | String)? # string is image/gif
    property likes : Int32
    property published : Time

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "type", "community_post"

        json.field "author", self.author
        json.field "authorId", self.author_id
        json.field "author_thumbnail", self.author_thumbnail
        json.field "authorUrl", "/channel/#{self.author_id}"

        json.field "contents", self.contents
        json.field "attachment", self.attachment.to_json
        json.field "likes", self.likes
        json.field "published", self.published.to_unix
      end
    end

    def to_json(locale, json : JSON::Builder | Nil = nil)
      if json
        to_json(locale, json)
      else
        JSON.build do |json|
          to_json(locale, json)
        end
      end
    end
  end
end
