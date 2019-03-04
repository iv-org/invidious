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

require "digest/md5"
require "file_utils"
require "kemal"
require "openssl/hmac"
require "option_parser"
require "pg"
require "sqlite3"
require "xml"
require "yaml"
require "zip"
require "./invidious/helpers/*"
require "./invidious/*"

CONFIG   = Config.from_yaml(File.read("config/config.yml"))
HMAC_KEY = CONFIG.hmac_key || Random::Secure.hex(32)

config = CONFIG
logger = Invidious::LogHandler.new

Kemal.config.extra_options do |parser|
  parser.banner = "Usage: invidious [arguments]"
  parser.on("-t THREADS", "--crawl-threads=THREADS", "Number of threads for crawling YouTube (default: #{config.crawl_threads})") do |number|
    begin
      config.crawl_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-c THREADS", "--channel-threads=THREADS", "Number of threads for refreshing channels (default: #{config.channel_threads})") do |number|
    begin
      config.channel_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-f THREADS", "--feed-threads=THREADS", "Number of threads for refreshing feeds (default: #{config.feed_threads})") do |number|
    begin
      config.feed_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-v THREADS", "--video-threads=THREADS", "Number of threads for refreshing videos (default: #{config.video_threads})") do |number|
    begin
      config.video_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-o OUTPUT", "--output=OUTPUT", "Redirect output (default: STDOUT)") do |output|
    FileUtils.mkdir_p(File.dirname(output))
    logger = Invidious::LogHandler.new(File.open(output, mode: "a"))
  end
end

Kemal::CLI.new ARGV

PG_URL = URI.new(
  scheme: "postgres",
  user: CONFIG.db[:user],
  password: CONFIG.db[:password],
  host: CONFIG.db[:host],
  port: CONFIG.db[:port],
  path: CONFIG.db[:dbname],
)

PG_DB           = DB.open PG_URL
YT_URL          = URI.parse("https://www.youtube.com")
REDDIT_URL      = URI.parse("https://www.reddit.com")
LOGIN_URL       = URI.parse("https://accounts.google.com")
PUBSUB_URL      = URI.parse("https://pubsubhubbub.appspot.com")
TEXTCAPTCHA_URL = URI.parse("http://textcaptcha.com/omarroth@hotmail.com.json")
CURRENT_BRANCH  = `git branch | sed -n '/\* /s///p'`.strip
CURRENT_COMMIT  = `git rev-list HEAD --max-count=1 --abbrev-commit`.strip
CURRENT_VERSION = `git describe --tags --abbrev=0`.strip

LOCALES = {
  "ar"    => load_locale("ar"),
  "de"    => load_locale("de"),
  "en-US" => load_locale("en-US"),
  "eu"    => load_locale("eu"),
  "fr"    => load_locale("fr"),
  "it"    => load_locale("it"),
  "nb_NO" => load_locale("nb_NO"),
  "nl"    => load_locale("nl"),
  "pl"    => load_locale("pl"),
  "ru"    => load_locale("ru"),
}

config.crawl_threads.times do
  spawn do
    crawl_videos(PG_DB, logger)
  end
end

refresh_channels(PG_DB, logger, config.channel_threads, config.full_refresh)

refresh_feeds(PG_DB, logger, config.feed_threads)

subscribe_to_feeds(PG_DB, logger, HMAC_KEY, config)

config.video_threads.times do |i|
  spawn do
    refresh_videos(PG_DB, logger)
  end
end

statistics = {
  "error" => "Statistics are not availabile.",
}
if config.statistics_enabled
  spawn do
    loop do
      statistics = {
        "version"  => "2.0",
        "software" => {
          "name"    => "invidious",
          "version" => "#{CURRENT_VERSION}-#{CURRENT_COMMIT}",
          "branch"  => "#{CURRENT_BRANCH}",
        },
        "openRegistrations" => config.registration_enabled,
        "usage"             => {
          "users" => {
            "total"          => PG_DB.query_one("SELECT count(*) FROM users", as: Int64),
            "activeHalfyear" => PG_DB.query_one("SELECT count(*) FROM users WHERE CURRENT_TIMESTAMP - updated < '6 months'", as: Int64),
            "activeMonth"    => PG_DB.query_one("SELECT count(*) FROM users WHERE CURRENT_TIMESTAMP - updated < '1 month'", as: Int64),
          },
        },
        "metadata" => {
          "updatedAt"              => Time.now.to_unix,
          "lastChannelRefreshedAt" => PG_DB.query_one?("SELECT updated FROM channels ORDER BY updated DESC LIMIT 1", as: Time).try &.to_unix || 0,
        },
      }

      sleep 1.minute
      Fiber.yield
    end
  end
end

top_videos = [] of Video
if config.top_enabled
  spawn do
    pull_top_videos(config, PG_DB) do |videos|
      top_videos = videos
      sleep 1.minutes
      Fiber.yield
    end
  end
end

popular_videos = [] of ChannelVideo
spawn do
  pull_popular_videos(PG_DB) do |videos|
    popular_videos = videos
    sleep 1.minutes
    Fiber.yield
  end
end

decrypt_function = [] of {name: String, value: Int32}
spawn do
  update_decrypt_function do |function|
    decrypt_function = function
    sleep 1.minutes
    Fiber.yield
  end
end

proxies = PROXY_LIST

before_all do |env|
  env.response.headers["X-XSS-Protection"] = "1; mode=block;"
  env.response.headers["X-Content-Type-Options"] = "nosniff"

  if env.request.cookies.has_key? "SID"
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    sid = env.request.cookies["SID"].value

    # Invidious users only have SID
    if !env.request.cookies.has_key? "SSID"
      email = PG_DB.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)

      if email
        user = PG_DB.query_one("SELECT * FROM users WHERE email = $1", email, as: User)
        challenge, token = create_response(user.email, "sign_out", HMAC_KEY, PG_DB, 1.week)

        env.set "challenge", challenge
        env.set "token", token

        locale = user.preferences.locale
        env.set "user", user
        env.set "preferences", user.preferences
        env.set "sid", sid
      end
    else
      begin
        user, sid = get_user(sid, headers, PG_DB, false)

        challenge, token = create_response(user.email, "sign_out", HMAC_KEY, PG_DB, 1.week)
        env.set "challenge", challenge
        env.set "token", token

        locale = user.preferences.locale
        env.set "user", user
        env.set "preferences", user.preferences
        env.set "sid", sid
      rescue ex
      end
    end
  end

  if env.request.cookies.has_key? "PREFS"
    preferences = Preferences.from_json(env.request.cookies["PREFS"].value)

    locale = preferences.locale
    env.set "preferences", preferences
  end

  locale = env.params.query["hl"]? || locale
  locale ||= "en-US"
  env.set "locale", locale

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
  locale = LOCALES[env.get("locale").as(String)]?
  user = env.get? "user"

  if user
    user = user.as(User)
    if user.preferences.redirect_feed
      env.redirect "/feed/subscriptions"
    end
  end

  case config.default_home
  when "Popular"
    templated "popular"
  when "Top"
    templated "top"
  when "Trending"
    env.redirect "/feed/trending"
  when "Subscriptions"
    if user
      env.redirect "/feed/subscriptions"
    else
      templated "popular"
    end
  end
end

get "/licenses" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  rendered "licenses"
end

# Videos

get "/watch" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  region = env.params.query["region"]?

  if env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
    url = "/watch?" + env.params.query.to_s.gsub("%20", "").delete("+")
    next env.redirect url
  end

  if env.params.query["v"]?
    id = env.params.query["v"]

    if env.params.query["v"].empty?
      error_message = "Invalid parameters."
      next templated "error"
    end

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

  plid = env.params.query["list"]?
  nojs = env.params.query["nojs"]?

  nojs ||= "0"
  nojs = nojs == "1"

  if env.get? "preferences"
    preferences = env.get("preferences").as(Preferences)
  end

  if env.get? "user"
    user = env.get("user").as(User)
    subscriptions = user.subscriptions
    watched = user.watched
  end
  subscriptions ||= [] of String

  params = process_video_params(env.params.query, preferences)
  env.params.query.delete_all("listen")

  begin
    video = get_video(id, PG_DB, proxies, region: params[:region])
  rescue ex : VideoRedirect
    next env.redirect "/watch?v=#{ex.message}"
  rescue ex
    error_message = ex.message
    logger.write("#{id} : #{ex.message}\n")
    next templated "error"
  end

  if watched && !watched.includes? id
    PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE email = $2", [id], user.as(User).email)
  end

  if nojs
    if preferences
      source = preferences.comments[0]
      if source.empty?
        source = preferences.comments[1]
      end

      if source == "youtube"
        begin
          comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, region))["contentHtml"]
        rescue ex
          if preferences.comments[1] == "reddit"
            comments, reddit_thread = fetch_reddit_comments(id)
            comment_html = template_reddit_comments(comments, locale)

            comment_html = fill_links(comment_html, "https", "www.reddit.com")
            comment_html = replace_links(comment_html)
          end
        end
      elsif source == "reddit"
        begin
          comments, reddit_thread = fetch_reddit_comments(id)
          comment_html = template_reddit_comments(comments, locale)

          comment_html = fill_links(comment_html, "https", "www.reddit.com")
          comment_html = replace_links(comment_html)
        rescue ex
          if preferences.comments[1] == "youtube"
            comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, region))["contentHtml"]
          end
        end
      end
    else
      comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, region))["contentHtml"]
    end

    comment_html ||= ""
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

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
    hlsvp = video.player_response["streamingData"]["hlsManifestUrl"].as_s
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
  locale = LOCALES[env.get("locale").as(String)]?
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
    video = get_video(id, PG_DB, proxies, region: params[:region])
  rescue ex : VideoRedirect
    next env.redirect "/embed/#{ex.message}"
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

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
    hlsvp = video.player_response["streamingData"]["hlsManifestUrl"].as_s
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
  locale = LOCALES[env.get("locale").as(String)]?

  plid = env.params.query["list"]?
  if !plid
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if plid.starts_with? "RD"
    next env.redirect "/mix?list=#{plid}"
  end

  begin
    playlist = fetch_playlist(plid, locale)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  begin
    videos = fetch_playlist_videos(plid, page, playlist.video_count, locale: locale)
  rescue ex
    videos = [] of PlaylistVideo
  end

  templated "playlist"
