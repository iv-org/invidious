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
require "./helpers"
require "./cookie_fix"

CONFIG = Config.from_yaml(File.read("config/config.yml"))

pool_size = CONFIG.pool_size
threads = CONFIG.threads
channel_threads = 10

Kemal.config.extra_options do |parser|
  parser.banner = "Usage: invidious [arguments]"
  parser.on("-z SIZE", "--youtube-pool=SIZE", "Number of clients in youtube pool (default: #{pool_size})") do |number|
    begin
      pool_size = number.to_i
    rescue ex
      puts "SIZE must be integer"
      exit
    end
  end
  parser.on("-t THREADS", "--youtube-threads=THREADS", "Number of threads for crawling (default: #{threads})") do |number|
    begin
      threads = number.to_i
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

youtube_pool = Deque.new(pool_size) do
  make_client(YT_URL)
end

# Refresh youtube_pool by crawling YT
threads.times do
  spawn do
    ids = Deque(String).new
    random = Random.new

    client = get_client(youtube_pool)
    search(random.base64(3), client) do |id|
      ids << id
    end
    youtube_pool << client

    loop do
      client = get_client(youtube_pool)

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
        youtube_pool << make_client(YT_URL)
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

      youtube_pool << client
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
          client = get_client(youtube_pool)
          id = rs.read(String)
          channel = get_channel(id, client, PG_DB)
          youtube_pool << client
        end
      end
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
  else
    filter = false
  end

  loop do
    begin
      top = rank_videos(PG_DB, 40, youtube_pool, filter)
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
      client = get_client(youtube_pool)
      begin
        videos << get_video(id, client, PG_DB)
      rescue ex
        next
      end
      youtube_pool << client
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

    notifications = PG_DB.query_one?("SELECT cardinality(notifications) FROM users WHERE id = $1", sid, as: Int32)
    notifications ||= 0
    env.set "notifications", notifications
  end
end

get "/" do |env|
  templated "index"
end

get "/watch" do |env|
  if env.params.query["v"]?
    id = env.params.query["v"]
  else
    next env.redirect "/"
  end

  listen = false
  if env.params.query["listen"]? && env.params.query["listen"] == "true"
    listen = true
    env.params.query.delete_all("listen")
  end

  client = get_client(youtube_pool)

  authorized = env.get? "authorized"
  if authorized
    sid = env.get("sid").as(String)

    subscriptions = PG_DB.query_one?("SELECT subscriptions FROM users WHERE id = $1", sid, as: Array(String))
  end

  subscriptions = [] of String

  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    error_message = ex.message
    next templated "error"
  ensure
    youtube_pool << client
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    if !string.empty?
      fmt_stream << HTTP::Params.parse(string)
    end
  end

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end

  signature = false
  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    signature = true
  end

  if signature
    adaptive_fmts.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"])
    end

    fmt_stream.each do |fmt|
      fmt["url"] += "&signature=" + decrypt_signature(fmt["s"])
    end
  end

  fmt_stream = fmt_stream.uniq { |s| s["quality"] }

  video_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("video") ? s : nil }
  video_streams = video_streams.uniq { |s| s["size"] }

  audio_streams = adaptive_fmts.compact_map { |s| s["type"].starts_with?("audio") ? s : nil }
  audio_streams.sort_by! { |s| s["bitrate"].to_i }.reverse!
  audio_streams.each do |fmt|
    fmt["bitrate"] = (fmt["bitrate"].to_f64/1000).to_i.to_s
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
  else
    calculated_rating = 0.0
  end

  reddit_client = make_client(REDDIT_URL)
  headers = HTTP::Headers{"User-Agent" => "web:invidio.us:v0.1.0 (by /u/omarroth)"}
  begin
    reddit_comments, reddit_thread = get_reddit_comments(id, reddit_client, headers)
    reddit_html = template_comments(reddit_comments)

    reddit_html = add_alt_links(reddit_html)
  rescue ex
    reddit_thread = nil
    reddit_html = ""
  end

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = add_alt_links(video.description)

  thumbnail = "https://i1.ytimg.com/vi/#{id}/mqdefault.jpg"

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

  client = get_client(youtube_pool)

  html = client.get("/results?q=#{URI.escape(query)}&page=#{page}&sp=EgIQAVAU").body
  html = XML.parse_html(html)

  youtube_pool << client

  videos = Array(Hash(String, String)).new

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if root
      video = {} of String => String

      id = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
      if id
        id = id.content.lchop("/watch?v=")
      else
        id = ""
      end
      video["id"] = id

      title = root.xpath_node(%q(div[@class="yt-lockup-content"]/h3/a))
      if title
        video["title"] = title.content
      else
        video["title"] = ""
      end

      author = root.xpath_node(%q(div[@class="yt-lockup-content"]/div/a))
      if author
        video["author"] = author.content
        video["ucid_url"] = author["href"]
      else
        video["author"] = ""
        video["ucid_url"] = ""
      end

      videos << video
    end
  end

  templated "search"
