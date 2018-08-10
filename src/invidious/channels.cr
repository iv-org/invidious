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
    videos = [] of ChannelVideo
    page = 1

    loop do
      url = produce_videos_url(ucid, page)
      response = client.get(url)

      json = JSON.parse(response.body)
      content_html = json["content_html"].as_s
      if content_html.empty?
        # If we don't get anything, move on
        break
      end
      document = XML.parse_html(content_html)

      document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")])).each do |item|
        anchor = item.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
        if !anchor
          raise "could not find anchor"
        end

        title = anchor.content.strip
        video_id = anchor["href"].lchop("/watch?v=")

        published = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[1]))
        if !published
          # This happens on Youtube red videos, here we just skip them
          next
        end
        published = published.content
        published = decode_date(published)

        videos << ChannelVideo.new(video_id, title, published, Time.now, ucid, author)
      end

      if document.xpath_nodes(%q(//li[contains(@class, "channels-content-item")])).size < 30
        break
      end

      page += 1
    end

    video_ids = [] of String
    videos.each do |video|
      db.exec("UPDATE users SET notifications = notifications || $1 \
        WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, ucid)
      video_ids << video.id

      video_array = video.to_a
      args = arg_array(video_array)
      db.exec("INSERT INTO channel_videos VALUES (#{args}) ON CONFLICT (id) DO NOTHING", video_array)
    end

    # When a video is deleted from a channel, we find and remove it here
    db.exec("DELETE FROM channel_videos * WHERE NOT id = ANY ('{#{video_ids.map { |a| %("#{a}") }.join(",")}}') AND ucid = $1", ucid)
  end

  channel = InvidiousChannel.new(ucid, author, Time.now)

  return channel
end

def extract_channel_videos(document, author, ucid)
  channel_videos = [] of Video
  document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")])).each do |node|
    anchor = node.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
    if !anchor
      next
    end

    if anchor["href"].starts_with? "https://www.googleadservices.com"
      next
    end

    title = anchor.content.strip
    id = anchor["href"].lchop("/watch?v=")

    metadata = node.xpath_nodes(%q(.//div[contains(@class,"yt-lockup-meta")]/ul/li))
    if metadata.size == 0
      next
    elsif metadata.size == 1
      view_count = metadata[0].content.split(" ")[0].delete(",").to_i64
      published = Time.now
    else
      published = decode_date(metadata[0].content)

      view_count = metadata[1].content.split(" ")[0]
      if view_count == "No"
        view_count = 0_i64
      else
        view_count = view_count.delete(",").to_i64
      end
    end

    description_html = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
    description, description_html = html_to_description(description_html)

    length_seconds = node.xpath_node(%q(.//span[@class="video-time"]))
    if length_seconds
      length_seconds = decode_length_seconds(length_seconds.content)
    else
      length_seconds = -1
    end

    info = HTTP::Params.parse("length_seconds=#{length_seconds}")
    channel_videos << Video.new(
      id,
      info,
      Time.now,
      title,
      view_count,
      0,   # Like count
      0,   # Dislike count
      0.0, # Wilson score
      published,
      description,
      "", # Language,
      author,
      ucid,
      [] of String, # Allowed regions
      true,         # Is family friendly
      ""            # Genre
    )
  end

  return channel_videos
end