end

get "/mix" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  rdid = env.params.query["list"]?
  if !rdid
    next env.redirect "/"
  end

  continuation = env.params.query["continuation"]?
  continuation ||= rdid.lchop("RD")

  begin
    mix = fetch_mix(rdid, continuation, locale: locale)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  templated "mix"
end

# Search

get "/opensearch.xml" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  env.response.content_type = "application/opensearchdescription+xml"

  host = make_host_url(Kemal.config.ssl || config.https_only, config.domain)

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("OpenSearchDescription", xmlns: "http://a9.com/-/spec/opensearch/1.1/") do
      xml.element("ShortName") { xml.text "Invidious" }
      xml.element("LongName") { xml.text "Invidious Search" }
      xml.element("Description") { xml.text "Search for videos, channels, and playlists on Invidious" }
      xml.element("InputEncoding") { xml.text "UTF-8" }
      xml.element("Image", width: 48, height: 48, type: "image/x-icon") { xml.text "#{host}/favicon.ico" }
      xml.element("Url", type: "text/html", method: "get", template: "#{host}/search?q={searchTerms}")
    end
  end
end

get "/results" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

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
  locale = LOCALES[env.get("locale").as(String)]?
  region = env.params.query["region"]?

  query = env.params.query["search_query"]?
  query ||= env.params.query["q"]?
  query ||= ""

  if query.empty?
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  user = env.get? "user"
  if user
    user = user.as(User)
    view_name = "subscriptions_#{sha256(user.email)[0..7]}"
  end

  channel = nil
  content_type = "all"
  date = ""
  duration = ""
  features = [] of String
  sort = "relevance"
  subscriptions = nil

  operators = query.split(" ").select { |a| a.match(/\w+:[\w,]+/) }
  operators.each do |operator|
    key, value = operator.downcase.split(":")

    case key
    when "channel", "user"
      channel = operator.split(":")[-1]
    when "content_type", "type"
      content_type = value
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
    if view_name
      videos = PG_DB.query_all("SELECT id,title,published,updated,ucid,author,length_seconds FROM (
      SELECT *,
      to_tsvector(#{view_name}.title) ||
      to_tsvector(#{view_name}.author)
      as document
      FROM #{view_name}
      ) v_search WHERE v_search.document @@ plainto_tsquery($1) LIMIT 20 OFFSET $2;", search_query, (page - 1) * 20, as: ChannelVideo)
      count = videos.size
    else
      videos = [] of ChannelVideo
      count = 0
    end
  else
    begin
      search_params = produce_search_params(sort: sort, date: date, content_type: content_type,
        duration: duration, features: features)
    rescue ex
      error_message = ex.message
      next templated "error"
    end

    count, videos = search(search_query, page, search_params, proxies, region).as(Tuple)
  end

  templated "search"
end

# Users

get "/login" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  if user
    next env.redirect "/feed/subscriptions"
  end

  if !config.login_enabled
    error_message = "Login has been disabled by administrator."
    next templated "error"
  end

  referer = get_referer(env, "/feed/subscriptions")

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  captcha_type = env.params.query["captcha"]?
  captcha_type ||= "image"

  if account_type == "invidious"
    if captcha_type == "image"
      captcha = generate_captcha(HMAC_KEY, PG_DB)
    else
      response = HTTP::Client.get(TEXTCAPTCHA_URL).body
      response = JSON.parse(response)

      tokens = response["a"].as_a.map do |answer|
        create_response(answer.as_s, "sign_in", HMAC_KEY, PG_DB)
      end

      text_captcha = {
        question: response["q"].as_s,
        tokens:   tokens,
      }
    end
  end

  tfa = env.params.query["tfa"]?
  tfa ||= false

  templated "login"
end

# See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L79
post "/login" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  referer = get_referer(env, "/feed/subscriptions")

  if !config.login_enabled
    error_message = "Login has been disabled by administrator."
    next templated "error"
  end

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

      lookup_req = {
        email, nil, [] of String, nil, "US", nil, nil, 2, false, true,
        {nil, nil,
         {2, 1, nil, 1, "https://accounts.google.com/ServiceLogin?passive=1209600&continue=https%3A%2F%2Faccounts.google.com%2FManageAccount&followup=https%3A%2F%2Faccounts.google.com%2FManageAccount", nil, [] of String, 4, [] of String},
         1,
         {nil, nil, [] of String},
         nil, nil, nil, true,
        }, email,
      }.to_json

      lookup_results = client.post("/_/signin/sl/lookup", headers, login_req(inputs, lookup_req))
      headers = lookup_results.cookies.add_request_headers(headers)

      lookup_results = lookup_results.body
      lookup_results = lookup_results[5..-1]
      lookup_results = JSON.parse(lookup_results)

      user_hash = lookup_results[0][2]

      challenge_req = {
        user_hash, nil, 1, nil,
        {1, nil, nil, nil,
         {password, nil, true},
        },
        {nil, nil,
         {2, 1, nil, 1, "https://accounts.google.com/ServiceLogin?passive=1209600&continue=https%3A%2F%2Faccounts.google.com%2FManageAccount&followup=https%3A%2F%2Faccounts.google.com%2FManageAccount", nil, [] of String, 4, [] of String},
         1,
         {nil, nil, [] of String},
         nil, nil, nil, true},
      }.to_json

      challenge_results = client.post("/_/signin/sl/challenge", headers, login_req(inputs, challenge_req))
      headers = challenge_results.cookies.add_request_headers(headers)

      challenge_results = challenge_results.body
      challenge_results = challenge_results[5..-1]
      challenge_results = JSON.parse(challenge_results)

      headers["Cookie"] = URI.unescape(headers["Cookie"])

      if challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
        error_message = translate(locale, "Incorrect password")
        next templated "error"
      end

      if challenge_results[0][-1][0].as_a?
        # Prefer Authenticator app and SMS over unsupported protocols
        if challenge_results[0][-1][0][0][8] != 6 && challenge_results[0][-1][0][0][8] != 9
          tfa = challenge_results[0][-1][0].as_a.select { |auth_type| auth_type[8] == 6 || auth_type[8] == 9 }[0]
          select_challenge = "[2,null,null,null,[#{tfa[8]}]]"

          tl = challenge_results[1][2]

          tfa = client.post("/_/signin/selectchallenge?TL=#{tl}", headers, login_req(inputs, select_challenge)).body
          tfa = tfa[5..-1]
          tfa = JSON.parse(tfa)[0][-1]
        else
          tfa = challenge_results[0][-1][0][0]
        end

        if tfa[2] == "TWO_STEP_VERIFICATION"
          if tfa[5] == "QUOTA_EXCEEDED"
            error_message = translate(locale, "Quota exceeded, try again in a few hours")
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
            error_message = translate(locale, "Invalid TFA code")
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

      user, sid = get_user(sid, headers, PG_DB)

      # We are now logged in

      host = URI.parse(env.request.headers["Host"]).host

      if Kemal.config.ssl || config.https_only
        secure = true
      else
        secure = false
      end

      login.cookies.each do |cookie|
        if Kemal.config.ssl || config.https_only
          cookie.secure = secure
        else
          cookie.secure = secure
        end

        cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
        cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
      end

      if env.request.cookies["PREFS"]?
        preferences = env.get("preferences").as(Preferences)
        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)

        login.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: "", expires: Time.new(1990, 1, 1),
          secure: secure, http_only: true)
      end

      login.cookies.add_response_headers(env.response.headers)

      env.redirect referer
    rescue ex
      error_message = translate(locale, "Login failed. This may be because two-factor authentication is not enabled on your account.")
      next templated "error"
    end
  elsif account_type == "invidious"
    answer = env.params.body["answer"]?
    text_answer = env.params.body["text_answer"]?

    if config.captcha_enabled
      if answer
        answer = answer.lstrip('0')
        answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)

        challenge = env.params.body["challenge"]?
        token = env.params.body["token"]?

        begin
          validate_response(challenge, token, answer, "sign_in", HMAC_KEY, PG_DB, locale)
        rescue ex
          if ex.message == translate(locale, "Invalid user")
            error_message = translate(locale, "Invalid answer")
          else
            error_message = ex.message
          end

          next templated "error"
        end
      elsif text_answer
        text_answer = Digest::MD5.hexdigest(text_answer.downcase.strip)

        challenges = env.params.body.select { |k, v| k.match(/text_challenge\d+/) }
        tokens = env.params.body.select { |k, v| k.match(/text_token\d+/) }

        found_valid_captcha = false

        error_message = translate(locale, "Invalid CAPTCHA")
        challenges.each_with_index do |challenge, i|
          begin
            challenge = challenge[1]
            token = tokens[i][1]
            validate_response(challenge, token, text_answer, "sign_in", HMAC_KEY, PG_DB, locale)
            found_valid_captcha = true
          rescue ex
            if ex.message == translate(locale, "Invalid user")
              error_message = translate(locale, "Invalid answer")
            else
              error_message = ex.message
            end
          end
        end

        if !found_valid_captcha
          next templated "error"
        end
      else
        error_message = translate(locale, "CAPTCHA is a required field")
        next templated "error"
      end
    end

    action = env.params.body["action"]?
    action ||= "signin"

    if !email
      error_message = translate(locale, "User ID is a required field")
      next templated "error"
    end

    if !password
      error_message = translate(locale, "Password is a required field")
      next templated "error"
    end

    if action == "signin"
      user = PG_DB.query_one?("SELECT * FROM users WHERE LOWER(email) = LOWER($1)", email, as: User)

      if !user
        error_message = translate(locale, "Invalid username or password")
        next templated "error"
      end

      if !user.password
        error_message = translate(locale, "Please sign in using 'Sign in with Google'")
        next templated "error"
      end

      if Crypto::Bcrypt::Password.new(user.password.not_nil!) == password
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.now)

        if Kemal.config.ssl || config.https_only
          secure = true
        else
          secure = false
        end

        if config.domain
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{config.domain}", value: sid, expires: Time.now + 2.years,
            secure: secure, http_only: true)
        else
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.now + 2.years,
            secure: secure, http_only: true)
        end
      else
        error_message = translate(locale, "Invalid username or password")
        next templated "error"
      end

      # Since this user has already registered, we don't want to overwrite their preferences
      if env.request.cookies["PREFS"]?
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: "", expires: Time.new(1990, 1, 1),
          secure: secure, http_only: true)
      end
    elsif action == "register"
      if !config.registration_enabled
        error_message = "Registration has been disabled by administrator."
        next templated "error"
      end

      if password.empty?
        error_message = translate(locale, "Password cannot be empty")
        next templated "error"
      end

      # See https://security.stackexchange.com/a/39851
      if password.size > 55
        error_message = translate(locale, "Password cannot be longer than 55 characters")
        next templated "error"
      end

      user = PG_DB.query_one?("SELECT * FROM users WHERE LOWER(email) = LOWER($1) AND password IS NOT NULL", email, as: User)
      if user
        error_message = translate(locale, "Please sign in")
        next templated "error"
      end

      sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
      user, sid = create_user(sid, email, password)
      user_array = user.to_a

      user_array[4] = user_array[4].to_json
      args = arg_array(user_array)

      PG_DB.exec("INSERT INTO users VALUES (#{args})", user_array)
      PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.now)

      view_name = "subscriptions_#{sha256(user.email)[0..7]}"
      PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
        SELECT * FROM channel_videos WHERE \
        ucid = ANY ((SELECT subscriptions FROM users WHERE email = E'#{user.email.gsub("'", "\\'")}')::text[]) \
      ORDER BY published DESC;")

      if Kemal.config.ssl || config.https_only
        secure = true
      else
        secure = false
      end

      if config.domain
        env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{config.domain}", value: sid, expires: Time.now + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.now + 2.years,
          secure: secure, http_only: true)
      end

      if env.request.cookies["PREFS"]?
        preferences = env.get("preferences").as(Preferences)
        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)

        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: "", expires: Time.new(1990, 1, 1),
          secure: secure, http_only: true)
      end
    end

    env.redirect referer
  end