end

get "/login" do |env|
  templated "login"
end

# See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L79
post "/login" do |env|
  email = env.params.body["email"]?
  password = env.params.body["password"]?

  begin
    client = make_client(LOGIN_URL)
    headers = HTTP::Headers.new
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

    lookup_req = %(["#{email}","#{inputs["session-state"]}",[],null,"US",null,null,2,false,true,[null,null,[2,1,null,1,"https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn",null,[],4,[]],1,[null,null,[]],null,null,null,true],"#{email}"])

    headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8"
    headers["Google-Accounts-XSRF"] = "1"

    lookup_results = client.post("/_/signin/sl/lookup", headers, login_req(inputs, lookup_req))
    headers = lookup_results.cookies.add_request_headers(headers)

    lookup_results = lookup_results.body
    lookup_results = lookup_results[5..-1]
    lookup_results = JSON.parse(lookup_results)

    user_hash = lookup_results[0][2]

    challenge_req = %([#{user_hash},null,1,null,[1,null,null,null,[#{password},null,true]],[null,null,[2,1,null,1,"https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn", null,[],4],1,[null,null,[]],null,null,null,true]])

    challenge_results = client.post("/_/signin/sl/challenge", headers, login_req(inputs, challenge_req))
    headers = challenge_results.cookies.add_request_headers(headers)

    challenge_results = challenge_results.body
    challenge_results = challenge_results[5..-1]
    challenge_results = JSON.parse(challenge_results)

    login_res = challenge_results[0][13][2].to_s

    login = client.get(login_res, headers)
    headers = login.cookies.add_request_headers(headers)

    login = client.get(login.headers["Location"], headers)
    headers = login.cookies.add_request_headers(headers)

    # We are now logged in

    host = URI.parse(env.request.headers["Host"]).host

    login.cookies.each do |cookie|
      cookie.secure = false
      cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
      cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
    end

    login.cookies.add_response_headers(env.response.headers)

    env.redirect "/feed/subscriptions"
  rescue ex
    error_message = "Login failed"
    next templated "error"
  end
end

get "/signout" do |env|
  env.request.cookies.each do |cookie|
    cookie.expires = Time.new(1990, 1, 1)
  end

  env.request.cookies.add_response_headers(env.response.headers)
  env.redirect "/"
end

get "/redirect" do |env|
  if env.params.query["q"]?
    env.redirect env.params.query["q"]
  else
    env.redirect "/"
  end
end

# Return dash manifest for the given video ID
get "/api/manifest/dash/id/:id" do |env|
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  env.response.content_type = "application/dash+xml"

  id = env.params.url["id"]

  yt_client = get_client(youtube_pool)
  begin
    video = get_video(id, yt_client, PG_DB)
  rescue ex
    halt env, status_code: 403
  ensure
    youtube_pool << yt_client
  end

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  else
    halt env, status_code: 403
  end

  signature = false
  if adaptive_fmts[0]? && adaptive_fmts[0]["s"]?
    signature = true
  end

  if signature
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
    xml.element("MPD", "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance", "xsi:schemaLocation": "urn:mpeg:DASH:schema:MPD:2011 DASH-MPD.xsd",
      xmlns: "urn:mpeg:dash:schema:mpd:2011", profiles: "urn:mpeg:dash:profile:isoff-main:2011",
      mediaPresentationDuration: "PT#{video.info["length_seconds"]}S", minBufferTime: "PT2S", type: "static") do
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

            xml.element("Representation", id: fmt["itag"], codecs: codecs, bandwidth: bandwidth) do
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
            fmt_type = mimetype.split("/")[0]
            bandwidth = fmt["bitrate"]
            itag = fmt["itag"]
            url = fmt["url"]
            height, width = fmt["size"].split("x")

            xml.element("Representation", id: itag, codecs: codecs, width: width, height: height, bandwidth: bandwidth, frameRate: fmt["fps"]) do
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
    max_results = env.params.query["maxResults"]?.try &.to_i
    max_results ||= 40

    page = env.params.query["page"]?.try &.to_i
    page ||= 1

    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    sid = env.get("sid").as(String)

    client = get_client(youtube_pool)
    user = get_user(sid, client, headers, PG_DB)
    youtube_pool << client

    args = arg_array(user.subscriptions, 3)
    offset = (page - 1) * max_results
    videos = PG_DB.query_all("SELECT * FROM channel_videos WHERE ucid IN (#{args}) \
    ORDER BY published DESC LIMIT $1 OFFSET $2", [max_results, offset] + user.subscriptions, as: ChannelVideo)

    env.set "notifications", 0

    templated "subscriptions"
  else
    env.redirect "/"
  end
end

# Two functions that are useful if you have multiple subscriptions that don't have
# the "bell dinged". enable_notifications dings the bell for all subscriptions,
# disable_notifications does the opposite. These don't fit conveniently anywhere,
# so instead are here more as an undocumented utility.
get "/enable_notifications" do |env|
  authorized = env.get? "authorized"

  if authorized
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = get_client(youtube_pool)
    subs = client.get("/subscription_manager?disable_polymer=1", headers)
    headers["Cookie"] += "; " + subs.cookies.add_request_headers(headers)["Cookie"]
    match = subs.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    if match
      session_token = match["session_token"]
    else
      next env.redirect "/"
    end

    headers["content-type"] = "application/x-www-form-urlencoded"
    subs = XML.parse_html(subs.body)
    subs.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
      channel_id = channel.content.lstrip("/channel/").not_nil!

      channel_req = {
        "channel_id"           => channel_id,
        "receive_all_updates"  => "true",
        "receive_post_updates" => "true",
        "session_token"        => session_token,
      }

      channel_req = HTTP::Params.encode(channel_req)

      client.post("/subscription_ajax?action_update_subscription_preferences=1", headers, channel_req)
    end

    youtube_pool << client
  end

  env.redirect "/"
end

get "/disable_notifications" do |env|
  authorized = env.get? "authorized"

  if authorized
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = get_client(youtube_pool)
    subs = client.get("/subscription_manager?disable_polymer=1", headers)
    headers["Cookie"] += "; " + subs.cookies.add_request_headers(headers)["Cookie"]
    match = subs.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    if match
      session_token = match["session_token"]
    else
      next env.redirect "/"
    end

    headers["content-type"] = "application/x-www-form-urlencoded"
    subs = XML.parse_html(subs.body)
    subs.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
      channel_id = channel.content.lstrip("/channel/").not_nil!

      channel_req = {
        "channel_id"           => channel_id,
        "receive_all_updates"  => "false",
        "receive_no_updates"   => "false",
        "receive_post_updates" => "true",
        "session_token"        => session_token,
      }

      channel_req = HTTP::Params.encode(channel_req)

      client.post("/subscription_ajax?action_update_subscription_preferences=1", headers, channel_req)
    end

    youtube_pool << client
  end

  env.redirect "/"
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

    client = get_client(youtube_pool)
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

    youtube_pool << client
  end

  env.redirect referer
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
    server = HTTP::Server.new("0.0.0.0", 80) do |context|
      redirect_url = "https://#{context.request.host}#{context.request.path}"
      if context.request.query
        redirect_url += "?#{context.request.query}"
      end
      context.response.headers.add("Location", redirect_url)
      context.response.status_code = 301
    end

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

Kemal.run
