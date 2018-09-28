class InvidiousChannel
  add_mapping({
    id:      String,
    author:  String,
    updated: Time,
  })
end

class ChannelVideo
  add_mapping({
    id:        String,
    title:     String,
    published: Time,
    updated:   Time,
    ucid:      String,
    author:    String,
  })
end

def get_channel(id, client, db, refresh = true, pull_all_videos = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM channels WHERE id = $1)", id, as: Bool)
    channel = db.query_one("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)

    if refresh && Time.now - channel.updated > 10.minutes
      channel = fetch_channel(id, client, db, pull_all_videos)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET updated = $3", channel_array)
    end
  else
    channel = fetch_channel(id, client, db, pull_all_videos)
    args = arg_array(channel.to_a)
    db.exec("INSERT INTO channels VALUES (#{args})", channel.to_a)
  end

  return channel
end

def fetch_channel(ucid, client, db, pull_all_videos = true)
  rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  author = rss.xpath_node(%q(//feed/title))
  if !author
    raise "Deleted or invalid channel"
  end
  author = author.content

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  if !pull_all_videos
    rss.xpath_nodes("//feed/entry").each do |entry|
      video_id = entry.xpath_node("videoid").not_nil!.content
      title = entry.xpath_node("title").not_nil!.content
      published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z", Time::Location.local)
      updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z", Time::Location.local)
      author = entry.xpath_node("author/name").not_nil!.content
      ucid = entry.xpath_node("channelid").not_nil!.content

      video = ChannelVideo.new(video_id, title, published, Time.now, ucid, author)

      db.exec("UPDATE users SET notifications = notifications || $1 \
        WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, ucid)

      video_array = video.to_a
      args = arg_array(video_array)
      db.exec("INSERT INTO channel_videos VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
        updated = $4, ucid = $5, author = $6", video_array)
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
      videos = videos.map { |video| ChannelVideo.new(video.id, video.title, video.published, Time.now, video.ucid, video.author) }

      videos.each do |video|
        ids << video.id

        # FIXME: Red videos don't provide published date, so the best we can do is ignore them
        if Time.now - video.published > 1.minute
          db.exec("UPDATE users SET notifications = notifications || $1 \
          WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, video.ucid)

          video_array = video.to_a
          args = arg_array(video_array)
          db.exec("INSERT INTO channel_videos VALUES (#{args}) ON CONFLICT (id) DO UPDATE SET title = $2, \
          published = $3, updated = $4, ucid = $5, author = $6", video_array)
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

def produce_channel_videos_url(ucid, page = 1, auto_generated = nil)
  if auto_generated
    seed = Time.epoch(1525757349)

    until seed >= Time.now
      seed += 1.month
    end
    timestamp = seed - (page - 1).months

    page = "#{timestamp.epoch}"
    switch = "\x36"
  else
    page = "#{page}"
    switch = "\x00"
  end

  meta = "\x12\x06videos"
  meta += "\x30\x02"
  meta += "\x38\x01"
  meta += "\x60\x01"
  meta += "\x6a\x00"
  meta += "\xb8\x01\x00"
  meta += "\x20#{switch}"
  meta += "\x7a"
  meta += page.size.to_u8.unsafe_chr
  meta += page

  meta = Base64.urlsafe_encode(meta)
  meta = URI.escape(meta)

  continuation = "\x12"
  continuation += ucid.size.to_u8.unsafe_chr
  continuation += ucid
  continuation += "\x1a"
  continuation += meta.size.to_u8.unsafe_chr
  continuation += meta

  continuation = continuation.size.to_u8.unsafe_chr + continuation
  continuation = "\xe2\xa9\x85\xb2\x02" + continuation

  continuation = Base64.urlsafe_encode(continuation)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?continuation=#{continuation}"

  return url
end

def get_about_info(ucid)
  client = make_client(YT_URL)

  about = client.get("/user/#{ucid}/about?disable_polymer=1")
  about = XML.parse_html(about.body)

  if !about.xpath_node(%q(//span[@class="qualified-channel-title-text"]/a))
    about = client.get("/channel/#{ucid}/about?disable_polymer=1")
    about = XML.parse_html(about.body)
  end

  if !about.xpath_node(%q(//span[@class="qualified-channel-title-text"]/a))
    raise "User does not exist."
  end

  author = about.xpath_node(%q(//span[@class="qualified-channel-title-text"]/a)).not_nil!.content
  ucid = about.xpath_node(%q(//link[@rel="canonical"])).not_nil!["href"].split("/")[-1]

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  auto_generated = false
  if about.xpath_node(%q(//ul[@class="about-custom-links"]/li/a[@title="Auto-generated by YouTube"])) ||
     about.xpath_node(%q(//span[@class="qualified-channel-title-badge"]/span[@title="Auto-generated by YouTube"]))
    auto_generated = true
  end

  return {author, ucid, auto_generated}
end
