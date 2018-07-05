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

require "detect_language"
require "kemal"
require "option_parser"
require "pg"
require "xml"
require "yaml"
require "./cookie_fix"
require "./helpers"

CONFIG = Config.from_yaml(File.read("config/config.yml"))

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
        client = make_client(YT_URL)
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
            channel = get_channel(id, client, PG_DB)
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

before_all do |env|
  if env.request.cookies.has_key?("SID")
    env.set "authorized", true

    sid = env.request.cookies["SID"].value
    env.set "sid", sid

    subscriptions = PG_DB.query_one?("SELECT subscriptions FROM users WHERE id = $1", sid, as: Array(String))
    subscriptions ||= [] of String
    env.set "subscriptions", subscriptions

    notifications = PG_DB.query_one?("SELECT cardinality(notifications) FROM users WHERE id = $1", sid, as: Int32)
    notifications ||= 0

    env.set "notifications", notifications
  end

  if env.request.cookies.has_key?("darktheme") && env.request.cookies["darktheme"].value == "true"
    env.set "darktheme", true
  end
end

get "/" do |env|
  templated "index"
end

get "/watch" do |env|
  authorized = env.get? "authorized"
  if authorized
    subscriptions = env.get("subscriptions").as(Array(String))
  end
  subscriptions ||= [] of String

  if env.params.query["v"]?
    id = env.params.query["v"]
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
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"])
    end

    fmt_stream.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"])
    end
  end

  audio_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("audio") ? s : nil }
  audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
  audio_streams.each do |stream|
    stream["bitrate"] = (stream["bitrate"].to_f64/1000).to_i.to_s
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

  reddit_client = make_client(REDDIT_URL)
  headers = HTTP::Headers{"User-Agent" => "web:invidio.us:v0.1.0 (by /u/omarroth)"}
  begin
    reddit_comments, reddit_thread = get_reddit_comments(id, reddit_client, headers)
    reddit_html = template_comments(reddit_comments)

    reddit_html = fill_links(reddit_html, "https", "www.reddit.com")
    reddit_html = add_alt_links(reddit_html)
  rescue ex
    reddit_thread = nil
    reddit_html = ""
  end

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = add_alt_links(video.description)

  thumbnail = "https://i.ytimg.com/vi/#{id}/mqdefault.jpg"

  templated "watch"
end

get "/search" do |env|
  if env.params.query["q"]?
    query = env.params.query["q"]
  else
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i
  page ||= 1

  client = make_client(YT_URL)

  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=EgIQAVAU").body
  html = XML.parse_html(html)

  videos = [] of Video

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

      video = Video.new(id, HTTP::Params.parse(""), Time.now, title, 0_i64, 0, 0, 0.0, Time.now, "", nil, author, ucid)
      videos << video
    end
  end

  templated "search"
end

get "/login" do |env|
  referer = env.request.headers["referer"]?
  referer ||= "/feed/subscriptions"

  tfa = env.params.query["tfa"]?
  tfa ||= false

  if referer.ends_with? "/login"
    referer = "/feed/subscriptions"
  end

  if referer.size > 32
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

    if challenge_results[0][5]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
      error_message = "Incorrect password"
      next templated "error"
    end

    if challenge_results[0][-1][0].as_a?
      tfa = challenge_results[0][-1][0][0]

      if tfa[2] == "TWO_STEP_VERIFICATION"
        if tfa[5] == "QUOTA_EXCEEDED"
          error_message = "Quota exceeded, try again in a few hours"
          next templated "error"
        end

        if !tfa_code
          next env.redirect "/login?tfa=true"
        end

        tl = challenge_results[1][2]

        tfa_req = %(["#{user_hash}",null,2,null,[9,null,null,null,null,null,null,null,[null,"#{tfa_code}",false,2]]])

        challenge_results = client.post("/_/signin/challenge?hl=en&TL=#{tl}", headers, login_req(inputs, tfa_req))
        headers = challenge_results.cookies.add_request_headers(headers)

        challenge_results = challenge_results.body
        challenge_results = challenge_results[5..-1]
        challenge_results = JSON.parse(challenge_results)

        if challenge_results[0][5]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
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
      cookie.secure = false
      cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
      cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
    end

    login.cookies.add_response_headers(env.response.headers)

    env.redirect referer
  rescue ex
    error_message = "Login failed. This may be because two-factor authentication is not enabled on your account."
    next templated "error"
  end
end

get "/signout" do |env|
  referer = env.request.headers["referer"]?
  referer ||= "/"

  env.request.cookies.each do |cookie|
    if cookie.name != "darktheme"
      cookie.expires = Time.new(1990, 1, 1)
    end
  end

  env.request.cookies.add_response_headers(env.response.headers)
  env.redirect referer
