class Config
  YAML.mapping({
    crawl_threads:   Int32,
    channel_threads: Int32,
    video_threads:   Int32,
    db:              NamedTuple(
      user: String,
      password: String,
      host: String,
      port: Int32,
      dbname: String,
    ),
    dl_api_key:   String?,
    https_only:   Bool?,
    hmac_key:     String?,
    full_refresh: Bool,
  })
end

class FilteredCompressHandler < Kemal::Handler
  exclude ["/videoplayback", "/videoplayback/*", "/api/*"]

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Flate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class DenyFrame < Kemal::Handler
  exclude ["/embed/*"]

  def call(env)
    return call_next env if exclude_match? env

    env.response.headers["X-Frame-Options"] = "sameorigin"
    call_next env
  end
end

def rank_videos(db, n, filter, url)
  top = [] of {Float64, String}

  db.query("SELECT id, wilson_score, published FROM videos WHERE views > 5000 ORDER BY published DESC LIMIT 1000") do |rs|
    rs.each do
      id = rs.read(String)
      wilson_score = rs.read(Float64)
      published = rs.read(Time)

      # Exponential decay, older videos tend to rank lower
      temperature = wilson_score * Math.exp(-0.000005*((Time.now - published).total_minutes))
      top << {temperature, id}
    end
  end

  top.sort!

  # Make hottest come first
  top.reverse!
  top = top.map { |a, b| b }

  if filter
    language_list = [] of String
    top.each do |id|
      if language_list.size == n
        break
      else
        client = make_client(url)
        begin
          video = get_video(id, db)
        rescue ex
          next
        end

        if video.language
          language = video.language
        else
          description = XML.parse(video.description)
          content = [video.title, description.content].join(" ")
          content = content[0, 10000]

          results = DetectLanguage.detect(content)
          language = results[0].language

          db.exec("UPDATE videos SET language = $1 WHERE id = $2", language, id)
        end

        if language == "en"
          language_list << id
        end
      end
    end
    return language_list
  else
    return top[0..n - 1]
  end
end

def login_req(login_form, f_req)
  data = {
    "pstMsg"          => "1",
    "checkConnection" => "youtube",
    "checkedDomains"  => "youtube",
    "hl"              => "en",
    "deviceinfo"      => %q([null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[]]]),
    "f.req"           => f_req,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
  }

  data = login_form.merge(data)

  return HTTP::Params.encode(data)
end

def generate_captcha(key)
  minute = Random::Secure.rand(12)
  minute_angle = minute * 30
  minute = minute * 5

  hour = Random::Secure.rand(12)
  hour_angle = hour * 30 + minute_angle.to_f / 12
  if hour == 0
    hour = 12
  end

  clock_svg = <<-END_SVG
  <svg viewBox="0 0 100 100" width="200px">
  <circle cx="50" cy="50" r="45" fill="#eee" stroke="black" stroke-width="2"></circle>
  
  <text x="69"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 1</text>
  <text x="82.909" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 2</text>
  <text x="88"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 3</text>
  <text x="82.909" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 4</text>
  <text x="69"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 5</text>
  <text x="50"     y="91"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 6</text>
  <text x="31"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 7</text>
  <text x="17.091" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 8</text>
  <text x="12"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 9</text>
  <text x="17.091" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">10</text>
  <text x="31"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px">11</text>
  <text x="50"     y="15"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">12</text>

  <circle cx="50" cy="50" r="3" fill="black"></circle>
  <line id="minute" transform="rotate(#{minute_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="16" fill="black" stroke="black" stroke-width="2"></line>
  <line id="hour"   transform="rotate(#{hour_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="24" fill="black" stroke="black" stroke-width="2"></line>
  </svg>
  END_SVG

  challenge = ""
  convert = Process.run(%(convert -density 1200 -resize 400x400 -background none svg:- png:-), shell: true,
    input: IO::Memory.new(clock_svg), output: Process::Redirect::Pipe) do |proc|
    challenge = proc.output.gets_to_end
    challenge = Base64.strict_encode(challenge)
    challenge = "data:image/png;base64,#{challenge}"
  end

  answer = "#{hour}:#{minute.to_s.rjust(2, '0')}"
  token = OpenSSL::HMAC.digest(:sha256, key, answer)
  token = Base64.urlsafe_encode(token)

  return {challenge: challenge, token: token}
end

def html_to_content(description_html)
  if !description_html
    description = ""
    description_html = ""
  else
    description_html = description_html.to_s
    description = description_html.gsub("<br>", "\n")
    description = description.gsub("<br/>", "\n")
    description = XML.parse_html(description).content.strip("\n ")
  end

  return description_html, description
end

def extract_videos(nodeset, ucid = nil)
  # TODO: Make this a 'common', so it makes more sense to be used here
  videos = [] of SearchVideo

  nodeset.each do |node|
    anchor = node.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
    if !anchor
      next
    end

    if anchor["href"].starts_with? "https://www.googleadservices.com"
      next
    end

    case node.xpath_node(%q(.//div)).not_nil!["class"]
    when .includes? "yt-lockup-movie-vertical-poster"
      next
    when .includes? "yt-lockup-playlist"
      next
    when .includes? "yt-lockup-channel"
      next
    end

    title = anchor.content.strip
    id = anchor["href"].lchop("/watch?v=")

    if ucid
      author = ""
      author_id = ""
    else
      anchor = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-byline")]/a))
      if !anchor
        next
      end

      author = anchor.content
      author_id = anchor["href"].split("/")[-1]
    end

    metadata = node.xpath_nodes(%q(.//div[contains(@class,"yt-lockup-meta")]/ul/li))
    if metadata.empty?
      next
    end

    begin
      published = decode_date(metadata[0].content.lchop("Streamed ").lchop("Starts "))
    rescue ex
    end
    begin
      published ||= Time.epoch(metadata[0].xpath_node(%q(.//span)).not_nil!["data-timestamp"].to_i64)
    rescue ex
    end
    published ||= Time.now

    begin
      view_count = metadata[0].content.rchop(" watching").delete(",").try &.to_i64?
    rescue ex
    end
    begin
      view_count ||= metadata.try &.[1].content.delete("No views,").try &.to_i64?
    rescue ex
    end
    view_count ||= 0_i64

    description_html = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
    description_html, description = html_to_content(description_html)

    length_seconds = node.xpath_node(%q(.//span[@class="video-time"]))
    if length_seconds
      length_seconds = decode_length_seconds(length_seconds.content)
    else
      length_seconds = -1
    end

    videos << SearchVideo.new(
      title,
      id,
      author,
      author_id,
      published,
      view_count,
      description,
      description_html,
      length_seconds,
    )
  end

  return videos
end
