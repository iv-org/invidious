class Playlist
  add_mapping({
    title:            String,
    id:               String,
    author:           String,
    author_thumbnail: String,
    ucid:             String,
    description:      String,
    description_html: String,
    video_count:      Int32,
    views:            Int64,
    updated:          Time,
  })
end

class PlaylistVideo
  add_mapping({
    title:          String,
    id:             String,
    author:         String,
    ucid:           String,
    length_seconds: Int32,
    published:      Time,
    playlists:      Array(String),
    index:          Int32,
  })
end

def fetch_playlist_videos(plid, page, video_count)
  client = make_client(YT_URL)

  if video_count > 100
    index = (page - 1) * 100
    url = produce_playlist_url(plid, index)

    response = client.get(url)
    response = JSON.parse(response.body)
    if !response["content_html"]? || response["content_html"].as_s.empty?
      raise "Playlist is empty"
    end

    document = XML.parse_html(response["content_html"].as_s)
    nodeset = document.xpath_nodes(%q(.//tr[contains(@class, "pl-video")]))
    videos = extract_playlist(plid, nodeset, index)
  else
    if page > 1
      videos = [] of PlaylistVideo
    else
      response = client.get("/playlist?list=#{plid}&disable_polymer=1")
      document = XML.parse_html(response.body)
      nodeset = document.xpath_nodes(%q(.//tr[contains(@class, "pl-video")]))

      videos = extract_playlist(plid, nodeset, 0)
    end
  end

  return videos
end

def extract_playlist(plid, nodeset, index)
  videos = [] of PlaylistVideo

  nodeset.each_with_index do |video, offset|
    anchor = video.xpath_node(%q(.//td[@class="pl-video-title"]))
    if !anchor
      next
    end

    title = anchor.xpath_node(%q(.//a)).not_nil!.content.strip(" \n")
    id = anchor.xpath_node(%q(.//a)).not_nil!["href"].lchop("/watch?v=")[0, 11]

    anchor = anchor.xpath_node(%q(.//div[@class="pl-video-owner"]/a))
    if anchor
      author = anchor.content
      ucid = anchor["href"].split("/")[2]
    else
      author = ""
      ucid = ""
    end

    anchor = video.xpath_node(%q(.//td[@class="pl-video-time"]/div/div[1]))
    if anchor && !anchor.content.empty?
      length_seconds = decode_length_seconds(anchor.content)
    else
      length_seconds = 0
    end

    videos << PlaylistVideo.new(
      title,
      id,
      author,
      ucid,
      length_seconds,
      Time.now,
      [plid],
      index + offset,
    )
  end

  return videos
end

def produce_playlist_url(id, index)
  if id.starts_with? "UC"
    id = "UU" + id.lchop("UC")
  end
  ucid = "VL" + id

  meta = "\x08#{write_var_int(index).join}"
  meta = Base64.urlsafe_encode(meta, false)
  meta = "PT:#{meta}"

  wrapped = "\x7a"
  wrapped += meta.bytes.size.unsafe_chr
  wrapped += meta

  wrapped = Base64.urlsafe_encode(wrapped)
  meta = URI.escape(wrapped)

  continuation = "\x12"
  continuation += ucid.size.unsafe_chr
  continuation += ucid
  continuation += "\x1a"
  continuation += meta.bytes.size.unsafe_chr
  continuation += meta

  continuation = continuation.size.to_u8.unsafe_chr + continuation
  continuation = "\xe2\xa9\x85\xb2\x02" + continuation

  continuation = Base64.urlsafe_encode(continuation)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?continuation=#{continuation}"

  return url
end

def fetch_playlist(plid)
  client = make_client(YT_URL)

  if plid.starts_with? "UC"
    plid = "UU#{plid.lchop("UC")}"
  end

  response = client.get("/playlist?list=#{plid}&disable_polymer=1")
  if response.status_code != 200
    raise "Invalid playlist."
  end

  body = response.body.gsub(<<-END_BUTTON
  <button class="yt-uix-button yt-uix-button-size-default yt-uix-button-link yt-uix-expander-head playlist-description-expander yt-uix-inlineedit-ignore-edit" type="button" onclick=";return false;"><span class="yt-uix-button-content">  less <img alt="" src="/yts/img/pixel-vfl3z5WfW.gif">
  </span></button>
  END_BUTTON
  , "")
  document = XML.parse_html(body)

  title = document.xpath_node(%q(//h1[@class="pl-header-title"]))
  if !title
    raise "Playlist does not exist."
  end
  title = title.content.strip(" \n")

  description_html = document.xpath_node(%q(//span[@class="pl-header-description-text"]/div/div[1]))
  description_html ||= document.xpath_node(%q(//span[@class="pl-header-description-text"]))
  description_html, description = html_to_content(description_html)

  anchor = document.xpath_node(%q(//ul[@class="pl-header-details"])).not_nil!
  author = anchor.xpath_node(%q(.//li[1]/a)).not_nil!.content
  author_thumbnail = document.xpath_node(%q(//img[@class="channel-header-profile-image"])).try &.["src"]
  author_thumbnail ||= ""
  ucid = anchor.xpath_node(%q(.//li[1]/a)).not_nil!["href"].split("/")[2]

  video_count = anchor.xpath_node(%q(.//li[2])).not_nil!.content.delete("videos, ").to_i
  views = anchor.xpath_node(%q(.//li[3])).not_nil!.content.delete("No views, ")
  if views.empty?
    views = 0_i64
  else
    views = views.to_i64
  end

  updated = anchor.xpath_node(%q(.//li[4])).not_nil!.content.lchop("Last updated on ").lchop("Updated ")
  updated = decode_date(updated)

  playlist = Playlist.new(
    title,
    plid,
    author,
    author_thumbnail,
    ucid,
    description,
    description_html,
    video_count,
    views,
    updated
  )

  return playlist
end