end

get "/redirect" do |env|
  if env.params.query["q"]?
    env.redirect env.params.query["q"]
  else
    env.redirect "/"
  end
end

# Return dash manifest for the given video ID, note this will not work on
# videos that already have a dashmpd in video info.
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
      if Kemal.config.ssl
        scheme = "https://"
      end
      scheme ||= "http://"

      fmt["url"] = scheme + env.request.headers["Host"] + URI.parse(fmt["url"]).full_path
    end
  end

  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"])
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
              xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011", value: "2")
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

# Get subscriptions for authorized user
get "/feed/subscriptions" do |env|
  authorized = env.get? "authorized"

  if authorized
    max_results = env.params.query["maxResults"]?.try &.to_i || 40

    page = env.params.query["page"]?.try &.to_i
    page ||= 1

    if max_results < 0
      limit = nil
      offset = (page - 1) * 1
    else
      limit = max_results
      offset = (page - 1) * max_results
    end

    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    sid = env.get("sid").as(String)

    client = make_client(YT_URL)
    user = get_user(sid, client, headers, PG_DB)

    args = arg_array(user.subscriptions, 3)
    videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid IN (#{args}) \
    ORDER BY published DESC LIMIT $1 OFFSET $2", [limit, offset] + user.subscriptions, as: ChannelVideo)

    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email, as: Array(String))

    notifications = videos.select { |v| notifications.includes? v.id }
    videos = videos - notifications

    if !limit
      videos = videos[0..max_results]
    end

    PG_DB.exec("UPDATE users SET notifications = $1 WHERE id = $2", [] of String, sid)
    env.set "notifications", 0

    templated "subscriptions"
  else
    env.redirect "/"
  end
end

# Function that is useful if you have multiple channels that don't have
# the bell dinged. Request parameters are fairly self-explanatory,
# receive_all_updates = true and receive_post_updates = true will ding all
# channels. Calling /modify_notifications without any arguments will
# request all notifications from all channels.
# /modify_notifications?receive_all_updates=false&receive_no_updates=false
# will "unding" all subscriptions.
get "/modify_notifications" do |env|
  authorized = env.get? "authorized"

  referer = env.request.headers["referer"]?
  referer ||= "/"

  if authorized
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

      client.post("/subscription_ajax?action_update_subscription_preferences=1", headers, HTTP::Params.encode(channel_req)).body
    end
  end

  env.redirect referer
end

get "/subscription_ajax" do |env|
  authorized = env.get? "authorized"
  referer = env.request.headers["referer"]?
  referer ||= "/"

  if authorized
    if env.params.query["action_create_subscription_to_channel"]?
      action = "action_create_subscription_to_channel"
    elsif env.params.query["action_remove_subscriptions"]?
      action = "action_remove_subscriptions"
    else
      next env.redirect referer
    end

    channel_id = env.params.query["c"]?
    channel_id ||= ""

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
      sid = env.get("sid").as(String)

      case action
      when .starts_with? "action_create"
        PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE id = $2", channel_id, sid)
      when .starts_with? "action_remove"
        PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE id = $2", channel_id, sid)
      end
    end
  end

  env.redirect referer
end

get "/modify_theme" do |env|
  referer = env.request.headers["referer"]?
  referer ||= "/"

  if env.params.query["dark"]?
    env.response.cookies["darktheme"] = "true"
  elsif env.params.query["light"]?
    env.request.cookies["darktheme"].expires = Time.new(1990, 1, 1)
    env.request.cookies.add_response_headers(env.response.headers)
  end

  env.redirect referer
end

get "/videoplayback*" do |env|
  path = env.request.path
  if path != "/videoplayback"
    path = path.lchop("/videoplayback/")
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
      env.redirect url.full_path
    else
      env.response.status_code = response.status_code

      response.headers.each do |key, value|
        env.response.headers[key] = value
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      chunk = Bytes[8]

      loop do
        count = response.body_io.read(chunk)

        begin
          env.response.write(chunk)
          env.response.flush
        rescue ex
          break
        end
      end
    end
  end
end

get "/user/:user" do |env|
  user = env.params.url["user"]
  env.redirect "/channel/#{user}"
end

get "/channel/:ucid" do |env|
  authorized = env.get? "authorized"
  if authorized
    sid = env.get("sid").as(String)

    subscriptions = PG_DB.query_one?("SELECT subscriptions FROM users WHERE id = $1", sid, as: Array(String))
  end
  subscriptions ||= [] of String

  ucid = env.params.url["ucid"]

  page = env.params.query["page"]?.try &.to_i
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

options "/videoplayback*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, range"
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
add_context_storage_type(Array(String))

Kemal.run
