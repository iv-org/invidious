module YouTubeStructs
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
    property contents : Array(Renderer) | Array(Video)
    property url : String?
    property description_html : String
    property badges : Array(Tuple(String, String))?

    # Extracts all renderers out of the category's contents.
    def extract_renderers
      target = [] of Renderer

      @contents.each { |cate_i| target << cate_i if !cate_i.is_a? Video }

      return target
    end

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
