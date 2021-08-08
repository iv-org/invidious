# Data structs used by Invidious to provide certain features.
module InvidiousStructs
  # Struct for representing a cached YouTube channel.
  #
  # This is constructed from YouTube's RSS feeds for channels and is
  # currently only used for storing subscriptions in a user.
  struct Channel
    include DB::Serializable

    property id : String
    property author : String
    property updated : Time
    property deleted : Bool
    # TODO I don't believe the subscripted attribute is actually used.
    # so this can likely be removed.
    property subscribed : Time?
  end

  # Struct for representing a video from a YouTube channel
  #
  # This is constructed from YouTube's RSS feeds for channels and is
  # used for referencing videos used by Invidious exclusive features. IE popular feeds,
  # notifications, subscriptions, etc.
  #
  # TODO ideally this should be expanded to include all channel videos. That way
  # we can implement optional caching of YT requests in a DB such as redis.
  #
  struct ChannelVideo
    include DB::Serializable

    property id : String
    property title : String
    property published : Time
    property updated : Time
    property ucid : String
    property author : String
    property length_seconds : Int32 = 0
    property live_now : Bool = false
    property premiere_timestamp : Time? = nil
    property views : Int64? = nil

    def to_json(locale, json : JSON::Builder)
      json.object do
        json.field "type", "shortVideo"

        json.field "title", self.title
        json.field "videoId", self.id
        json.field "videoThumbnails" do
          generate_thumbnails(json, self.id)
        end

        json.field "lengthSeconds", self.length_seconds

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"
        json.field "published", self.published.to_unix
        json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))

        json.field "viewCount", self.views
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

    def to_xml(locale, query_params, xml : XML::Builder)
      query_params["v"] = self.id

      xml.element("entry") do
        xml.element("id") { xml.text "yt:video:#{self.id}" }
        xml.element("yt:videoId") { xml.text self.id }
        xml.element("yt:channelId") { xml.text self.ucid }
        xml.element("title") { xml.text self.title }
        xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?#{query_params}")

        xml.element("author") do
          xml.element("name") { xml.text self.author }
          xml.element("uri") { xml.text "#{HOST_URL}/channel/#{self.ucid}" }
        end

        xml.element("content", type: "xhtml") do
          xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
            xml.element("a", href: "#{HOST_URL}/watch?#{query_params}") do
              xml.element("img", src: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg")
            end
          end
        end

        xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }
        xml.element("updated") { xml.text self.updated.to_s("%Y-%m-%dT%H:%M:%S%:z") }

        xml.element("media:group") do
          xml.element("media:title") { xml.text self.title }
          xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg",
            width: "320", height: "180")
        end
      end
    end

    def to_xml(locale, xml : XML::Builder | Nil = nil)
      if xml
        to_xml(locale, xml)
      else
        XML.build do |xml|
          to_xml(locale, xml)
        end
      end
    end

    def to_tuple
      {% begin %}
        {
          {{*@type.instance_vars.map { |var| var.name }}}
        }
      {% end %}
    end
  end
end