end

get "/signout" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    challenge = env.params.query["challenge"]?
    token = env.params.query["token"]?

    begin
      validate_response(challenge, token, user.email, "sign_out", HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      next templated "error"
    end

    user = env.get("user").as(User)
    sid = env.get("sid").as(String)
    PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", sid)

    env.request.cookies.each do |cookie|
      cookie.expires = Time.new(1990, 1, 1)
    end

    env.request.cookies.add_response_headers(env.response.headers)
  end

  env.redirect referer
end

get "/preferences" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  referer = get_referer(env)

  if preferences = env.get? "preferences"
    preferences = preferences.as(Preferences)

    templated "preferences"
  else
    preferences = DEFAULT_USER_PREFERENCES

    templated "preferences"
  end
end

post "/preferences" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  referer = get_referer(env)

  video_loop = env.params.body["video_loop"]?.try &.as(String)
  video_loop ||= "off"
  video_loop = video_loop == "on"

  autoplay = env.params.body["autoplay"]?.try &.as(String)
  autoplay ||= "off"
  autoplay = autoplay == "on"

  continue = env.params.body["continue"]?.try &.as(String)
  continue ||= "off"
  continue = continue == "on"

  listen = env.params.body["listen"]?.try &.as(String)
  listen ||= "off"
  listen = listen == "on"

  speed = env.params.body["speed"]?.try &.as(String).to_f?
  speed ||= DEFAULT_USER_PREFERENCES.speed

  quality = env.params.body["quality"]?.try &.as(String)
  quality ||= DEFAULT_USER_PREFERENCES.quality

  volume = env.params.body["volume"]?.try &.as(String).to_i?
  volume ||= DEFAULT_USER_PREFERENCES.volume

  comments = [] of String
  2.times do |i|
    comments << (env.params.body["comments[#{i}]"]?.try &.as(String) || DEFAULT_USER_PREFERENCES.comments[i])
  end

  captions = [] of String
  3.times do |i|
    captions << (env.params.body["captions[#{i}]"]?.try &.as(String) || DEFAULT_USER_PREFERENCES.captions[i])
  end

  related_videos = env.params.body["related_videos"]?.try &.as(String)
  related_videos ||= "off"
  related_videos = related_videos == "on"

  redirect_feed = env.params.body["redirect_feed"]?.try &.as(String)
  redirect_feed ||= "off"
  redirect_feed = redirect_feed == "on"

  locale = env.params.body["locale"]?.try &.as(String)
  locale ||= DEFAULT_USER_PREFERENCES.locale

  dark_mode = env.params.body["dark_mode"]?.try &.as(String)
  dark_mode ||= "off"
  dark_mode = dark_mode == "on"

  thin_mode = env.params.body["thin_mode"]?.try &.as(String)
  thin_mode ||= "off"
  thin_mode = thin_mode == "on"

  max_results = env.params.body["max_results"]?.try &.as(String).to_i?
  max_results ||= DEFAULT_USER_PREFERENCES.max_results

  sort = env.params.body["sort"]?.try &.as(String)
  sort ||= DEFAULT_USER_PREFERENCES.sort

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
    "continue"           => continue,
    "listen"             => listen,
    "speed"              => speed,
    "quality"            => quality,
    "volume"             => volume,
    "comments"           => comments,
    "captions"           => captions,
    "related_videos"     => related_videos,
    "redirect_feed"      => redirect_feed,
    "locale"             => locale,
    "dark_mode"          => dark_mode,
    "thin_mode"          => thin_mode,
    "max_results"        => max_results,
    "sort"               => sort,
    "latest_only"        => latest_only,
    "unseen_only"        => unseen_only,
    "notifications_only" => notifications_only,
  }.to_json

  if user = env.get? "user"
    user = user.as(User)
    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)

    if config.admins.includes? user.email
      config.default_home = env.params.body["default_home"]?.try &.as(String) || config.default_home

      feed_menu = [] of String
      4.times do |index|
        option = env.params.body["feed_menu[#{index}]"]?.try &.as(String) || ""
        if !option.empty?
          feed_menu << option
        end
      end
      config.feed_menu = feed_menu

      top_enabled = env.params.body["top_enabled"]?.try &.as(String)
      top_enabled ||= "off"
      config.top_enabled = top_enabled == "on"

      captcha_enabled = env.params.body["captcha_enabled"]?.try &.as(String)
      captcha_enabled ||= "off"
      config.captcha_enabled = captcha_enabled == "on"

      login_enabled = env.params.body["login_enabled"]?.try &.as(String)
      login_enabled ||= "off"
      config.login_enabled = login_enabled == "on"

      registration_enabled = env.params.body["registration_enabled"]?.try &.as(String)
      registration_enabled ||= "off"
      config.registration_enabled = registration_enabled == "on"

      statistics_enabled = env.params.body["statistics_enabled"]?.try &.as(String)
      statistics_enabled ||= "off"
      config.statistics_enabled = statistics_enabled == "on"

      File.write("config/config.yml", config.to_yaml)
    end
  else
    env.response.cookies["PREFS"] = preferences
  end

  env.redirect referer
