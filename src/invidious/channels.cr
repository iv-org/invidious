class InvidiousChannel
  add_mapping({
    id:         String,
    author:     String,
    updated:    Time,
    deleted:    Bool,
    subscribed: Time?,
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
    length_seconds: {type: Int32, default: 0},
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
  if db.query_one?("SELECT EXISTS (SELECT true FROM channels WHERE id = $1)", id, as: Bool)
    channel = db.query_one("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)

    if refresh && Time.now - channel.updated > 10.minutes
      channel = fetch_channel(id, db, pull_all_videos: pull_all_videos)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET author = $2, updated = $3", channel_array)
    end
  else
    channel = fetch_channel(id, db, pull_all_videos: pull_all_videos)
    channel_array = channel.to_a
    args = arg_array(channel_array)

    db.exec("INSERT INTO channels VALUES (#{args})", channel_array)
  end

  return channel
end

def fetch_channel(ucid, db, pull_all_videos = true, locale = nil)
  client = make_client(YT_URL)

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
      published = Time.parse_rfc3339(entry.xpath_node("published").not_nil!.content)
      updated = Time.parse_rfc3339(entry.xpath_node("updated").not_nil!.content)
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

  channel = InvidiousChannel.new(ucid, author, Time.now, false, nil)

  return channel
end

def subscribe_pubsub(ucid, key, config)
  client = make_client(PUBSUB_URL)
  time = Time.now.to_unix.to_s
  nonce = Random::Secure.hex(4)
  signature = "#{time}:#{nonce}"

  host_url = make_host_url(config, Kemal.config)

  body = {
    "hub.callback"      => "#{host_url}/feed/webhook/v1:#{time}:#{nonce}:#{OpenSSL::HMAC.hexdigest(:sha1, key, signature)}",
    "hub.topic"         => "https://www.youtube.com/xml/feeds/videos.xml?channel_id=#{ucid}",
    "hub.verify"        => "async",
    "hub.mode"          => "subscribe",
    "hub.lease_seconds" => "432000",
    "hub.secret"        => key.to_s,
  }

  return client.post("/subscribe", form: body)
end

def fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)
  client = make_client(YT_URL)

  if continuation
    url = produce_channel_playlists_url(ucid, continuation, sort_by, auto_generated)

    response = client.get(url)
    json = JSON.parse(response.body)

    if json["load_more_widget_html"].as_s.empty?
      return [] of SearchItem, nil
    end

    continuation = XML.parse_html(json["load_more_widget_html"].as_s)
    continuation = continuation.xpath_node(%q(//button[@data-uix-load-more-href]))
    if continuation
      continuation = extract_channel_playlists_cursor(continuation["data-uix-load-more-href"], auto_generated)
    end

    html = XML.parse_html(json["content_html"].as_s)
    nodeset = html.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))
  else
    url = "/channel/#{ucid}/playlists?disable_polymer=1&flow=list"

    if auto_generated
      url += "&view=50"
    else
      url += "&view=1"
    end

    case sort_by
    when "last", "last_added"
      #
    when "oldest", "oldest_created"
      url += "&sort=da"
    when "newest", "newest_created"
      url += "&sort=dd"
    end

    response = client.get(url)
    html = XML.parse_html(response.body)

    continuation = html.xpath_node(%q(//button[@data-uix-load-more-href]))
    if continuation
      continuation = extract_channel_playlists_cursor(continuation["data-uix-load-more-href"], auto_generated)
    end

    nodeset = html.xpath_nodes(%q(//ul[@id="browse-items-primary"]/li[contains(@class, "feed-item-container")]))
  end

  if auto_generated
    items = extract_shelf_items(nodeset, ucid, author)
  else
    items = extract_items(nodeset, ucid, author)
  end

  return items, continuation
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

  meta.write(Bytes[0x20, switch])
  meta.write(Bytes[0x7a, page.size])
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

def produce_channel_playlists_url(ucid, cursor, sort = "newest", auto_generated = false)
  if !auto_generated
    cursor = Base64.urlsafe_encode(cursor, false)
  end

  meta = IO::Memory.new

  if auto_generated
    meta.write(Bytes[0x08, 0x0a])
  end

  meta.write(Bytes[0x12, 0x09])
  meta.print("playlists")

  if auto_generated
    meta.write(Bytes[0x20, 0x32])
  else
    # TODO: Look at 0x01, 0x00
    case sort
    when "oldest", "oldest_created"
      meta.write(Bytes[0x18, 0x02])
    when "newest", "newest_created"
      meta.write(Bytes[0x18, 0x03])
    when "last", "last_added"
      meta.write(Bytes[0x18, 0x04])
    end

    meta.write(Bytes[0x20, 0x01])
  end

  meta.write(Bytes[0x30, 0x02])
  meta.write(Bytes[0x38, 0x01])
  meta.write(Bytes[0x60, 0x01])
  meta.write(Bytes[0x6a, 0x00])

  meta.write(Bytes[0x7a, cursor.size])
  meta.print(cursor)

  meta.write(Bytes[0xb8, 0x01, 0x00])

  meta.rewind
  meta = Base64.urlsafe_encode(meta.to_slice)
  meta = URI.escape(meta)

  continuation = IO::Memory.new
  continuation.write(Bytes[0x12, ucid.size])
  continuation.print(ucid)

  continuation.write(Bytes[0x1a])
  continuation.write(write_var_int(meta.size))
  continuation.print(meta)

  continuation.rewind
  continuation = continuation.gets_to_end

  wrapper = IO::Memory.new
  wrapper.write(Bytes[0xe2, 0xa9, 0x85, 0xb2, 0x02])
  wrapper.write(write_var_int(continuation.size))
  wrapper.print(continuation)
  wrapper.rewind

  wrapper = Base64.urlsafe_encode(wrapper.to_slice)
  wrapper = URI.escape(wrapper)

  url = "/browse_ajax?continuation=#{wrapper}&gl=US&hl=en"

  return url
end

def extract_channel_playlists_cursor(url, auto_generated)
  wrapper = HTTP::Params.parse(URI.parse(url).query.not_nil!)["continuation"]

  wrapper = URI.unescape(wrapper)
  wrapper = Base64.decode(wrapper)

  # 0xe2 0xa9 0x85 0xb2 0x02
  wrapper += 5

  continuation_size = read_var_int(wrapper[0, 4])
  wrapper += write_var_int(continuation_size).size
  continuation = wrapper[0, continuation_size]

  # 0x12
  continuation += 1
  ucid_size = continuation[0]
  continuation += 1
  ucid = continuation[0, ucid_size]
  continuation += ucid_size

  # 0x1a
  continuation += 1
  meta_size = read_var_int(continuation[0, 4])
  continuation += write_var_int(meta_size).size
  meta = continuation[0, meta_size]
  continuation += meta_size

  meta = String.new(meta)
  meta = URI.unescape(meta)
  meta = Base64.decode(meta)

  # 0x12 0x09 playlists
  meta += 11

  until meta[0] == 0x7a
    tag = read_var_int(meta[0, 4])
    meta += write_var_int(tag).size
    value = meta[0]
    meta += 1
  end

  # 0x7a
  meta += 1
  cursor_size = meta[0]
  meta += 1
  cursor = meta[0, cursor_size]

  cursor = String.new(cursor)

  if !auto_generated
    cursor = URI.unescape(cursor)
    cursor = Base64.decode_string(cursor)
  end

  return cursor
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
  ucid = about.xpath_node(%q(//meta[@itemprop="channelId"])).not_nil!["content"]

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

def get_latest_videos(ucid)
  client = make_client(YT_URL)
  videos = [] of SearchVideo

  url = produce_channel_videos_url(ucid, 0)
  response = client.get(url)
  json = JSON.parse(response.body)

  if json["content_html"]? && !json["content_html"].as_s.empty?
    document = XML.parse_html(json["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

    videos = extract_videos(nodeset, ucid)
  end

  return videos
end
