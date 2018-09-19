# "Invidious" (which is an alternative front-end to YouTube)
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
require "zip"
require "./invidious/helpers/*"
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
REDDIT_URL = URI.parse("https://www.reddit.com")
LOGIN_URL  = URI.parse("https://accounts.google.com")

crawl_threads.times do
  spawn do
    crawl_videos(PG_DB)
  end
end

refresh_channels(PG_DB, channel_threads, CONFIG.full_refresh)

video_threads.times do |i|
  spawn do
    refresh_videos(PG_DB)
  end
end

top_videos = [] of Video
spawn do
  pull_top_videos(CONFIG, PG_DB) do |videos|
    top_videos = videos
  end
end

decrypt_function = [] of {name: String, value: Int32}
spawn do
  update_decrypt_function do |function|
    decrypt_function = function
  end
end

before_all do |env|
  env.response.headers["X-XSS-Protection"] = "1; mode=block;"
  env.response.headers["X-Content-Type-Options"] = "nosniff"

  if env.request.cookies.has_key? "SID"
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    sid = env.request.cookies["SID"].value

    # Invidious users only have SID
    if !env.request.cookies.has_key? "SSID"
      user = PG_DB.query_one?("SELECT * FROM users WHERE $1 = ANY(id)", sid, as: User)

      if user
        env.set "user", user
        env.set "sid", sid
      end
    else
      begin
        client = make_client(YT_URL)
        user = get_user(sid, client, headers, PG_DB, false)

        env.set "user", user
        env.set "sid", sid
      rescue ex
      end
    end
  end

  current_page = env.request.path
  if env.request.query
    query = HTTP::Params.parse(env.request.query.not_nil!)

    if query["referer"]?
      query["referer"] = get_referer(env, "/")
    end

    current_page += "?#{query}"
  end

  env.set "current_page", URI.escape(current_page)
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

# Videos

get "/:id" do |env|
  id = env.params.url["id"]

  if md = id.match(/[a-zA-Z0-9_-]{11}/)
    params = [] of String
    env.params.query.each do |k, v|
      params << "#{k}=#{v}"
    end
    params = params.join("&")

    url = "/watch?v=#{id}"
    if !params.empty?
      url += "&#{params}"
    end

    env.redirect url
  else
    env.response.status_code = 404
  end
end

get "/watch" do |env|
  if env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
    url = "/watch?" + env.params.query.to_s.gsub("%20", "").delete("+")
    next env.redirect url
  end

  if env.params.query["v"]?
    id = env.params.query["v"]

    if id.size > 11
      url = "/watch?v=#{id[0, 11]}"
      env.params.query.delete_all("v")
      if env.params.query.size > 0
        url += "&#{env.params.query}"
      end

      next env.redirect url
    end
  else
    next env.redirect "/"
  end

  user = env.get? "user"
  if user
    user = user.as(User)
    if !user.watched.includes? id
      PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE id = $2", [id], user.id)
    end

    preferences = user.preferences
    subscriptions = user.subscriptions
  end
  subscriptions ||= [] of String

  params = process_video_params(env.params.query, preferences)

  if params[:listen]
    env.params.query.delete_all("listen")
  end

  begin
    video = get_video(id, PG_DB)
  rescue ex
    error_message = ex.message
    STDOUT << id << " : " << ex.message << "\n"
    next templated "error"
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)
  video_streams = video.video_streams(adaptive_fmts)
  audio_streams = video.audio_streams(adaptive_fmts)

  captions = video.captions

  preferred_captions = captions.select { |caption|
    params[:preferred_captions].includes?(caption.name.simpleText) ||
      params[:preferred_captions].includes?(caption.languageCode.split("-")[0])
  }
  preferred_captions.sort_by! { |caption|
    (params[:preferred_captions].index(caption.name.simpleText) ||
      params[:preferred_captions].index(caption.languageCode.split("-")[0])).not_nil!
  }
  captions = captions - preferred_captions

  aspect_ratio = "16:9"

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = replace_links(video.description)
  description = video.short_description

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.info["hlsvp"]?
    hlsvp = video.info["hlsvp"]
    hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)
  end

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params[:raw]
    url = fmt_stream[0]["url"]

    fmt_stream.each do |fmt|
      if fmt["label"].split(" - ")[0] == params[:quality]
        url = fmt["url"]
      end
    end

    next env.redirect url
  end

  rvs = [] of Hash(String, String)
  video.info["rvs"]?.try &.split(",").each do |rv|
    rvs << HTTP::Params.parse(rv).to_h
  end

  # rating = (video.likes.to_f/(video.likes.to_f + video.dislikes.to_f) * 4 + 1)
  rating = video.info["avg_rating"].to_f64

  engagement = ((video.dislikes.to_f + video.likes.to_f)/video.views * 100)

  playability_status = video.player_response["playabilityStatus"]?
  if playability_status && playability_status["status"] == "LIVE_STREAM_OFFLINE"
    reason = playability_status["reason"]?.try &.as_s
  end
  reason ||= ""

  templated "watch"
end

get "/embed/:id" do |env|
  id = env.params.url["id"]

  if id.includes?("%20") || id.includes?("+") || env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
    id = env.params.url["id"].gsub("%20", "").delete("+")

    url = "/embed/#{id}"

    if env.params.query.size > 0
      url += "?#{env.params.query.to_s.gsub("%20", "").delete("+")}"
    end

    next env.redirect url
  end

  if id.size > 11
    url = "/embed/#{id[0, 11]}"

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    next env.redirect url
  end

  params = process_video_params(env.params.query, nil)

  begin
    video = get_video(id, PG_DB)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)
  video_streams = video.video_streams(adaptive_fmts)
  audio_streams = video.audio_streams(adaptive_fmts)

  captions = video.captions

  preferred_captions = captions.select { |caption|
    params[:preferred_captions].includes?(caption.name.simpleText) ||
      params[:preferred_captions].includes?(caption.languageCode.split("-")[0])
  }
  preferred_captions.sort_by! { |caption|
    (params[:preferred_captions].index(caption.name.simpleText) ||
      params[:preferred_captions].index(caption.languageCode.split("-")[0])).not_nil!
  }
  captions = captions - preferred_captions

  aspect_ratio = nil

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = replace_links(video.description)
  description = video.short_description

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.info["hlsvp"]?
    hlsvp = video.info["hlsvp"]
    hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)
  end

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params[:raw]
    url = fmt_stream[0]["url"]

    fmt_stream.each do |fmt|
      if fmt["label"].split(" - ")[0] == params[:quality]
        url = fmt["url"]
      end
    end

    next env.redirect url
  end

  rendered "embed"
end

# Playlists
get "/playlist" do |env|
  plid = env.params.query["list"]?
  if !plid
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  begin
    videos = extract_playlist(plid, page)
  rescue ex
    error_message = ex.message
    next templated "error"
  end
  playlist = fetch_playlist(plid)

  templated "playlist"
end

# Search

get "/results" do |env|
  query = env.params.query["search_query"]?
  query ||= env.params.query["q"]?
  query ||= ""

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if query
    env.redirect "/search?q=#{URI.escape(query)}&page=#{page}"
  else
    env.redirect "/"
  end
end