end

get "/toggle_theme" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  referer = get_referer(env)

  if user = env.get? "user"
    user = user.as(User)
    preferences = user.preferences
    preferences.dark_mode = !preferences.dark_mode

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)
  elsif preferences = env.get? "preferences"
    preferences = preferences.as(Preferences)
    preferences.dark_mode = !preferences.dark_mode

    env.response.cookies["PREFS"] = preferences.to_json
  else
    preferences = DEFAULT_USER_PREFERENCES
    preferences.dark_mode = true

    env.response.cookies["PREFS"] = preferences.to_json
  end

  env.redirect referer
end

get "/mark_watched" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env, "/feed/subscriptions")

  id = env.params.query["id"]?
  if !id
    halt env, status_code: 400
  end

  redirect = env.params.query["redirect"]?
  redirect ||= "false"
  redirect = redirect == "true"

  if user
    user = user.as(User)
    if !user.watched.includes? id
      PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE email = $2", [id], user.email)
    end
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

get "/mark_unwatched" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env, "/feed/history")

  id = env.params.query["id"]?
  if !id
    halt env, status_code: 400
  end

  redirect = env.params.query["redirect"]?
  redirect ||= "false"
  redirect = redirect == "true"

  if user
    user = user.as(User)
    PG_DB.exec("UPDATE users SET watched = array_remove(watched, $1) WHERE email = $2", id, user.email)
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

# /modify_notifications
# will "ding" all subscriptions.
# /modify_notifications?receive_all_updates=false&receive_no_updates=false
# will "unding" all subscriptions.
get "/modify_notifications" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

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
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/")

  if !user && !sid
    next env.redirect referer
  end

  user = user.as(User)

  if !user.password
    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    user, sid = get_user(sid, headers, PG_DB)
  end

  action_takeout = env.params.query["action_takeout"]?.try &.to_i?
  action_takeout ||= 0
  action_takeout = action_takeout == 1

  format = env.params.query["format"]?
  format ||= "rss"

  subscriptions = PG_DB.query_all("SELECT * FROM channels WHERE id = ANY('{#{user.subscriptions.join(",")}}')", as: InvidiousChannel)
  subscriptions.sort_by! { |channel| channel.author.downcase }

  if action_takeout
    host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)

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
  locale = LOCALES[env.get("locale").as(String)]?

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
  locale = LOCALES[env.get("locale").as(String)]?

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

        if body["subscriptions"]?
          user.subscriptions += body["subscriptions"].as_a.map { |a| a.as_s }
          user.subscriptions.uniq!

          user.subscriptions.select! do |ucid|
            begin
              get_channel(ucid, PG_DB, false, false)
              true
            rescue ex
              false
            end
          end

          PG_DB.exec("UPDATE users SET subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
        end

        if body["watch_history"]?
          user.watched += body["watch_history"].as_a.map { |a| a.as_s }
          user.watched.uniq!
          PG_DB.exec("UPDATE users SET watched = $1 WHERE email = $2", user.watched, user.email)
        end

        if body["preferences"]?
          user.preferences = Preferences.from_json(body["preferences"].to_json)
          PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", user.preferences.to_json, user.email)
        end
      when "import_youtube"
        subscriptions = XML.parse(body)
        user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
          channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_freetube"
        user.subscriptions += body.scan(/"channelId":"(?<channel_id>[a-zA-Z0-9_-]{24})"/).map do |md|
          md["channel_id"]
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_newpipe_subscriptions"
        body = JSON.parse(body)
        user.subscriptions += body["subscriptions"].as_a.map do |channel|
          channel["url"].as_s.match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_newpipe"
        Zip::Reader.open(IO::Memory.new(body)) do |file|
          file.each_entry do |entry|
            if entry.filename == "newpipe.db"
              tempfile = File.tempfile(".db")
              File.write(tempfile.path, entry.io.gets_to_end)
              db = DB.open("sqlite3://" + tempfile.path)

              user.watched += db.query_all("SELECT url FROM streams", as: String).map { |url| url.lchop("https://www.youtube.com/watch?v=") }
              user.watched.uniq!

              PG_DB.exec("UPDATE users SET watched = $1 WHERE email = $2", user.watched, user.email)

              user.subscriptions += db.query_all("SELECT url FROM subscriptions", as: String).map { |url| url.lchop("https://www.youtube.com/channel/") }
              user.subscriptions.uniq!

              user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

              PG_DB.exec("UPDATE users SET subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)

              db.close
              tempfile.delete
            end
          end
        end
      end
    end
  end

  env.redirect referer
end

get "/subscription_ajax" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  redirect = env.params.query["redirect"]?
  redirect ||= "false"
  redirect = redirect == "true"

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
        email = user.email

        case action
        when .starts_with? "action_create"
          PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", channel_id, email)
        when .starts_with? "action_remove"
          PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE email = $2", channel_id, email)
        end
      end
    else
      email = user.email

      case action
      when .starts_with? "action_create"
        if !user.subscriptions.includes? channel_id
          PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", channel_id, email)

          get_channel(channel_id, PG_DB, false, false)
        end
      when .starts_with? "action_remove"
        PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE email = $2", channel_id, email)
      end
    end
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

get "/delete_account" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    challenge, token = create_response(user.email, "delete_account", HMAC_KEY, PG_DB)

    templated "delete_account"
  else
    env.redirect referer
  end
end

post "/delete_account" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    challenge = env.params.body["challenge"]?
    token = env.params.body["token"]?

    begin
      validate_response(challenge, token, user.email, "delete_account", HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      next templated "error"
    end

    view_name = "subscriptions_#{sha256(user.email)[0..7]}"
    PG_DB.exec("DROP MATERIALIZED VIEW #{view_name}")
    PG_DB.exec("DELETE FROM users * WHERE email = $1", user.email)
    PG_DB.exec("DELETE FROM session_ids * WHERE email = $1", user.email)

    env.request.cookies.each do |cookie|
      cookie.expires = Time.new(1990, 1, 1)
    end
    env.request.cookies.add_response_headers(env.response.headers)
  end

  env.redirect referer
end

get "/clear_watch_history" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    challenge, token = create_response(user.email, "clear_watch_history", HMAC_KEY, PG_DB)

    templated "clear_watch_history"
  else
    env.redirect referer
  end
end

post "/clear_watch_history" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    challenge = env.params.body["challenge"]?
    token = env.params.body["token"]?

    begin
      validate_response(challenge, token, user.email, "clear_watch_history", HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      next templated "error"
    end

    PG_DB.exec("UPDATE users SET watched = '{}' WHERE email = $1", user.email)
  end

  env.redirect referer
end

# Feeds

get "/feed/top" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  if config.top_enabled
    templated "top"
  else
    env.redirect "/"
  end
end

get "/feed/popular" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  templated "popular"
end

get "/feed/trending" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  trending_type = env.params.query["type"]?
  trending_type ||= "Default"

  region = env.params.query["region"]?
  region ||= "US"

  begin
    trending = fetch_trending(trending_type, proxies, region, locale)
  rescue ex
    error_message = "#{ex.message}"
    next templated "error"
  end

  templated "trending"
end

get "/feed/subscriptions" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    preferences = user.preferences

    if preferences.unseen_only
      env.set "show_watched", true
    end

    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    if !user.password
      user, sid = get_user(sid, headers, PG_DB)
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

    if preferences.sort == "published - reverse"
      sort = ""
    else
      sort = "DESC"
    end

    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
      as: Array(String))
    view_name = "subscriptions_#{sha256(user.email)[0..7]}"

    if preferences.notifications_only && !notifications.empty?
      # Only show notifications

      args = arg_array(notifications)

      notifications = PG_DB.query_all("SELECT * FROM channel_videos WHERE id IN (#{args})
      ORDER BY published #{sort}", notifications, as: ChannelVideo)
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
          # Show latest video from a channel that a user hasn't watched
          # "unseen_only" isn't really correct here, more accurate would be "unwatched_only"

          if user.watched.empty?
            values = "'{}'"
          else
            values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
          end
          videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} WHERE \
          NOT id = ANY (#{values}) \
          ORDER BY ucid, published #{sort}", as: ChannelVideo)
        else
          # Show latest video from each channel

          videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} \
          ORDER BY ucid, published", as: ChannelVideo)
        end

        videos.sort_by! { |video| video.published }.reverse!
      else
        if preferences.unseen_only
          # Only show unwatched

          if user.watched.empty?
            values = "'{}'"
          else
            values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
          end
          videos = PG_DB.query_all("SELECT * FROM #{view_name} WHERE \
          NOT id = ANY (#{values}) \
          ORDER BY published #{sort} LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
        else
          # Sort subscriptions as normal

          videos = PG_DB.query_all("SELECT * FROM #{view_name} \
          ORDER BY published #{sort} LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
        end
      end

      case preferences.sort
      when "published - reverse"
        videos.sort_by! { |video| video.published }
      when "alphabetically"
        videos.sort_by! { |video| video.title }
      when "alphabetically - reverse"
        videos.sort_by! { |video| video.title }.reverse!
      when "channel name"
        videos.sort_by! { |video| video.author }
      when "channel name - reverse"
        videos.sort_by! { |video| video.author }.reverse!
      end

      notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
        as: Array(String))

      notifications = videos.select { |v| notifications.includes? v.id }
      videos = videos - notifications
    end

    if !limit
      videos = videos[0..max_results]
    end

    # Clear user's notifications and set updated to the current time.

    # "updated" here is used for delivering new notifications, so if
    # we know a user has looked at their feed e.g. in the past 10 minutes,
    # they've already seen a video posted 20 minutes ago, and don't need
    # to be notified.
    PG_DB.exec("UPDATE users SET notifications = $1, updated = $2 WHERE email = $3", [] of String, Time.now,
      user.email)
    user.notifications = [] of String
    env.set "user", user

    templated "subscriptions"
  else
    env.redirect referer
  end
end

get "/feed/history" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  referer = get_referer(env)

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if user
    user = user.as(User)

    limit = user.preferences.max_results
    if user.watched[(page - 1) * limit]?
      watched = user.watched.reverse[(page - 1) * limit, limit]
    else
      watched = [] of String
    end

    templated "history"
  else
    env.redirect referer
  end
end

get "/feed/channel/:ucid" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "text/xml"
  ucid = env.params.url["ucid"]

  begin
    author, ucid, auto_generated = get_about_info(ucid, locale)
  rescue ex
    error_message = ex.message
    halt env, status_code: 500, response: error_message
  end

  client = make_client(YT_URL)
  rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  videos = [] of SearchVideo

  rss.xpath_nodes("//feed/entry").each do |entry|
    video_id = entry.xpath_node("videoid").not_nil!.content
    title = entry.xpath_node("title").not_nil!.content

    published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z", Time::Location.local)
    updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z", Time::Location.local)

    author = entry.xpath_node("author/name").not_nil!.content
    ucid = entry.xpath_node("channelid").not_nil!.content
    description = entry.xpath_node("group/description").not_nil!.content
    views = entry.xpath_node("group/community/statistics").not_nil!.["views"].to_i64

    videos << SearchVideo.new(
      title: title,
      id: video_id,
      author: author,
      ucid: ucid,
      published: published,
      views: views,
      description: description,
      description_html: "",
      length_seconds: 0,
      live_now: false,
      paid: false,
      premium: false
    )
  end

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)
  path = env.request.path

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
      "xml:lang": "en-US") do
      xml.element("link", rel: "self", href: "#{host_url}#{path}")
      xml.element("id") { xml.text "yt:channel:#{ucid}" }
      xml.element("yt:channelId") { xml.text ucid }
      xml.element("title") { xml.text author }
      xml.element("link", rel: "alternate", href: "#{host_url}/channel/#{ucid}")

      xml.element("author") do
        xml.element("name") { xml.text author }
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

          xml.element("content", type: "xhtml") do
            xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
              xml.element("a", href: "#{host_url}/watch?v=#{video.id}") do
                xml.element("img", src: "#{host_url}/vi/#{video.id}/mqdefault.jpg")
              end
            end
          end

          xml.element("published") { xml.text video.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text video.title }
            xml.element("media:thumbnail", url: "#{host_url}/vi/#{video.id}/mqdefault.jpg",
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

  feed
end

get "/feed/private" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

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

  sort = env.params.query["sort"]?
  sort ||= "published"

  if sort == "published - reverse"
    desc = ""
  else
    desc = "DESC"
  end

  view_name = "subscriptions_#{sha256(user.email)[0..7]}"

  if latest_only
    videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} \
    ORDER BY ucid, published", as: ChannelVideo)

    videos.sort_by! { |video| video.published }.reverse!
  else
    videos = PG_DB.query_all("SELECT * FROM #{view_name} \
    ORDER BY published #{desc} LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
  end

  case sort
  when "reverse_published"
    videos.sort_by! { |video| video.published }
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

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)
  path = env.request.path
  query = env.request.query.not_nil!

  feed = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
      "xml:lang": "en-US") do
      xml.element("link", "type": "text/html", rel: "alternate", href: "#{host_url}/feed/subscriptions")
      xml.element("link", "type": "application/atom+xml", rel: "self", href: "#{host_url}#{path}?#{query}")
      xml.element("title") { xml.text translate(locale, "Invidious Private Feed for `x`", user.email) }

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

          xml.element("content", type: "xhtml") do
            xml.element("div", xmlns: "http://www.w3.org/1999/xhtml") do
              xml.element("a", href: "#{host_url}/watch?v=#{video.id}") do
                xml.element("img", src: "#{host_url}/vi/#{video.id}/mqdefault.jpg")
              end
            end
          end

          xml.element("published") { xml.text video.published.to_s("%Y-%m-%dT%H:%M:%S%:z") }
          xml.element("updated") { xml.text video.updated.to_s("%Y-%m-%dT%H:%M:%S%:z") }

          xml.element("media:group") do
            xml.element("media:title") { xml.text video.title }
            xml.element("media:thumbnail", url: "#{host_url}/vi/#{video.id}/mqdefault.jpg",
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
  locale = LOCALES[env.get("locale").as(String)]?

  plid = env.params.url["plid"]

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)
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

# Support push notifications via PubSubHubbub

get "/feed/webhook/:token" do |env|
  verify_token = env.params.url["token"]

  mode = env.params.query["hub.mode"]
  topic = env.params.query["hub.topic"]
  challenge = env.params.query["hub.challenge"]
  lease_seconds = env.params.query["hub.lease_seconds"]

  if verify_token.starts_with? "v1"
    _, time, nonce, signature = verify_token.split(":")
    data = "#{time}:#{nonce}"
  else
    time, signature = verify_token.split(":")
    data = "#{time}"
  end

  if Time.now.to_unix - time.to_i > 600
    halt env, status_code: 400
  end

  if OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, data) != signature
    halt env, status_code: 400
  end

  ucid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["channel_id"]
  PG_DB.exec("UPDATE channels SET subscribed = $1 WHERE id = $2", Time.now, ucid)

  halt env, status_code: 200, response: challenge
