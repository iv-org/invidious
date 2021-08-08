module YouTubeStructs
  # Struct to represent an InnerTube `"videoRenderer"`
  #
  # A videoRenderer renders a video to click on within the YouTube and Invidious UI. It is **not**
  # the watchable video itself.
  #
  # See specs for example JSON response
  #
  # `videoRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  struct VideoRenderer
    include DB::Serializable

    property title : String
    property id : String
    property author : String
    property ucid : String
    property published : Time
    property views : Int64
    property description_html : String
    property length_seconds : Int32
    property live_now : Bool
    property paid : Bool
    property premium : Bool
    property premiere_timestamp : Time?

    def to_xml(auto_generated, query_params, xml : XML::Builder)
      query_params["v"] = self.id

      xml.element("entry") do
        xml.element("id") { xml.text "yt:video:#{self.id}" }
        xml.element("yt:videoId") { xml.text self.id }
        xml.element("yt:channelId") { xml.text self.ucid }
        xml.element("title") { xml.text self.title }
        xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?#{query_params}")

        xml.element("author") do
          if auto_generated
            xml.element("name") { xml.text self.author }
            xml.element("uri") { xml.text "#{HOST_URL}/channel/#{self.ucid}" }
          else
            xml.element("name") { xml.text author }
            xml.element("uri") { xml.text "#{HOST_URL}/channel/#{ucid}" }
          end
        end

        xml.element("content", type: "xhtml") do
          xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
            xml.element("a", href: "#{HOST_URL}/watch?#{query_params}") do
              xml.element("img", src: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg")
            end

            xml.element("p", style: "word-break:break-word;white-space:pre-wrap") { xml.text html_to_content(self.description_html) }
          end
        end

        xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

        xml.element("media:group") do
          xml.element("media:title") { xml.text self.title }
          xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg",
            width: "320", height: "180")
          xml.element("media:description") { xml.text html_to_content(self.description_html) }
        end

        xml.element("media:community") do
          xml.element("media:statistics", views: self.views)
        end
      end
    end

    def to_xml(auto_generated, query_params, xml : XML::Builder | Nil = nil)
      if xml
        to_xml(HOST_URL, auto_generated, query_params, xml)
      else
        XML.build do |json|
          to_xml(HOST_URL, auto_generated, query_params, xml)
        end
      end
    end

    def to_json(locale : Hash(String, JSON::Any), json : JSON::Builder)
      json.object do
        json.field "type", "video"
        json.field "title", self.title
        json.field "videoId", self.id

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "videoThumbnails" do
          generate_thumbnails(json, self.id)
        end

        json.field "description", html_to_content(self.description_html)
        json.field "descriptionHtml", self.description_html

        json.field "viewCount", self.views
        json.field "published", self.published.to_unix
        json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
        json.field "lengthSeconds", self.length_seconds
        json.field "liveNow", self.live_now
        json.field "paid", self.paid
        json.field "premium", self.premium
        json.field "isUpcoming", self.is_upcoming

        if self.premiere_timestamp
          json.field "premiereTimestamp", self.premiere_timestamp.try &.to_unix
        end
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

    def is_upcoming
      premiere_timestamp ? true : false
    end
  end
end
