module YouTubeStructs
  # Represents a video within a playlist.
  #
  # TODO Make consistent with VideoRenderer. Maybe inherit from abstract struct?
  struct PlaylistVideo
    include DB::Serializable

    property title : String
    property id : String
    property author : String
    property ucid : String
    property length_seconds : Int32
    property published : Time
    property plid : String
    property index : Int64
    property live_now : Bool

    def to_xml(auto_generated, xml : XML::Builder)
      xml.element("entry") do
        xml.element("id") { xml.text "yt:video:#{self.id}" }
        xml.element("yt:videoId") { xml.text self.id }
        xml.element("yt:channelId") { xml.text self.ucid }
        xml.element("title") { xml.text self.title }
        xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?v=#{self.id}")

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
            xml.element("a", href: "#{HOST_URL}/watch?v=#{self.id}") do
              xml.element("img", src: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg")
            end
          end
        end

        xml.element("published") { xml.text self.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

        xml.element("media:group") do
          xml.element("media:title") { xml.text self.title }
          xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{self.id}/mqdefault.jpg",
            width: "320", height: "180")
        end
      end
    end

    def to_xml(auto_generated, xml : XML::Builder? = nil)
      if xml
        to_xml(auto_generated, xml)
      else
        XML.build do |xml|
          to_xml(auto_generated, xml)
        end
      end
    end

    def to_json(locale, json : JSON::Builder, index : Int32?)
      json.object do
        json.field "title", self.title
        json.field "videoId", self.id

        json.field "author", self.author
        json.field "authorId", self.ucid
        json.field "authorUrl", "/channel/#{self.ucid}"

        json.field "videoThumbnails" do
          generate_thumbnails(json, self.id)
        end

        if index
          json.field "index", index
          json.field "indexId", self.index.to_u64.to_s(16).upcase
        else
          json.field "index", self.index
        end

        json.field "lengthSeconds", self.length_seconds
      end
    end

    def to_json(locale, json : JSON::Builder? = nil, index : Int32? = nil)
      if json
        to_json(locale, json, index: index)
      else
        JSON.build do |json|
          to_json(locale, json, index: index)
        end
      end
    end
  end
end
