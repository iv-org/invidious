module YTStructs
  # Struct to represent an InnerTube `"shelfRenderers"`
  #
  # A shelfRenderer renders divided sections on YouTube. IE "People also watched" in search results and
  # the various organizational sections in the channel home page. A separate one (richShelfRenderer) is used
  # for YouTube home. A shelfRenderer can also sometimes be expanded to show more content within it.
  #
  # See specs for example JSON response
  #
  # `shelfRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  class Category
    include DB::Serializable

    property title : String
    property contents : Array(SearchItem) | Array(Video)
    property url : String?
    property description_html : String
    property badges : Array(Tuple(String, String))?

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "title", self.title
        json.field "contents", self.contents
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
