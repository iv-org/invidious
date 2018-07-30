# "Invidious" (which is what YouTube should be)
# Copyright (C) 2018  Omar Roth
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

require "crypto/bcrypt/password"
require "detect_language"
require "kemal"
require "openssl/hmac"
require "option_parser"
require "pg"
require "xml"
require "yaml"
require "./invidious/*"

CONFIG   = Config.from_yaml(File.read("config/config.yml"))
HMAC_KEY = CONFIG.hmac_key || Random::Secure.random_bytes(32)

crawl_threads = CONFIG.crawl_threads
channel_threads = CONFIG.channel_threads
video_threads = CONFIG.video_threads

Kemal.config.extra_options do |parser|
  parser.banner = "Usage: invidious [arguments]"
  parser.on("-t THREADS", "--crawl-threads=THREADS", "Number of threads for crawling (default: #{crawl_threads})") do |number|
    begin
      crawl_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-c THREADS", "--channel-threads=THREADS", "Number of threads for refreshing channels (default: #{channel_threads})") do |number|
    begin
      channel_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-v THREADS", "--video-threads=THREADS", "Number of threads for refreshing videos (default: #{video_threads})") do |number|
    begin
      video_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
end

Kemal::CLI.new

PG_URL = URI.new(
  scheme: "postgres",
  user: CONFIG.db[:user],
  password: CONFIG.db[:password],
  host: CONFIG.db[:host],
  port: CONFIG.db[:port],
  path: CONFIG.db[:dbname],
)

PG_DB      = DB.open PG_URL
YT_URL     = URI.parse("https://www.youtube.com")
REDDIT_URL = URI.parse("https://api.reddit.com")
LOGIN_URL  = URI.parse("https://accounts.google.com")

crawl_threads.times do
  spawn do
    ids = Deque(String).new
    random = Random.new

    client = make_client(YT_URL)
    search(random.base64(3), client) do |id|
      ids << id
    end

    loop do
      client = make_client(YT_URL)
      if ids.empty?
        search(random.base64(3), client) do |id|
          ids << id
        end
      end

      begin
        id = ids[0]
        video = get_video(id, client, PG_DB)
      rescue ex
        STDOUT << id << " : " << ex.message << "\n"
        next
      ensure
        ids.delete(id)
      end

      rvs = [] of Hash(String, String)
      if video.info.has_key?("rvs")
        video.info["rvs"].split(",").each do |rv|
          rvs << HTTP::Params.parse(rv).to_h
        end
      end

      rvs.each do |rv|
        if rv.has_key?("id") && !PG_DB.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", rv["id"], as: Bool)
          ids.delete(id)
          ids << rv["id"]
          if ids.size == 150
            ids.shift
          end
        end
      end

      Fiber.yield
    end
  end
end

channel_threads.times do |i|
  spawn do
    loop do
      query = "SELECT id FROM channels ORDER BY updated \
      LIMIT (SELECT count(*)/$2 FROM channels) \
      OFFSET (SELECT count(*)*$1/$2 FROM channels)"
      PG_DB.query(query, i, channel_threads) do |rs|
        rs.each do
          client = make_client(YT_URL)

          begin
            id = rs.read(String)
            channel = fetch_channel(id, client, PG_DB, false)
            PG_DB.exec("UPDATE channels SET updated = $1 WHERE id = $2", Time.now, id)
          rescue ex
            STDOUT << id << " : " << ex.message << "\n"
            next
          end
        end
      end

      Fiber.yield
    end
  end
end

video_threads.times do |i|
  spawn do
    loop do
      query = "SELECT id FROM videos ORDER BY updated \
      LIMIT (SELECT count(*)/$2 FROM videos) \
      OFFSET (SELECT count(*)*$1/$2 FROM videos)"
      PG_DB.query(query, i, video_threads) do |rs|
        rs.each do
          client = make_client(YT_URL)

          begin
            id = rs.read(String)
            video = get_video(id, client, PG_DB)
          rescue ex
            STDOUT << id << " : " << ex.message << "\n"
            client = make_client(YT_URL)
            next
          end
        end
      end

      Fiber.yield
    end
  end
end

top_videos = [] of Video
spawn do
  if CONFIG.dl_api_key
    DetectLanguage.configure do |config|
      config.api_key = CONFIG.dl_api_key.not_nil!
    end
    filter = true
  end

  filter ||= false

  loop do
    begin
      top = rank_videos(PG_DB, 40, filter, YT_URL)
    rescue ex
      next
    end

    if top.size > 0
      args = arg_array(top)
    else
      next
    end

    videos = [] of Video

    top.each do |id|
      client = make_client(YT_URL)
      begin
        videos << get_video(id, client, PG_DB)
      rescue ex
        next
      end
    end

    top_videos = videos
    Fiber.yield
  end
end

# Refresh decrypt function
decrypt_function = [] of {name: String, value: Int32}
spawn do
  loop do
    client = make_client(YT_URL)

    begin
      decrypt_function = update_decrypt_function(client)
    rescue ex
    end

    Fiber.yield
  end
end

before_all do |env|
  if env.request.cookies.has_key? "SID"
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    sid = env.request.cookies["SID"].value

    # Invidious users only have SID
    if !env.request.cookies.has_key? "SSID"
      user = PG_DB.query_one?("SELECT * FROM users WHERE id = $1", sid, as: User)

      if user
        env.set "user", user
      end
    else
      begin
        client = make_client(YT_URL)
        user = get_user(sid, client, headers, PG_DB, false)

        env.set "user", user
      rescue ex
      end
    end
  end
end

get "/" do |env|
  user = env.get? "user"
  if user
    user = user.as(User)
    if user.preferences.redirect_feed
      env.redirect "/feed/subscriptions"
    end
  end

  templated "index"
end

get "/watch" do |env|
  if env.params.query["v"]?
    id = env.params.query["v"]
  else
    next env.redirect "/"
  end

  user = env.get? "user"
  if user
    user = user.as(User)
    if user.watched != ["N/A"] && !user.watched.includes? id
      PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE id = $2", [id], user.id)
    end

    preferences = user.preferences
    subscriptions = user.subscriptions.as(Array(String))
  end
  subscriptions ||= [] of String

  autoplay = env.params.query["autoplay"]?.try &.to_i
  video_loop = env.params.query["video_loop"]?.try &.to_i

  if preferences
    autoplay ||= preferences.autoplay.to_unsafe
    video_loop ||= preferences.video_loop.to_unsafe
  end

  autoplay ||= 0
  video_loop ||= 0

  autoplay = autoplay == 1
  video_loop = video_loop == 1

  if env.params.query["start"]?
    video_start = decode_time(env.params.query["start"])
  end

  if env.params.query["t"]?
    video_start = decode_time(env.params.query["t"])
  end
  video_start ||= 0

  if env.params.query["end"]?
    video_end = decode_time(env.params.query["end"])
  end
  video_end ||= -1

  if env.params.query["listen"]? && env.params.query["listen"] == "true"
    listen = true
    env.params.query.delete_all("listen")
  end
  listen ||= false

  client = make_client(YT_URL)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    if !string.empty?
      fmt_stream << HTTP::Params.parse(string)
    end
  end

  fmt_stream.each { |s| s.add("label", "#{s["quality"]} - #{s["type"].split(";")[0].split("/")[1]}") }
  fmt_stream = fmt_stream.uniq { |s| s["label"] }

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end

  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end

    fmt_stream.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end
  end

  audio_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("audio") ? s : nil }
  audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
  audio_streams.each do |stream|
    stream["bitrate"] = (stream["bitrate"].to_f64/1000).to_i.to_s
  end

  player_response = JSON.parse(video.info["player_response"])
  if player_response["captions"]?
    captions = player_response["captions"]["playerCaptionsTracklistRenderer"]["captionTracks"]?.try &.as_a
  end
  captions ||= [] of JSON::Any

  if video.info["hlsvp"]?
    hlsvp = video.info["hlsvp"]

    if Kemal.config.ssl || CONFIG.https_only
      scheme = "https://"
    else
      scheme = "http://"
    end
    host = env.request.headers["Host"]
    url = "#{scheme}#{host}"

    hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", url)
  end

  rvs = [] of Hash(String, String)
  if video.info.has_key?("rvs")
    video.info["rvs"].split(",").each do |rv|
      rvs << HTTP::Params.parse(rv).to_h
    end
  end

  rating = video.info["avg_rating"].to_f64

  engagement = ((video.dislikes.to_f + video.likes.to_f)/video.views * 100)

  if video.likes > 0 || video.dislikes > 0
    calculated_rating = (video.likes.to_f/(video.likes.to_f + video.dislikes.to_f) * 4 + 1)
  end
  calculated_rating ||= 0.0

  if video.info["ad_slots"]?
    ad_slots = video.info["ad_slots"].split(",")
    ad_slots = ad_slots.join(", ")
  end

  if video.info["enabled_engage_types"]?
    engage_types = video.info["enabled_engage_types"].split(",")
    engage_types = engage_types.join(", ")
  end

  if video.info["ad_tag"]?
    ad_tag = URI.parse(video.info["ad_tag"])
    ad_query = HTTP::Params.parse(ad_tag.query.not_nil!)

    ad_category = URI.unescape(ad_query["iu"])
    ad_category = ad_category.lstrip("/4061/").split(".")[-1]

    ad_query = HTTP::Params.parse(ad_query["scp"])

    k2 = URI.unescape(ad_query["k2"]).split(",")
    k2 = k2.join(", ")
  end

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = add_alt_links(video.description)

  description = video.description.gsub("<br>", " ")
  description = description.gsub("<br/>", " ")
  description = XML.parse_html(description).content[0..200].gsub('"', "&quot;").gsub("\n", " ").strip(" ")
  if description.empty?
    description = " "
  end

  thumbnail = "https://i.ytimg.com/vi/#{id}/mqdefault.jpg"

  templated "watch"
end

get "/api/v1/captions/:id" do |env|
  id = env.params.url["id"]

  client = make_client(YT_URL)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    halt env, status_code: 403
  end

  player_response = JSON.parse(video.info["player_response"])
  if !player_response["captions"]?
    env.response.content_type = "application/json"
    next {
      "captions" => [] of String,
    }.to_json
  end

  tracks = player_response["captions"]["playerCaptionsTracklistRenderer"]["captionTracks"]?.try &.as_a
  tracks ||= [] of JSON::Any

  label = env.params.query["label"]?
  if !label
    env.response.content_type = "application/json"

    response = JSON.build do |json|
      json.object do
        json.field "captions" do
          json.array do
            tracks.each do |caption|
              json.object do
                json.field "label", caption["name"]["simpleText"]
                json.field "languageCode", caption["languageCode"]
              end
            end
          end
        end
      end
    end

    next response
  end

  track = tracks.select { |tracks| tracks["name"]["simpleText"] == label }

  env.response.content_type = "text/vtt"
  if track.empty?
    halt env, status_code: 403
  else
    track = track[0]
  end

  track_xml = client.get(track["baseUrl"].as_s).body
  track_xml = XML.parse(track_xml)

  webvtt = <<-END_VTT
  WEBVTT
  Kind: captions
  Language: #{track["languageCode"]}


  END_VTT

  track_xml.xpath_nodes("//transcript/text").each do |node|
    start_time = node["start"].to_f.seconds
    duration = node["dur"]?.try &.to_f.seconds
    duration ||= start_time
    end_time = start_time + duration

    start_time = "#{start_time.hours.to_s.rjust(2, '0')}:#{start_time.minutes.to_s.rjust(2, '0')}:#{start_time.seconds.to_s.rjust(2, '0')}.#{start_time.milliseconds.to_s.rjust(3, '0')}"
    end_time = "#{end_time.hours.to_s.rjust(2, '0')}:#{end_time.minutes.to_s.rjust(2, '0')}:#{end_time.seconds.to_s.rjust(2, '0')}.#{end_time.milliseconds.to_s.rjust(3, '0')}"

    text = HTML.unescape(node.content)
    if md = text.match(/(?<name>.*) : (?<text>.*)/)
      text = "<v #{md["name"]}>#{md["text"]}</v>"
    end

    webvtt = webvtt + <<-END_CUE
    #{start_time} --> #{end_time}
    #{text}


    END_CUE
  end

  webvtt
end

get "/api/v1/comments/:id" do |env|
  id = env.params.url["id"]

  source = env.params.query["source"]?
  source ||= "youtube"

  format = env.params.query["format"]?
  format ||= "json"

  if source == "youtube"
    client = make_client(YT_URL)
    headers = HTTP::Headers.new
    html = client.get("/watch?v=#{id}&disable_polymer=1")

    headers["cookie"] = html.cookies.add_request_headers(headers)["cookie"]
    headers["content-type"] = "application/x-www-form-urlencoded"

    headers["x-client-data"] = "CIi2yQEIpbbJAQipncoBCNedygEIqKPKAQ=="
    headers["x-spf-previous"] = "https://www.youtube.com/watch?v=#{id}"
    headers["x-spf-referer"] = "https://www.youtube.com/watch?v=#{id}"

    headers["x-youtube-client-name"] = "1"
    headers["x-youtube-client-version"] = "2.20180719"

    body = html.body
    session_token = body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/).not_nil!["session_token"]
    ctoken = body.match(/'COMMENTS_TOKEN': "(?<ctoken>[^"]+)"/)
    if !ctoken
      env.response.content_type = "application/json"
      next {"comments" => [] of String}.to_json
    end
    ctoken = ctoken["ctoken"]
    itct = body.match(/itct=(?<itct>[^"]+)"/).not_nil!["itct"]

    if env.params.query["continuation"]?
      continuation = env.params.query["continuation"]
      ctoken = continuation
    else
      continuation = ctoken
    end

    post_req = {
      "session_token" => session_token,
    }
    post_req = HTTP::Params.encode(post_req)

    response = client.post("/comment_service_ajax?action_get_comments=1&pbj=1&ctoken=#{ctoken}&continuation=#{continuation}&itct=#{itct}", headers, post_req).body
    response = JSON.parse(response)

    env.response.content_type = "application/json"

    if !response["response"]["continuationContents"]?
      halt env, status_code: 401
    end

    response = response["response"]["continuationContents"]
    if response["commentRepliesContinuation"]?
      body = response["commentRepliesContinuation"]
    else
      body = response["itemSectionContinuation"]
    end
    contents = body["contents"]?
    if !contents
      if format == "json"
        next {"comments" => [] of String}.to_json
      else
        next {"content_html" => ""}.to_json
      end
    end

    comments = JSON.build do |json|
      json.object do
        if body["header"]?
          comment_count = body["header"]["commentsHeaderRenderer"]["countText"]["simpleText"].as_s.delete("Comments,").to_i
          json.field "commentCount", comment_count
        end

        json.field "comments" do
          json.array do
            contents.as_a.each do |item|
              json.object do
                if !response["commentRepliesContinuation"]?
                  item = item["commentThreadRenderer"]
                end

                if item["replies"]?
                  item_replies = item["replies"]["commentRepliesRenderer"]
                end

                if !response["commentRepliesContinuation"]?
                  item_comment = item["comment"]["commentRenderer"]
                else
                  item_comment = item["commentRenderer"]
                end

                content_text = item_comment["contentText"]["simpleText"]?.try &.as_s.rchop('\ufeff')
                content_text ||= item_comment["contentText"]["runs"].as_a.map { |comment| comment["text"] }
                  .join("").rchop('\ufeff')

                json.field "author", item_comment["authorText"]["simpleText"]
                json.field "authorThumbnails" do
                  json.array do
                    item_comment["authorThumbnail"]["thumbnails"].as_a.each do |thumbnail|
                      json.object do
                        json.field "url", thumbnail["url"]
                        json.field "width", thumbnail["width"]
                        json.field "height", thumbnail["height"]
                      end
                    end
                  end
                end
                json.field "authorId", item_comment["authorEndpoint"]["browseEndpoint"]["browseId"]
                json.field "authorUrl", item_comment["authorEndpoint"]["browseEndpoint"]["canonicalBaseUrl"]
                json.field "content", content_text
                json.field "published", item_comment["publishedTimeText"]["runs"][0]["text"]
                json.field "likeCount", item_comment["likeCount"]
                json.field "commentId", item_comment["commentId"]

                if item_replies && !response["commentRepliesContinuation"]?
                  reply_count = item_replies["moreText"]["simpleText"].as_s.match(/View all (?<count>\d+) replies/)
                    .try &.["count"].to_i
                  reply_count ||= 1

                  continuation = item_replies["continuations"].as_a[0]["nextContinuationData"]["continuation"].as_s

                  json.field "replies" do
                    json.object do
                      json.field "replyCount", reply_count
                      json.field "continuation", continuation
                    end
                  end
                end
              end
            end
          end
        end

        if body["continuations"]?
          continuation = body["continuations"][0]["nextContinuationData"]["continuation"]
          json.field "continuation", continuation
        end
      end
    end

    if format == "json"
      next comments
    else
      comments = JSON.parse(comments)
      content_html = template_youtube_comments(comments)

      {"content_html" => content_html}.to_json
    end
  elsif source == "reddit"
    client = make_client(REDDIT_URL)
    headers = HTTP::Headers{"User-Agent" => "web:invidio.us:v0.1.0 (by /u/omarroth)"}
    begin
      comments, reddit_thread = get_reddit_comments(id, client, headers)
      content_html = template_reddit_comments(comments)

      content_html = fill_links(content_html, "https", "www.reddit.com")
      content_html = add_alt_links(content_html)
    rescue ex
      reddit_thread = nil
      content_html = ""
    end

    if !reddit_thread
      halt env, status_code: 404
    end

    {"title"        => reddit_thread.title,
     "permalink"    => reddit_thread.permalink,
     "content_html" => content_html}.to_json
  end
end

get "/api/v1/videos/:id" do |env|
  id = env.params.url["id"]

  client = make_client(YT_URL)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    halt env, status_code: 403
  end

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    if !string.empty?
      fmt_stream << HTTP::Params.parse(string)
    end
  end

  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end

    fmt_stream.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end
  end

  player_response = JSON.parse(video.info["player_response"])
  if player_response["captions"]?
    captions = player_response["captions"]["playerCaptionsTracklistRenderer"]["captionTracks"]?.try &.as_a
  end
  captions ||= [] of JSON::Any

  env.response.content_type = "application/json"
  video_info = JSON.build do |json|
    json.object do
      json.field "title", video.title
      json.field "videoId", video.id
      json.field "videoThumbnails" do
        json.object do
          qualities = [{name: "default", url: "default", width: 120, height: 90},
                       {name: "high", url: "hqdefault", width: 480, height: 360},
                       {name: "medium", url: "mqdefault", width: 320, height: 180},
          ]
          qualities.each do |quality|
            json.field quality[:name] do
              json.object do
                json.field "url", "https://i.ytimg.com/vi/#{id}/#{quality["url"]}.jpg"
                json.field "width", quality[:width]
                json.field "height", quality[:height]
              end
            end
          end
        end
      end

      description = video.description.gsub("<br>", "\n")
      description = description.gsub("<br/>", "\n")
      description = XML.parse_html(description)

      json.field "description", description.content
      json.field "descriptionHtml", video.description
      json.field "published", video.published.epoch
      json.field "keywords" do
        json.array do
          video.info["keywords"].split(",").each { |keyword| json.string keyword }
        end
      end

      json.field "viewCount", video.views
      json.field "likeCount", video.likes
      json.field "dislikeCount", video.dislikes

      json.field "isFamilyFriendly", video.is_family_friendly
      json.field "allowedRegions", video.allowed_regions
      json.field "genre", video.genre

      json.field "author", video.author
      json.field "authorId", video.ucid
      json.field "authorUrl", "/channel/#{video.ucid}"

      json.field "lengthSeconds", video.info["length_seconds"].to_i
      if video.info["allow_ratings"]?
        json.field "allowRatings", video.info["allow_ratings"] == "1"
      else
        json.field "allowRatings", false
      end
      json.field "rating", video.info["avg_rating"].to_f32

      if video.info["is_listed"]?
        json.field "isListed", video.info["is_listed"] == "1"
      end

      fmt_list = video.info["fmt_list"].split(",").map { |fmt| fmt.split("/")[1] }
      fmt_list = Hash.zip(fmt_list.map { |fmt| fmt[0] }, fmt_list.map { |fmt| fmt[1] })

      json.field "adaptiveFormats" do
        json.array do
          adaptive_fmts.each_with_index do |adaptive_fmt, i|
            json.object do
              json.field "index", adaptive_fmt["index"]
              json.field "bitrate", adaptive_fmt["bitrate"]
              json.field "init", adaptive_fmt["init"]
              json.field "url", adaptive_fmt["url"]
              json.field "itag", adaptive_fmt["itag"]
              json.field "type", adaptive_fmt["type"]
              json.field "clen", adaptive_fmt["clen"]
              json.field "lmt", adaptive_fmt["lmt"]
              json.field "projectionType", adaptive_fmt["projection_type"]

              fmt_info = itag_to_metadata(adaptive_fmt["itag"])
              json.field "container", fmt_info["ext"]
              json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

              if fmt_info["fps"]?
                json.field "fps", fmt_info["fps"]
              end

              if fmt_info["height"]?
                json.field "qualityLabel", "#{fmt_info["height"]}p"
                json.field "resolution", "#{fmt_info["height"]}p"

                if fmt_info["width"]?
                  json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                end
              end
            end
          end
        end
      end

      json.field "formatStreams" do
        json.array do
          fmt_stream.each do |fmt|
            json.object do
              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"]
              json.field "type", fmt["type"]
              json.field "quality", fmt["quality"]

              fmt_info = itag_to_metadata(fmt["itag"])
              json.field "container", fmt_info["ext"]
              json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

              if fmt_info["fps"]?
                json.field "fps", fmt_info["fps"]
              end

              if fmt_info["height"]?
                json.field "qualityLabel", "#{fmt_info["height"]}p"
                json.field "resolution", "#{fmt_info["height"]}p"

                if fmt_info["width"]?
                  json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                end
              end
            end
          end
        end
      end

      json.field "captions" do
        json.array do
          captions.each do |caption|
            json.object do
              json.field "label", caption["name"]["simpleText"]
              json.field "languageCode", caption["languageCode"]
            end
          end
        end
      end

      json.field "recommendedVideos" do
        json.array do
          video.info["rvs"].split(",").each do |rv|
            rv = HTTP::Params.parse(rv)

            if rv["id"]?
              json.object do
                json.field "videoId", rv["id"]
                json.field "title", rv["title"]
                json.field "videoThumbnails" do
                  json.object do
                    qualities = [{name: "default", url: "default", width: 120, height: 90},
                                 {name: "high", url: "hqdefault", width: 480, height: 360},
                                 {name: "medium", url: "mqdefault", width: 320, height: 180},
                    ]
                    qualities.each do |quality|
                      json.field quality[:name] do
                        json.object do
                          json.field "url", "https://i.ytimg.com/vi/#{rv["id"]}/#{quality["url"]}.jpg"
                          json.field "width", quality[:width]
                          json.field "height", quality[:height]
                        end
                      end
                    end
                  end
                end
                json.field "author", rv["author"]
                json.field "lengthSeconds", rv["length_seconds"]
                json.field "viewCountText", rv["short_view_count_text"].rchop(" views")
              end
            end
          end
        end
      end
    end
  end

  video_info
end

get "/api/v1/trending" do |env|
  client = make_client(YT_URL)
  trending = client.get("/feed/trending?disable_polymer=1").body

  trending = XML.parse_html(trending)
  videos = JSON.build do |json|
    json.array do
      trending.xpath_nodes(%q(//ul/li[@class="expanded-shelf-content-item-wrapper"])).each do |node|
        length_seconds = node.xpath_node(%q(.//span[@class="video-time"])).not_nil!.content
        minutes, seconds = length_seconds.split(":")
        length_seconds = minutes.to_i * 60 + seconds.to_i

        video = node.xpath_node(%q(.//h3/a)).not_nil!
        title = video.content
        id = video["href"].lchop("/watch?v=")

        channel = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-byline")]/a)).not_nil!
        author = channel.content
        author_url = channel["href"]

        published, views = node.xpath_nodes(%q(.//ul[@class="yt-lockup-meta-info"]/li))
        views = views.content.rchop(" views").delete(",").to_i

        descriptionHtml = node.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
        if !descriptionHtml
          description = ""
          descriptionHtml = ""
        else
          descriptionHtml = descriptionHtml.to_s
          description = descriptionHtml.gsub("<br>", "\n")
          description = description.gsub("<br/>", "\n")
          description = XML.parse_html(description).content.strip("\n ")
        end

        published = published.content.split(" ")[-3..-1].join(" ")
        published = decode_date(published)

        json.object do
          json.field "title", title
          json.field "videoId", id
          json.field "videoThumbnails" do
            json.object do
              qualities = [{name: "default", url: "default", width: 120, height: 90},
                           {name: "high", url: "hqdefault", width: 480, height: 360},
                           {name: "medium", url: "mqdefault", width: 320, height: 180},
              ]
              qualities.each do |quality|
                json.field quality[:name] do
                  json.object do
                    json.field "url", "https://i.ytimg.com/vi/#{id}/#{quality["url"]}.jpg"
                    json.field "width", quality[:width]
                    json.field "height", quality[:height]
                  end
                end
              end
            end
          end

          json.field "lengthSeconds", length_seconds
          json.field "views", views
          json.field "author", author
          json.field "authorUrl", author_url
          json.field "published", published.epoch
          json.field "description", description
          json.field "descriptionHtml", descriptionHtml
        end
      end
    end
  end

  env.response.content_type = "application/json"
  videos
end

get "/api/v1/top" do |env|
  videos = JSON.build do |json|
    json.array do
      top_videos.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id
          json.field "videoThumbnails" do
            json.object do
              qualities = [{name: "default", url: "default", width: 120, height: 90},
                           {name: "high", url: "hqdefault", width: 480, height: 360},
                           {name: "medium", url: "mqdefault", width: 320, height: 180},
              ]
              qualities.each do |quality|
                json.field quality[:name] do
                  json.object do
                    json.field "url", "https://i.ytimg.com/vi/#{video.id}/#{quality["url"]}.jpg"
                    json.field "width", quality[:width]
                    json.field "height", quality[:height]
                  end
                end
              end
            end
          end

          json.field "lengthSeconds", video.info["length_seconds"].to_i
          json.field "views", video.views

          json.field "author", video.author
          json.field "authorUrl", "/channel/#{video.ucid}"
          json.field "published", video.published.epoch

          description = video.description.gsub("<br>", "\n")
          description = description.gsub("<br/>", "\n")
          description = XML.parse_html(description)
          json.field "description", description.content
          json.field "descriptionHtml", video.description
        end
      end
    end
  end

  env.response.content_type = "application/json"
  videos
end

get "/api/v1/channels/:ucid" do |env|
  ucid = env.params.url["ucid"]

  client = make_client(YT_URL)
  channel = get_channel(ucid, client, PG_DB, pull_all_videos: false)

  # TODO: Integrate this into `get_channel` function
  # We can't get everything from RSS feed, so we get it from the channel page
  channel_html = client.get("/channel/#{ucid}/about?disable_polymer=1").body
  channel_html = XML.parse_html(channel_html)
  banner = channel_html.xpath_node(%q(//div[@id="gh-banner"]/style)).not_nil!.content
  banner = "https:" + banner.match(/background-image: url\((?<url>[^)]+)\)/).not_nil!["url"]

  author_url = channel_html.xpath_node(%q(//a[@class="channel-header-profile-image-container spf-link"])).not_nil!["href"]
  author_thumbnail = channel_html.xpath_node(%q(//img[@class="channel-header-profile-image"])).not_nil!["src"]
  description = channel_html.xpath_node(%q(//meta[@itemprop="description"])).not_nil!["content"]

  paid = channel_html.xpath_node(%q(//meta[@itemprop="paid"])).not_nil!["content"] == "True"
  is_family_friendly = channel_html.xpath_node(%q(//meta[@itemprop="isFamilyFriendly"])).not_nil!["content"] == "True"
  allowed_regions = channel_html.xpath_node(%q(//meta[@itemprop="regionsAllowed"])).not_nil!["content"].split(",")

  sub_count, total_views, joined = channel_html.xpath_nodes(%q(//span[@class="about-stat"]))
  sub_count = sub_count.content.rchop(" subscribers").delete(",").to_i64
  total_views = total_views.content.rchop(" views").lchop(" • ").delete(",").to_i64
  joined = Time.parse(joined.content.lchop("Joined "), "%b %-d, %Y", Time::Location.local)

  latest_videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid = $1 ORDER BY published DESC LIMIT 15",
    channel.id, as: ChannelVideo)

  channel_info = JSON.build do |json|
    json.object do
      json.field "author", channel.author
      json.field "authorId", channel.id
      json.field "authorUrl", author_url

      json.field "authorBanners" do
        json.array do
          qualities = [{width: 2560, height: 424},
                       {width: 2120, height: 351},
                       {width: 1060, height: 175}]
          qualities.each do |quality|
            json.object do
              json.field "url", banner.gsub("=w1060", "=w#{quality[:width]}")
              json.field "width", quality[:width]
              json.field "height", quality[:height]
            end
          end

          json.object do
            json.field "url", banner.rchop("=w1060-fcrop64=1,00005a57ffffa5a8-nd-c0xffffffff-rj-k-no")
            json.field "width", 512
            json.field "height", 288
          end
        end
      end

      json.field "authorThumbnails" do
        json.array do
          qualities = [32, 48, 76, 100, 512]

          qualities.each do |quality|
            json.object do
              json.field "url", author_thumbnail.gsub("/s100-", "/s#{quality}-")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCount", sub_count
      json.field "totalViews", total_views
      json.field "joined", joined.epoch
      json.field "paid", paid

      json.field "isFamilyFriendly", is_family_friendly
      json.field "description", description
      json.field "allowedRegions", allowed_regions

      json.field "latestVideos" do
        json.array do
          latest_videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id
              json.field "published", video.published.epoch

              json.field "videoThumbnails" do
                json.object do
                  qualities = [{name: "default", url: "default", width: 120, height: 90},
                               {name: "high", url: "hqdefault", width: 480, height: 360},
                               {name: "medium", url: "mqdefault", width: 320, height: 180},
                  ]
                  qualities.each do |quality|
                    json.field quality[:name] do
                      json.object do
                        json.field "url", "https://i.ytimg.com/vi/#{video.id}/#{quality["url"]}.jpg"
                        json.field "width", quality[:width]
                        json.field "height", quality[:height]
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  env.response.content_type = "application/json"
  channel_info
end

get "/api/v1/channels/:ucid/videos" do |env|
  ucid = env.params.url["ucid"]
  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  url = produce_videos_url(ucid, page)
  client = make_client(YT_URL)
  response = client.get(url)

  json = JSON.parse(response.body)
  if !json["content_html"]?
    env.response.content_type = "application/json"
    next {"error" => "No videos or nonexistent channel"}.to_json
  end

  content_html = json["content_html"].as_s
  if content_html.empty?
    env.response.content_type = "application/json"
    next Hash(String, String).new.to_json
  end
  document = XML.parse_html(content_html)

  videos = JSON.build do |json|
    json.array do
      document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")])).each do |item|
        anchor = item.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a)).not_nil!
        title = anchor.content.strip
        video_id = anchor["href"].lchop("/watch?v=")

        view_count = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[2])).not_nil!
        view_count = view_count.content.rchop(" views").delete(",").to_i

        descriptionHtml = item.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
        if !descriptionHtml
          description = ""
          descriptionHtml = ""
        else
          descriptionHtml = descriptionHtml.to_s
          description = descriptionHtml.gsub("<br>", "\n")
          description = description.gsub("<br/>", "\n")
          description = XML.parse_html(description).content.strip("\n ")
        end

        published = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[1]))
        if !published
          next
        end
        published = published.content
        published = decode_date(published)

        length_seconds = item.xpath_node(%q(.//span[@class="video-time"]/span)).not_nil!.content
        length_seconds = length_seconds.split(":").map { |a| a.to_i }
        length_seconds = [0] * (3 - length_seconds.size) + length_seconds
        length_seconds = Time::Span.new(length_seconds[0], length_seconds[1], length_seconds[2])

        json.object do
          json.field "title", title
          json.field "videoId", video_id

          json.field "videoThumbnails" do
            json.object do
              qualities = [{name: "default", url: "default", width: 120, height: 90},
                           {name: "high", url: "hqdefault", width: 480, height: 360},
                           {name: "medium", url: "mqdefault", width: 320, height: 180},
              ]
              qualities.each do |quality|
                json.field quality[:name] do
                  json.object do
                    json.field "url", "https://i.ytimg.com/vi/#{video_id}/#{quality["url"]}.jpg"
                    json.field "width", quality[:width]
                    json.field "height", quality[:height]
                  end
                end
              end
            end
          end

          json.field "description", description
          json.field "descriptionHtml", descriptionHtml

          json.field "viewCount", view_count
          json.field "published", published.epoch
          json.field "lengthSeconds", length_seconds.total_seconds.to_i
        end
      end
    end
  end

  env.response.content_type = "application/json"
  videos
end

get "/embed/:id" do |env|
  if env.params.url["id"]?
    id = env.params.url["id"]
  else
    next env.redirect "/"
  end

  if env.params.query["start"]?
    video_start = decode_time(env.params.query["start"])
  end

  if env.params.query["t"]?
    video_start = decode_time(env.params.query["t"])
  end
  video_start ||= 0

  if env.params.query["end"]?
    video_end = decode_time(env.params.query["end"])
  end
  video_end ||= -1

  if env.params.query["listen"]? && env.params.query["listen"] == "true"
    listen = true
    env.params.query.delete_all("listen")
  end
  listen ||= false

  raw = env.params.query["raw"]? && env.params.query["raw"].to_i
  raw ||= 0
  raw = raw == 1

  quality = env.params.query["quality"]? && env.params.query["quality"]
  quality ||= "hd720"

  autoplay = env.params.query["autoplay"]?.try &.to_i
  autoplay ||= 0

  controls = env.params.query["controls"]?.try &.to_i
  controls ||= 1

  video_loop = env.params.query["loop"]?.try &.to_i
  video_loop ||= 0

  client = make_client(YT_URL)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    if !string.empty?
      fmt_stream << HTTP::Params.parse(string)
    end
  end

  fmt_stream.each { |s| s.add("label", "#{s["quality"]} - #{s["type"].split(";")[0].split("/")[1]}") }
  fmt_stream = fmt_stream.uniq { |s| s["label"] }

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end

  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end

    fmt_stream.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end
  end

  audio_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("audio") ? s : nil }
  audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
  audio_streams.each do |stream|
    stream["bitrate"] = (stream["bitrate"].to_f64/1000).to_i.to_s
  end

  if raw
    url = fmt_stream[0]["url"]

    fmt_stream.each do |fmt|
      if fmt["label"].split(" - ")[0] == quality
        url = fmt["url"]
      end
    end

    next env.redirect url
  end

  thumbnail = "https://i.ytimg.com/vi/#{id}/mqdefault.jpg"

  rendered "embed"
end

get "/results" do |env|
  search_query = env.params.query["search_query"]?
  if search_query
    env.redirect "/search?q=#{URI.escape(search_query)}"
  else
    env.redirect "/"
  end
end

get "/search" do |env|
  if env.params.query["q"]?
    query = env.params.query["q"]
  else
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  client = make_client(YT_URL)

  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=EgIQAVAU").body
  html = XML.parse_html(html)

  videos = [] of ChannelVideo

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if root
      id = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
      if id
        id = id.content.lchop("/watch?v=")
      end
      id ||= ""

      title = root.xpath_node(%q(div[@class="yt-lockup-content"]/h3/a))
      if title
        title = title.content
      end
      title ||= ""

      author = root.xpath_node(%q(div[@class="yt-lockup-content"]/div/a))
      if author
        ucid = author["href"].rpartition("/")[-1]
        author = author.content
      end
      author ||= ""
      ucid ||= ""

      video = ChannelVideo.new(id, title, Time.now, Time.now, ucid, author)
      videos << video
    end
  end

  templated "search"
end

get "/login" do |env|
  user = env.get? "user"
  if user
    next env.redirect "/feed/subscriptions"
  end

  referer = env.request.headers["referer"]?
  referer ||= "/feed/subscriptions"

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  if account_type == "invidious"
    captcha = generate_captcha(HMAC_KEY)
  end

  tfa = env.params.query["tfa"]?
  tfa ||= false

  if referer.ends_with? "/login"
    referer = "/feed/subscriptions"
  end

  if referer.size > 64
    referer = "/feed/subscriptions"
  end

  templated "login"
end

# See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L79
post "/login" do |env|
  referer = env.params.query["referer"]?
  referer ||= "/feed/subscriptions"

  email = env.params.body["email"]?
  password = env.params.body["password"]?

  account_type = env.params.query["type"]?
  account_type ||= "google"

  if account_type == "google"
    tfa_code = env.params.body["tfa"]?.try &.lchop("G-")

    begin
      client = make_client(LOGIN_URL)
      headers = HTTP::Headers.new
      headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8"
      headers["Google-Accounts-XSRF"] = "1"

      login_page = client.get("/ServiceLogin")
      headers = login_page.cookies.add_request_headers(headers)

      login_page = XML.parse_html(login_page.body)

      inputs = {} of String => String
      login_page.xpath_nodes(%q(//input[@type="submit"])).each do |node|
        name = node["id"]? || node["name"]?
        name ||= ""
        value = node["value"]?
        value ||= ""

        if name != "" && value != ""
          inputs[name] = value
        end
      end

      login_page.xpath_nodes(%q(//input[@type="hidden"])).each do |node|
        name = node["id"]? || node["name"]?
        name ||= ""
        value = node["value"]?
        value ||= ""

        if name != "" && value != ""
          inputs[name] = value
        end
      end

      lookup_req = %(["#{email}",null,[],null,"US",null,null,2,false,true,[null,null,[2,1,null,1,"https://accounts.google.com/ServiceLogin?passive=1209600&continue=https%3A%2F%2Faccounts.google.com%2FManageAccount&followup=https%3A%2F%2Faccounts.google.com%2FManageAccount",null,[],4,[]],1,[null,null,[]],null,null,null,true],"#{email}"])

      lookup_results = client.post("/_/signin/sl/lookup", headers, login_req(inputs, lookup_req))
      headers = lookup_results.cookies.add_request_headers(headers)

      lookup_results = lookup_results.body
      lookup_results = lookup_results[5..-1]
      lookup_results = JSON.parse(lookup_results)

      user_hash = lookup_results[0][2]

      challenge_req = %(["#{user_hash}",null,1,null,[1,null,null,null,["#{password}",null,true]],[null,null,[2,1,null,1,"https://accounts.google.com/ServiceLogin?passive=1209600&continue=https%3A%2F%2Faccounts.google.com%2FManageAccount&followup=https%3A%2F%2Faccounts.google.com%2FManageAccount",null,[],4,[]],1,[null,null,[]],null,null,null,true]])

      challenge_results = client.post("/_/signin/sl/challenge", headers, login_req(inputs, challenge_req))
      headers = challenge_results.cookies.add_request_headers(headers)

      challenge_results = challenge_results.body
      challenge_results = challenge_results[5..-1]
      challenge_results = JSON.parse(challenge_results)

      headers["Cookie"] = URI.unescape(headers["Cookie"])

      if challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
        error_message = "Incorrect password"
        next templated "error"
      end

      if challenge_results[0][-1][0].as_a?
        # Prefer Authenticator app and SMS over unsupported protocols
        if challenge_results[0][-1][0][0][8] != 6 || challenge_results[0][-1][0][0][8] != 9
          tfa = challenge_results[0][-1][0].as_a.select { |auth_type| auth_type[8] == 6 || auth_type[8] == 9 }[0]
          select_challenge = "[#{challenge_results[0][-1][0].as_a.index(tfa).not_nil!}]"

          tl = challenge_results[1][2]

          tfa = client.post("/_/signin/selectchallenge?TL=#{tl}", headers, login_req(inputs, select_challenge)).body
          tfa = tfa[5..-1]
          tfa = JSON.parse(tfa)[0][-1]
        else
          tfa = challenge_results[0][-1][0][0]
        end

        if tfa[2] == "TWO_STEP_VERIFICATION"
          if tfa[5] == "QUOTA_EXCEEDED"
            error_message = "Quota exceeded, try again in a few hours"
            next templated "error"
          end

          if !tfa_code
            next env.redirect "/login?tfa=true&type=google"
          end

          tl = challenge_results[1][2]

          request_type = tfa[8]
          case request_type
          when 6
            # Authenticator app
            tfa_req = %(["#{user_hash}",null,2,null,[6,null,null,null,null,["#{tfa_code}",false]]])
          when 9
            # Voice or text message
            tfa_req = %(["#{user_hash}",null,2,null,[9,null,null,null,null,null,null,null,[null,"#{tfa_code}",false,2]]])
          else
            error_message = "Unable to login, make sure two-factor authentication (Authenticator or SMS) is enabled."
            next templated "error"
          end

          challenge_results = client.post("/_/signin/challenge?hl=en&TL=#{tl}", headers, login_req(inputs, tfa_req))
          headers = challenge_results.cookies.add_request_headers(headers)

          challenge_results = challenge_results.body
          challenge_results = challenge_results[5..-1]
          challenge_results = JSON.parse(challenge_results)

          if challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
            error_message = "Invalid TFA code"
            next templated "error"
          end
        end
      end

      login_res = challenge_results[0][13][2].to_s

      login = client.get(login_res, headers)
      headers = login.cookies.add_request_headers(headers)

      login = client.get(login.headers["Location"], headers)

      headers = HTTP::Headers.new
      headers = login.cookies.add_request_headers(headers)

      sid = login.cookies["SID"].value

      client = make_client(YT_URL)
      user = get_user(sid, client, headers, PG_DB)

      # We are now logged in

      host = URI.parse(env.request.headers["Host"]).host

      login.cookies.each do |cookie|
        if Kemal.config.ssl || CONFIG.https_only
          cookie.secure = true
        else
          cookie.secure = false
        end

        cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
        cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
      end

      login.cookies.add_response_headers(env.response.headers)

      env.redirect referer
    rescue ex
      error_message = "Login failed. This may be because two-factor authentication is not enabled on your account."
      next templated "error"
    end
  elsif account_type == "invidious"
    challenge_response = env.params.body["challenge_response"]?
    token = env.params.body["token"]?

    action = env.params.body["action"]?
    action ||= "signin"

    if !email
      error_message = "User ID is a required field"
      next templated "error"
    end

    if !password
      error_message = "Password is a required field"
      next templated "error"
    end

    if !challenge_response || !token
      error_message = "CAPTCHA is a required field"
      next templated "error"
    end

    challenge_response = challenge_response.lstrip('0')
    if OpenSSL::HMAC.digest(:sha256, HMAC_KEY, challenge_response) == Base64.decode(token)
    else
      error_message = "Invalid CAPTCHA response"
      next templated "error"
    end

    if action == "signin"
      user = PG_DB.query_one?("SELECT * FROM users WHERE email = $1 AND password IS NOT NULL", email, as: User)

      if !user
        error_message = "Invalid username or password"
        next templated "error"
      end

      if !user.password
        error_message = "Please sign in using 'Sign in with Google'"
        next templated "error"
      end

      if Crypto::Bcrypt::Password.new(user.password.not_nil!) == password
        sid = Base64.encode(Random::Secure.random_bytes(50))
        PG_DB.exec("UPDATE users SET id = $1 WHERE email = $2", sid, email)

        if Kemal.config.ssl || CONFIG.https_only
          secure = true
        else
          secure = false
        end

        env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.now + 2.years,
          secure: secure, http_only: true)
      else
        error_message = "Invalid username or password"
        next templated "error"
      end
    elsif action == "register"
      user = PG_DB.query_one?("SELECT * FROM users WHERE email = $1 AND password IS NOT NULL", email, as: User)
      if user
        error_message = "Please sign in"
        next templated "error"
      end

      sid = Base64.encode(Random::Secure.random_bytes(50))
      user = create_user(sid, email, password)
      if user.watched = ["N/A"]
        user_array = user.to_a[0..-2]
      else
        user_array = user.to_a
      end

      user_array[5] = user_array[5].to_json
      args = arg_array(user_array)

      PG_DB.exec("INSERT INTO users VALUES (#{args})", user_array)

      if Kemal.config.ssl || CONFIG.https_only
        secure = true
      else
        secure = false
      end

      env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.now + 2.years,
        secure: secure, http_only: true)
    end

    env.redirect referer
  end
end

get "/signout" do |env|
  referer = env.request.headers["referer"]?
  referer ||= "/"

  env.request.cookies.each do |cookie|
    cookie.expires = Time.new(1990, 1, 1)
  end

  env.request.cookies.add_response_headers(env.response.headers)
  env.redirect referer
end

get "/preferences" do |env|
  user = env.get? "user"

  referer = env.request.headers["referer"]?
  referer ||= "/preferences"

  if referer.size > 64
    referer = "/preferences"
  end

  if user
    user = user.as(User)
    templated "preferences"
  else
    env.redirect referer
  end
end

post "/preferences" do |env|
  user = env.get? "user"

  referer = env.params.query["referer"]?
  referer ||= "/preferences"

  if user
    user = user.as(User)

    video_loop = env.params.body["video_loop"]?.try &.as(String)
    video_loop ||= "off"
    video_loop = video_loop == "on"

    autoplay = env.params.body["autoplay"]?.try &.as(String)
    autoplay ||= "off"
    autoplay = autoplay == "on"

    speed = env.params.body["speed"]?.try &.as(String).to_f
    speed ||= 1.0

    quality = env.params.body["quality"]?.try &.as(String)
    quality ||= "hd720"

    volume = env.params.body["volume"]?.try &.as(String).to_i
    volume ||= 100

    comments = env.params.body["comments"]?
    comments ||= "youtube"

    redirect_feed = env.params.body["redirect_feed"]?.try &.as(String)
    redirect_feed ||= "off"
    redirect_feed = redirect_feed == "on"

    dark_mode = env.params.body["dark_mode"]?.try &.as(String)
    dark_mode ||= "off"
    dark_mode = dark_mode == "on"

    thin_mode = env.params.body["thin_mode"]?.try &.as(String)
    thin_mode ||= "off"
    thin_mode = thin_mode == "on"

    max_results = env.params.body["max_results"]?.try &.as(String).to_i
    max_results ||= 40

    sort = env.params.body["sort"]?.try &.as(String)
    sort ||= "published"

    latest_only = env.params.body["latest_only"]?.try &.as(String)
    latest_only ||= "off"
    latest_only = latest_only == "on"

    unseen_only = env.params.body["unseen_only"]?.try &.as(String)
    unseen_only ||= "off"
    unseen_only = unseen_only == "on"

    preferences = {
      "video_loop"    => video_loop,
      "autoplay"      => autoplay,
      "speed"         => speed,
      "quality"       => quality,
      "volume"        => volume,
      "comments"      => comments,
      "redirect_feed" => redirect_feed,
      "dark_mode"     => dark_mode,
      "thin_mode"     => thin_mode,
      "max_results"   => max_results,
      "sort"          => sort,
      "latest_only"   => latest_only,
      "unseen_only"   => unseen_only,
    }.to_json

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)
  end

  env.redirect referer
end

# Get subscriptions for authorized user
get "/feed/subscriptions" do |env|
  user = env.get? "user"

  if user
    user = user.as(User)
    preferences = user.preferences

    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    if !user.password
      client = make_client(YT_URL)
      user = get_user(user.id, client, headers, PG_DB)
    end

    max_results = preferences.max_results
    max_results ||= env.params.query["max_results"]?.try &.to_i
    max_results ||= 40

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    if max_results < 0
      limit = nil
      offset = (page - 1) * 1
    else
      limit = max_results
      offset = (page - 1) * max_results
    end

    if preferences.latest_only
      if preferences.unseen_only
        ucids = arg_array(user.subscriptions)
        if user.watched.empty?
          watched = "'{}'"
        else
          watched = arg_array(user.watched, user.subscriptions.size + 1)
        end

        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM channel_videos WHERE \
      ucid IN (#{ucids}) AND id NOT IN (#{watched}) ORDER BY ucid, published DESC",
          user.subscriptions + user.watched, as: ChannelVideo)
      else
        args = arg_array(user.subscriptions)
        videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM channel_videos WHERE \
        ucid IN (#{args}) ORDER BY ucid, published DESC", user.subscriptions, as: ChannelVideo)
      end

      videos.sort_by! { |video| video.published }.reverse!
    else
      if preferences.unseen_only
        ucids = arg_array(user.subscriptions, 3)
        if user.watched.empty?
          watched = "'{}'"
        else
          watched = arg_array(user.watched, user.subscriptions.size + 3)
        end

        videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid IN (#{ucids}) \
          AND id NOT IN (#{watched}) ORDER BY published DESC LIMIT $1 OFFSET $2",
          [limit, offset] + user.subscriptions + user.watched, as: ChannelVideo)
      else
        args = arg_array(user.subscriptions, 3)
        videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid IN (#{args}) \
          ORDER BY published DESC LIMIT $1 OFFSET $2", [limit, offset] + user.subscriptions, as: ChannelVideo)
      end
    end

    case preferences.sort
    when "alphabetically"
      videos.sort_by! { |video| video.title }
    when "alphabetically - reverse"
      videos.sort_by! { |video| video.title }.reverse!
    when "channel name"
      videos.sort_by! { |video| video.author }
    when "channel name - reverse"
      videos.sort_by! { |video| video.author }.reverse!
    end

    # TODO: Add option to disable picking out notifications from regular feed
    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
      as: Array(String))

    notifications = videos.select { |v| notifications.includes? v.id }
    videos = videos - notifications

    if !limit
      videos = videos[0..max_results]
    end

    PG_DB.exec("UPDATE users SET notifications = $1, updated = $2 WHERE id = $3", [] of String, Time.now,
      user.id)
    user.notifications = [] of String
    env.set "user", user

    templated "subscriptions"
  else
    env.redirect "/"
  end
end

get "/feed/channel/:ucid" do |env|
  ucid = env.params.url["ucid"]

  url = produce_videos_url(ucid)
  client = make_client(YT_URL)
  response = client.get(url)

  channel = get_channel(ucid, client, PG_DB, pull_all_videos: false)

  json = JSON.parse(response.body)
  if !json["content_html"]?
    error_message = "This channel does not exist or has no videos."
    next templated "error"
  end

  content_html = json["content_html"].as_s
  if content_html.empty?
    halt env, status_code: 403
  end
  document = XML.parse_html(content_html)

  if Kemal.config.ssl || CONFIG.https_only
    scheme = "https://"
  else
    scheme = "http://"
  end
  host = env.request.headers["Host"]
  path = env.request.path

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom") do
      xml.element("link", rel: "self", href: "#{scheme}#{host}#{path}")
      xml.element("id") { xml.text "yt:channel:#{ucid}" }
      xml.element("yt:channelId") { xml.text ucid }
      xml.element("title") { xml.text channel.author }
      xml.element("link", rel: "alternate", href: "#{scheme}#{host}/channel/#{ucid}")

      xml.element("author") do
        xml.element("name") { xml.text channel.author }
        xml.element("uri") { xml.text "#{scheme}#{host}/channel/#{ucid}" }
      end

      document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")])).each do |item|
        anchor = item.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a)).not_nil!
        title = anchor.content.strip
        video_id = anchor["href"].lchop("/watch?v=")

        view_count = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[2])).not_nil!
        view_count = view_count.content.rchop(" views").delete(",").to_i

        descriptionHtml = item.xpath_node(%q(.//div[contains(@class, "yt-lockup-description")]))
        if !descriptionHtml
          description = ""
          descriptionHtml = ""
        else
          descriptionHtml = descriptionHtml.to_s
          description = descriptionHtml.gsub("<br>", "\n")
          description = description.gsub("<br/>", "\n")
          description = XML.parse_html(description).content.strip("\n ")
        end

        published = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[1]))
        if !published
          next
        end
        published = published.content
        published = decode_date(published)

        xml.element("entry") do
          xml.element("id") { xml.text "yt:video:#{video_id}" }
          xml.element("yt:videoId") { xml.text video_id }
          xml.element("yt:channelId") { xml.text ucid }
          xml.element("title") { xml.text title }
          xml.element("link", rel: "alternate", href: "#{scheme}#{host}/watch?v=#{video_id}")

          xml.element("author") do
            xml.element("name") { xml.text channel.author }
            xml.element("uri") { xml.text "#{scheme}#{host}/channel/#{ucid}" }
          end

          xml.element("published") { xml.text published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text title }
            xml.element("media:thumbnail", url: "https://i.ytimg.com/vi/#{video_id}/hqdefault.jpg",
              width: "480", height: "360")
            xml.element("media:description") { xml.text description }
          end

          xml.element("media:community") do
            xml.element("media:statistics", views: view_count)
          end
        end
      end
    end
  end

  env.response.content_type = "text/xml"
  feed
end

get "/feed/private" do |env|
  token = env.params.query["token"]?

  if !token
    halt env, status_code: 401
  end

  user = PG_DB.query_one?("SELECT * FROM users WHERE token = $1", token, as: User)
  if !user
    halt env, status_code: 401
  end

  max_results = env.params.query["max_results"]?.try &.to_i
  max_results ||= 40

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if max_results < 0
    limit = nil
    offset = (page - 1) * 1
  else
    limit = max_results
    offset = (page - 1) * max_results
  end

  latest_only = env.params.query["latest_only"]?.try &.to_i
  latest_only ||= 0
  latest_only = latest_only == 1

  if latest_only
    args = arg_array(user.subscriptions)
    videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM channel_videos WHERE \
    ucid IN (#{args}) ORDER BY ucid, published DESC", user.subscriptions, as: ChannelVideo)
    videos.sort_by! { |video| video.published }.reverse!
  else
    args = arg_array(user.subscriptions, 3)
    videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid IN (#{args}) \
  ORDER BY published DESC LIMIT $1 OFFSET $2", [limit, offset] + user.subscriptions, as: ChannelVideo)
  end

  sort = env.params.query["sort"]?
  sort ||= "published"

  case sort
  when "alphabetically"
    videos.sort_by! { |video| video.title }
  when "reverse_alphabetically"
    videos.sort_by! { |video| video.title }.reverse!
  when "channel_name"
    videos.sort_by! { |video| video.author }
  when "reverse_channel_name"
    videos.sort_by! { |video| video.author }.reverse!
  end

  if Kemal.config.ssl || CONFIG.https_only
    scheme = "https://"
  else
    scheme = "http://"
  end

  if !limit
    videos = videos[0..max_results]
  end

  host = env.request.headers["Host"]
  path = env.request.path
  query = env.request.query.not_nil!

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", xmlns: "http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/",
      "xml:lang": "en-US") do
      xml.element("link", "type": "text/html", rel: "alternate", href: "#{scheme}#{host}/feed/subscriptions")
      xml.element("link", "type": "application/atom+xml", rel: "self", href: "#{scheme}#{host}#{path}?#{query}")
      xml.element("title") { xml.text "Invidious Private Feed for #{user.email}" }

      videos.each do |video|
        xml.element("entry") do
          xml.element("id") { xml.text "yt:video:#{video.id}" }
          xml.element("yt:videoId") { xml.text video.id }
          xml.element("yt:channelId") { xml.text video.ucid }
          xml.element("title") { xml.text video.title }
          xml.element("link", rel: "alternate", href: "#{scheme}#{host}/watch?v=#{video.id}")

          xml.element("author") do
            xml.element("name") { xml.text video.author }
            xml.element("uri") { xml.text "#{scheme}#{host}/channel/#{video.ucid}" }
          end

          xml.element("published") { xml.text video.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }
          xml.element("updated") { xml.text video.updated.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text video.title }
            xml.element("media:thumbnail", url: "https://i.ytimg.com/vi/#{video.id}/hqdefault.jpg",
              width: "480", height: "360")
          end
        end
      end
    end
  end

  env.response.content_type = "application/atom+xml"
  feed
end

# Function that is useful if you have multiple channels that don't have
# the bell dinged. Request parameters are fairly self-explanatory,
# receive_all_updates = true and receive_post_updates = true will ding all
# channels. Calling /modify_notifications without any arguments will
# request all notifications from all channels.
# /modify_notifications?receive_all_updates=false&receive_no_updates=false
# will "unding" all subscriptions.
get "/modify_notifications" do |env|
  user = env.get? "user"

  referer = env.request.headers["referer"]?
  referer ||= "/"

  if user
    user = user.as(User)

    channel_req = {} of String => String

    channel_req["receive_all_updates"] = env.params.query["receive_all_updates"]? || "true"
    channel_req["receive_no_updates"] = env.params.query["receive_no_updates"]? || ""
    channel_req["receive_post_updates"] = env.params.query["receive_post_updates"]? || "true"

    channel_req.reject! { |k, v| v != "true" && v != "false" }

    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = make_client(YT_URL)
    subs = client.get("/subscription_manager?disable_polymer=1", headers)
    headers["Cookie"] += "; " + subs.cookies.add_request_headers(headers)["Cookie"]
    match = subs.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    if match
      session_token = match["session_token"]
    else
      next env.redirect referer
    end

    channel_req["session_token"] = session_token

    headers["content-type"] = "application/x-www-form-urlencoded"
    subs = XML.parse_html(subs.body)
    subs.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
      channel_id = channel.content.lstrip("/channel/").not_nil!

      channel_req["channel_id"] = channel_id

      client.post("/subscription_ajax?action_update_subscription_preferences=1", headers,
        HTTP::Params.encode(channel_req)).body
    end
  end

  env.redirect referer
end

get "/subscription_manager" do |env|
  user = env.get? "user"

  if !user
    next env.redirect "/"
  end

  user = user.as(User)

  if !user.password
    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = make_client(YT_URL)
    user = get_user(user.id, client, headers, PG_DB)
  end
  subscriptions = user.subscriptions

  client = make_client(YT_URL)
  subscriptions = subscriptions.map do |ucid|
    get_channel(ucid, client, PG_DB, false)
  end
  subscriptions.sort_by! { |channel| channel.author.downcase }

  templated "subscription_manager"
end

get "/subscription_ajax" do |env|
  user = env.get? "user"
  referer = env.request.headers["referer"]?
  referer ||= "/"

  if user
    user = user.as(User)

    if env.params.query["action_create_subscription_to_channel"]?
      action = "action_create_subscription_to_channel"
    elsif env.params.query["action_remove_subscriptions"]?
      action = "action_remove_subscriptions"
    else
      next env.redirect referer
    end

    channel_id = env.params.query["c"]?
    channel_id ||= ""

    if !user.password
      headers = HTTP::Headers.new
      headers["Cookie"] = env.request.headers["Cookie"]

      client = make_client(YT_URL)
      subs = client.get("/subscription_manager?disable_polymer=1", headers)
      headers["Cookie"] += "; " + subs.cookies.add_request_headers(headers)["Cookie"]
      match = subs.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
      if match
        session_token = match["session_token"]
      else
        next env.redirect "/"
      end

      headers["content-type"] = "application/x-www-form-urlencoded"

      post_req = {
        "session_token" => session_token,
      }
      post_req = HTTP::Params.encode(post_req)
      post_url = "/subscription_ajax?#{action}=1&c=#{channel_id}"

      # Update user
      if client.post(post_url, headers, post_req).status_code == 200
        sid = user.id

        case action
        when .starts_with? "action_create"
          PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE id = $2", channel_id, sid)
        when .starts_with? "action_remove"
          PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE id = $2", channel_id, sid)
        end
      end
    else
      sid = user.id

      case action
      when .starts_with? "action_create"
        if !user.subscriptions.includes? channel_id
          PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE id = $2", channel_id, sid)

          client = make_client(YT_URL)
          get_channel(channel_id, client, PG_DB, false, false)
        end
      when .starts_with? "action_remove"
        PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE id = $2", channel_id, sid)
      end
    end
  end

  env.redirect referer
end

get "/clear_watch_history" do |env|
  user = env.get? "user"
  referer = env.request.headers["referer"]?
  referer ||= "/"

  if user
    user = user.as(User)

    PG_DB.exec("UPDATE users SET watched = '{}' WHERE id = $1", user.id)
  end

  env.redirect referer
end

get "/user/:user" do |env|
  user = env.params.url["user"]
  env.redirect "/channel/#{user}"
end

get "/channel/:ucid" do |env|
  user = env.get? "user"
  if user
    user = user.as(User)
    subscriptions = user.subscriptions
  end
  subscriptions ||= [] of String

  ucid = env.params.url["ucid"]

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  client = make_client(YT_URL)

  if !ucid.starts_with? "UC"
    rss = client.get("/feeds/videos.xml?user=#{ucid}").body
    rss = XML.parse_html(rss)

    ucid = rss.xpath_node("//feed/channelid").not_nil!.content
    env.redirect "/channel/#{ucid}"
  end

  url = produce_playlist_url(ucid, (page - 1) * 100)
  response = client.get(url)

  json = JSON.parse(response.body)
  if !json["content_html"]?
    error_message = "This channel does not exist or has no videos."
    next templated "error"
  end

  if json["content_html"].as_s.strip(" \n").empty?
    rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
    rss = XML.parse_html(rss)
    author = rss.xpath_node("//feed/author/name").not_nil!.content

    videos = [] of ChannelVideo

    next templated "channel"
  end

  document = XML.parse_html(json["content_html"].as_s)
  author = document.xpath_node(%q(//div[@class="pl-video-owner"]/a)).not_nil!.content

  videos = [] of ChannelVideo
  document.xpath_nodes(%q(//a[contains(@class,"pl-video-title-link")])).each do |item|
    href = URI.parse(item["href"])
    id = HTTP::Params.parse(href.query.not_nil!)["v"]
    title = item.content

    videos << ChannelVideo.new(id, title, Time.now, Time.now, ucid, author)
  end

  templated "channel"
end

get "/redirect" do |env|
  if env.params.query["q"]?
    env.redirect env.params.query["q"]
  else
    env.redirect "/"
  end
end

get "/api/manifest/dash/id/:id" do |env|
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  env.response.content_type = "application/dash+xml"

  local = env.params.query["local"]?.try &.== "true"
  id = env.params.url["id"]

  client = make_client(YT_URL)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    halt env, status_code: 403
  end

  if video.info["dashmpd"]?
    manifest = client.get(video.info["dashmpd"]).body

    manifest = manifest.gsub(/<BaseURL>[^<]+<\/BaseURL>/) do |baseurl|
      url = baseurl.lchop("<BaseURL>")
      url = url.rchop("</BaseURL>")

      if local
        if Kemal.config.ssl || CONFIG.https_only
          scheme = "https://"
        end
        scheme ||= "http://"

        url = scheme + env.request.headers["Host"] + URI.parse(url).full_path
      end

      "<BaseURL>#{url}</BaseURL>"
    end

    next manifest
  end

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  else
    halt env, status_code: 403
  end

  if local
    adaptive_fmts.each do |fmt|
      if Kemal.config.ssl || CONFIG.https_only
        scheme = "https://"
      end
      scheme ||= "http://"

      fmt["url"] = scheme + env.request.headers["Host"] + URI.parse(fmt["url"]).full_path
    end
  end

  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"], decrypt_function)
    end
  end

  video_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("video/mp4") ? s : nil }

  audio_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("audio/mp4") ? s : nil }
  audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
  audio_streams.each do |fmt|
    fmt["bitrate"] = (fmt["bitrate"].to_f64/1000).to_i.to_s
  end

  manifest = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("MPD", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xmlns": "urn:mpeg:DASH:schema:MPD:2011",
      "xmlns:yt": "http://youtube.com/yt/2012/10/10", "xsi:schemaLocation": "urn:mpeg:DASH:schema:MPD:2011 DASH-MPD.xsd",
      minBufferTime: "PT1.5S", profiles: "urn:mpeg:dash:profile:isoff-main:2011", type: "static",
      mediaPresentationDuration: "PT#{video.info["length_seconds"]}S") do
      xml.element("Period") do
        xml.element("AdaptationSet", id: 0, mimeType: "audio/mp4", subsegmentAlignment: true) do
          xml.element("Role", schemeIdUri: "urn:mpeg:DASH:role:2011", value: "main")
          audio_streams.each do |fmt|
            mimetype, codecs = fmt["type"].split(";")
            codecs = codecs[9..-2]
            fmt_type = mimetype.split("/")[0]
            bandwidth = fmt["bitrate"]
            itag = fmt["itag"]
            url = fmt["url"]
            url = url.gsub("?", "/")
            url = url.gsub("&", "/")
            url = url.gsub("=", "/")

            xml.element("Representation", id: fmt["itag"], codecs: codecs, bandwidth: bandwidth) do
              xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011",
                value: "2")
              xml.element("BaseURL") { xml.text url }
              xml.element("SegmentBase", indexRange: fmt["init"]) do
                xml.element("Initialization", range: fmt["index"])
              end
            end
          end
        end

        xml.element("AdaptationSet", id: 1, mimeType: "video/mp4", subsegmentAlignment: true) do
          xml.element("Role", schemeIdUri: "urn:mpeg:DASH:role:2011", value: "main")
          video_streams.each do |fmt|
            mimetype, codecs = fmt["type"].split(";")
            codecs = codecs[9..-2]
            bandwidth = fmt["bitrate"]
            itag = fmt["itag"]
            url = fmt["url"]
            url = url.gsub("?", "/")
            url = url.gsub("&", "/")
            url = url.gsub("=", "/")
            height, width = fmt["size"].split("x")

            xml.element("Representation", id: itag, codecs: codecs, width: width, startWithSAP: "1", maxPlayoutRate: "1",
              height: height, bandwidth: bandwidth, frameRate: fmt["fps"]) do
              xml.element("BaseURL") { xml.text url }
              xml.element("SegmentBase", indexRange: fmt["init"]) do
                xml.element("Initialization", range: fmt["index"])
              end
            end
          end
        end
      end
    end
  end

  manifest = manifest.gsub(%(<?xml version="1.0" encoding="UTF-8U"?>), %(<?xml version="1.0" encoding="UTF-8"?>))
  manifest = manifest.gsub(%(<?xml version="1.0" encoding="UTF-8V"?>), %(<?xml version="1.0" encoding="UTF-8"?>))
  manifest
end

options "/videoplayback*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, range"
end

get "/api/manifest/hls_variant/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    halt env, status_code: 403
  end

  manifest = manifest.body

  if Kemal.config.ssl || CONFIG.https_only
    scheme = "https://"
  else
    scheme = "http://"
  end
  host = env.request.headers["Host"]

  url = "#{scheme}#{host}"

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  manifest.gsub("https://www.youtube.com", url)
end

get "/api/manifest/hls_playlist/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    halt env, status_code: 403
  end

  if Kemal.config.ssl || CONFIG.https_only
    scheme = "https://"
  else
    scheme = "http://"
  end
  host = env.request.headers["Host"]

  url = "#{scheme}#{host}"

  manifest = manifest.body.gsub("https://www.youtube.com", url)
  manifest = manifest.gsub(/https:\/\/r\d---.{11}\.c\.youtube\.com/, url)
  fvip = manifest.match(/hls_chunk_host\/r(?<fvip>\d)---/).not_nil!["fvip"]
  manifest = manifest.gsub("seg.ts", "seg.ts/fvip/#{fvip}")

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  manifest
end

get "/videoplayback*" do |env|
  path = env.request.path
  if path != "/videoplayback"
    path = path.lchop("/videoplayback/")
    path = path.rchop("/")

    path = path.gsub(/mime\/\w+\/\w+/) do |mimetype|
      mimetype = mimetype.split("/")
      mimetype[0] + "/" + mimetype[1] + "%2F" + mimetype[2]
    end

    path = path.split("/")

    raw_params = {} of String => Array(String)
    path.each_slice(2) do |pair|
      key, value = pair
      value = URI.unescape(value)

      if raw_params[key]?
        raw_params[key] << value
      else
        raw_params[key] = [value]
      end
    end

    query_params = HTTP::Params.new(raw_params)
  else
    query_params = env.params.query
  end

  fvip = query_params["fvip"]
  mn = query_params["mn"].split(",")[0]
  host = "https://r#{fvip}---#{mn}.googlevideo.com"
  url = "/videoplayback?#{query_params.to_s}"

  client = make_client(URI.parse(host))
  response = client.head(url)

  headers = env.request.headers
  headers.delete("Host")
  headers.delete("Cookie")
  headers.delete("User-Agent")
  headers.delete("Referer")

  client.get(url, headers) do |response|
    if response.headers["Location"]?
      url = URI.parse(response.headers["Location"])
      env.response.headers["Access-Control-Allow-Origin"] = "*"
      env.redirect url.full_path
    else
      env.response.status_code = response.status_code

      response.headers.each do |key, value|
        env.response.headers[key] = value
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      begin
        chunk_size = 4096
        size = 1
        while size > 0
          size = IO.copy(response.body_io, env.response.output, chunk_size)
          env.response.flush
          Fiber.yield
        end
      rescue ex
        break
      end
    end
  end
end

get "/:id" do |env|
  id = env.params.url["id"]

  if md = id.match(/[a-zA-Z0-9_-]{11}/)
    params = [] of String
    env.params.query.each do |k, v|
      params << "#{k}=#{v}"
    end
    params = params.join("&")

    url = "/watch?v=#{id}"
    if params
      url += "&#{params}"
    end

    env.redirect url
  else
    env.response.status_code = 404
  end
end

error 404 do |env|
  error_message = "404 Page not found"
  templated "error"
end

error 500 do |env|
  error_message = "500 Server error"
  templated "error"
end

# Add redirect if SSL is enabled
if Kemal.config.ssl
  spawn do
    server = HTTP::Server.new do |context|
      redirect_url = "https://#{context.request.host}#{context.request.path}"
      if context.request.query
        redirect_url += "?#{context.request.query}"
      end
      context.response.headers.add("Location", redirect_url)
      context.response.status_code = 301
    end

    server.bind_tcp "0.0.0.0", 80
    server.listen
  end

  before_all do |env|
    env.response.headers.add("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload")
  end
end

static_headers do |response, filepath, filestat|
  response.headers.add("Cache-Control", "max-age=86400")
end

public_folder "assets"

add_handler FilteredCompressHandler.new
add_context_storage_type(User)

Kemal.run