get "/search" do |env|
  query = env.params.query["search_query"]?
  query ||= env.params.query["q"]?
  query ||= ""

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  user = env.get? "user"
  if user
    user = user.as(User)
    ucids = user.subscriptions
  end
  ucids ||= [] of String

  channel = nil
  date = ""
  duration = ""
  features = [] of String
  sort = "relevance"
  subscriptions = nil

  operators = query.split(" ").select { |a| a.match(/\w+:[\w,]+/) }
  operators.each do |operator|
    key, value = operator.split(":")

    case key
    when "channel", "user"
      channel = value
    when "date"
      date = value
    when "duration"
      duration = value
    when "feature", "features"
      features = value.split(",")
    when "sort"
      sort = value
    when "subscriptions"
      subscriptions = value == "true"
    end
  end

  search_query = (query.split(" ") - operators).join(" ")

  if channel
    count, videos = channel_search(search_query, page, channel)
  elsif subscriptions
    videos = PG_DB.query_all("SELECT id,title,published,updated,ucid,author FROM (
      SELECT *,
        to_tsvector(channel_videos.title) ||
        to_tsvector(channel_videos.author)
          as document
      FROM channel_videos WHERE ucid IN (#{arg_array(ucids, 3)})
    ) v_search WHERE v_search.document @@ plainto_tsquery($1) LIMIT 20 OFFSET $2;", [search_query, (page - 1) * 20] + ucids, as: ChannelVideo)
    count = videos.size
  else
    begin
      search_params = produce_search_params(sort: sort, date: date, content_type: "video",
        duration: duration, features: features)
    rescue ex
      error_message = ex.message
      next templated "error"
    end

    count, videos = search(search_query, page, search_params).as(Tuple)
  end

  templated "search"
end

# Users

get "/login" do |env|
  user = env.get? "user"
  if user
    next env.redirect "/feed/subscriptions"
  end

  referer = get_referer(env, "/feed/subscriptions")

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  if account_type == "invidious"
    captcha = generate_captcha(HMAC_KEY)
  end

  tfa = env.params.query["tfa"]?
  tfa ||= false

  templated "login"
end

# See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L79
post "/login" do |env|
  referer = get_referer(env, "/feed/subscriptions")

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
            next env.redirect "/login?tfa=true&type=google&referer=#{URI.escape(referer)}"
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
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        PG_DB.exec("UPDATE users SET id = id || $1 WHERE email = $2", [sid], email)

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

      sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
      user = create_user(sid, email, password)
      user_array = user.to_a

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
  referer = get_referer(env)

  env.request.cookies.each do |cookie|
    cookie.expires = Time.new(1990, 1, 1)
  end

  if env.get? "user"
    user = env.get("user").as(User)
    sid = env.get("sid").as(String)
    PG_DB.exec("UPDATE users SET id = array_remove(id, $1) WHERE email = $2", sid, user.email)
  end

  env.request.cookies.add_response_headers(env.response.headers)
  env.redirect URI.unescape(referer)
end

get "/preferences" do |env|
  user = env.get? "user"

  referer = get_referer(env)

  if user
    user = user.as(User)
    templated "preferences"
  else
    env.redirect referer
  end
end

post "/preferences" do |env|
  user = env.get? "user"

  referer = get_referer(env)

  if user
    user = user.as(User)

    video_loop = env.params.body["video_loop"]?.try &.as(String)
    video_loop ||= "off"
    video_loop = video_loop == "on"

    autoplay = env.params.body["autoplay"]?.try &.as(String)
    autoplay ||= "off"
    autoplay = autoplay == "on"

    speed = env.params.body["speed"]?.try &.as(String).to_f?
    speed ||= 1.0

    quality = env.params.body["quality"]?.try &.as(String)
    quality ||= "hd720"

    volume = env.params.body["volume"]?.try &.as(String).to_i?
    volume ||= 100

    comments_0 = env.params.body["comments_0"]?.try &.as(String) || "youtube"
    comments_1 = env.params.body["comments_1"]?.try &.as(String) || ""
    comments = [comments_0, comments_1]

    captions_0 = env.params.body["captions_0"]?.try &.as(String) || ""
    captions_1 = env.params.body["captions_1"]?.try &.as(String) || ""
    captions_2 = env.params.body["captions_2"]?.try &.as(String) || ""
    captions = [captions_0, captions_1, captions_2]

    related_videos = env.params.body["related_videos"]?.try &.as(String)
    related_videos ||= "off"
    related_videos = related_videos == "on"

    redirect_feed = env.params.body["redirect_feed"]?.try &.as(String)
    redirect_feed ||= "off"
    redirect_feed = redirect_feed == "on"

    dark_mode = env.params.body["dark_mode"]?.try &.as(String)
    dark_mode ||= "off"
    dark_mode = dark_mode == "on"

    thin_mode = env.params.body["thin_mode"]?.try &.as(String)
    thin_mode ||= "off"
    thin_mode = thin_mode == "on"

    max_results = env.params.body["max_results"]?.try &.as(String).to_i?
    max_results ||= 40

    sort = env.params.body["sort"]?.try &.as(String)
    sort ||= "published"

    latest_only = env.params.body["latest_only"]?.try &.as(String)
    latest_only ||= "off"
    latest_only = latest_only == "on"

    unseen_only = env.params.body["unseen_only"]?.try &.as(String)
    unseen_only ||= "off"
    unseen_only = unseen_only == "on"

    notifications_only = env.params.body["notifications_only"]?.try &.as(String)
    notifications_only ||= "off"
    notifications_only = notifications_only == "on"

    preferences = {
      "video_loop"         => video_loop,
      "autoplay"           => autoplay,
      "speed"              => speed,
      "quality"            => quality,
      "volume"             => volume,
      "comments"           => comments,
      "captions"           => captions,
      "related_videos"     => related_videos,
      "redirect_feed"      => redirect_feed,
      "dark_mode"          => dark_mode,
      "thin_mode"          => thin_mode,
      "max_results"        => max_results,
      "sort"               => sort,
      "latest_only"        => latest_only,
      "unseen_only"        => unseen_only,
      "notifications_only" => notifications_only,
    }.to_json

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)
  end

  env.redirect referer
end

get "/toggle_theme" do |env|
  user = env.get? "user"

  referer = get_referer(env)

  if user
    user = user.as(User)
    preferences = user.preferences

    if preferences.dark_mode
      preferences.dark_mode = false
    else
      preferences.dark_mode = true
    end

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)
  end

  env.redirect referer
end

