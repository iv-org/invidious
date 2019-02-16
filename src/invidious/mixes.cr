class MixVideo
  add_mapping({
    title:          String,
    id:             String,
    author:         String,
    ucid:           String,
    length_seconds: Int32,
    index:          Int32,
    mixes:          Array(String),
  })
end

class Mix
  add_mapping({
    title:  String,
    id:     String,
    videos: Array(MixVideo),
  })
end

def fetch_mix(rdid, video_id, cookies = nil, locale = nil)
  client = make_client(YT_URL)
  headers = HTTP::Headers.new
  headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/69.0.3497.100 Safari/537.36"

  if cookies
    headers = cookies.add_request_headers(headers)
  end
  response = client.get("/watch?v=#{video_id}&list=#{rdid}&gl=US&hl=en&has_verified=1&bpctr=9999999999", headers)

  yt_data = response.body.match(/window\["ytInitialData"\] = (?<data>.*);/)
  if yt_data
    yt_data = JSON.parse(yt_data["data"].rchop(";"))
  else
    raise translate(locale, "Could not create mix.")
  end

  if !yt_data["contents"]["twoColumnWatchNextResults"]["playlist"]?
    raise translate(locale, "Could not create mix.")
  end

  playlist = yt_data["contents"]["twoColumnWatchNextResults"]["playlist"]["playlist"]
  mix_title = playlist["title"].as_s

  contents = playlist["contents"].as_a
  until contents[0]["playlistPanelVideoRenderer"]["videoId"].as_s == video_id
    contents.shift
  end

  videos = [] of MixVideo
  contents.each do |item|
    item = item["playlistPanelVideoRenderer"]

    id = item["videoId"].as_s
    title = item["title"]?.try &.["simpleText"].as_s
    if !title
      next
    end
    author = item["longBylineText"]["runs"][0]["text"].as_s
    ucid = item["longBylineText"]["runs"][0]["navigationEndpoint"]["browseEndpoint"]["browseId"].as_s
    length_seconds = decode_length_seconds(item["lengthText"]["simpleText"].as_s)
    index = item["navigationEndpoint"]["watchEndpoint"]["index"].as_i

    videos << MixVideo.new(
      title,
      id,
      author,
      ucid,
      length_seconds,
      index,
      [rdid]
    )
  end

  if !cookies
    next_page = fetch_mix(rdid, videos[-1].id, response.cookies, locale)
    videos += next_page.videos
  end

  videos.uniq! { |video| video.id }
  videos = videos.first(50)
  return Mix.new(mix_title, rdid, videos)
end

def template_mix(mix)
  html = <<-END_HTML
  <h3>
    <a href="/mix?list=#{mix["mixId"]}">
      #{mix["title"]}
    </a>
  </h3>
  <div class="pure-menu pure-menu-scrollable playlist-restricted">
    <ol class="pure-menu-list">
  END_HTML

  mix["videos"].as_a.each do |video|
    html += <<-END_HTML
      <li class="pure-menu-item">
        <a href="/watch?v=#{video["videoId"]}&list=#{mix["mixId"]}">
          <img style="width:100%;" src="/vi/#{video["videoId"]}/mqdefault.jpg">
          <p style="width:100%">#{video["title"]}</p>
          <p>
              <b style="width: 100%">#{video["author"]}</b>
          </p>
        </a>
      </li>
    END_HTML
  end

  html += <<-END_HTML
    </ol>
  </div>
  <hr>
  END_HTML

  html
end