end

post "/feed/webhook/:token" do |env|
  token = env.params.url["token"]
  body = env.request.body.not_nil!.gets_to_end
  signature = env.request.headers["X-Hub-Signature"].lchop("sha1=")

  if signature != OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, body)
    logger.write("#{token} : Invalid signature")
    halt env, status_code: 200
  end

  spawn do
    rss = XML.parse_html(body)
    rss.xpath_nodes("//feed/entry").each do |entry|
      id = entry.xpath_node("videoid").not_nil!.content
      published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z", Time::Location.local)
      updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z", Time::Location.local)

      video = get_video(id, PG_DB, proxies, region: nil)
      video = ChannelVideo.new(id, video.title, published, updated, video.ucid, video.author, video.length_seconds)

      PG_DB.exec("UPDATE users SET notifications = notifications || $1 \
      WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, video.ucid)

      video_array = video.to_a
      args = arg_array(video_array)

      PG_DB.exec("INSERT INTO channel_videos VALUES (#{args}) \
      ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
      updated = $4, ucid = $5, author = $6, length_seconds = $7", video_array)
    end
  end

  halt env, status_code: 200
end

# Channels

# YouTube appears to let users set a "brand" URL that
# is different from their username, so we convert that here
get "/c/:user" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

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

# Legacy endpoint for /user/:username
get "/profile" do |env|
  user = env.params.query["user"]?
  if !user
    env.redirect "/"
  else
    env.redirect "/user/#{user}"
  end
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
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  if user
    user = user.as(User)
    subscriptions = user.subscriptions
  end
  subscriptions ||= [] of String

  ucid = env.params.url["ucid"]

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  continuation = env.params.query["continuation"]?

  sort_by = env.params.query["sort_by"]?.try &.downcase

  begin
    author, ucid, auto_generated, sub_count = get_about_info(ucid, locale)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  if !auto_generated
    if author.includes?(" ") || author.includes?("-")
      env.set "search", "channel:#{ucid} "
    else
      env.set "search", "channel:#{author.downcase} "
    end
  end

  if auto_generated
    sort_options = {"last", "oldest", "newest"}
    sort_by ||= "last"

    items, continuation = fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)
    items.select! { |item| item.is_a?(SearchPlaylist) && !item.videos.empty? }
    items = items.map { |item| item.as(SearchPlaylist) }
    items.each { |item| item.author = "" }
  else
    sort_options = {"newest", "oldest", "popular"}
    sort_by ||= "newest"

    items, count = get_60_videos(ucid, page, auto_generated, sort_by)
    items.select! { |item| !item.paid }
  end

  templated "channel"
end

get "/channel/:ucid/videos" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  ucid = env.params.url["ucid"]
  params = env.request.query

  if !params || params.empty?
    params = ""
  else
    params = "?#{params}"
  end

  env.redirect "/channel/#{ucid}#{params}"
end

get "/channel/:ucid/playlists" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  user = env.get? "user"
  if user
    user = user.as(User)
    subscriptions = user.subscriptions
  end
  subscriptions ||= [] of String

  ucid = env.params.url["ucid"]

  continuation = env.params.query["continuation"]?

  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "last"

  begin
    author, ucid, auto_generated, sub_count = get_about_info(ucid, locale)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  if auto_generated
    next env.redirect "/channel/#{ucid}"
  end

  items, continuation = fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)
  items.select! { |item| item.is_a?(SearchPlaylist) && !item.videos.empty? }
  items = items.map { |item| item.as(SearchPlaylist) }
  items.each { |item| item.author = "" }

  templated "playlists"
