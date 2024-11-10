struct MixVideo
  include DB::Serializable

  property title : String
  property id : String
  property author : String
  property ucid : String
  property length_seconds : Int32
  property index : Int32
  property rdid : String
end

struct Mix
  include DB::Serializable

  property title : String
  property id : String
  property videos : Array(MixVideo)
end

def fetch_mix(rdid, video_id, cookies = nil, locale = nil)
  headers = HTTP::Headers.new

  if cookies
    headers = cookies.add_request_headers(headers)
  end

  video_id = "CvFH_6DNRCY" if rdid.starts_with? "OLAK5uy_"
  response = YT_POOL.client &.get("/watch?v=#{video_id}&list=#{rdid}&gl=US&hl=en", headers)
  initial_data = extract_initial_data(response.body)

  if !initial_data["contents"]["twoColumnWatchNextResults"]["playlist"]?
    raise InfoException.new("Could not create mix.")
  end

  playlist = initial_data["contents"]["twoColumnWatchNextResults"]["playlist"]["playlist"]
  mix_title = playlist["title"].as_s

  contents = playlist["contents"].as_a
  if contents.map { |video| video["playlistPanelVideoRenderer"]["videoId"] }.includes? video_id
    until contents[0]["playlistPanelVideoRenderer"]["videoId"].as_s == video_id
      contents.shift
    end
  end

  videos = [] of MixVideo
  contents.each do |item|
    item = item["playlistPanelVideoRenderer"]

    id = item["videoId"].as_s
    title = item["title"]?.try &.["simpleText"].as_s
    next if !title

    author = item["longBylineText"]["runs"][0]["text"].as_s
    ucid = item["longBylineText"]["runs"][0]["navigationEndpoint"]["browseEndpoint"]["browseId"].as_s
    length_seconds = decode_length_seconds(item["lengthText"]["simpleText"].as_s)
    index = item["navigationEndpoint"]["watchEndpoint"]["index"].as_i

    videos << MixVideo.new({
      title:          title,
      id:             id,
      author:         author,
      ucid:           ucid,
      length_seconds: length_seconds,
      index:          index,
      rdid:           rdid,
    })
  end

  if !cookies
    next_page = fetch_mix(rdid, videos[-1].id, response.cookies, locale)
    videos += next_page.videos
  end

  videos.uniq!(&.id)
  videos = videos.first(50)
  return Mix.new({
    title:  mix_title,
    id:     rdid,
    videos: videos,
  })
end

def template_mix(mix, listen)
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
        <a href="/watch?v=#{video["videoId"]}&list=#{mix["mixId"]}#{listen ? "&listen=1" : ""}">
          <div class="thumbnail">
              <img loading="lazy" class="thumbnail" src="/vi/#{video["videoId"]}/mqdefault.jpg" alt="" />
              <p class="length">#{recode_length_seconds(video["lengthSeconds"].as_i)}</p>
          </div>
          <p style="width:100%">#{video["title"]}</p>
          <p>
              <b style="width:100%">#{video["author"]}</b>
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
