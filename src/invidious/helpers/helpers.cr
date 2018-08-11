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

def produce_playlist_url(ucid, index)
  ucid = ucid.lchop("UC")
  ucid = "VLUU" + ucid

  continuation = write_var_int(index)
  continuation.unshift(0x08_u8)
  slice = continuation.to_unsafe.to_slice(continuation.size)

  continuation = Base64.urlsafe_encode(slice, false)
  continuation = "PT:" + continuation
  continuation = continuation.bytes
  continuation.unshift(0x7a_u8, continuation.size.to_u8)

  slice = continuation.to_unsafe.to_slice(continuation.size)
  continuation = Base64.urlsafe_encode(slice)
  continuation = URI.escape(continuation)
  continuation = continuation.bytes
  continuation.unshift(continuation.size.to_u8)

  continuation.unshift(ucid.size.to_u8)
  continuation = ucid.bytes + continuation
  continuation.unshift(0x12.to_u8, ucid.size.to_u8)
  continuation.unshift(0xe2_u8, 0xa9_u8, 0x85_u8, 0xb2_u8, 2_u8, continuation.size.to_u8)

  slice = continuation.to_unsafe.to_slice(continuation.size)
  continuation = Base64.urlsafe_encode(slice)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?action_continuation=1&continuation=#{continuation}"

  return url
end

def produce_videos_url(ucid, page = 1)
  page = "#{page}"

  meta = "\x12\x06videos \x00\x30\x02\x38\x01\x60\x01\x6a\x00\x7a"
  meta += page.size.to_u8.unsafe_chr
  meta += page
  meta += "\xb8\x01\x00"

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

def read_var_int(bytes)
  numRead = 0
  result = 0

  read = bytes[numRead]

  if bytes.size == 1
    result = bytes[0].to_i32
  else
    while ((read & 0b10000000) != 0)
      read = bytes[numRead].to_u64
      value = (read & 0b01111111)
      result |= (value << (7 * numRead))

      numRead += 1
      if numRead > 5
        raise "VarInt is too big"
      end
    end
  end

  return result
end

def write_var_int(value : Int)
  bytes = [] of UInt8
  value = value.to_u32

  if value == 0
    bytes = [0_u8]
  else
    while value != 0
      temp = (value & 0b01111111).to_u8
      value = value >> 7

      if value != 0
        temp |= 0b10000000
      end

      bytes << temp
    end
  end

  return bytes
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
  token = Base64.encode(token)

  return {challenge: challenge, token: token}
end

def html_to_description(description_html)
  if !description_html
    description = ""
    description_html = ""
  else
    description_html = description_html.to_s
    description = description_html.gsub("<br>", "\n")
    description = description.gsub("<br/>", "\n")
    description = XML.parse_html(description).content.strip("\n ")
  end

  return description, description_html
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

    # Skip playlists
    if node.xpath_node(%q(.//div[contains(@class, "yt-playlist-renderer")]))
      next
    end

    # Skip movies
    if node.xpath_node(%q(.//div[contains(@class, "yt-lockup-movie-top-content")]))
      next
    end

    metadata = node.xpath_nodes(%q(.//div[contains(@class,"yt-lockup-meta")]/ul/li))
    if metadata.size == 0
      next
    elsif metadata.size == 1
      if metadata[0].content.starts_with? "Starts"
        view_count = 0_i64
        published = Time.epoch(metadata[0].xpath_node(%q(.//span)).not_nil!["data-timestamp"].to_i64)
      else
        view_count = metadata[0].content.lchop("Streamed ").split(" ")[0].delete(",").to_i64
        published = Time.now
      end
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