end

# API Endpoints

get "/api/v1/stats" do |env|
  env.response.content_type = "application/json"

  if !config.statistics_enabled
    error_message = {"error" => "Statistics are not enabled."}.to_json
    halt env, status_code: 400, response: error_message
  end

  if statistics["error"]?
    halt env, status_code: 500, response: statistics.to_json
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    statistics.to_pretty_json
  else
    statistics.to_json
  end
end

get "/api/v1/captions/:id" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    next env.redirect "/api/v1/captions/#{ex.message}"
  rescue ex
    halt env, status_code: 500
  end

  captions = video.captions

  label = env.params.query["label"]?
  lang = env.params.query["lang"]?
  tlang = env.params.query["tlang"]?

  if !label && !lang
    response = JSON.build do |json|
      json.object do
        json.field "captions" do
          json.array do
            captions.each do |caption|
              json.object do
                json.field "label", caption.name.simpleText
                json.field "languageCode", caption.languageCode
                json.field "url", "/api/v1/captions/#{id}?label=#{URI.escape(caption.name.simpleText)}"
              end
            end
          end
        end
      end
    end

    if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
      next JSON.parse(response).to_pretty_json
    else
      next response
    end
  end

  env.response.content_type = "text/vtt"

  caption = captions.select { |caption| caption.name.simpleText == label }

  if lang
    caption = captions.select { |caption| caption.languageCode == lang }
  end

  if caption.empty?
    halt env, status_code: 404
  else
    caption = caption[0]
  end

  caption_xml = client.get(caption.baseUrl + "&tlang=#{tlang}").body
  caption_xml = XML.parse(caption_xml)

  webvtt = <<-END_VTT
  WEBVTT
  Kind: captions
  Language: #{tlang || caption.languageCode}


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
  locale = LOCALES[env.get("locale").as(String)]?
  region = env.params.query["region"]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]

  source = env.params.query["source"]?
  source ||= "youtube"

  format = env.params.query["format"]?
  format ||= "json"

  continuation = env.params.query["continuation"]?

  if source == "youtube"
    begin
      comments = fetch_youtube_comments(id, PG_DB, continuation, proxies, format, locale, region)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      halt env, status_code: 500, response: error_message
    end

    next comments
  elsif source == "reddit"
    begin
      comments, reddit_thread = fetch_reddit_comments(id)
      content_html = template_reddit_comments(comments, locale)

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

    if format == "json"
      reddit_thread = JSON.parse(reddit_thread.to_json).as_h
      reddit_thread["comments"] = JSON.parse(comments.to_json)

      if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
        next reddit_thread.to_pretty_json
      else
        next reddit_thread.to_json
      end
    else
      response = {
        "title"       => reddit_thread.title,
        "permalink"   => reddit_thread.permalink,
        "contentHtml" => content_html,
      }

      if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
        next response.to_pretty_json
      else
        next response.to_json
      end
    end
  end
end

get "/api/v1/insights/:id" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  id = env.params.url["id"]
  env.response.content_type = "application/json"

  error_message = {"error" => "YouTube has removed publicly-available analytics."}.to_json
  halt env, status_code: 410, response: error_message

  client = make_client(YT_URL)
  headers = HTTP::Headers.new
  html = client.get("/watch?v=#{id}&gl=US&hl=en&disable_polymer=1")

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

  response = {
    "viewCount"              => view_count,
    "timeWatchedText"        => time_watched,
    "subscriptionsDriven"    => subscriptions_driven,
    "shares"                 => shares,
    "avgViewDurationSeconds" => avg_view_duration_seconds,
    "graphData"              => graph_data,
  }

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    next response.to_pretty_json
  else
    next response.to_json
  end
end

get "/api/v1/videos/:id" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    next env.redirect "/api/v1/videos/#{ex.message}"
  rescue ex
    error_message = {"error" => ex.message}.to_json
    halt env, status_code: 500, response: error_message
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  captions = video.captions

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
      json.field "published", video.published.to_unix
      json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
      json.field "keywords", video.keywords

      json.field "viewCount", video.views
      json.field "likeCount", video.likes
      json.field "dislikeCount", video.dislikes

      json.field "paid", video.paid
      json.field "premium", video.premium
      json.field "isFamilyFriendly", video.is_family_friendly
      json.field "allowedRegions", video.allowed_regions
      json.field "genre", video.genre
      json.field "genreUrl", video.genre_url

      json.field "author", video.author
      json.field "authorId", video.ucid
      json.field "authorUrl", "/channel/#{video.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = [32, 48, 76, 100, 176, 512]

          qualities.each do |quality|
            json.object do
              json.field "url", video.author_thumbnail.gsub("=s48-", "=s#{quality}-")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCountText", video.sub_count_text

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

      if video.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
        host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)

        host_params = env.request.query_params
        host_params.delete_all("v")

        hlsvp = video.player_response["streamingData"]["hlsManifestUrl"].as_s
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
              json.field "url", "/api/v1/captions/#{id}?label=#{URI.escape(caption.name.simpleText)}"
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

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(video_info).to_pretty_json
  else
    video_info
  end
end

get "/api/v1/trending" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  region = env.params.query["region"]?
  trending_type = env.params.query["type"]?

  begin
    trending = fetch_trending(trending_type, proxies, region, locale)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    halt env, status_code: 500, response: error_message
  end

  videos = JSON.build do |json|
    json.array do
      trending.each do |video|
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

          json.field "published", video.published.to_unix
          json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
          json.field "description", video.description
          json.field "descriptionHtml", video.description_html
          json.field "liveNow", video.live_now
          json.field "paid", video.paid
          json.field "premium", video.premium
        end
      end
    end
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(videos).to_pretty_json
  else
    videos
  end
end

get "/api/v1/popular" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  videos = JSON.build do |json|
    json.array do
      popular_videos.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id
          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id)
          end

          json.field "lengthSeconds", video.length_seconds

          json.field "author", video.author
          json.field "authorId", video.ucid
          json.field "authorUrl", "/channel/#{video.ucid}"
          json.field "published", video.published.to_unix
          json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
        end
      end
    end
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(videos).to_pretty_json
  else
    videos
  end
end

get "/api/v1/top" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  if !config.top_enabled
    error_message = {"error" => "Administrator has disabled this endpoint."}.to_json
    halt env, status_code: 400, response: error_message
  end

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
          json.field "published", video.published.to_unix
          json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))

          description = video.description.gsub("<br>", "\n")
          description = description.gsub("<br/>", "\n")
          description = XML.parse_html(description)
          json.field "description", description.content
          json.field "descriptionHtml", video.description
        end
      end
    end
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(videos).to_pretty_json
  else
    videos
  end
end

