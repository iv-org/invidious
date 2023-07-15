struct SearchVideo
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
  property premium : Bool
  property premiere_timestamp : Time?
  property author_verified : Bool

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

  def to_xml(auto_generated, query_params, _xml : Nil)
    XML.build do |xml|
      to_xml(auto_generated, query_params, xml)
    end
  end

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "video"
      json.field "title", self.title
      json.field "videoId", self.id

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"
      json.field "authorVerified", self.author_verified

      json.field "videoThumbnails" do
        Invidious::JSONify::APIv1.thumbnails(json, self.id)
      end

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html

      json.field "viewCount", self.views
      json.field "viewCountText", translate_count(locale, "generic_views_count", self.views, NumberFormatting::Short)
      json.field "published", self.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(self.published, locale))
      json.field "lengthSeconds", self.length_seconds
      json.field "liveNow", self.live_now
      json.field "premium", self.premium
      json.field "isUpcoming", self.is_upcoming

      if self.premiere_timestamp
        json.field "premiereTimestamp", self.premiere_timestamp.try &.to_unix
      end
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build do |json|
      to_json(locale, json)
    end
  end

  def to_json(json : JSON::Builder)
    to_json(nil, json)
  end

  def is_upcoming
    premiere_timestamp ? true : false
  end
end

struct SearchPlaylistVideo
  include DB::Serializable

  property title : String
  property id : String
  property length_seconds : Int32
end

struct SearchPlaylist
  include DB::Serializable

  property title : String
  property id : String
  property author : String
  property ucid : String
  property video_count : Int32
  property videos : Array(SearchPlaylistVideo)
  property thumbnail : String?
  property author_verified : Bool

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "playlist"
      json.field "title", self.title
      json.field "playlistId", self.id
      json.field "playlistThumbnail", self.thumbnail

      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"

      json.field "authorVerified", self.author_verified

      json.field "videoCount", self.video_count
      json.field "videos" do
        json.array do
          self.videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id
              json.field "lengthSeconds", video.length_seconds

              json.field "videoThumbnails" do
                Invidious::JSONify::APIv1.thumbnails(json, video.id)
              end
            end
          end
        end
      end
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build do |json|
      to_json(locale, json)
    end
  end

  def to_json(json : JSON::Builder)
    to_json(nil, json)
  end
end

struct SearchChannel
  include DB::Serializable

  property author : String
  property ucid : String
  property author_thumbnail : String
  property subscriber_count : Int32
  property video_count : Int32
  property description_html : String
  property auto_generated : Bool
  property author_verified : Bool

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "channel"
      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"
      json.field "authorVerified", self.author_verified
      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", self.author_thumbnail.gsub(/=\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "autoGenerated", self.auto_generated
      json.field "subCount", self.subscriber_count
      json.field "videoCount", self.video_count

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build do |json|
      to_json(locale, json)
    end
  end

  def to_json(json : JSON::Builder)
    to_json(nil, json)
  end
end

struct SearchHashtag
  include DB::Serializable

  property title : String
  property url : String
  property video_count : Int64
  property channel_count : Int64

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "hashtag"
      json.field "title", self.title
      json.field "url", self.url
      json.field "videoCount", self.video_count
      json.field "channelCount", self.channel_count
    end
  end
end

class Category
  include DB::Serializable

  property title : String
  property contents : Array(SearchItem) | Array(Video)
  property url : String?
  property description_html : String
  property badges : Array(Tuple(String, String))?

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "category"
      json.field "title", self.title
      json.field "contents" do
        json.array do
          self.contents.each do |item|
            item.to_json(locale, json)
          end
        end
      end
    end
  end

  # TODO: remove the locale and follow the crystal convention
  def to_json(locale : String?, _json : Nil)
    JSON.build do |json|
      to_json(locale, json)
    end
  end

  def to_json(json : JSON::Builder)
    to_json(nil, json)
  end
end

struct Continuation
  getter token

  def initialize(@token : String)
  end
end

alias SearchItem = SearchVideo | SearchChannel | SearchPlaylist | SearchHashtag | Category
