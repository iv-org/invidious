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
      json.field "publishedText", I18n.translate(locale, "`x` ago", recode_date(self.published, locale))

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

  channel_info = get_about_info(ucid)

  LOGGER.trace("fetch_channel: #{ucid} : author = #{channel_info.author}, auto_generated = #{channel_info.auto_generated}")

  channel = InvidiousChannel.new({
    id:         ucid,
    author:     channel_info.author,
    updated:    Time.utc,
    deleted:    false,
    subscribed: nil,
  })

  LOGGER.trace("fetch_channel: #{ucid} : Downloading channel videos, shorts, and streams pages")
  videos, continuation = IV::Channel::Tabs.get_videos(channel)
  shorts, shorts_continuation = IV::Channel::Tabs.get_shorts(channel_info)
  livestreams, livestreams_continuation = IV::Channel::Tabs.get_livestreams(channel_info)

  LOGGER.trace("fetch_channel: #{ucid} : Extracting channel tab videos")
  update_channel_videos(ucid, videos.select(SearchVideo))
  update_channel_videos(ucid, shorts.select(SearchVideo))
  update_channel_videos(ucid, livestreams.select(SearchVideo))

  if pull_all_videos
    update_all_channel_videos(ucid, channel, continuation)
    update_all_channel_shorts(ucid, channel_info, shorts_continuation)
    update_all_channel_livestreams(ucid, channel_info, livestreams_continuation)
  end

  channel.updated = Time.utc
  return channel
end

private def update_all_channel_videos(ucid : String, channel : InvidiousChannel, continuation : String?)
  loop do
    break if continuation.nil?

    items, continuation = IV::Channel::Tabs.get_videos(channel, continuation: continuation)
    videos = items.select(SearchVideo)
    update_channel_videos(ucid, videos, skip_recent: true)

    break if videos.size < 25
    sleep 500.milliseconds
  end
end

private def update_all_channel_shorts(ucid : String, channel : AboutChannel, continuation : String?)
  loop do
    break if continuation.nil?

    items, continuation = IV::Channel::Tabs.get_shorts(channel, continuation: continuation)
    videos = items.select(SearchVideo)
    update_channel_videos(ucid, videos, skip_recent: true)

    break if videos.size < 25
    sleep 500.milliseconds
  end
end

private def update_all_channel_livestreams(ucid : String, channel : AboutChannel, continuation : String?)
  loop do
    break if continuation.nil?

    items, continuation = IV::Channel::Tabs.get_livestreams(channel, continuation: continuation)
    videos = items.select(SearchVideo)
    update_channel_videos(ucid, videos, skip_recent: true)

    break if videos.size < 25
    sleep 500.milliseconds
  end
end

private def update_channel_videos(ucid : String, videos : Array(SearchVideo), skip_recent : Bool = false)
  stored_videos = {} of String => ChannelVideo
  Invidious::Database::ChannelVideos.select(videos.map(&.id)).each do |video|
    stored_videos[video.id] = video
  end

  videos.each do |video|
    published = stored_videos[video.id]?.try(&.published) || fetch_video_published_at(video.id)
    unless published
      LOGGER.warn("fetch_channel: #{ucid} : video #{video.id} : Could not fetch publication date")
      next
    end

    # We are notified of Red videos elsewhere (PubSub), which includes a correct published date,
    # so since they don't provide a published date here we can safely ignore them.
    next if skip_recent && Time.utc - published <= 1.minute

    channel_video = ChannelVideo.new({
      id:                 video.id,
      title:              video.title,
      published:          published,
      updated:            Time.utc,
      ucid:               video.ucid,
      author:             video.author,
      length_seconds:     video.length_seconds,
      live_now:           video.badges.live_now?,
      premiere_timestamp: video.premiere_timestamp,
      views:              video.views,
    })

    LOGGER.trace("fetch_channel: #{ucid} : video #{video.id} : Updating or inserting video")

    # We don't include the 'premiere_timestamp' here because channel pages don't include them,
    # meaning the above timestamp is always null.
    was_insert = Invidious::Database::ChannelVideos.insert(channel_video, preserve_timestamps_on_conflict: true)

    if was_insert
      LOGGER.trace("fetch_channel: #{ucid} : video #{video.id} : Inserted, updating subscriptions")
      NOTIFICATION_CHANNEL.send(VideoNotification.from_video(channel_video))
    else
      LOGGER.trace("fetch_channel: #{ucid} : video #{video.id} : Updated")
    end
  end
end

private def fetch_video_published_at(video_id : String) : Time?
  response = YoutubeAPI.next({"videoId" => video_id, "params" => ""})
  if published = response.dig?("microformat", "playerMicroformatRenderer", "publishDate").try(&.as_s)
    return parse_video_published_at(published)
  end

  date_text = response.dig?(
    "contents", "twoColumnWatchNextResults", "results", "results", "contents", 0,
    "videoPrimaryInfoRenderer", "dateText", "simpleText"
  ).try(&.as_s)

  return date_text.try do |text|
    Time.parse(text.lchop("Scheduled for "), "%b %-d, %Y", Time::Location::UTC)
  end
rescue ex
  LOGGER.debug("fetch_video_published_at: #{video_id}: #{ex.message}")
  return nil
end

private def parse_video_published_at(published : String) : Time
  return Time.parse_rfc3339(published)
rescue
  return Time.parse(published, "%Y-%m-%d", Time::Location::UTC)
end
