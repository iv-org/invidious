class InvidiousChannel
  add_mapping({
    id:      String,
    author:  String,
    updated: Time,
  })
end

class ChannelVideo
  add_mapping({
    id:             String,
    title:          String,
    published:      Time,
    updated:        Time,
    ucid:           String,
    author:         String,
    length_seconds: {
      type:    Int32,
      default: 0,
    },
  })
end

def get_batch_channels(channels, db, refresh = false, pull_all_videos = true, max_threads = 10)
  active_threads = 0
  active_channel = Channel(String | Nil).new

  final = [] of String
  channels.map do |ucid|
    if active_threads >= max_threads
      if response = active_channel.receive
        active_threads -= 1
        final << response
      end
    end

    active_threads += 1
    spawn do
      begin
        get_channel(ucid, db, refresh, pull_all_videos)
        active_channel.send(ucid)
      rescue ex
        active_channel.send(nil)
      end
    end
  end

  return final
end

def get_channel(id, db, refresh = true, pull_all_videos = true)
  client = make_client(YT_URL)

  if db.query_one?("SELECT EXISTS (SELECT true FROM channels WHERE id = $1)", id, as: Bool)
    channel = db.query_one("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)

    if refresh && Time.now - channel.updated > 10.minutes
      channel = fetch_channel(id, client, db, pull_all_videos: pull_all_videos)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET author = $2, updated = $3", channel_array)
    end
  else
    channel = fetch_channel(id, client, db, pull_all_videos: pull_all_videos)
    channel_array = channel.to_a
    args = arg_array(channel_array)

    db.exec("INSERT INTO channels VALUES (#{args})", channel_array)
  end

  return channel
end

def fetch_channel(ucid, client, db, pull_all_videos = true, locale = nil)
  rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  author = rss.xpath_node(%q(//feed/title))
  if !author
    raise translate(locale, "Deleted or invalid channel")
  end
  author = author.content

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  if !pull_all_videos
    url = produce_channel_videos_url(ucid, 1, auto_generated: auto_generated)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if auto_generated
        videos = extract_videos(nodeset)
      else
        videos = extract_videos(nodeset, ucid)
        videos.each { |video| video.ucid = ucid }
        videos.each { |video| video.author = author }
      end
    end

    videos ||= [] of ChannelVideo

    rss.xpath_nodes("//feed/entry").each do |entry|
      video_id = entry.xpath_node("videoid").not_nil!.content
      title = entry.xpath_node("title").not_nil!.content
      published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z", Time::Location.local)
      updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z", Time::Location.local)
      author = entry.xpath_node("author/name").not_nil!.content
      ucid = entry.xpath_node("channelid").not_nil!.content

      length_seconds = videos.select { |video| video.id == video_id }[0]?.try &.length_seconds
      length_seconds ||= 0

      video = ChannelVideo.new(video_id, title, published, Time.now, ucid, author, length_seconds)

      db.exec("UPDATE users SET notifications = notifications || $1 \
        WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, ucid)

      video_array = video.to_a
      args = arg_array(video_array)

      db.exec("INSERT INTO channel_videos VALUES (#{args}) \
      ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
      updated = $4, ucid = $5, author = $6, length_seconds = $7", video_array)
    end
  else
    page = 1
    ids = [] of String

    loop do
      url = produce_channel_videos_url(ucid, page, auto_generated: auto_generated)
      response = client.get(url)
      json = JSON.parse(response.body)

      if json["content_html"]? && !json["content_html"].as_s.empty?
        document = XML.parse_html(json["content_html"].as_s)
        nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))
      else
        break
      end

      if auto_generated
        videos = extract_videos(nodeset)
      else
        videos = extract_videos(nodeset, ucid)
        videos.each { |video| video.ucid = ucid }
        videos.each { |video| video.author = author }
      end

      count = nodeset.size
      videos = videos.map { |video| ChannelVideo.new(video.id, video.title, video.published, Time.now, video.ucid, video.author, video.length_seconds) }

      videos.each do |video|
        ids << video.id

        # FIXME: Red videos don't provide published date, so the best we can do is ignore them
        if Time.now - video.published > 1.minute
          db.exec("UPDATE users SET notifications = notifications || $1 \
          WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, video.ucid)

          video_array = video.to_a
          args = arg_array(video_array)

          db.exec("INSERT INTO channel_videos VALUES (#{args}) ON CONFLICT (id) DO UPDATE SET title = $2, \
          published = $3, updated = $4, ucid = $5, author = $6, length_seconds = $7", video_array)
        end
      end

      if count < 30
        break
      end

      page += 1
    end

    # When a video is deleted from a channel, we find and remove it here
    db.exec("DELETE FROM channel_videos * WHERE NOT id = ANY ('{#{ids.map { |id| %("#{id}") }.join(",")}}') AND ucid = $1", ucid)
  end

  channel = InvidiousChannel.new(ucid, author, Time.now)

  return channel
end

def produce_channel_videos_url(ucid, page = 1, auto_generated = nil, sort_by = "newest")
  if auto_generated
    seed = Time.unix(1525757349)

    until seed >= Time.now
      seed += 1.month
    end
    timestamp = seed - (page - 1).months

    page = "#{timestamp.to_unix}"
    switch = 0x36
  else
    page = "#{page}"
    switch = 0x00
  end

  meta = IO::Memory.new
  meta.write(Bytes[0x12, 0x06])
  meta.print("videos")

  meta.write(Bytes[0x30, 0x02])
  meta.write(Bytes[0x38, 0x01])
  meta.write(Bytes[0x60, 0x01])
  meta.write(Bytes[0x6a, 0x00])
  meta.write(Bytes[0xb8, 0x01, 0x00])

  meta.write(Bytes[0x20, switch, 0x7a, page.size])
  meta.print(page)

  case sort_by
  when "newest"
    # Empty tags can be omitted
    # meta.write(Bytes[0x18,0x00])
  when "popular"
    meta.write(Bytes[0x18, 0x01])
  when "oldest"
    meta.write(Bytes[0x18, 0x02])
  end

  meta.rewind
  meta = Base64.urlsafe_encode(meta.to_slice)
  meta = URI.escape(meta)

  continuation = IO::Memory.new
  continuation.write(Bytes[0x12, ucid.size])
  continuation.print(ucid)

  continuation.write(Bytes[0x1a, meta.size])
  continuation.print(meta)

  continuation.rewind
  continuation = continuation.gets_to_end

  wrapper = IO::Memory.new
  wrapper.write(Bytes[0xe2, 0xa9, 0x85, 0xb2, 0x02, continuation.size])
  wrapper.print(continuation)
  wrapper.rewind

  wrapper = Base64.urlsafe_encode(wrapper.to_slice)
  wrapper = URI.escape(wrapper)

  url = "/browse_ajax?continuation=#{wrapper}&gl=US&hl=en"

  return url
end

def get_about_info(ucid, locale)
  client = make_client(YT_URL)

  about = client.get("/channel/#{ucid}/about?disable_polymer=1&gl=US&hl=en")
  if about.status_code == 404
    about = client.get("/user/#{ucid}/about?disable_polymer=1&gl=US&hl=en")
  end

  about = XML.parse_html(about.body)

  if about.xpath_node(%q(//div[contains(@class, "channel-empty-message")]))
    error_message = translate(locale, "This channel does not exist.")

    raise error_message
  end

  if about.xpath_node(%q(//span[contains(@class,"qualified-channel-title-text")]/a)).try &.content.empty?
    error_message = about.xpath_node(%q(//div[@class="yt-alert-content"])).try &.content.strip
    error_message ||= translate(locale, "Could not get channel info.")

    raise error_message
  end

  sub_count = about.xpath_node(%q(//span[contains(text(), "subscribers")]))
  if sub_count
    sub_count = sub_count.content.delete(", subscribers").to_i?
  end
  sub_count ||= 0

  author = about.xpath_node(%q(//span[contains(@class,"qualified-channel-title-text")]/a)).not_nil!.content
  ucid = about.xpath_node(%q(//link[@rel="canonical"])).not_nil!["href"].split("/")[-1]

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  auto_generated = false
  if about.xpath_node(%q(//ul[@class="about-custom-links"]/li/a[@title="Auto-generated by YouTube"])) ||
     about.xpath_node(%q(//span[@class="qualified-channel-title-badge"]/span[@title="Auto-generated by YouTube"]))
    auto_generated = true
  end

  return {author, ucid, auto_generated, sub_count}
end

def get_60_videos(ucid, page, auto_generated, sort_by = "newest")
  count = 0
  videos = [] of SearchVideo

  client = make_client(YT_URL)

  2.times do |i|
    url = produce_channel_videos_url(ucid, page * 2 + (i - 1), auto_generated: auto_generated, sort_by: sort_by)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if !json["load_more_widget_html"]?.try &.as_s.empty?
        count += 30
      end

      if auto_generated
        videos += extract_videos(nodeset)
      else
        videos += extract_videos(nodeset, ucid)
      end
    else
      break
    end
  end

  return videos, count
end