# /modify_notifications
# will "ding" all subscriptions.
# /modify_notifications?receive_all_updates=false&receive_no_updates=false
# will "unding" all subscriptions.
get "/modify_notifications" do |env|
  user = env.get? "user"

  referer = get_referer(env)

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

  referer = get_referer(env, "/")

  if !user
    next env.redirect referer
  end

  user = user.as(User)

  if !user.password
    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = make_client(YT_URL)
    user = get_user(user.id[0], client, headers, PG_DB)
  end

  action_takeout = env.params.query["action_takeout"]?.try &.to_i?
  action_takeout ||= 0
  action_takeout = action_takeout == 1

  format = env.params.query["format"]?
  format ||= "rss"

  client = make_client(YT_URL)

  subscriptions = [] of InvidiousChannel
  user.subscriptions.each do |ucid|
    begin
      subscriptions << get_channel(ucid, client, PG_DB, false)
    rescue ex
      next
    end
  end
  subscriptions.sort_by! { |channel| channel.author.downcase }

  if action_takeout
    host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)

    if format == "json"
      env.response.content_type = "application/json"
      env.response.headers["content-disposition"] = "attachment"
      next {
        "subscriptions" => user.subscriptions,
        "watch_history" => user.watched,
        "preferences"   => user.preferences,
      }.to_json
    else
      env.response.content_type = "application/xml"
      env.response.headers["content-disposition"] = "attachment"
      export = XML.build do |xml|
        xml.element("opml", version: "1.1") do
          xml.element("body") do
            if format == "newpipe"
              title = "YouTube Subscriptions"
            else
              title = "Invidious Subscriptions"
            end

            xml.element("outline", text: title, title: title) do
              subscriptions.each do |channel|
                if format == "newpipe"
                  xmlUrl = "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel.id}"
                else
                  xmlUrl = "#{host_url}/feed/channel/#{channel.id}"
                end

                xml.element("outline", text: channel.author, title: channel.author,
                  "type": "rss", xmlUrl: xmlUrl)
              end
            end
          end
        end
      end

      next export.gsub(%(<?xml version="1.0"?>\n), "")
    end
  end

  templated "subscription_manager"
end

get "/data_control" do |env|
  user = env.get? "user"

  referer = get_referer(env)

  if user
    user = user.as(User)

    templated "data_control"
  else
    env.redirect referer
  end
end

post "/data_control" do |env|
  user = env.get? "user"

  referer = get_referer(env)

  if user
    user = user.as(User)

    HTTP::FormData.parse(env.request) do |part|
      body = part.body.gets_to_end
      if body.empty?
        next
      end

      case part.name
      when "import_invidious"
        body = JSON.parse(body)
        body["subscriptions"].as_a.each do |ucid|
          ucid = ucid.as_s
          if !user.subscriptions.includes? ucid
            PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE id = $2", ucid, user.id)

            begin
              client = make_client(YT_URL)
              get_channel(ucid, client, PG_DB, false, false)
            rescue ex
              next
            end
          end
        end

        body["watch_history"].as_a.each do |id|
          id = id.as_s
          if !user.watched.includes? id
            PG_DB.exec("UPDATE users SET watched = array_append(watched,$1) WHERE email = $2", id, user.email)
          end
        end

        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", body["preferences"].to_json, user.email)
      when "import_youtube"
        subscriptions = XML.parse(body)
        subscriptions.xpath_nodes(%q(//outline[@type="rss"])).each do |channel|
          ucid = channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]

          if !user.subscriptions.includes? ucid
            PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)

            begin
              client = make_client(YT_URL)
              get_channel(ucid, client, PG_DB, false, false)
            rescue ex
              next
            end
          end
        end
      when "import_freetube"
        body.scan(/"channelId":"(?<channel_id>[a-zA-Z0-9_-]{24})"/).each do |md|
          ucid = md["channel_id"]

          if !user.subscriptions.includes? ucid
            PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)

            begin
              client = make_client(YT_URL)
              get_channel(ucid, client, PG_DB, false, false)
            rescue ex
              next
            end
          end
        end
      when "import_newpipe_subscriptions"
        body = JSON.parse(body)
        body["subscriptions"].as_a.each do |channel|
          ucid = channel["url"].as_s.match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]

          if !user.subscriptions.includes? ucid
            PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)

            begin
              client = make_client(YT_URL)
              get_channel(ucid, client, PG_DB, false, false)
            rescue ex
              next
            end
          end
        end
      when "import_newpipe"
        Zip::Reader.open(body) do |file|
          file.each_entry do |entry|
            if entry.filename == "newpipe.db"
              # We do this because the SQLite driver cannot parse a database from an IO
              # Currently: channel URLs can **only** be subscriptions, and
              # video URLs can **only** be watch history, so this works okay for now.

              db = entry.io.gets_to_end
              db.scan(/youtube\.com\/watch\?v\=(?<id>[a-zA-Z0-9_-]{11})/) do |md|
                if !user.watched.includes? md["id"]
                  PG_DB.exec("UPDATE users SET watched = array_append(watched,$1) WHERE email = $2", md["id"], user.email)
                end
              end

              db.scan(/youtube\.com\/channel\/(?<ucid>[a-zA-Z0-9_-]{22})/) do |md|
                ucid = md["ucid"]
                if !user.subscriptions.includes? ucid
                  PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)

                  begin
                    client = make_client(YT_URL)
                    get_channel(ucid, client, PG_DB, false, false)
                  rescue ex
                    next
                  end
                end
              end
            end
          end
        end
      end
    end
  end

  env.redirect referer
end

get "/subscription_ajax" do |env|
  user = env.get? "user"

  referer = get_referer(env)

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
        next env.redirect referer
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

  referer = get_referer(env)

  if user
    user = user.as(User)

    PG_DB.exec("UPDATE users SET watched = '{}' WHERE email = $1", user.email)
  end

  env.redirect referer
end

# Feeds

