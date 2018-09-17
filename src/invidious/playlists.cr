class Playlist
  add_mapping({
    title:            String,
    id:               String,
    author:           String,
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

def extract_playlist(plid, page)
  index = (page - 1) * 100
  url = produce_playlist_url(plid, index)

  client = make_client(YT_URL)
  response = client.get(url)
  response = JSON.parse(response.body)
  if !response["content_html"]? || response["content_html"].as_s.empty?
    raise "Playlist does not exist"
  end

  videos = [] of PlaylistVideo

  document = XML.parse_html(response["content_html"].as_s)
  anchor = document.xpath_node(%q(//div[@class="pl-video-owner"]/a))
  if anchor
    document.xpath_nodes(%q(.//tr[contains(@class, "pl-video")])).each_with_index do |video, offset|
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

  url = "/browse_ajax?action_continuation=1&continuation=#{continuation}"

  return url
end

def fetch_playlist(plid)
  client = make_client(YT_URL)
  response = client.get("/playlist?list=#{plid}&disable_polymer=1")
  body = response.body.gsub(<<-END_BUTTON
  <button class="yt-uix-button yt-uix-button-size-default yt-uix-button-link yt-uix-expander-head playlist-description-expander yt-uix-inlineedit-ignore-edit" type="button" onclick=";return false;"><span class="yt-uix-button-content">  less <img alt="" src="/yts/img/pixel-vfl3z5WfW.gif">
  </span></button>
  END_BUTTON
  , "")
  document = XML.parse_html(body)

  title = document.xpath_node(%q(//h1[@class="pl-header-title"])).not_nil!.content
  title = title.strip(" \n")

  description_html = document.xpath_node(%q(//span[@class="pl-header-description-text"]/div/div[1]))
  description_html, description = html_to_content(description_html)

  anchor = document.xpath_node(%q(//ul[@class="pl-header-details"])).not_nil!
  author = anchor.xpath_node(%q(.//li[1]/a)).not_nil!.content
  ucid = anchor.xpath_node(%q(.//li[1]/a)).not_nil!["href"].split("/")[2]

  video_count = anchor.xpath_node(%q(.//li[2])).not_nil!.content.delete("videos, ").to_i
  views = anchor.xpath_node(%q(.//li[3])).not_nil!.content.delete("views, ").to_i64

  updated = anchor.xpath_node(%q(.//li[4])).not_nil!.content.lchop("Last updated on ").lchop("Updated ")
  updated = decode_date(updated)

  playlist = Playlist.new(
    title,
    plid,
    author,
    ucid,
    description,
    description_html,
    video_count,
    views,
    updated
  )

  return playlist
end
