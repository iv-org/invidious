class Playlist
  add_mapping({
    title:       String,
    id:          String,
    author:      String,
    ucid:        String,
    description: String,
    video_count: Int32,
    views:       Int64,
    updated:     Time,
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

  continuation = [0x08_u8] + write_var_int(index)
  slice = continuation.to_unsafe.to_slice(continuation.size)
  slice = Base64.urlsafe_encode(slice, false)

  # Inner Base64
  continuation = "PT:" + slice
  continuation = [0x7a_u8, continuation.bytes.size.to_u8] + continuation.bytes
  slice = continuation.to_unsafe.to_slice(continuation.size)
  slice = Base64.urlsafe_encode(slice)
  slice = URI.escape(slice)

  # Outer Base64
  continuation = [0x1a_u8, slice.bytes.size.to_u8] + slice.bytes
  continuation = ucid.bytes + continuation
  continuation = [0x12_u8, ucid.size.to_u8] + continuation
  continuation = [0xe2_u8, 0xa9_u8, 0x85_u8, 0xb2_u8, 2_u8, continuation.size.to_u8] + continuation

  # Wrap bytes
  slice = continuation.to_unsafe.to_slice(continuation.size)
  slice = Base64.urlsafe_encode(slice)
  slice = URI.escape(slice)
  continuation = slice

  url = "/browse_ajax?action_continuation=1&continuation=#{continuation}"

  return url
end

def fetch_playlist(plid)
  client = make_client(YT_URL)
  response = client.get("/playlist?list=#{plid}&disable_polymer=1")
  document = XML.parse_html(response.body)

  title = document.xpath_node(%q(//h1[@class="pl-header-title"])).not_nil!.content
  title = title.strip(" \n")

  description = document.xpath_node(%q(//span[@class="pl-header-description-text"]/div/div[1]))
  description ||= document.xpath_node(%q(//span[@class="pl-header-description-text"]))

  if description
    description = description.to_xml.strip(" \n")
    description = description.split("<button ")[0]
    description = fill_links(description, "https", "www.youtube.com")
    description = replace_links(description)
  else
    description = ""
  end

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
    video_count,
    views,
    updated
  )

  return playlist
end