get "/feed/subscriptions" do |env|
  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)
    preferences = user.preferences

    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    if !user.password
      client = make_client(YT_URL)
      user = get_user(user.id[0], client, headers, PG_DB)
    end

    max_results = preferences.max_results
    max_results ||= env.params.query["max_results"]?.try &.to_i?
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

    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
      as: Array(String))
    if preferences.notifications_only && !notifications.empty?
      args = arg_array(notifications)

      notifications = PG_DB.query_all("SELECT * FROM channel_videos WHERE id IN (#{args})
      ORDER BY published DESC", notifications, as: ChannelVideo)
      videos = [] of ChannelVideo

      notifications.sort_by! { |video| video.published }.reverse!

      case preferences.sort
      when "alphabetically"
        notifications.sort_by! { |video| video.title }
      when "alphabetically - reverse"
        notifications.sort_by! { |video| video.title }.reverse!
      when "channel name"
        notifications.sort_by! { |video| video.author }
      when "channel name - reverse"
        notifications.sort_by! { |video| video.author }.reverse!
      end
    else
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
    end

    if !limit
      videos = videos[0..max_results]
    end

    PG_DB.exec("UPDATE users SET notifications = $1, updated = $2 WHERE id = $3", [] of String, Time.now,
      user.id)
    user.notifications = [] of String
    env.set "user", user

    templated "subscriptions"
  else
    env.redirect referer
  end
end

get "/feed/channel/:ucid" do |env|
  ucid = env.params.url["ucid"]

  client = make_client(YT_URL)

  if !ucid.match(/UC[a-zA-Z0-9_-]{22}/)
    rss = client.get("/feeds/videos.xml?user=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      halt env, status_code: 404, response: error_message
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
    next env.redirect "/feed/channel/#{ucid}"
  else
    rss = client.get("/feeds/videos.xml?channel_id=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      next templated "error"
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
  end

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  page = 1

  videos = [] of SearchVideo
  2.times do |i|
    url = produce_channel_videos_url(ucid, page * 2 + (i - 1), auto_generated: auto_generated)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if auto_generated
        videos += extract_videos(nodeset)
      else
        videos += extract_videos(nodeset, ucid)
      end
    else
      break
    end
  end

  channel = get_channel(ucid, client, PG_DB, pull_all_videos: false)

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
  path = env.request.path

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom") do
      xml.element("link", rel: "self", href: "#{host_url}#{path}")
      xml.element("id") { xml.text "yt:channel:#{ucid}" }
      xml.element("yt:channelId") { xml.text ucid }
      xml.element("title") { xml.text channel.author }
      xml.element("link", rel: "alternate", href: "#{host_url}/channel/#{ucid}")

      xml.element("author") do
        xml.element("name") { xml.text channel.author }
        xml.element("uri") { xml.text "#{host_url}/channel/#{ucid}" }
      end

      videos.each do |video|
        xml.element("entry") do
          xml.element("id") { xml.text "yt:video:#{video.id}" }
          xml.element("yt:videoId") { xml.text video.id }
          xml.element("yt:channelId") { xml.text video.ucid }
          xml.element("title") { xml.text video.title }
          xml.element("link", rel: "alternate", href: "#{host_url}/watch?v=#{video.id}")

          xml.element("author") do
            if auto_generated
              xml.element("name") { xml.text video.author }
              xml.element("uri") { xml.text "#{host_url}/channel/#{video.ucid}" }
            else
              xml.element("name") { xml.text author }
              xml.element("uri") { xml.text "#{host_url}/channel/#{ucid}" }
            end
          end

          xml.element("published") { xml.text video.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text video.title }
            xml.element("media:thumbnail", url: "/vi/#{video.id}/mqdefault.jpg",
              width: "320", height: "180")
            xml.element("media:description") { xml.text video.description }
          end

          xml.element("media:community") do
            xml.element("media:statistics", views: video.views)
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
    halt env, status_code: 403
  end

  user = PG_DB.query_one?("SELECT * FROM users WHERE token = $1", token.strip, as: User)
  if !user
    halt env, status_code: 403
  end

  max_results = env.params.query["max_results"]?.try &.to_i?
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

  latest_only = env.params.query["latest_only"]?.try &.to_i?
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

  if !limit
    videos = videos[0..max_results]
  end

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
  path = env.request.path
  query = env.request.query.not_nil!

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", xmlns: "http://www.w3.org/2005/Atom", "xmlns:media": "http://search.yahoo.com/mrss/",
      "xml:lang": "en-US") do
      xml.element("link", "type": "text/html", rel: "alternate", href: "#{host_url}/feed/subscriptions")
      xml.element("link", "type": "application/atom+xml", rel: "self", href: "#{host_url}#{path}?#{query}")
      xml.element("title") { xml.text "Invidious Private Feed for #{user.email}" }

      videos.each do |video|
        xml.element("entry") do
          xml.element("id") { xml.text "yt:video:#{video.id}" }
          xml.element("yt:videoId") { xml.text video.id }
          xml.element("yt:channelId") { xml.text video.ucid }
          xml.element("title") { xml.text video.title }
          xml.element("link", rel: "alternate", href: "#{host_url}/watch?v=#{video.id}")

          xml.element("author") do
            xml.element("name") { xml.text video.author }
            xml.element("uri") { xml.text "#{host_url}/channel/#{video.ucid}" }
          end

          xml.element("published") { xml.text video.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }
          xml.element("updated") { xml.text video.updated.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text video.title }
            xml.element("media:thumbnail", url: "/vi/#{video.id}/mqdefault.jpg",
              width: "320", height: "180")
          end
        end
      end
    end
  end

  env.response.content_type = "application/atom+xml"
  feed
end

get "/feed/playlist/:plid" do |env|
  plid = env.params.url["plid"]

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
  path = env.request.path

  client = make_client(YT_URL)
  response = client.get("/feeds/videos.xml?playlist_id=#{plid}")
  document = XML.parse(response.body)

  document.xpath_nodes(%q(//*[@href]|//*[@url])).each do |node|
    node.attributes.each do |attribute|
      case attribute.name
      when "url"
        node["url"] = "#{host_url}#{URI.parse(node["url"]).full_path}"
      when "href"
        node["href"] = "#{host_url}#{URI.parse(node["href"]).full_path}"
      end
    end
  end

  document = document.to_xml(options: XML::SaveOptions::NO_DECL)

  document.scan(/<uri>(?<url>[^<]+)<\/uri>/).each do |match|
    content = "#{host_url}#{URI.parse(match["url"]).full_path}"
    document = document.gsub(match[0], "<uri>#{content}</uri>")
  end

  env.response.content_type = "text/xml"
  document
end

# Channels

# YouTube appears to let users set a "brand" URL that
# is different from their username, so we convert that here
get "/c/:user" do |env|
  client = make_client(YT_URL)
  user = env.params.url["user"]

  response = client.get("/c/#{user}")
  document = XML.parse_html(response.body)

  anchor = document.xpath_node(%q(//a[contains(@class,"branded-page-header-title-link")]))
  if !anchor
    next env.redirect "/"
  end

  env.redirect anchor["href"]
end

get "/user/:user" do |env|
  user = env.params.url["user"]
  env.redirect "/channel/#{user}"
end

get "/user/:user/videos" do |env|
  user = env.params.url["user"]
  env.redirect "/channel/#{user}/videos"
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

  if !ucid.match(/UC[a-zA-Z0-9_-]{22}/)
    rss = client.get("/feeds/videos.xml?user=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      next templated "error"
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
    next env.redirect "/channel/#{ucid}"
  else
    rss = client.get("/feeds/videos.xml?channel_id=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      next templated "error"
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
  end

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  if !auto_generated
    if author.includes? " "
      env.set "search", "channel:#{ucid} "
    else
      env.set "search", "channel:#{author.downcase} "
    end
  end

  videos = [] of SearchVideo
  2.times do |i|
    url = produce_channel_videos_url(ucid, page * 2 + (i - 1), auto_generated: auto_generated)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if auto_generated
        videos += extract_videos(nodeset)
      else
        videos += extract_videos(nodeset, ucid)
      end
    else
      break
    end
  end

  templated "channel"
end

get "/channel/:ucid/videos" do |env|
  ucid = env.params.url["ucid"]
  params = env.request.query

  if !params || params.empty?
    params = ""
  else
    params = "?#{params}"
  end

  env.redirect "/channel/#{ucid}#{params}"
end

# API Endpoints

get "/api/v1/captions/:id" do |env|
  id = env.params.url["id"]

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB)
  rescue ex
    halt env, status_code: 403
  end

  captions = video.captions

  label = env.params.query["label"]?
  if !label
    env.response.content_type = "application/json"

    response = JSON.build do |json|
      json.object do
        json.field "captions" do
          json.array do
            captions.each do |caption|
              json.object do
                json.field "label", caption.name.simpleText
                json.field "languageCode", caption.languageCode
              end
            end
          end
        end
      end
    end

    next response
  end

  caption = captions.select { |caption| caption.name.simpleText == label }

  env.response.content_type = "text/vtt"
  if caption.empty?
    halt env, status_code: 403
  else
    caption = caption[0]
  end

  caption_xml = client.get(caption.baseUrl).body
  caption_xml = XML.parse(caption_xml)

  webvtt = <<-END_VTT
  WEBVTT
  Kind: captions
  Language: #{caption.languageCode}


  END_VTT

  caption_nodes = caption_xml.xpath_nodes("//transcript/text")
  caption_nodes.each_with_index do |node, i|
    start_time = node["start"].to_f.seconds
    duration = node["dur"]?.try &.to_f.seconds
    duration ||= start_time

    if caption_nodes.size > i + 1
      end_time = caption_nodes[i + 1]["start"].to_f.seconds
    else
      end_time = start_time + duration
    end

    start_time = "#{start_time.hours.to_s.rjust(2, '0')}:#{start_time.minutes.to_s.rjust(2, '0')}:#{start_time.seconds.to_s.rjust(2, '0')}.#{start_time.milliseconds.to_s.rjust(3, '0')}"
    end_time = "#{end_time.hours.to_s.rjust(2, '0')}:#{end_time.minutes.to_s.rjust(2, '0')}:#{end_time.seconds.to_s.rjust(2, '0')}.#{end_time.milliseconds.to_s.rjust(3, '0')}"

    text = HTML.unescape(node.content)
    text = text.gsub(/<font color="#[a-fA-F0-9]{6}">/, "")
    text = text.gsub(/<\/font>/, "")
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
    html = client.get("/watch?v=#{id}&bpctr=#{Time.new.epoch + 2000}&disable_polymer=1")

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

      if format == "json"
        next {"comments" => [] of String}.to_json
      else
        next {"contentHtml" => "", "commentCount" => 0}.to_json
      end
    end
    ctoken = ctoken["ctoken"]
    itct = body.match(/itct=(?<itct>[^"]+)"/).not_nil!["itct"]

    if env.params.query["continuation"]? && !env.params.query["continuation"].empty?
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
      halt env, status_code: 403
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
        next {"contentHtml" => "", "commentCount" => 0}.to_json
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
            contents.as_a.each do |node|
              json.object do
                if !response["commentRepliesContinuation"]?
                  node = node["commentThreadRenderer"]
                end

                if node["replies"]?
                  node_replies = node["replies"]["commentRepliesRenderer"]
                end

                if !response["commentRepliesContinuation"]?
                  node_comment = node["comment"]["commentRenderer"]
                else
                  node_comment = node["commentRenderer"]
                end

                content_html = node_comment["contentText"]["simpleText"]?.try &.as_s.rchop('\ufeff')
                if content_html
                  content_html = HTML.escape(content_html)
                end

                content_html ||= node_comment["contentText"]["runs"].as_a.map do |run|
                  text = HTML.escape(run["text"].as_s)

                  if run["text"] == "\n"
                    text = "<br>"
                  end

                  if run["bold"]?
                    text = "<b>#{text}</b>"
                  end

                  if run["italics"]?
                    text = "<i>#{text}</i>"
                  end

                  if run["navigationEndpoint"]?
                    url = run["navigationEndpoint"]["urlEndpoint"]?.try &.["url"].as_s
                    if url
                      url = URI.parse(url)

                      if {"m.youtube.com", "www.youtube.com", "youtu.be"}.includes? url.host
                        if url.path == "/redirect"
                          url = HTTP::Params.parse(url.query.not_nil!)["q"]
                        else
                          url = url.full_path
                        end
                      end
                    else
                      url = run["navigationEndpoint"]["commandMetadata"]?.try &.["webCommandMetadata"]["url"].as_s
                    end

                    text = %(<a href="#{url}">#{text}</a>)
                  end

                  text
                end.join.rchop('\ufeff')

                content_html, content = html_to_content(content_html)

                author = node_comment["authorText"]?.try &.["simpleText"]
                author ||= ""

                json.field "author", author
                json.field "authorThumbnails" do
                  json.array do
                    node_comment["authorThumbnail"]["thumbnails"].as_a.each do |thumbnail|
                      json.object do
                        json.field "url", thumbnail["url"]
                        json.field "width", thumbnail["width"]
                        json.field "height", thumbnail["height"]
                      end
                    end
                  end
                end

                if node_comment["authorEndpoint"]?
                  json.field "authorId", node_comment["authorEndpoint"]["browseEndpoint"]["browseId"]
                  json.field "authorUrl", node_comment["authorEndpoint"]["browseEndpoint"]["canonicalBaseUrl"]
                else
                  json.field "authorId", ""
                  json.field "authorUrl", ""
                end

                published = decode_date(node_comment["publishedTimeText"]["runs"][0]["text"].as_s.rchop(" (edited)"))

                json.field "content", content
                json.field "contentHtml", content_html
                json.field "published", published.epoch
                json.field "publishedText", "#{recode_date(published)} ago"
                json.field "likeCount", node_comment["likeCount"]
                json.field "commentId", node_comment["commentId"]

                if node_replies && !response["commentRepliesContinuation"]?
                  reply_count = node_replies["moreText"]["simpleText"].as_s.delete("View all reply replies,")
                  if reply_count.empty?
                    reply_count = 1
                  else
                    reply_count = reply_count.try &.to_i?
                    reply_count ||= 1
                  end

                  continuation = node_replies["continuations"].as_a[0]["nextContinuationData"]["continuation"].as_s

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

      response = JSON.build do |json|
        json.object do
          json.field "contentHtml", content_html

          if comments["commentCount"]?
            json.field "commentCount", comments["commentCount"]
          else
            json.field "commentCount", 0
          end
        end
      end

      next response
    end
  elsif source == "reddit"
    client = make_client(REDDIT_URL)
    headers = HTTP::Headers{"User-Agent" => "web:invidio.us:v0.2.0 (by /u/omarroth)"}
    begin
      comments, reddit_thread = get_reddit_comments(id, client, headers)
      content_html = template_reddit_comments(comments)

      content_html = fill_links(content_html, "https", "www.reddit.com")
      content_html = replace_links(content_html)
    rescue ex
      comments = nil
      reddit_thread = nil
      content_html = ""
    end

    if !reddit_thread || !comments
      halt env, status_code: 404
    end

    env.response.content_type = "application/json"

    if format == "json"
      reddit_thread = JSON.parse(reddit_thread.to_json).as_h
      reddit_thread["comments"] = JSON.parse(comments.to_json)
      next reddit_thread.to_json
    else
      next {
        "title"       => reddit_thread.title,
        "permalink"   => reddit_thread.permalink,
        "contentHtml" => content_html,
      }.to_json
    end
  end
end

get "/api/v1/insights/:id" do |env|
  id = env.params.url["id"]
  env.response.content_type = "application/json"

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

  post_req = {
    "session_token" => session_token,
  }
  post_req = HTTP::Params.encode(post_req)

  response = client.post("/insight_ajax?action_get_statistics_and_data=1&v=#{id}", headers, post_req).body
  response = XML.parse(response)

  html_content = XML.parse_html(response.xpath_node(%q(//html_content)).not_nil!.content)
  graph_data = response.xpath_node(%q(//graph_data))
  if !graph_data
    error = html_content.xpath_node(%q(//p)).not_nil!.content
    next {"error" => error}.to_json
  end

  graph_data = JSON.parse(graph_data.content)

  view_count = 0_i64
  time_watched = 0_i64
  subscriptions_driven = 0
  shares = 0

  stats_nodes = html_content.xpath_nodes(%q(//table/tr/td))
  stats_nodes.each do |node|
    key = node.xpath_node(%q(.//span))
    value = node.xpath_node(%q(.//div))

    if !key || !value
      next
    end

    key = key.content
    value = value.content

    case key
    when "Views"
      view_count = value.delete(", ").to_i64
    when "Time watched"
      time_watched = value
    when "Subscriptions driven"
      subscriptions_driven = value.delete(", ").to_i
    when "Shares"
      shares = value.delete(", ").to_i
    end
  end

  avg_view_duration_seconds = html_content.xpath_node(%q(//div[@id="stats-chart-tab-watch-time"]/span/span[2])).not_nil!.content
  avg_view_duration_seconds = decode_length_seconds(avg_view_duration_seconds)

  {
    "viewCount"              => view_count,
    "timeWatchedText"        => time_watched,
    "subscriptionsDriven"    => subscriptions_driven,
    "shares"                 => shares,
    "avgViewDurationSeconds" => avg_view_duration_seconds,
    "graphData"              => graph_data,
  }.to_json
end

get "/api/v1/videos/:id" do |env|
  id = env.params.url["id"]

  begin
    video = get_video(id, PG_DB)
  rescue ex
    env.response.content_type = "application/json"
    response = {"error" => ex.message}.to_json
    halt env, status_code: 500, response: response
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  captions = video.captions

  env.response.content_type = "application/json"
  video_info = JSON.build do |json|
    json.object do
      json.field "title", video.title
      json.field "videoId", video.id
      json.field "videoThumbnails" do
        generate_thumbnails(json, video.id)
      end

      video.description, description = html_to_content(video.description)

      json.field "description", description
      json.field "descriptionHtml", video.description
      json.field "published", video.published.epoch
      json.field "publishedText", "#{recode_date(video.published)} ago"
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
      json.field "genreUrl", video.genre_url

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

      if video.info["hlsvp"]?
        host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"]?)
        host_params = env.request.query_params
        host_params.delete_all("v")

        hlsvp = video.info["hlsvp"]
        hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)

        json.field "hlsUrl", hlsvp
      end

      json.field "adaptiveFormats" do
        json.array do
          adaptive_fmts.each do |fmt|
            json.object do
              json.field "index", fmt["index"]
              json.field "bitrate", fmt["bitrate"]
              json.field "init", fmt["init"]
              json.field "url", fmt["url"]
              json.field "itag", fmt["itag"]
              json.field "type", fmt["type"]
              json.field "clen", fmt["clen"]
              json.field "lmt", fmt["lmt"]
              json.field "projectionType", fmt["projection_type"]

              fmt_info = itag_to_metadata?(fmt["itag"])
              if fmt_info
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.to_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
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

              fmt_info = itag_to_metadata?(fmt["itag"])
              if fmt_info
                fps = fmt_info["fps"]?.try &.to_i || fmt["fps"]?.try &.to_i || 30
                json.field "fps", fps
                json.field "container", fmt_info["ext"]
                json.field "encoding", fmt_info["vcodec"]? || fmt_info["acodec"]

                if fmt_info["height"]?
                  json.field "resolution", "#{fmt_info["height"]}p"

                  quality_label = "#{fmt_info["height"]}p"
                  if fps > 30
                    quality_label += "60"
                  end
                  json.field "qualityLabel", quality_label

                  if fmt_info["width"]?
                    json.field "size", "#{fmt_info["width"]}x#{fmt_info["height"]}"
                  end
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
              json.field "label", caption.name.simpleText
              json.field "languageCode", caption.languageCode
            end
          end
        end
      end

      json.field "recommendedVideos" do
        json.array do
          video.info["rvs"]?.try &.split(",").each do |rv|
            rv = HTTP::Params.parse(rv)

            if rv["id"]?
              json.object do
                json.field "videoId", rv["id"]
                json.field "title", rv["title"]
                json.field "videoThumbnails" do
                  generate_thumbnails(json, rv["id"])
                end
                json.field "author", rv["author"]
                json.field "lengthSeconds", rv["length_seconds"].to_i
                json.field "viewCountText", rv["short_view_count_text"]
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
      nodeset = trending.xpath_nodes(%q(//ul/li[@class="expanded-shelf-content-item-wrapper"]))
      extract_videos(nodeset).each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id
          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id)
          end

          json.field "lengthSeconds", video.length_seconds
          json.field "viewCount", video.views

          json.field "author", video.author
          json.field "authorId", video.ucid
          json.field "authorUrl", "/channel/#{video.ucid}"

          json.field "published", video.published.epoch
          json.field "publishedText", "#{recode_date(video.published)} ago"
          json.field "description", video.description
          json.field "descriptionHtml", video.description_html
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
            generate_thumbnails(json, video.id)
          end

          json.field "lengthSeconds", video.info["length_seconds"].to_i
          json.field "viewCount", video.views

          json.field "author", video.author
          json.field "authorId", video.ucid
          json.field "authorUrl", "/channel/#{video.ucid}"
          json.field "published", video.published.epoch
          json.field "publishedText", "#{recode_date(video.published)} ago"

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
  if !ucid.match(/UC[a-zA-Z0-9_-]{22}/)
    rss = client.get("/feeds/videos.xml?user=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      env.response.content_type = "application/json"
      next {"error" => "User does not exist"}.to_json
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
    next env.redirect "/api/v1/channels/#{ucid}"
  else
    rss = client.get("/feeds/videos.xml?channel_id=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      next templated "error"
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
  end

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  page = 1

  videos = [] of SearchVideo
  2.times do |i|
    url = produce_channel_videos_url(ucid, page * 2 + (i - 1), auto_generated: auto_generated)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if auto_generated
        videos += extract_videos(nodeset)
      else
        videos += extract_videos(nodeset, ucid)
      end
    else
      break
    end
  end

  channel_html = client.get("/channel/#{ucid}/about?disable_polymer=1").body
  channel_html = XML.parse_html(channel_html)
  banner = channel_html.xpath_node(%q(//div[@id="gh-banner"]/style)).not_nil!.content
  banner = "https:" + banner.match(/background-image: url\((?<url>[^)]+)\)/).not_nil!["url"]

  author = channel_html.xpath_node(%q(//a[contains(@class, "branded-page-header-title-link")])).not_nil!.content
  author_url = channel_html.xpath_node(%q(//a[@class="channel-header-profile-image-container spf-link"])).not_nil!["href"]
  author_thumbnail = channel_html.xpath_node(%q(//img[@class="channel-header-profile-image"])).not_nil!["src"]
  description_html = channel_html.xpath_node(%q(//div[contains(@class,"about-description")]))
  description_html, description = html_to_content(description_html)

  paid = channel_html.xpath_node(%q(//meta[@itemprop="paid"])).not_nil!["content"] == "True"
  is_family_friendly = channel_html.xpath_node(%q(//meta[@itemprop="isFamilyFriendly"])).not_nil!["content"] == "True"
  allowed_regions = channel_html.xpath_node(%q(//meta[@itemprop="regionsAllowed"])).not_nil!["content"].split(",")

  total_views = 0_i64
  sub_count = 0_i64
  joined = Time.epoch(0)
  metadata = channel_html.xpath_nodes(%q(//span[@class="about-stat"]))
  metadata.each do |item|
    case item.content
    when .includes? "views"
      total_views = item.content.delete("views •,").to_i64
    when .includes? "subscribers"
      sub_count = item.content.delete("subscribers").delete(",").to_i64
    when .includes? "Joined"
      joined = Time.parse(item.content.lchop("Joined "), "%b %-d, %Y", Time::Location.local)
    end
  end

  channel_info = JSON.build do |json|
    json.object do
      json.field "author", author
      json.field "authorId", ucid
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
      json.field "descriptionHtml", description_html

      json.field "allowedRegions", allowed_regions

      json.field "latestVideos" do
        json.array do
          videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id

              if auto_generated
                json.field "author", video.author
                json.field "authorId", video.ucid
                json.field "authorUrl", "/channel/#{video.ucid}"
              else
                json.field "author", author
                json.field "authorId", ucid
                json.field "authorUrl", "/channel/#{ucid}"
              end

              json.field "videoThumbnails" do
                generate_thumbnails(json, video.id)
              end

              json.field "description", video.description
              json.field "descriptionHtml", video.description_html

              json.field "viewCount", video.views
              json.field "published", video.published.epoch
              json.field "publishedText", "#{recode_date(video.published)} ago"
              json.field "lengthSeconds", video.length_seconds
            end
          end
        end
      end
    end
  end

  env.response.content_type = "application/json"
  channel_info
end

["/api/v1/channels/:ucid/videos", "/api/v1/channels/videos/:ucid"].each do |route|
  get route do |env|
  ucid = env.params.url["ucid"]
  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  client = make_client(YT_URL)

  if !ucid.match(/UC[a-zA-Z0-9_-]{22}/)
    rss = client.get("/feeds/videos.xml?user=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      env.response.content_type = "application/json"
      next {"error" => "User does not exist"}.to_json
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
    next env.redirect "/feed/channel/#{ucid}"
  else
    rss = client.get("/feeds/videos.xml?channel_id=#{ucid}")
    rss = XML.parse_html(rss.body)

    ucid = rss.xpath_node("//feed/channelid")
    if !ucid
      error_message = "User does not exist."
      next templated "error"
    end

    ucid = ucid.content
    author = rss.xpath_node("//author/name").not_nil!.content
  end

  # Auto-generated channels
  # https://support.google.com/youtube/answer/2579942
  if author.ends_with?(" - Topic") ||
     {"Popular on YouTube", "Music", "Sports", "Gaming"}.includes? author
    auto_generated = true
  end

  videos = [] of SearchVideo
  2.times do |i|
    url = produce_channel_videos_url(ucid, page * 2 + (i - 1), auto_generated: auto_generated)
    response = client.get(url)
    json = JSON.parse(response.body)

    if json["content_html"]? && !json["content_html"].as_s.empty?
      document = XML.parse_html(json["content_html"].as_s)
      nodeset = document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")]))

      if auto_generated
        videos += extract_videos(nodeset)
      else
        videos += extract_videos(nodeset, ucid)
      end
    else
      break
    end
  end

  result = JSON.build do |json|
    json.array do
      videos.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id

          if auto_generated
            json.field "author", video.author
            json.field "authorId", video.ucid
            json.field "authorUrl", "/channel/#{video.ucid}"
          else
            json.field "author", author
            json.field "authorId", ucid
            json.field "authorUrl", "/channel/#{ucid}"
          end

          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id)
          end

          json.field "description", video.description
          json.field "descriptionHtml", video.description_html

          json.field "viewCount", video.views
          json.field "published", video.published.epoch
          json.field "publishedText", "#{recode_date(video.published)} ago"
          json.field "lengthSeconds", video.length_seconds
        end
      end
    end
  end

  env.response.content_type = "application/json"
  result
end
end

get "/api/v1/search" do |env|
  query = env.params.query["q"]?
  query ||= ""

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "relevance"

  date = env.params.query["date"]?.try &.downcase
  date ||= ""

  duration = env.params.query["date"]?.try &.downcase
  duration ||= ""

  features = env.params.query["features"]?.try &.split(",").map { |feature| feature.downcase }
  features ||= [] of String

  # TODO: Support other content types
  content_type = "video"

  env.response.content_type = "application/json"

  begin
    search_params = produce_search_params(sort_by, date, content_type, duration, features)
  rescue ex
    next JSON.build do |json|
      json.object do
        json.field "error", ex.message
      end
    end
  end

  response = JSON.build do |json|
    json.array do
      count, search_results = search(query, page, search_params).as(Tuple)
      search_results.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id

          json.field "author", video.author
          json.field "authorId", video.ucid
          json.field "authorUrl", "/channel/#{video.ucid}"

          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id)
          end

          json.field "description", video.description
          json.field "descriptionHtml", video.description_html

          json.field "viewCount", video.views
          json.field "published", video.published.epoch
          json.field "publishedText", "#{recode_date(video.published)} ago"
          json.field "lengthSeconds", video.length_seconds
        end
      end
    end
  end

  response
end

get "/api/v1/playlists/:plid" do |env|
  plid = env.params.url["plid"]

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  begin
    videos = extract_playlist(plid, page)
  rescue ex
    env.response.content_type = "application/json"
    response = {"error" => "Playlist is empty"}.to_json
    halt env, status_code: 404, response: response
  end

  playlist = fetch_playlist(plid)

  response = JSON.build do |json|
    json.object do
      json.field "title", playlist.title
      json.field "id", playlist.id

      json.field "author", playlist.author
      json.field "authorId", playlist.ucid
      json.field "authorUrl", "/channel/#{playlist.ucid}"

      json.field "description", playlist.description
      json.field "descriptionHtml", playlist.description_html
      json.field "videoCount", playlist.video_count

      json.field "viewCount", playlist.views
      json.field "updated", playlist.updated.epoch

      json.field "videos" do
        json.array do
          videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "id", video.id

              json.field "author", video.author
              json.field "authorId", video.ucid
              json.field "authorUrl", "/channel/#{video.ucid}"

              json.field "videoThumbnails" do
                generate_thumbnails(json, video.id)
              end

              json.field "index", video.index
              json.field "lengthSeconds", video.length_seconds
            end
          end
        end
      end
    end
  end

  env.response.content_type = "application/json"
  response
end

get "/api/manifest/dash/id/videoplayback" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.redirect "/videoplayback?#{env.params.query}"
end

get "/api/manifest/dash/id/videoplayback/*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.redirect env.request.path.lchop("/api/manifest/dash/id")
end

get "/api/manifest/dash/id/:id" do |env|
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  env.response.content_type = "application/dash+xml"

  local = env.params.query["local"]?.try &.== "true"
  id = env.params.url["id"]

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB)
  rescue ex
    halt env, status_code: 403
  end

  if video.info["dashmpd"]?
    manifest = client.get(video.info["dashmpd"]).body

    manifest = manifest.gsub(/<BaseURL>[^<]+<\/BaseURL>/) do |baseurl|
      url = baseurl.lchop("<BaseURL>")
      url = url.rchop("</BaseURL>")

      if local
        url = URI.parse(url).full_path.lchop("/")
      end

      "<BaseURL>#{url}</BaseURL>"
    end

    next manifest
  end

  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  if local
    adaptive_fmts.each do |fmt|
      fmt["url"] = URI.parse(fmt["url"]).full_path.lchop("/")
    end
  end

  video_streams = video.video_streams(adaptive_fmts).select { |stream| stream["type"].starts_with? "video/mp4" }
  audio_streams = video.audio_streams(adaptive_fmts).select { |stream| stream["type"].starts_with? "audio/mp4" }

  manifest = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
      "profiles": "urn:mpeg:dash:profile:isoff-live:2011", minBufferTime: "PT1.5S", type: "static",
      mediaPresentationDuration: "PT#{video.info["length_seconds"]}S") do
      xml.element("Period") do
        xml.element("AdaptationSet", mimeType: "audio/mp4", startWithSAP: 1, subsegmentAlignment: true) do
          audio_streams.each do |fmt|
            mimetype = fmt["type"].split(";")[0]
            codecs = fmt["type"].split("codecs=")[1].strip('"')
            fmt_type = mimetype.split("/")[0]
            bandwidth = fmt["bitrate"]
            itag = fmt["itag"]
            url = fmt["url"]

            xml.element("Representation", id: fmt["itag"], codecs: codecs, bandwidth: bandwidth) do
              xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011",
                value: "2")
              xml.element("BaseURL") { xml.text url }
              xml.element("SegmentBase", indexRange: fmt["index"]) do
                xml.element("Initialization", range: fmt["init"])
              end
            end
          end
        end

        xml.element("AdaptationSet", mimeType: "video/mp4", startWithSAP: 1, subsegmentAlignment: true,
          scanType: "progressive") do
          video_streams.each do |fmt|
            mimetype = fmt["type"].split(";")
            codecs = fmt["type"].split("codecs=")[1].strip('"')
            bandwidth = fmt["bitrate"]
            itag = fmt["itag"]
            url = fmt["url"]
            height, width = fmt["size"].split("x")

            xml.element("Representation", id: itag, codecs: codecs, width: width, height: height,
              startWithSAP: "1", maxPlayoutRate: "1",
              bandwidth: bandwidth, frameRate: fmt["fps"]) do
              xml.element("BaseURL") { xml.text url }
              xml.element("SegmentBase", indexRange: fmt["index"]) do
                xml.element("Initialization", range: fmt["init"])
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

get "/api/manifest/hls_variant/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    halt env, status_code: manifest.status_code
  end

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"])
  manifest = manifest.body
  manifest.gsub("https://www.youtube.com", host_url)
end

get "/api/manifest/hls_playlist/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    halt env, status_code: manifest.status_code
  end

  host_url = make_host_url(Kemal.config.ssl || CONFIG.https_only, env.request.headers["Host"])

  manifest = manifest.body.gsub("https://www.youtube.com", host_url)
  manifest = manifest.gsub(/https:\/\/r\d---.{11}\.c\.youtube\.com/, host_url)
  fvip = manifest.match(/hls_chunk_host\/r(?<fvip>\d)---/).not_nil!["fvip"]
  manifest = manifest.gsub("seg.ts", "seg.ts/fvip/#{fvip}")

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  manifest
end

options "/videoplayback" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/videoplayback/*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/api/manifest/dash/id/videoplayback" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/api/manifest/dash/id/videoplayback/*" do |env|
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

get "/videoplayback/*" do |env|
  path = env.request.path

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

  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.redirect "/videoplayback?#{query_params}"
end

get "/videoplayback" do |env|
  query_params = env.params.query

  fvip = query_params["fvip"]
  mn = query_params["mn"].split(",")[-1]
  host = "https://r#{fvip}---#{mn}.googlevideo.com"
  url = "/videoplayback?#{query_params.to_s}"

  client = make_client(URI.parse(host))
  response = client.head(url)

  if response.headers["Location"]?
    url = URI.parse(response.headers["Location"])
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    next env.redirect url.full_path
  end

  headers = env.request.headers
  headers.delete("Host")
  headers.delete("Cookie")
  headers.delete("User-Agent")
  headers.delete("Referer")

  client.get(url, headers) do |response|
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

get "/ggpht*" do |env|
end

get "/ggpht/*" do |env|
  host = "https://yt3.ggpht.com"
  client = make_client(URI.parse(host))
  url = env.request.path.lchop("/ggpht")

  headers = env.request.headers
  headers.delete("Host")
  headers.delete("Cookie")
  headers.delete("User-Agent")
  headers.delete("Referer")

  client.get(url, headers) do |response|
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      env.response.headers[key] = value
    end

    if response.status_code == 304
      break
    end

    chunk_size = 4096
    size = 1
    if response.headers.includes_word?("Content-Encoding", "gzip")
      Gzip::Writer.open(env.response) do |deflate|
        until size == 0
          size = IO.copy(response.body_io, deflate)
          env.response.flush
        end
      end
    elsif response.headers.includes_word?("Content-Encoding", "deflate")
      Flate::Writer.open(env.response) do |deflate|
        until size == 0
          size = IO.copy(response.body_io, deflate)
          env.response.flush
        end
      end
    else
      until size == 0
        size = IO.copy(response.body_io, env.response, chunk_size)
        env.response.flush
      end
    end
  end
end

get "/vi/:id/:name" do |env|
  id = env.params.url["id"]
  name = env.params.url["name"]

  host = "https://i.ytimg.com"
  client = make_client(URI.parse(host))

  if name == "maxres.jpg"
    VIDEO_THUMBNAILS.each do |thumb|
      if client.head("/vi/#{id}/#{thumb[:url]}.jpg").status_code == 200
        name = thumb[:url] + ".jpg"
        break
      end
    end
  end
  url = "/vi/#{id}/#{name}"

  headers = env.request.headers
  headers.delete("Host")
  headers.delete("Cookie")
  headers.delete("User-Agent")
  headers.delete("Referer")

  client.get(url, headers) do |response|
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      env.response.headers[key] = value
    end

    if response.status_code == 304
      break
    end

    chunk_size = 4096
    size = 1
    if response.headers.includes_word?("Content-Encoding", "gzip")
      Gzip::Writer.open(env.response) do |deflate|
        until size == 0
          size = IO.copy(response.body_io, deflate)
          env.response.flush
        end
      end
    elsif response.headers.includes_word?("Content-Encoding", "deflate")
      Flate::Writer.open(env.response) do |deflate|
        until size == 0
          size = IO.copy(response.body_io, deflate)
          env.response.flush
        end
      end
    else
      until size == 0
        size = IO.copy(response.body_io, env.response, chunk_size)
        env.response.flush
      end
    end
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
end

static_headers do |response, filepath, filestat|
  response.headers.add("Cache-Control", "max-age=86400")
end

public_folder "assets"

Kemal.config.powered_by_header = false
add_handler FilteredCompressHandler.new
add_handler DenyFrame.new
add_context_storage_type(User)

Kemal.run
