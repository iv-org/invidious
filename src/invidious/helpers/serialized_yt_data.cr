@[Flags]
enum VideoBadges
  LiveNow
  Premium
  ThreeD
  FourK
  New
  EightK
  VR180
  VR360
  ClosedCaptions
end

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
  property premiere_timestamp : Time?
  property author_verified : Bool
  property author_thumbnail : String?
  property badges : VideoBadges

  def to_xml(auto_generated, query_params, xml : XML::Builder)
    query_params["v"] = id

    xml.element("entry") do
      xml.element("id") { xml.text "yt:video:#{id}" }
      xml.element("yt:videoId") { xml.text id }
      xml.element("yt:channelId") { xml.text ucid }
      xml.element("title") { xml.text title }
      xml.element("link", rel: "alternate", href: "#{HOST_URL}/watch?#{query_params}")

      xml.element("author") do
        if auto_generated
          xml.element("name") { xml.text author }
          xml.element("uri") { xml.text "#{HOST_URL}/channel/#{ucid}" }
        else
          xml.element("name") { xml.text author }
          xml.element("uri") { xml.text "#{HOST_URL}/channel/#{ucid}" }
        end
      end

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("a", href: "#{HOST_URL}/watch?#{query_params}") do
            xml.element("img", src: "#{HOST_URL}/vi/#{id}/mqdefault.jpg")
          end

          xml.element("p", style: "word-break:break-word;white-space:pre-wrap") { xml.text html_to_content(description_html) }
        end
      end

      xml.element("published") { xml.text published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

      xml.element("media:group") do
        xml.element("media:title") { xml.text title }
        xml.element("media:thumbnail", url: "#{HOST_URL}/vi/#{id}/mqdefault.jpg",
          width: "320", height: "180")
        xml.element("media:description") { xml.text html_to_content(description_html) }
      end

      xml.element("media:community") do
        xml.element("media:statistics", views: views)
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
      json.field "title", title
      json.field "videoId", id

      json.field "author", author
      json.field "authorId", ucid
      json.field "authorUrl", "/channel/#{ucid}"
      json.field "authorVerified", author_verified

      author_thumbnail = self.author_thumbnail

      if author_thumbnail
        json.field "authorThumbnails" do
          json.array do
            qualities = {32, 48, 76, 100, 176, 512}

            qualities.each do |quality|
              json.object do
                json.field "url", author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
                json.field "width", quality
                json.field "height", quality
              end
            end
          end
        end
      end

      json.field "videoThumbnails" do
        Invidious::JSONify::APIv1.thumbnails(json, id)
      end

      json.field "description", html_to_content(description_html)
      json.field "descriptionHtml", description_html

      json.field "viewCount", views
      json.field "viewCountText", translate_count(locale, "generic_views_count", views, NumberFormatting::Short)
      json.field "published", published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(published, locale))
      json.field "lengthSeconds", length_seconds
      json.field "liveNow", badges.live_now?
      json.field "premium", badges.premium?
      json.field "isUpcoming", upcoming?

      if premiere_timestamp
        json.field "premiereTimestamp", premiere_timestamp.try &.to_unix
      end
      json.field "isNew", badges.new?
      json.field "is4k", badges.four_k?
      json.field "is8k", badges.eight_k?
      json.field "isVr180", badges.vr180?
      json.field "isVr360", badges.vr360?
      json.field "is3d", badges.three_d?
      json.field "hasCaptions", badges.closed_captions?
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

  def upcoming?
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
      json.field "title", title
      json.field "playlistId", id
      json.field "playlistThumbnail", thumbnail

      json.field "author", author
      json.field "authorId", ucid
      json.field "authorUrl", "/channel/#{ucid}"

      json.field "authorVerified", author_verified

      json.field "videoCount", video_count
      json.field "videos" do
        json.array do
          videos.each do |video|
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
  property channel_handle : String?
  property description_html : String
  property auto_generated : Bool
  property author_verified : Bool

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "channel"
      json.field "author", author
      json.field "authorId", ucid
      json.field "authorUrl", "/channel/#{ucid}"
      json.field "authorVerified", author_verified
      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "autoGenerated", auto_generated
      json.field "subCount", subscriber_count
      json.field "videoCount", video_count
      json.field "channelHandle", channel_handle

      json.field "description", html_to_content(description_html)
      json.field "descriptionHtml", description_html
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
      json.field "title", title
      json.field "url", url
      json.field "videoCount", video_count
      json.field "channelCount", channel_count
    end
  end
end

# A `ProblematicTimelineItem` is a `SearchItem` created by Invidious that
# represents an item that caused an exception during parsing.
#
# This is not a parsed object from YouTube but rather an Invidious-only type
# created to gracefully communicate parse errors without throwing away
# the rest of the (hopefully) successfully parsed item on a page.
struct ProblematicTimelineItem
  property parse_exception : Exception
  property id : String

  def initialize(@parse_exception)
    @id = Random.new.hex(8)
  end

  def to_json(locale : String?, json : JSON::Builder)
    json.object do
      json.field "type", "parse-error"
      json.field "errorMessage", @parse_exception.message
      json.field "errorBacktrace", @parse_exception.inspect_with_backtrace
    end
  end

  # Provides compatibility with PlaylistVideo
  def to_json(json : JSON::Builder, *args, **kwargs)
    to_json("", json)
  end

  def to_xml(env, locale, xml : XML::Builder)
    xml.element("entry") do
      xml.element("id") { xml.text "iv-err-#{@id}" }
      xml.element("title") { xml.text "Parse Error: This item has failed to parse" }
      xml.element("updated") { xml.text Time.utc.to_rfc3339 }

      xml.element("content", type: "xhtml") do
        xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
          xml.element("div") do
            xml.element("h4") { translate(locale, "timeline_parse_error_placeholder_heading") }
            xml.element("p") { translate(locale, "timeline_parse_error_placeholder_message") }
          end

          xml.element("pre") do
            get_issue_template(env, @parse_exception)
          end
        end
      end
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
      json.field "title", title
      json.field "contents" do
        json.array do
          contents.each do |item|
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

alias SearchItem = SearchVideo | SearchChannel | SearchPlaylist | SearchHashtag | Category | ProblematicTimelineItem