get "/api/v1/channels/:ucid" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  ucid = env.params.url["ucid"]
  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "newest"

  begin
    author, ucid, auto_generated = get_about_info(ucid, locale)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    halt env, status_code: 500, response: error_message
  end

  page = 1
  if auto_generated
    videos = [] of SearchVideo
    count = 0
  else
    begin
      videos, count = get_60_videos(ucid, page, auto_generated, sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      halt env, status_code: 500, response: error_message
    end
  end

  client = make_client(YT_URL)
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

  related_channels = channel_html.xpath_nodes(%q(//div[contains(@class, "branded-page-related-channels")]/ul/li))
  related_channels = related_channels.map do |node|
    related_id = node["data-external-id"]?
    related_id ||= ""

    anchor = node.xpath_node(%q(.//h3[contains(@class, "yt-lockup-title")]/a))
    related_title = anchor.try &.["title"]
    related_title ||= ""

    related_author_url = anchor.try &.["href"]
    related_author_url ||= ""

    related_author_thumbnail = node.xpath_node(%q(.//img)).try &.["data-thumb"]
    related_author_thumbnail ||= ""

    {
      id:               related_id,
      author:           related_title,
      author_url:       related_author_url,
      author_thumbnail: related_author_thumbnail,
    }
  end

  total_views = 0_i64
  sub_count = 0_i64
  joined = Time.unix(0)
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
          qualities = [32, 48, 76, 100, 176, 512]

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
      json.field "joined", joined.to_unix
      json.field "paid", paid

      json.field "autoGenerated", auto_generated
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
              json.field "published", video.published.to_unix
              json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
              json.field "lengthSeconds", video.length_seconds
              json.field "liveNow", video.live_now
              json.field "paid", video.paid
              json.field "premium", video.premium
            end
          end
        end
      end

      json.field "relatedChannels" do
        json.array do
          related_channels.each do |related_channel|
            json.object do
              json.field "author", related_channel[:author]
              json.field "authorId", related_channel[:id]
              json.field "authorUrl", related_channel[:author_url]

              json.field "authorThumbnails" do
                json.array do
                  qualities = [32, 48, 76, 100, 176, 512]

                  qualities.each do |quality|
                    json.object do
                      json.field "url", related_channel[:author_thumbnail].gsub("=s48-", "=s#{quality}-")
                      json.field "width", quality
                      json.field "height", quality
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

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(channel_info).to_pretty_json
  else
    channel_info
  end
end

["/api/v1/channels/:ucid/videos", "/api/v1/channels/videos/:ucid"].each do |route|
  get route do |env|
    locale = LOCALES[env.get("locale").as(String)]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    page = env.params.query["page"]?.try &.to_i?
    page ||= 1
    sort_by = env.params.query["sort"]?.try &.downcase
    sort_by ||= env.params.query["sort_by"]?.try &.downcase
    sort_by ||= "newest"

    begin
      author, ucid, auto_generated = get_about_info(ucid, locale)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      halt env, status_code: 500, response: error_message
    end

    begin
      videos, count = get_60_videos(ucid, page, auto_generated, sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      halt env, status_code: 500, response: error_message
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
            json.field "published", video.published.to_unix
            json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
            json.field "lengthSeconds", video.length_seconds
            json.field "liveNow", video.live_now
            json.field "paid", video.paid
            json.field "premium", video.premium
          end
        end
      end
    end

    if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
      JSON.parse(result).to_pretty_json
    else
      result
    end
  end
end

["/api/v1/channels/:ucid/latest", "/api/v1/channels/latest/:ucid"].each do |route|
  get route do |env|
    locale = LOCALES[env.get("locale").as(String)]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]

    begin
      videos = get_latest_videos(ucid)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      halt env, status_code: 500, response: error_message
    end

    response = JSON.build do |json|
      json.array do
        videos.each do |video|
          json.object do
            json.field "title", video.title
            json.field "videoId", video.id

            json.field "authorId", ucid
            json.field "authorUrl", "/channel/#{ucid}"

            json.field "videoThumbnails" do
              generate_thumbnails(json, video.id)
            end

            json.field "description", video.description
            json.field "descriptionHtml", video.description_html

            json.field "viewCount", video.views
            json.field "published", video.published.to_unix
            json.field "publishedText", translate(locale, "`x` ago", recode_date(video.published, locale))
            json.field "lengthSeconds", video.length_seconds
            json.field "liveNow", video.live_now
            json.field "paid", video.paid
            json.field "premium", video.premium
          end
        end
      end
    end

    if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
      JSON.parse(response).to_pretty_json
    else
      response
    end
  end
end

["/api/v1/channels/:ucid/playlists", "/api/v1/channels/playlists/:ucid"].each do |route|
  get route do |env|
    locale = LOCALES[env.get("locale").as(String)]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?
    sort_by = env.params.query["sort"]?.try &.downcase
    sort_by ||= env.params.query["sort_by"]?.try &.downcase
    sort_by ||= "last"

    begin
      author, ucid, auto_generated = get_about_info(ucid, locale)
    rescue ex
      error_message = ex.message
      halt env, status_code: 500, response: error_message
    end

    items, continuation = fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)

    response = JSON.build do |json|
      json.object do
        json.field "playlists" do
          json.array do
            items.each do |item|
              json.object do
                if item.is_a?(SearchPlaylist)
                  json.field "title", item.title
                  json.field "playlistId", item.id

                  json.field "author", item.author
                  json.field "authorId", item.ucid
                  json.field "authorUrl", "/channel/#{item.ucid}"

                  json.field "videoCount", item.video_count
                  json.field "videos" do
                    json.array do
                      item.videos.each do |video|
                        json.object do
                          json.field "title", video.title
                          json.field "videoId", video.id
                          json.field "lengthSeconds", video.length_seconds

                          json.field "videoThumbnails" do
                            generate_thumbnails(json, video.id)
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

        json.field "continuation", continuation
      end
    end

    if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
      JSON.parse(response).to_pretty_json
    else
      response
    end
  end
end

get "/api/v1/channels/search/:ucid" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  ucid = env.params.url["ucid"]

  query = env.params.query["q"]?
  query ||= ""

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  count, search_results = channel_search(query, page, ucid)
  response = JSON.build do |json|
    json.array do
      search_results.each do |item|
        json.object do
          case item
          when SearchVideo
            json.field "type", "video"
            json.field "title", item.title
            json.field "videoId", item.id

            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "videoThumbnails" do
              generate_thumbnails(json, item.id)
            end

            json.field "description", item.description
            json.field "descriptionHtml", item.description_html

            json.field "viewCount", item.views
            json.field "published", item.published.to_unix
            json.field "publishedText", translate(locale, "`x` ago", recode_date(item.published, locale))
            json.field "lengthSeconds", item.length_seconds
            json.field "liveNow", item.live_now
            json.field "paid", item.paid
            json.field "premium", item.premium
          when SearchPlaylist
            json.field "type", "playlist"
            json.field "title", item.title
            json.field "playlistId", item.id

            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "videoCount", item.video_count
            json.field "videos" do
              json.array do
                item.videos.each do |video|
                  json.object do
                    json.field "title", video.title
                    json.field "videoId", video.id
                    json.field "lengthSeconds", video.length_seconds

                    json.field "videoThumbnails" do
                      generate_thumbnails(json, video.id)
                    end
                  end
                end
              end
            end
          when SearchChannel
            json.field "type", "channel"
            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "authorThumbnails" do
              json.array do
                qualities = [32, 48, 76, 100, 176, 512]

                qualities.each do |quality|
                  json.object do
                    json.field "url", item.author_thumbnail.gsub("=s176-", "=s#{quality}-")
                    json.field "width", quality
                    json.field "height", quality
                  end
                end
              end
            end

            json.field "subCount", item.subscriber_count
            json.field "videoCount", item.video_count
            json.field "description", item.description
            json.field "descriptionHtml", item.description_html
          end
        end
      end
    end
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(response).to_pretty_json
  else
    response
  end
end

get "/api/v1/search" do |env|
  locale = LOCALES[env.get("locale").as(String)]?
  region = env.params.query["region"]?

  env.response.content_type = "application/json"

  query = env.params.query["q"]?
  query ||= ""

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "relevance"

  date = env.params.query["date"]?.try &.downcase
  date ||= ""

  duration = env.params.query["duration"]?.try &.downcase
  duration ||= ""

  features = env.params.query["features"]?.try &.split(",").map { |feature| feature.downcase }
  features ||= [] of String

  content_type = env.params.query["type"]?.try &.downcase
  content_type ||= "video"

  begin
    search_params = produce_search_params(sort_by, date, content_type, duration, features)
  rescue ex
    env.response.status_code = 400
    next JSON.build do |json|
      json.object do
        json.field "error", ex.message
      end
    end
  end

  count, search_results = search(query, page, search_params, proxies, region).as(Tuple)
  response = JSON.build do |json|
    json.array do
      search_results.each do |item|
        json.object do
          case item
          when SearchVideo
            json.field "type", "video"
            json.field "title", item.title
            json.field "videoId", item.id

            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "videoThumbnails" do
              generate_thumbnails(json, item.id)
            end

            json.field "description", item.description
            json.field "descriptionHtml", item.description_html

            json.field "viewCount", item.views
            json.field "published", item.published.to_unix
            json.field "publishedText", translate(locale, "`x` ago", recode_date(item.published, locale))
            json.field "lengthSeconds", item.length_seconds
            json.field "liveNow", item.live_now
            json.field "paid", item.paid
            json.field "premium", item.premium
          when SearchPlaylist
            json.field "type", "playlist"
            json.field "title", item.title
            json.field "playlistId", item.id

            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "videoCount", item.video_count
            json.field "videos" do
              json.array do
                item.videos.each do |video|
                  json.object do
                    json.field "title", video.title
                    json.field "videoId", video.id
                    json.field "lengthSeconds", video.length_seconds

                    json.field "videoThumbnails" do
                      generate_thumbnails(json, video.id)
                    end
                  end
                end
              end
            end
          when SearchChannel
            json.field "type", "channel"
            json.field "author", item.author
            json.field "authorId", item.ucid
            json.field "authorUrl", "/channel/#{item.ucid}"

            json.field "authorThumbnails" do
              json.array do
                qualities = [32, 48, 76, 100, 176, 512]

                qualities.each do |quality|
                  json.object do
                    json.field "url", item.author_thumbnail.gsub("=s176-", "=s#{quality}-")
                    json.field "width", quality
                    json.field "height", quality
                  end
                end
              end
            end

            json.field "subCount", item.subscriber_count
            json.field "videoCount", item.video_count
            json.field "description", item.description
            json.field "descriptionHtml", item.description_html
          end
        end
      end
    end
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(response).to_pretty_json
  else
    response
  end
end

get "/api/v1/playlists/:plid" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"
  plid = env.params.url["plid"]

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  format = env.params.query["format"]?
  format ||= "json"

  continuation = env.params.query["continuation"]?

  if plid.starts_with? "RD"
    next env.redirect "/api/v1/mixes/#{plid}"
  end

  begin
    playlist = fetch_playlist(plid, locale)
  rescue ex
    error_message = {"error" => "Playlist is empty"}.to_json
    halt env, status_code: 500, response: error_message
  end

  begin
    videos = fetch_playlist_videos(plid, page, playlist.video_count, continuation, locale)
  rescue ex
    videos = [] of PlaylistVideo
  end

  response = JSON.build do |json|
    json.object do
      json.field "title", playlist.title
      json.field "playlistId", playlist.id

      json.field "author", playlist.author
      json.field "authorId", playlist.ucid
      json.field "authorUrl", "/channel/#{playlist.ucid}"

      json.field "authorThumbnails" do
        json.array do
          qualities = [32, 48, 76, 100, 176, 512]

          qualities.each do |quality|
            json.object do
              json.field "url", playlist.author_thumbnail.gsub("=s100-", "=s#{quality}-")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "description", playlist.description
      json.field "descriptionHtml", playlist.description_html
      json.field "videoCount", playlist.video_count

      json.field "viewCount", playlist.views
      json.field "updated", playlist.updated.to_unix

      json.field "videos" do
        json.array do
          videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id

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

  if format == "html"
    response = JSON.parse(response)
    playlist_html = template_playlist(response)
    next_video = response["videos"].as_a[1]?.try &.["videoId"]

    response = {
      "playlistHtml" => playlist_html,
      "nextVideo"    => next_video,
    }.to_json
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(response).to_pretty_json
  else
    response
  end
end

get "/api/v1/mixes/:rdid" do |env|
  locale = LOCALES[env.get("locale").as(String)]?

  env.response.content_type = "application/json"

  rdid = env.params.url["rdid"]

  continuation = env.params.query["continuation"]?
  continuation ||= rdid.lchop("RD")[0, 11]

  format = env.params.query["format"]?
  format ||= "json"

  begin
    mix = fetch_mix(rdid, continuation, locale: locale)

    if !rdid.ends_with? continuation
      mix = fetch_mix(rdid, mix.videos[1].id)
      index = mix.videos.index(mix.videos.select { |video| video.id == continuation }[0]?)
    end
    index ||= 0

    mix.videos = mix.videos[index..-1]
  rescue ex
    error_message = {"error" => ex.message}.to_json
    halt env, status_code: 500, response: error_message
  end

  response = JSON.build do |json|
    json.object do
      json.field "title", mix.title
      json.field "mixId", mix.id

      json.field "videos" do
        json.array do
          mix.videos.each do |video|
            json.object do
              json.field "title", video.title
              json.field "videoId", video.id
              json.field "author", video.author

              json.field "authorId", video.ucid
              json.field "authorUrl", "/channel/#{video.ucid}"

              json.field "videoThumbnails" do
                json.array do
                  generate_thumbnails(json, video.id)
                end
              end

              json.field "index", video.index
              json.field "lengthSeconds", video.length_seconds
            end
          end
        end
      end
    end
  end

  if format == "html"
    response = JSON.parse(response)
    playlist_html = template_mix(response)
    next_video = response["videos"].as_a[1]?.try &.["videoId"]
    next_video ||= ""

    response = {
      "playlistHtml" => playlist_html,
      "nextVideo"    => next_video,
    }.to_json
  end

  if env.params.query["pretty"]? && env.params.query["pretty"] == "1"
    JSON.parse(response).to_pretty_json
  else
    response
  end
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
  region = env.params.query["region"]?

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    url = "/api/manifest/dash/id/#{ex.message}"
    if local
      url += "?local=true"
    end

    next env.redirect url
  rescue ex
    halt env, status_code: 403
  end

  if dashmpd = video.player_response["streamingData"]["dashManifestUrl"]?.try &.as_s
    manifest = client.get(dashmpd).body

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

  audio_streams = video.audio_streams(adaptive_fmts).select { |stream| stream["type"].starts_with? "audio/mp4" }
  video_streams = video.video_streams(adaptive_fmts).select { |stream| stream["type"].starts_with? "video/mp4" }.uniq { |stream| stream["size"] }

  manifest = XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
      "profiles": "urn:mpeg:dash:profile:isoff-live:2011", minBufferTime: "PT1.5S", type: "static",
      mediaPresentationDuration: "PT#{video.info["length_seconds"]}S") do
      xml.element("Period") do
        xml.element("AdaptationSet", mimeType: "audio/mp4", startWithSAP: 1, subsegmentAlignment: true) do
          audio_streams.each do |fmt|
            codecs = fmt["type"].split("codecs=")[1].strip('"')
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

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)

  manifest = manifest.body
  manifest.gsub("https://www.youtube.com", host_url)
end

get "/api/manifest/hls_playlist/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    halt env, status_code: manifest.status_code
  end

  host_url = make_host_url(Kemal.config.ssl || config.https_only, config.domain)

  manifest = manifest.body.gsub("https://www.youtube.com", host_url)
  manifest = manifest.gsub(/https:\/\/r\d---.{11}\.c\.youtube\.com/, host_url)
  fvip = manifest.match(/hls_chunk_host\/r(?<fvip>\d)---/).not_nil!["fvip"]
  manifest = manifest.gsub("seg.ts", "seg.ts/fvip/#{fvip}")

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")
  manifest
end

# YouTube /videoplayback links expire after 6 hours,
# so we have a mechanism here to redirect to the latest version
get "/latest_version" do |env|
  if env.params.query["download_widget"]?
    download_widget = JSON.parse(env.params.query["download_widget"])
    id = download_widget["id"].as_s
    itag = download_widget["itag"].as_s
    title = download_widget["title"].as_s
    local = "true"
  end

  id ||= env.params.query["id"]?
  itag ||= env.params.query["itag"]?

  region = env.params.query["region"]?

  local ||= env.params.query["local"]?
  local ||= "false"
  local = local == "true"

  if !id || !itag
    halt env, status_code: 400
  end

  video = get_video(id, PG_DB, proxies, region: region)

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  urls = (fmt_stream + adaptive_fmts).select { |fmt| fmt["itag"] == itag }
  if urls.empty?
    halt env, status_code: 404
  elsif urls.size > 1
    halt env, status_code: 409
  end

  url = urls[0]["url"]
  if local
    url = URI.parse(url).full_path.not_nil!
  end

  if title
    url += "&title=#{title}"
  end

  env.redirect url
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

  fvip = query_params["fvip"]? || "3"
  mn = query_params["mn"].split(",")[-1]
  host = "https://r#{fvip}---#{mn}.googlevideo.com"
  url = "/videoplayback?#{query_params.to_s}"

  headers = env.request.headers
  headers.delete("Host")
  headers.delete("Cookie")
  headers.delete("User-Agent")
  headers.delete("Referer")

  region = query_params["region"]?

  response = HTTP::Client::Response.new(403)
  loop do
    begin
      client = make_client(URI.parse(host), proxies, region)
      response = client.head(url, headers)
      break
    rescue ex
    end
  end

  if response.headers["Location"]?
    url = URI.parse(response.headers["Location"])
    env.response.headers["Access-Control-Allow-Origin"] = "*"

    url = url.full_path
    if region
      url += "&region=#{region}"
    end

    next env.redirect url
  end

  if response.status_code >= 400
    halt env, status_code: response.status_code
  end

  client = make_client(URI.parse(host), proxies, region)
  client.get(url, headers) do |response|
    env.response.status_code = response.status_code

    if title = env.params.query["title"]?
      # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
      env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.escape(title)}\"; filename*=UTF-8''#{URI.escape(title)}"
    end

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
  if md = env.request.path.match(/^\/(?<id>[a-zA-Z0-9_-]{11})$/)
    id = md["id"]

    params = [] of String
    env.params.query.each do |k, v|
      params << "#{k}=#{v}"
    end
    params = params.join("&")

    url = "/watch?v=#{id}"
    if !params.empty?
      url += "&#{params}"
    end

    client = make_client(YT_URL)
    if client.head("/#{id}").status_code == 404
      env.response.headers["Location"] = url
      halt env, status_code: 302
    end
  end

  if md = env.request.path.match(/^\/(?<name>\w+)$/)
    name = md["name"]

    client = make_client(YT_URL)
    response = client.get("/#{name}")

    if response.status_code == 301
      response = client.get(response.headers["Location"])
    end

    html = XML.parse_html(response.body)
    ucid = html.xpath_node(%q(//meta[@itemprop="channelId"]))

    if ucid
      env.response.headers["Location"] = "/channel/#{ucid["content"]}"
      halt env, status_code: 302
    end
  end

  env.response.headers["Location"] = "/"
  halt env, status_code: 302
end

error 500 do |env|
  error_message = <<-END_HTML
  Looks like you've found a bug in Invidious. Feel free to open a new issue
  <a href="https://github.com/omarroth/invidious/issues">
    here
  </a>
  or send an email to 
  <a href="mailto:omarroth@protonmail.com">
    omarroth@protonmail.com</a>.
  END_HTML
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
add_handler APIHandler.new
add_context_storage_type(User)
add_context_storage_type(Preferences)

Kemal.config.logger = logger
Kemal.run
