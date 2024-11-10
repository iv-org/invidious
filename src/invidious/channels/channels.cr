struct InvidiousChannel
  include DB::Serializable

  property id : String
  property author : String
  property updated : Time
  property deleted : Bool
  property subscribed : Time?
end

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
        Invidious::JSONify::APIv1.thumbnails(json, self.id)
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

  def to_json(locale, _json : Nil = nil)
    JSON.build do |json|
      to_json(locale, json)
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

  def to_xml(locale, _xml : Nil = nil)
    XML.build do |xml|
      to_xml(locale, xml)
    end
  end

  def to_tuple
    {% begin %}
      {
        {{@type.instance_vars.map(&.name).splat}}
      }
    {% end %}
  end
end

class ChannelRedirect < Exception
  property channel_id : String

  def initialize(@channel_id)
  end
end

def get_batch_channels(channels)
  finished_channel = Channel(String | Nil).new
  max_threads = 10

  spawn do
    active_threads = 0
    active_channel = Channel(Nil).new

    channels.each do |ucid|
      if active_threads >= max_threads
        active_channel.receive
        active_threads -= 1
      end

      active_threads += 1
      spawn do
        begin
          get_channel(ucid)
          finished_channel.send(ucid)
        rescue ex
          finished_channel.send(nil)
        ensure
          active_channel.send(nil)
        end
      end
    end
  end

  final = [] of String
  channels.size.times do
    if ucid = finished_channel.receive
      final << ucid
    end
  end

  return final
end

def get_channel(id) : InvidiousChannel
  channel = Invidious::Database::Channels.select(id)

  if channel.nil? || (Time.utc - channel.updated) > 2.days
    channel = fetch_channel(id, pull_all_videos: false)
    Invidious::Database::Channels.insert(channel, update_on_conflict: true)
  end

  return channel
end

def fetch_channel(ucid, pull_all_videos : Bool)
  LOGGER.debug("fetch_channel: #{ucid}")
  LOGGER.trace("fetch_channel: #{ucid} : pull_all_videos = #{pull_all_videos}")

  namespaces = {
    "yt"      => "http://www.youtube.com/xml/schemas/2015",
    "media"   => "http://search.yahoo.com/mrss/",
    "default" => "http://www.w3.org/2005/Atom",
  }

  LOGGER.trace("fetch_channel: #{ucid} : Downloading RSS feed")
  rss = YT_POOL.client &.get("/feeds/videos.xml?channel_id=#{ucid}").body
  LOGGER.trace("fetch_channel: #{ucid} : Parsing RSS feed")
  rss = XML.parse(rss)

  author = rss.xpath_node("//default:feed/default:title", namespaces)
  if !author
    raise InfoException.new("Deleted or invalid channel")
  end

  author = author.content

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  LOGGER.trace("fetch_channel: #{ucid} : author = #{author}, auto_generated = #{auto_generated}")

  channel = InvidiousChannel.new({
    id:         ucid,
    author:     author,
    updated:    Time.utc,
    deleted:    false,
    subscribed: nil,
  })

  LOGGER.trace("fetch_channel: #{ucid} : Downloading channel videos page")
  videos, continuation = IV::Channel::Tabs.get_videos(channel)

  LOGGER.trace("fetch_channel: #{ucid} : Extracting videos from channel RSS feed")
  rss.xpath_nodes("//default:feed/default:entry", namespaces).each do |entry|
    video_id = entry.xpath_node("yt:videoId", namespaces).not_nil!.content
    title = entry.xpath_node("default:title", namespaces).not_nil!.content

    published = Time.parse_rfc3339(
      entry.xpath_node("default:published", namespaces).not_nil!.content
    )
    updated = Time.parse_rfc3339(
      entry.xpath_node("default:updated", namespaces).not_nil!.content
    )

    author = entry.xpath_node("default:author/default:name", namespaces).not_nil!.content
    ucid = entry.xpath_node("yt:channelId", namespaces).not_nil!.content

    views = entry
      .xpath_node("media:group/media:community/media:statistics", namespaces)
      .try &.["views"]?.try &.to_i64? || 0_i64

    channel_video = videos
      .select(SearchVideo)
      .select(&.id.== video_id)[0]?

    length_seconds = channel_video.try &.length_seconds
    length_seconds ||= 0

    live_now = channel_video.try &.badges.live_now?
    live_now ||= false

    premiere_timestamp = channel_video.try &.premiere_timestamp

    video = ChannelVideo.new({
      id:                 video_id,
      title:              title,
      published:          published,
      updated:            updated,
      ucid:               ucid,
      author:             author,
      length_seconds:     length_seconds,
      live_now:           live_now,
      premiere_timestamp: premiere_timestamp,
      views:              views,
    })

    LOGGER.trace("fetch_channel: #{ucid} : video #{video_id} : Updating or inserting video")

    # We don't include the 'premiere_timestamp' here because channel pages don't include them,
    # meaning the above timestamp is always null
    was_insert = Invidious::Database::ChannelVideos.insert(video)

    if was_insert
      LOGGER.trace("fetch_channel: #{ucid} : video #{video_id} : Inserted, updating subscriptions")
      NOTIFICATION_CHANNEL.send(VideoNotification.from_video(video))
    else
      LOGGER.trace("fetch_channel: #{ucid} : video #{video_id} : Updated")
    end
  end

  if pull_all_videos
    loop do
      # Keep fetching videos using the continuation token retrieved earlier
      videos, continuation = IV::Channel::Tabs.get_videos(channel, continuation: continuation)

      count = 0
      videos.select(SearchVideo).each do |video|
        count += 1
        video = ChannelVideo.new({
          id:                 video.id,
          title:              video.title,
          published:          video.published,
          updated:            Time.utc,
          ucid:               video.ucid,
          author:             video.author,
          length_seconds:     video.length_seconds,
          live_now:           video.badges.live_now?,
          premiere_timestamp: video.premiere_timestamp,
          views:              video.views,
        })

        # We are notified of Red videos elsewhere (PubSub), which includes a correct published date,
        # so since they don't provide a published date here we can safely ignore them.
        if Time.utc - video.published > 1.minute
          was_insert = Invidious::Database::ChannelVideos.insert(video)
          if was_insert
            NOTIFICATION_CHANNEL.send(VideoNotification.from_video(video))
          end
        end
      end

      break if count < 25
      sleep 500.milliseconds
    end
  end

  channel.updated = Time.utc
  return channel
end
