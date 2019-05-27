# "Invidious" (which is an alternative front-end to YouTube)
# Copyright (C) 2019  Omar Roth
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
require "markdown"
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

PG_URL = URI.new(
  scheme: "postgres",
  user: CONFIG.db.user,
  password: CONFIG.db.password,
  host: CONFIG.db.host,
  port: CONFIG.db.port,
  path: CONFIG.db.dbname,
)

PG_DB           = DB.open PG_URL
ARCHIVE_URL     = URI.parse("https://archive.org")
LOGIN_URL       = URI.parse("https://accounts.google.com")
PUBSUB_URL      = URI.parse("https://pubsubhubbub.appspot.com")
REDDIT_URL      = URI.parse("https://www.reddit.com")
TEXTCAPTCHA_URL = URI.parse("http://textcaptcha.com")
YT_URL          = URI.parse("https://www.youtube.com")
CHARS_SAFE      = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
TEST_IDS        = {"AgbeGFYluEA", "BaW_jenozKc", "a9LDPn-MO4I", "ddFvjfvPnqk", "iqKdEhx-dD4"}
CURRENT_BRANCH  = {{ "#{`git branch | sed -n '/\* /s///p'`.strip}" }}
CURRENT_COMMIT  = {{ "#{`git rev-list HEAD --max-count=1 --abbrev-commit`.strip}" }}
CURRENT_VERSION = {{ "#{`git describe --tags --abbrev=0`.strip}" }}

# This is used to determine the `?v=` on the end of file URLs (for cache busting). We
# only need to expire modified assets, so we can use this to find the last commit that changes
# any assets
ASSET_COMMIT = {{ "#{`git rev-list HEAD --max-count=1 --abbrev-commit -- assets`.strip}" }}

SOFTWARE = {
  "name"    => "invidious",
  "version" => "#{CURRENT_VERSION}-#{CURRENT_COMMIT}",
  "branch"  => "#{CURRENT_BRANCH}",
}

LOCALES = {
  "ar"    => load_locale("ar"),
  "de"    => load_locale("de"),
  "el"    => load_locale("el"),
  "en-US" => load_locale("en-US"),
  "eo"    => load_locale("eo"),
  "es"    => load_locale("es"),
  "eu"    => load_locale("eu"),
  "fr"    => load_locale("fr"),
  "it"    => load_locale("it"),
  "nb_NO" => load_locale("nb_NO"),
  "nl"    => load_locale("nl"),
  "pl"    => load_locale("pl"),
  "ru"    => load_locale("ru"),
  "uk"    => load_locale("uk"),
}

config = CONFIG
logger = Invidious::LogHandler.new

Kemal.config.extra_options do |parser|
  parser.banner = "Usage: invidious [arguments]"
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
  parser.on("-o OUTPUT", "--output=OUTPUT", "Redirect output (default: STDOUT)") do |output|
    FileUtils.mkdir_p(File.dirname(output))
    logger = Invidious::LogHandler.new(File.open(output, mode: "a"))
  end
  parser.on("-v", "--version", "Print version") do |output|
    puts SOFTWARE.to_pretty_json
    exit
  end
end

Kemal::CLI.new ARGV

# Check table integrity
if CONFIG.check_tables
  analyze_table(PG_DB, logger, "channel_videos", ChannelVideo)
  analyze_table(PG_DB, logger, "nonces", Nonce)
  analyze_table(PG_DB, logger, "session_ids", SessionId)
  analyze_table(PG_DB, logger, "users", User)
  analyze_table(PG_DB, logger, "videos", Video)

  if CONFIG.cache_annotations
    analyze_table(PG_DB, logger, "annotations", Annotation)
  end
end

# Start jobs

refresh_channels(PG_DB, logger, config.channel_threads, config.full_refresh)
refresh_feeds(PG_DB, logger, config.feed_threads, config.use_feed_events)
subscribe_to_feeds(PG_DB, logger, HMAC_KEY, config)

statistics = {
  "error" => "Statistics are not availabile.",
}
if config.statistics_enabled
  spawn do
    loop do
      statistics = {
        "version"           => "2.0",
        "software"          => SOFTWARE,
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
    end
  end
end

top_videos = [] of Video
if config.top_enabled
  spawn do
    pull_top_videos(config, PG_DB) do |videos|
      top_videos = videos
      sleep 1.minute
    end
  end
end

popular_videos = [] of ChannelVideo
spawn do
  pull_popular_videos(PG_DB) do |videos|
    popular_videos = videos
    sleep 1.minute
  end
end

decrypt_function = [] of {name: String, value: Int32}
spawn do
  update_decrypt_function do |function|
    decrypt_function = function
  end
end

proxies = PROXY_LIST

before_all do |env|
  host_url = make_host_url(config, Kemal.config)
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  env.response.headers["Content-Security-Policy"] = "default-src blob: data: 'self' #{host_url} 'unsafe-inline' 'unsafe-eval'; media-src blob: 'self' #{host_url} https://*.googlevideo.com:443"
  env.response.headers["Referrer-Policy"] = "same-origin"

  if (Kemal.config.ssl || config.https_only) && config.hsts
    env.response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
  end

  begin
    preferences = Preferences.from_json(env.request.cookies["PREFS"]?.try &.value || "{}")
  rescue
    preferences = Preferences.from_json("{}")
  end

  if env.request.cookies.has_key? "SID"
    sid = env.request.cookies["SID"].value

    if sid.starts_with? "v1:"
      raise "Cannot use token as SID"
    end

    # Invidious users only have SID
    if !env.request.cookies.has_key? "SSID"
      if email = PG_DB.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)
        user = PG_DB.query_one("SELECT * FROM users WHERE email = $1", email, as: User)
        csrf_token = generate_response(sid, {":signout", ":watch_ajax", ":subscription_ajax", ":token_ajax", ":authorize_token"}, HMAC_KEY, PG_DB, 1.week)

        preferences = user.preferences

        env.set "sid", sid
        env.set "csrf_token", csrf_token
        env.set "user", user
      end
    else
      headers = HTTP::Headers.new
      headers["Cookie"] = env.request.headers["Cookie"]

      begin
        user, sid = get_user(sid, headers, PG_DB, false)
        csrf_token = generate_response(sid, {":signout", ":watch_ajax", ":subscription_ajax", ":token_ajax", ":authorize_token"}, HMAC_KEY, PG_DB, 1.week)

        preferences = user.preferences

        env.set "sid", sid
        env.set "csrf_token", csrf_token
        env.set "user", user
      rescue ex
      end
    end
  end

  dark_mode = env.params.query["dark_mode"]? || preferences.dark_mode.to_s
  dark_mode = dark_mode == "true"

  thin_mode = env.params.query["thin_mode"]? || preferences.thin_mode.to_s
  thin_mode = thin_mode == "true"

  locale = env.params.query["hl"]? || preferences.locale

  preferences.dark_mode = dark_mode
  preferences.thin_mode = thin_mode
  preferences.locale = locale
  env.set "preferences", preferences

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  user = env.get? "user"

  if user
    user = user.as(User)
    if user.preferences.redirect_feed
      next env.redirect "/feed/subscriptions"
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

get "/privacy" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  templated "privacy"
end

get "/licenses" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  rendered "licenses"
end

# Videos

get "/watch" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
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

  preferences = env.get("preferences").as(Preferences)

  user = env.get?("user").try &.as(User)
  if user
    subscriptions = user.subscriptions
    watched = user.watched
  end
  subscriptions ||= [] of String

  params = process_video_params(env.params.query, preferences)
  env.params.query.delete_all("listen")

  begin
    video = get_video(id, PG_DB, proxies, region: params.region)
  rescue ex : VideoRedirect
    next env.redirect "/watch?v=#{ex.message}"
  rescue ex
    error_message = ex.message
    logger.write("#{id} : #{ex.message}\n")
    next templated "error"
  end

  if preferences.annotations_subscribed &&
     subscriptions.includes?(video.ucid) &&
     (env.params.query["iv_load_policy"]? || "1") == "1"
    params.annotations = true
  end
  env.params.query.delete_all("iv_load_policy")

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
          comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, preferences.thin_mode, region))["contentHtml"]
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
            comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, preferences.thin_mode, region))["contentHtml"]
          end
        end
      end
    else
      comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, proxies, "html", locale, preferences.thin_mode, region))["contentHtml"]
    end

    comment_html ||= ""
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  if params.local
    fmt_stream.each { |fmt| fmt["url"] = URI.parse(fmt["url"]).full_path }
    adaptive_fmts.each { |fmt| fmt["url"] = URI.parse(fmt["url"]).full_path }
  end

  video_streams = video.video_streams(adaptive_fmts)
  audio_streams = video.audio_streams(adaptive_fmts)

  # Older videos may not have audio sources available.
  # We redirect here so they're not unplayable
  if params.listen && audio_streams.empty?
    next env.redirect "/watch?#{env.params.query}&listen=0"
  end

  captions = video.captions

  preferred_captions = captions.select { |caption|
    params.preferred_captions.includes?(caption.name.simpleText) ||
      params.preferred_captions.includes?(caption.languageCode.split("-")[0])
  }
  preferred_captions.sort_by! { |caption|
    (params.preferred_captions.index(caption.name.simpleText) ||
      params.preferred_captions.index(caption.languageCode.split("-")[0])).not_nil!
  }
  captions = captions - preferred_captions

  aspect_ratio = "16:9"

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = replace_links(video.description)
  description = video.short_description

  host_url = make_host_url(config, Kemal.config)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
    hlsvp = video.player_response["streamingData"]["hlsManifestUrl"].as_s
    hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)
  end

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params.raw
    url = fmt_stream[0]["url"]

    fmt_stream.each do |fmt|
      if fmt["label"].split(" - ")[0] == params.quality
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  id = env.params.url["id"]
  plid = env.params.query["list"]?

  if md = env.params.query["playlist"]?
       .try &.match(/[a-zA-Z0-9_-]{11}(,[a-zA-Z0-9_-]{11})*/)
    video_series = md[0].split(",")
    env.params.query.delete("playlist")
  end

  preferences = env.get("preferences").as(Preferences)

  if id.includes?("%20") || id.includes?("+") || env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
    id = env.params.url["id"].gsub("%20", "").delete("+")

    url = "/embed/#{id}"

    if env.params.query.size > 0
      url += "?#{env.params.query.to_s.gsub("%20", "").delete("+")}"
    end

    next env.redirect url
  end

  # YouTube embed supports `videoseries` with either `list=PLID`
  # or `playlist=VIDEO_ID,VIDEO_ID`
  if id == "videoseries"
    url = ""

    if plid
      begin
        videos = fetch_playlist_videos(plid, 1, 1, locale: locale)
      rescue ex
        error_message = ex.message
        next templated "error"
      end

      url = "/embed/#{videos[0].id}"
    elsif video_series
      url = "/embed/#{video_series.shift}"
      env.params.query["playlist"] = video_series.join(",")
    else
      next env.redirect "/"
    end

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    next env.redirect url
  elsif id.size > 11
    url = "/embed/#{id[0, 11]}"

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    next env.redirect url
  end

  params = process_video_params(env.params.query, preferences)

  user = env.get?("user").try &.as(User)
  if user
    subscriptions = user.subscriptions
    watched = user.watched
  end
  subscriptions ||= [] of String

  begin
    video = get_video(id, PG_DB, proxies, region: params.region)
  rescue ex : VideoRedirect
    next env.redirect "/embed/#{ex.message}"
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  if preferences.annotations_subscribed &&
     subscriptions.includes?(video.ucid) &&
     (env.params.query["iv_load_policy"]? || "1") == "1"
    params.annotations = true
  end

  if watched && !watched.includes? id
    PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE email = $2", [id], user.as(User).email)
  end

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  if params.local
    fmt_stream.each { |fmt| fmt["url"] = URI.parse(fmt["url"]).full_path }
    adaptive_fmts.each { |fmt| fmt["url"] = URI.parse(fmt["url"]).full_path }
  end

  video_streams = video.video_streams(adaptive_fmts)
  audio_streams = video.audio_streams(adaptive_fmts)

  captions = video.captions

  preferred_captions = captions.select { |caption|
    params.preferred_captions.includes?(caption.name.simpleText) ||
      params.preferred_captions.includes?(caption.languageCode.split("-")[0])
  }
  preferred_captions.sort_by! { |caption|
    (params.preferred_captions.index(caption.name.simpleText) ||
      params.preferred_captions.index(caption.languageCode.split("-")[0])).not_nil!
  }
  captions = captions - preferred_captions

  aspect_ratio = nil

  video.description = fill_links(video.description, "https", "www.youtube.com")
  video.description = replace_links(video.description)
  description = video.short_description

  host_url = make_host_url(config, Kemal.config)
  host_params = env.request.query_params
  host_params.delete_all("v")

  if video.player_response["streamingData"]?.try &.["hlsManifestUrl"]?
    hlsvp = video.player_response["streamingData"]["hlsManifestUrl"].as_s
    hlsvp = hlsvp.gsub("https://manifest.googlevideo.com", host_url)
  end

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params.raw
    url = fmt_stream[0]["url"]

    fmt_stream.each do |fmt|
      if fmt["label"].split(" - ")[0] == params.quality
        url = fmt["url"]
      end
    end

    next env.redirect url
  end

  rendered "embed"
end

# Playlists

get "/playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  env.response.content_type = "application/opensearchdescription+xml"

  host = make_host_url(config, Kemal.config)

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
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
    view_name = "subscriptions_#{sha256(user.email)}"
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
    else
      operators.delete(operator)
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  if user
    next env.redirect "/feed/subscriptions"
  end

  if !config.login_enabled
    error_message = "Login has been disabled by administrator."
    next templated "error"
  end

  referer = get_referer(env, "/feed/subscriptions")

  email = nil
  password = nil
  captcha = nil

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  captcha_type = env.params.query["captcha"]?
  captcha_type ||= "image"

  tfa = env.params.query["tfa"]?
  tfa ||= false

  templated "login"
end

post "/login" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  referer = get_referer(env, "/feed/subscriptions")

  if !config.login_enabled
    error_message = "Login has been disabled by administrator."
    next templated "error"
  end

  email = env.params.body["email"]?.try &.downcase
  password = env.params.body["password"]?

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  case account_type
  when "google"
    tfa_code = env.params.body["tfa"]?.try &.lchop("G-")

    # See https://github.com/ytdl-org/youtube-dl/blob/2019.04.07/youtube_dl/extractor/youtube.py#L82
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
          select_challenge = {2, nil, nil, nil, {tfa[8]}}.to_json

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
            account_type = "google"
            captcha_type = "image"
            tfa = true
            captcha = nil
            next templated "login"
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
            error_message = translate(locale, "Unable to log in, make sure two-factor authentication (Authenticator or SMS) is turned on.")
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
      headers = login.cookies.add_request_headers(headers)
      cookies = HTTP::Cookies.from_headers(headers)

      sid = cookies["SID"].value

      user, sid = get_user(sid, headers, PG_DB)

      # We are now logged in

      host = URI.parse(env.request.headers["Host"]).host

      if Kemal.config.ssl || config.https_only
        secure = true
      else
        secure = false
      end

      cookies.each do |cookie|
        if Kemal.config.ssl || config.https_only
          cookie.secure = secure
        else
          cookie.secure = secure
        end

        if cookie.extension
          cookie.extension = cookie.extension.not_nil!.gsub(".youtube.com", host)
          cookie.extension = cookie.extension.not_nil!.gsub("Secure; ", "")
        end
        env.response.cookies << cookie
      end

      if env.request.cookies["PREFS"]?
        preferences = env.get("preferences").as(Preferences)
        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)

        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.new(1990, 1, 1)
        env.response.cookies << cookie
      end

      env.redirect referer
    rescue ex
      error_message = translate(locale, "Login failed. This may be because two-factor authentication is not turned on for your account.")
      next templated "error"
    end
  when "invidious"
    if !email
      error_message = translate(locale, "User ID is a required field")
      next templated "error"
    end

    if !password
      error_message = translate(locale, "Password is a required field")
      next templated "error"
    end

    user = PG_DB.query_one?("SELECT * FROM users WHERE email = $1", email, as: User)

    if user
      if !user.password
        error_message = translate(locale, "Please sign in using 'Log in with Google'")
        next templated "error"
      end

      if Crypto::Bcrypt::Password.new(user.password.not_nil!) == password.byte_slice(0, 55)
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
        error_message = translate(locale, "Wrong username or password")
        next templated "error"
      end

      # Since this user has already registered, we don't want to overwrite their preferences
      if env.request.cookies["PREFS"]?
        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.new(1990, 1, 1)
        env.response.cookies << cookie
      end
    else
      if !config.registration_enabled
        error_message = "Registration has been disabled by administrator."
        next templated "error"
      end

      if password.empty?
        error_message = translate(locale, "Password cannot be empty")
        next templated "error"
      end

      # See https://security.stackexchange.com/a/39851
      if password.bytesize > 55
        error_message = translate(locale, "Password should not be longer than 55 characters")
        next templated "error"
      end

      password = password.byte_slice(0, 55)

      if config.captcha_enabled
        captcha_type = env.params.body["captcha_type"]?
        answer = env.params.body["answer"]?
        change_type = env.params.body["change_type"]?

        if !captcha_type || change_type
          if change_type
            captcha_type = change_type
          end
          captcha_type ||= "image"

          account_type = "invidious"
          tfa = false

          if captcha_type == "image"
            captcha = generate_captcha(HMAC_KEY, PG_DB)
          else
            captcha = generate_text_captcha(HMAC_KEY, PG_DB)
          end

          next templated "login"
        end

        tokens = env.params.body.select { |k, v| k.match(/^token\[\d+\]$/) }.map { |k, v| v }

        answer ||= ""
        captcha_type ||= "image"

        case captcha_type
        when "image"
          answer = answer.lstrip('0')
          answer = OpenSSL::HMAC.hexdigest(:sha256, HMAC_KEY, answer)

          begin
            validate_request(tokens[0], answer, env.request, HMAC_KEY, PG_DB, locale)
          rescue ex
            error_message = ex.message
            env.response.status_code = 400
            next templated "error"
          end
        when "text"
          answer = Digest::MD5.hexdigest(answer.downcase.strip)

          found_valid_captcha = false

          error_message = translate(locale, "Erroneous CAPTCHA")
          tokens.each_with_index do |token, i|
            begin
              validate_request(token, answer, env.request, HMAC_KEY, PG_DB, locale)
              found_valid_captcha = true
            rescue ex
              error_message = ex.message
            end
          end

          if !found_valid_captcha
            next templated "error"
          end
        end
      end

      sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
      user, sid = create_user(sid, email, password)
      user_array = user.to_a

      user_array[4] = user_array[4].to_json
      args = arg_array(user_array)

      PG_DB.exec("INSERT INTO users VALUES (#{args})", user_array)
      PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.now)

      view_name = "subscriptions_#{sha256(user.email)}"
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
        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)

        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.new(1990, 1, 1)
        env.response.cookies << cookie
      end
    end

    env.redirect referer
  else
    env.redirect referer
  end
end

post "/signout" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    end

    PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", sid)

    env.request.cookies.each do |cookie|
      cookie.expires = Time.new(1990, 1, 1)
      env.response.cookies << cookie
    end
  end

  env.redirect referer
end

get "/preferences" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  referer = get_referer(env)

  preferences = env.get("preferences").as(Preferences)

  templated "preferences"
end

post "/preferences" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  referer = get_referer(env)

  video_loop = env.params.body["video_loop"]?.try &.as(String)
  video_loop ||= "off"
  video_loop = video_loop == "on"

  annotations = env.params.body["annotations"]?.try &.as(String)
  annotations ||= "off"
  annotations = annotations == "on"

  annotations_subscribed = env.params.body["annotations_subscribed"]?.try &.as(String)
  annotations_subscribed ||= "off"
  annotations_subscribed = annotations_subscribed == "on"

  autoplay = env.params.body["autoplay"]?.try &.as(String)
  autoplay ||= "off"
  autoplay = autoplay == "on"

  continue = env.params.body["continue"]?.try &.as(String)
  continue ||= "off"
  continue = continue == "on"

  continue_autoplay = env.params.body["continue_autoplay"]?.try &.as(String)
  continue_autoplay ||= "off"
  continue_autoplay = continue_autoplay == "on"

  listen = env.params.body["listen"]?.try &.as(String)
  listen ||= "off"
  listen = listen == "on"

  local = env.params.body["local"]?.try &.as(String)
  local ||= "off"
  local = local == "on"

  speed = env.params.body["speed"]?.try &.as(String).to_f?
  speed ||= CONFIG.default_user_preferences.speed

  quality = env.params.body["quality"]?.try &.as(String)
  quality ||= CONFIG.default_user_preferences.quality

  volume = env.params.body["volume"]?.try &.as(String).to_i?
  volume ||= CONFIG.default_user_preferences.volume

  comments = [] of String
  2.times do |i|
    comments << (env.params.body["comments[#{i}]"]?.try &.as(String) || CONFIG.default_user_preferences.comments[i])
  end

  captions = [] of String
  3.times do |i|
    captions << (env.params.body["captions[#{i}]"]?.try &.as(String) || CONFIG.default_user_preferences.captions[i])
  end

  related_videos = env.params.body["related_videos"]?.try &.as(String)
  related_videos ||= "off"
  related_videos = related_videos == "on"

  redirect_feed = env.params.body["redirect_feed"]?.try &.as(String)
  redirect_feed ||= "off"
  redirect_feed = redirect_feed == "on"

  locale = env.params.body["locale"]?.try &.as(String)
  locale ||= CONFIG.default_user_preferences.locale

  dark_mode = env.params.body["dark_mode"]?.try &.as(String)
  dark_mode ||= "off"
  dark_mode = dark_mode == "on"

  thin_mode = env.params.body["thin_mode"]?.try &.as(String)
  thin_mode ||= "off"
  thin_mode = thin_mode == "on"

  max_results = env.params.body["max_results"]?.try &.as(String).to_i?
  max_results ||= CONFIG.default_user_preferences.max_results

  sort = env.params.body["sort"]?.try &.as(String)
  sort ||= CONFIG.default_user_preferences.sort

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
    "video_loop"             => video_loop,
    "annotations"            => annotations,
    "annotations_subscribed" => annotations_subscribed,
    "autoplay"               => autoplay,
    "continue"               => continue,
    "continue_autoplay"      => continue_autoplay,
    "listen"                 => listen,
    "local"                  => local,
    "speed"                  => speed,
    "quality"                => quality,
    "volume"                 => volume,
    "comments"               => comments,
    "captions"               => captions,
    "related_videos"         => related_videos,
    "redirect_feed"          => redirect_feed,
    "locale"                 => locale,
    "dark_mode"              => dark_mode,
    "thin_mode"              => thin_mode,
    "max_results"            => max_results,
    "sort"                   => sort,
    "latest_only"            => latest_only,
    "unseen_only"            => unseen_only,
    "notifications_only"     => notifications_only,
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
    if Kemal.config.ssl || config.https_only
      secure = true
    else
      secure = false
    end

    if config.domain
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{config.domain}", value: preferences, expires: Time.now + 2.years,
        secure: secure, http_only: true)
    else
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.now + 2.years,
        secure: secure, http_only: true)
    end
  end

  env.redirect referer
end

get "/toggle_theme" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  referer = get_referer(env)

  redirect = env.params.query["redirect"]?
  redirect ||= "true"
  redirect = redirect == "true"

  if user = env.get? "user"
    user = user.as(User)
    preferences = user.preferences
    preferences.dark_mode = !preferences.dark_mode

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)
  else
    preferences = env.get("preferences").as(Preferences)
    preferences.dark_mode = !preferences.dark_mode
    preferences = preferences.to_json

    if Kemal.config.ssl || config.https_only
      secure = true
    else
      secure = false
    end

    if config.domain
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{config.domain}", value: preferences, expires: Time.now + 2.years,
        secure: secure, http_only: true)
    else
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.now + 2.years,
        secure: secure, http_only: true)
    end
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

post "/watch_ajax" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/feed/subscriptions")

  redirect = env.params.query["redirect"]?
  redirect ||= "true"
  redirect = redirect == "true"

  if !user
    if redirect
      next env.redirect referer
    else
      error_message = {"error" => "No such user"}.to_json
      env.response.status_code = 403
      next error_message
    end
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  id = env.params.query["id"]?
  if !id
    env.response.status_code = 400
    next
  end

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    if redirect
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    else
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 400
      next error_message
    end
  end

  if env.params.query["action_mark_watched"]?
    action = "action_mark_watched"
  elsif env.params.query["action_mark_unwatched"]?
    action = "action_mark_unwatched"
  else
    next env.redirect referer
  end

  case action
  when "action_mark_watched"
    if !user.watched.includes? id
      PG_DB.exec("UPDATE users SET watched = watched || $1 WHERE email = $2", [id], user.email)
    end
  when "action_mark_unwatched"
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/")

  redirect = env.params.query["redirect"]?
  redirect ||= "false"
  redirect = redirect == "true"

  if !user
    if redirect
      next env.redirect referer
    else
      error_message = {"error" => "No such user"}.to_json
      env.response.status_code = 403
      next error_message
    end
  end

  user = user.as(User)

  if !user.password
    channel_req = {} of String => String

    channel_req["receive_all_updates"] = env.params.query["receive_all_updates"]? || "true"
    channel_req["receive_no_updates"] = env.params.query["receive_no_updates"]? || ""
    channel_req["receive_post_updates"] = env.params.query["receive_post_updates"]? || "true"

    channel_req.reject! { |k, v| v != "true" && v != "false" }

    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    client = make_client(YT_URL)
    html = client.get("/subscription_manager?disable_polymer=1", headers)

    cookies = HTTP::Cookies.from_headers(headers)
    html.cookies.each do |cookie|
      if {"VISITOR_INFO1_LIVE", "YSC", "SIDCC"}.includes? cookie.name
        if cookies[cookie.name]?
          cookies[cookie.name] = cookie
        else
          cookies << cookie
        end
      end
    end
    headers = cookies.add_request_headers(headers)

    match = html.body.match(/'XSRF_TOKEN': "(?<session_token>[A-Za-z0-9\_\-\=]+)"/)
    if match
      session_token = match["session_token"]
    else
      next env.redirect referer
    end

    headers["content-type"] = "application/x-www-form-urlencoded"
    channel_req["session_token"] = session_token

    subs = XML.parse_html(html.body)
    subs.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
      channel_id = channel.content.lstrip("/channel/").not_nil!
      channel_req["channel_id"] = channel_id

      client.post("/subscription_ajax?action_update_subscription_preferences=1", headers, form: channel_req)
    end
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

post "/subscription_ajax" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/")

  redirect = env.params.query["redirect"]?
  redirect ||= "true"
  redirect = redirect == "true"

  if !user
    if redirect
      next env.redirect referer
    else
      error_message = {"error" => "No such user"}.to_json
      env.response.status_code = 403
      next error_message
    end
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    if redirect
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    else
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 400
      next error_message
    end
  end

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
    # Sync subscriptions with YouTube
    subscribe_ajax(channel_id, action, env.request.headers)
  end
  email = user.email

  case action
  when .starts_with? "action_create"
    if !user.subscriptions.includes? channel_id
      get_channel(channel_id, PG_DB, false, false)
      PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", channel_id, email)
    end
  when .starts_with? "action_remove"
    PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE email = $2", channel_id, email)
  end

  payload = {
    "email"  => user.email,
    "action" => "refresh",
  }.to_json
  PG_DB.exec("NOTIFY feeds, E'#{payload}'")

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

get "/subscription_manager" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
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

  if user.subscriptions.empty?
    values = "'{}'"
  else
    values = "VALUES #{user.subscriptions.map { |id| %(('#{id}')) }.join(",")}"
  end

  subscriptions = PG_DB.query_all("SELECT * FROM channels WHERE id = ANY(#{values})", as: InvidiousChannel)

  subscriptions.sort_by! { |channel| channel.author.downcase }

  if action_takeout
    host_url = make_host_url(config, Kemal.config)

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    spawn do
      # Since import can take a while, if we're not done after 20 seconds
      # push out content to prevent timeout.

      # Interesting to note is that Chrome will try to render before the content has finished loading,
      # which is why we include a loading icon. Firefox and its derivatives will not see this page,
      # instead redirecting immediately once the connection has closed.

      # https://stackoverflow.com/q/2091239 is helpful but not directly applicable here.

      sleep 20.seconds
      env.response.puts %(<meta http-equiv="refresh" content="0; url=#{referer}">)
      env.response.puts %(<link rel="stylesheet" href="/css/ionicons.min.css?v=#{ASSET_COMMIT}">)
      env.response.puts %(<link rel="stylesheet" href="/css/default.css?v=#{ASSET_COMMIT}">)
      if env.get("preferences").as(Preferences).dark_mode
        env.response.puts %(<link rel="stylesheet" href="/css/darktheme.css?v=#{ASSET_COMMIT}">)
      else
        env.response.puts %(<link rel="stylesheet" href="/css/lighttheme.css?v=#{ASSET_COMMIT}">)
      end
      env.response.puts %(<h3><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>)
      env.response.flush

      loop do
        env.response.puts %(<!-- keepalive #{Time.now.to_unix} -->)
        env.response.flush

        sleep (20 + rand(11)).seconds
      end
    end

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

          user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

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
        user.subscriptions += body["subscriptions"].as_a.compact_map do |channel|
          if match = channel["url"].as_s.match(/\/channel\/(?<channel>UC[a-zA-Z0-9_-]{22})/)
            next match["channel"]
          elsif match = channel["url"].as_s.match(/\/user\/(?<user>.+)/)
            client = make_client(YT_URL)
            response = client.get("/user/#{match["user"]}?disable_polymer=1&hl=en&gl=US")
            document = XML.parse_html(response.body)
            canonical = document.xpath_node(%q(//link[@rel="canonical"]))

            if canonical
              ucid = canonical["href"].split("/")[-1]
              next ucid
            end
          end

          nil
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

    payload = {
      "email"  => user.email,
      "action" => "refresh",
    }.to_json
    PG_DB.exec("NOTIFY feeds, E'#{payload}'")
  end

  env.redirect referer
end

get "/change_password" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":change_password"}, HMAC_KEY, PG_DB)

    templated "change_password"
  else
    env.redirect referer
  end
end

post "/change_password" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    # We don't store passwords for Google accounts
    if !user.password
      error_message = "Cannot change password for Google accounts"
      next templated "error"
    end

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    end

    password = env.params.body["password"]?
    if !password
      error_message = translate(locale, "Password is a required field")
      next templated "error"
    end

    new_passwords = env.params.body.select { |k, v| k.match(/^new_password\[\d+\]$/) }.map { |k, v| v }

    if new_passwords.size <= 1 || new_passwords.uniq.size != 1
      error_message = translate(locale, "New passwords must match")
      next templated "error"
    end

    new_password = new_passwords.uniq[0]
    if new_password.empty?
      error_message = translate(locale, "Password cannot be empty")
      next templated "error"
    end

    if new_password.size > 55
      error_message = translate(locale, "Password cannot be longer than 55 characters")
      next templated "error"
    end

    if Crypto::Bcrypt::Password.new(user.password.not_nil!) != password
      error_message = translate(locale, "Incorrect password")
      next templated "error"
    end

    new_password = Crypto::Bcrypt::Password.create(new_password, cost: 10)
    PG_DB.exec("UPDATE users SET password = $1 WHERE email = $2", new_password.to_s, user.email)
  end

  env.redirect referer
end

get "/delete_account" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":delete_account"}, HMAC_KEY, PG_DB)

    templated "delete_account"
  else
    env.redirect referer
  end
end

post "/delete_account" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    end

    view_name = "subscriptions_#{sha256(user.email)}"
    PG_DB.exec("DELETE FROM users * WHERE email = $1", user.email)
    PG_DB.exec("DELETE FROM session_ids * WHERE email = $1", user.email)
    PG_DB.exec("DROP MATERIALIZED VIEW #{view_name}")

    env.request.cookies.each do |cookie|
      cookie.expires = Time.new(1990, 1, 1)
      env.response.cookies << cookie
    end
  end

  env.redirect referer
end

get "/clear_watch_history" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":clear_watch_history"}, HMAC_KEY, PG_DB)

    templated "clear_watch_history"
  else
    env.redirect referer
  end
end

post "/clear_watch_history" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    end

    PG_DB.exec("UPDATE users SET watched = '{}' WHERE email = $1", user.email)
  end

  env.redirect referer
end

get "/authorize_token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY, PG_DB)

    scopes = env.params.query["scopes"]?.try &.split(",")
    scopes ||= [] of String

    callback_url = env.params.query["callback_url"]?
    if callback_url
      callback_url = URI.parse(callback_url)
    end

    expire = env.params.query["expire"]?.try &.to_i?

    templated "authorize_token"
  else
    env.redirect referer
  end
end

post "/authorize_token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = env.get("user").as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      next templated "error"
    end

    scopes = env.params.body.select { |k, v| k.match(/^scopes\[\d+\]$/) }.map { |k, v| v }
    callback_url = env.params.body["callbackUrl"]?
    expire = env.params.body["expire"]?.try &.to_i?

    access_token = generate_token(user.email, scopes, expire, HMAC_KEY, PG_DB)

    if callback_url
      access_token = URI.escape(access_token)
      url = URI.parse(callback_url)

      if url.query
        query = HTTP::Params.parse(url.query.not_nil!)
      else
        query = HTTP::Params.new
      end

      query["token"] = access_token
      url.query = query.to_s

      env.redirect url.to_s
    else
      csrf_token = ""
      env.set "access_token", access_token
      templated "authorize_token"
    end
  end
end

get "/token_manager" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/subscription_manager")

  if !user
    next env.redirect referer
  end

  user = user.as(User)

  tokens = PG_DB.query_all("SELECT id, issued FROM session_ids WHERE email = $1 ORDER BY issued DESC", user.email, as: {session: String, issued: Time})

  templated "token_manager"
end

post "/token_ajax" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  redirect = env.params.query["redirect"]?
  redirect ||= "true"
  redirect = redirect == "true"

  if !user
    if redirect
      next env.redirect referer
    else
      error_message = {"error" => "No such user"}.to_json
      env.response.status_code = 403
      next error_message
    end
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    if redirect
      error_message = ex.message
      next templated "error"
    else
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 400
      next error_message
    end
  end

  if env.params.query["action_revoke_token"]?
    action = "action_revoke_token"
  else
    next env.redirect referer
  end

  session = env.params.query["session"]?
  session ||= ""

  case action
  when .starts_with? "action_revoke_token"
    PG_DB.exec("DELETE FROM session_ids * WHERE id = $1 AND email = $2", session, user.email)
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

# Feeds

get "/feed/top" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  if config.top_enabled
    templated "top"
  else
    env.redirect "/"
  end
end

get "/feed/popular" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  templated "popular"
end

get "/feed/trending" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  trending_type = env.params.query["type"]?
  trending_type ||= "Default"

  region = env.params.query["region"]?
  region ||= "US"

  begin
    trending, plid = fetch_trending(trending_type, proxies, region, locale)
  rescue ex
    error_message = "#{ex.message}"
    next templated "error"
  end

  templated "trending"
end

get "/feed/subscriptions" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if user
    user = user.as(User)
    sid = sid.as(String)
    preferences = user.preferences
    token = user.token

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

    notifications = PG_DB.query_one("SELECT notifications FROM users WHERE email = $1", user.email,
      as: Array(String))
    view_name = "subscriptions_#{sha256(user.email)}"

    if preferences.notifications_only && !notifications.empty?
      # Only show notifications

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
          # Show latest video from a channel that a user hasn't watched
          # "unseen_only" isn't really correct here, more accurate would be "unwatched_only"

          if user.watched.empty?
            values = "'{}'"
          else
            values = "VALUES #{user.watched.map { |id| %(('#{id}')) }.join(",")}"
          end
          videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} WHERE \
          NOT id = ANY (#{values}) \
          ORDER BY ucid, published DESC", as: ChannelVideo)
        else
          # Show latest video from each channel

          videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} \
          ORDER BY ucid, published DESC", as: ChannelVideo)
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
          ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
        else
          # Sort subscriptions as normal

          videos = PG_DB.query_all("SELECT * FROM #{view_name} \
          ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/atom+xml"

  ucid = env.params.url["ucid"]

  begin
    author, ucid, auto_generated = get_about_info(ucid, locale)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next error_message
  end

  client = make_client(YT_URL)
  rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  videos = [] of SearchVideo

  rss.xpath_nodes("//feed/entry").each do |entry|
    video_id = entry.xpath_node("videoid").not_nil!.content
    title = entry.xpath_node("title").not_nil!.content

    published = Time.parse_rfc3339(entry.xpath_node("published").not_nil!.content)
    updated = Time.parse_rfc3339(entry.xpath_node("updated").not_nil!.content)

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
      premium: false,
      premiere_timestamp: nil
    )
  end

  host_url = make_host_url(config, Kemal.config)
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/atom+xml"

  token = env.params.query["token"]?

  if !token
    env.response.status_code = 403
    next
  end

  user = PG_DB.query_one?("SELECT * FROM users WHERE token = $1", token.strip, as: User)
  if !user
    env.response.status_code = 403
    next
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

  view_name = "subscriptions_#{sha256(user.email)}"

  if latest_only
    videos = PG_DB.query_all("SELECT DISTINCT ON (ucid) * FROM #{view_name} \
    ORDER BY ucid, published DESC", as: ChannelVideo)

    videos.sort_by! { |video| video.published }.reverse!
  else
    videos = PG_DB.query_all("SELECT * FROM #{view_name} \
    ORDER BY published DESC LIMIT $1 OFFSET $2", limit, offset, as: ChannelVideo)
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

  host_url = make_host_url(config, Kemal.config)
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

  feed
end

get "/feed/playlist/:plid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/atom+xml"

  plid = env.params.url["plid"]

  host_url = make_host_url(config, Kemal.config)
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

  document
end

get "/feeds/videos.xml" do |env|
  if ucid = env.params.query["channel_id"]?
    env.redirect "/feed/channel/#{ucid}"
  elsif user = env.params.query["user"]?
    env.redirect "/feed/channel/#{user}"
  elsif plid = env.params.query["playlist_id"]?
    env.redirect "/feed/playlist/#{plid}"
  end
end

# Support push notifications via PubSubHubbub

get "/feed/webhook/:token" do |env|
  verify_token = env.params.url["token"]

  mode = env.params.query["hub.mode"]
  topic = env.params.query["hub.topic"]
  challenge = env.params.query["hub.challenge"]

  if verify_token.starts_with? "v1"
    _, time, nonce, signature = verify_token.split(":")
    data = "#{time}:#{nonce}"
  else
    time, signature = verify_token.split(":")
    data = "#{time}"
  end

  # The hub will sometimes check if we're still subscribed after delivery errors,
  # so we reply with a 200 as long as the request hasn't expired
  if Time.now.to_unix - time.to_i > 432000
    env.response.status_code = 400
    next
  end

  if OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, data) != signature
    env.response.status_code = 400
    next
  end

  ucid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["channel_id"]
  PG_DB.exec("UPDATE channels SET subscribed = $1 WHERE id = $2", Time.now, ucid)

  env.response.status_code = 200
  next challenge
end

post "/feed/webhook/:token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  token = env.params.url["token"]
  body = env.request.body.not_nil!.gets_to_end
  signature = env.request.headers["X-Hub-Signature"].lchop("sha1=")

  if signature != OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, body)
    logger.write("#{token} : Invalid signature\n")
    env.response.status_code = 200
    next
  end

  spawn do
    rss = XML.parse_html(body)
    rss.xpath_nodes("//feed/entry").each do |entry|
      id = entry.xpath_node("videoid").not_nil!.content
      author = entry.xpath_node("author/name").not_nil!.content
      published = Time.parse_rfc3339(entry.xpath_node("published").not_nil!.content)
      updated = Time.parse_rfc3339(entry.xpath_node("updated").not_nil!.content)

      video = get_video(id, PG_DB, proxies, force_refresh: true)

      # Deliver notifications to `/api/v1/auth/notifications`
      payload = {
        "topic"     => video.ucid,
        "videoId"   => video.id,
        "published" => published.to_unix,
      }.to_json
      PG_DB.exec("NOTIFY notifications, E'#{payload}'")

      video = ChannelVideo.new(
        id: id,
        title: video.title,
        published: published,
        updated: updated,
        ucid: video.ucid,
        author: author,
        length_seconds: video.length_seconds,
        live_now: video.live_now,
        premiere_timestamp: video.premiere_timestamp,
      )

      users = PG_DB.query_all("UPDATE users SET notifications = notifications || $1 \
        WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications) RETURNING email",
        video.id, video.published, video.ucid, as: String)

      video_array = video.to_a
      args = arg_array(video_array)

      PG_DB.exec("INSERT INTO channel_videos VALUES (#{args}) \
        ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
        updated = $4, ucid = $5, author = $6, length_seconds = $7, \
        live_now = $8, premiere_timestamp = $9", video_array)

      users.each do |user|
        payload = {
          "email"  => user,
          "action" => "refresh",
        }.to_json
        PG_DB.exec("NOTIFY feeds, E'#{payload}'")
      end
    end
  end

  env.response.status_code = 200
  next
end

# Channels

{"/channel/:ucid/live", "/user/:user/live", "/c/:user/live"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    client = make_client(YT_URL)

    # Appears to be a bug in routing, having several routes configured
    # as `/a/:a`, `/b/:a`, `/c/:a` results in 404
    value = env.request.resource.split("/")[2]
    body = ""
    {"channel", "user", "c"}.each do |type|
      response = client.get("/#{type}/#{value}/live?disable_polymer=1")
      if response.status_code == 200
        body = response.body
      end
    end

    video_id = body.match(/'VIDEO_ID': "(?<id>[a-zA-Z0-9_-]{11})"/).try &.["id"]?
    if video_id
      params = [] of String
      env.params.query.each do |k, v|
        params << "#{k}=#{v}"
      end
      params = params.join("&")

      url = "/watch?v=#{video_id}"
      if !params.empty?
        url += "&#{params}"
      end

      env.redirect url
    else
      env.redirect "/channel/#{value}"
    end
  end
end

# YouTube appears to let users set a "brand" URL that
# is different from their username, so we convert that here
get "/c/:user" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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

# Page used by YouTube to provide captioning widget, since we
# don't support it we redirect to '/'
get "/timedtext_video" do |env|
  env.redirect "/"
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
    env.set "search", "channel:#{ucid} "
  end

  if auto_generated
    sort_options = {"last", "oldest", "newest"}
    sort_by ||= "last"

    items, continuation = fetch_channel_playlists(ucid, author, auto_generated, continuation, sort_by)
    items.uniq! do |item|
      if item.responds_to?(:title)
        item.title
      elsif item.responds_to?(:author)
        item.author
      end
    end
    items.select! { |item| item.responds_to?(:thumbnail_id) && item.thumbnail_id }
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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
    env.response.status_code = 400
    next error_message
  end

  if statistics["error"]?
    env.response.status_code = 500
    next statistics.to_json
  end

  statistics.to_json
end

# YouTube provides "storyboards", which are sprites containing x * y
# preview thumbnails for individual scenes in a video.
# See https://support.jwplayer.com/articles/how-to-add-preview-thumbnails
get "/api/v1/storyboards/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    next env.redirect "/api/v1/storyboards/#{ex.message}"
  rescue ex
    env.response.status_code = 500
    next
  end

  storyboards = video.storyboards

  width = env.params.query["width"]?
  height = env.params.query["height"]?

  if !width && !height
    response = JSON.build do |json|
      json.object do
        json.field "storyboards" do
          generate_storyboards(json, id, storyboards, config, Kemal.config)
        end
      end
    end

    next response
  end

  env.response.content_type = "text/vtt"

  storyboard = storyboards.select { |storyboard| width == "#{storyboard[:width]}" || height == "#{storyboard[:height]}" }

  if storyboard.empty?
    env.response.status_code = 404
    next
  else
    storyboard = storyboard[0]
  end

  webvtt = <<-END_VTT
  WEBVTT


  END_VTT

  start_time = 0.milliseconds
  end_time = storyboard[:interval].milliseconds

  storyboard[:storyboard_count].times do |i|
    host_url = make_host_url(config, Kemal.config)
    url = storyboard[:url].gsub("$M", i).gsub("https://i9.ytimg.com", host_url)

    storyboard[:storyboard_height].times do |j|
      storyboard[:storyboard_width].times do |k|
        webvtt += <<-END_CUE
        #{start_time}.000 --> #{end_time}.000
        #{url}#xywh=#{storyboard[:width] * k},#{storyboard[:height] * j},#{storyboard[:width]},#{storyboard[:height]}


        END_CUE

        start_time += storyboard[:interval].milliseconds
        end_time += storyboard[:interval].milliseconds
      end
    end
  end

  webvtt
end

get "/api/v1/captions/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  # See https://github.com/ytdl-org/youtube-dl/blob/6ab30ff50bf6bd0585927cb73c7421bef184f87a/youtube_dl/extractor/youtube.py#L1354
  # It is possible to use `/api/timedtext?type=list&v=#{id}` and
  # `/api/timedtext?type=track&v=#{id}&lang=#{lang_code}` directly,
  # but this does not provide links for auto-generated captions.
  #
  # In future this should be investigated as an alternative, since it does not require
  # getting video info.

  client = make_client(YT_URL)
  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    next env.redirect "/api/v1/captions/#{ex.message}"
  rescue ex
    env.response.status_code = 500
    next
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

    next response
  end

  env.response.content_type = "text/vtt; charset=UTF-8"

  caption = captions.select { |caption| caption.name.simpleText == label }

  if lang
    caption = captions.select { |caption| caption.languageCode == lang }
  end

  if caption.empty?
    env.response.status_code = 404
    next
  else
    caption = caption[0]
  end

  url = caption.baseUrl + "&tlang=#{tlang}"

  # Auto-generated captions often have cues that aren't aligned properly with the video,
  # as well as some other markup that makes it cumbersome, so we try to fix that here
  if caption.name.simpleText.includes? "auto-generated"
    caption_xml = client.get(url).body
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

      webvtt += <<-END_CUE
    #{start_time} --> #{end_time}
    #{text}


    END_CUE
    end
  else
    url += "&format=vtt"
    webvtt = client.get(url).body
  end

  if title = env.params.query["title"]?
    # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
    env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.escape(title)}\"; filename*=UTF-8''#{URI.escape(title)}"
  end

  webvtt
end

get "/api/v1/comments/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  region = env.params.query["region"]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]

  source = env.params.query["source"]?
  source ||= "youtube"

  thin_mode = env.params.query["thin_mode"]?
  thin_mode = thin_mode == "true"

  format = env.params.query["format"]?
  format ||= "json"

  continuation = env.params.query["continuation"]?
  sort_by = env.params.query["sort_by"]?.try &.downcase

  if source == "youtube"
    sort_by ||= "top"

    begin
      comments = fetch_youtube_comments(id, PG_DB, continuation, proxies, format, locale, thin_mode, region, sort_by: sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end

    next comments
  elsif source == "reddit"
    sort_by ||= "confidence"

    begin
      comments, reddit_thread = fetch_reddit_comments(id, sort_by: sort_by)
      content_html = template_reddit_comments(comments, locale)

      content_html = fill_links(content_html, "https", "www.reddit.com")
      content_html = replace_links(content_html)
    rescue ex
      comments = nil
      reddit_thread = nil
      content_html = ""
    end

    if !reddit_thread || !comments
      env.response.status_code = 404
      next
    end

    if format == "json"
      reddit_thread = JSON.parse(reddit_thread.to_json).as_h
      reddit_thread["comments"] = JSON.parse(comments.to_json)

      next reddit_thread.to_json
    else
      response = {
        "title"       => reddit_thread.title,
        "permalink"   => reddit_thread.permalink,
        "contentHtml" => content_html,
      }

      next response.to_json
    end
  end
end

get "/api/v1/insights/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  id = env.params.url["id"]
  env.response.content_type = "application/json"

  error_message = {"error" => "YouTube has removed publicly-available analytics."}.to_json
  env.response.status_code = 410
  next error_message

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

  next response.to_json
end

get "/api/v1/annotations/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "text/xml"

  id = env.params.url["id"]
  source = env.params.query["source"]?
  source ||= "archive"

  if !id.match(/[a-zA-Z0-9_-]{11}/)
    env.response.status_code = 400
    next
  end

  annotations = ""

  case source
  when "archive"
    if CONFIG.cache_annotations && (cached_annotation = PG_DB.query_one?("SELECT * FROM annotations WHERE id = $1", id, as: Annotation))
      annotations = cached_annotation.annotations
    else
      index = CHARS_SAFE.index(id[0]).not_nil!.to_s.rjust(2, '0')

      # IA doesn't handle leading hyphens,
      # so we use https://archive.org/details/youtubeannotations_64
      if index == "62"
        index = "64"
        id = id.sub(/^-/, 'A')
      end

      file = URI.escape("#{id[0, 3]}/#{id}.xml")

      client = make_client(ARCHIVE_URL)
      location = client.get("/download/youtubeannotations_#{index}/#{id[0, 2]}.tar/#{file}")

      if !location.headers["Location"]?
        env.response.status_code = location.status_code
      end

      response = make_client(URI.parse(location.headers["Location"])).get(location.headers["Location"])

      if response.body.empty?
        env.response.status_code = 404
        next
      end

      if response.status_code != 200
        env.response.status_code = response.status_code
        next
      end

      annotations = response.body

      cache_annotation(PG_DB, id, annotations)
    end
  when "youtube"
    client = make_client(YT_URL)

    response = client.get("/annotations_invideo?video_id=#{id}")

    if response.status_code != 200
      env.response.status_code = response.status_code
      next
    end

    annotations = response.body
  end

  annotations
end

get "/api/v1/videos/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  begin
    video = get_video(id, PG_DB, proxies, region: region)
  rescue ex : VideoRedirect
    next env.redirect "/api/v1/videos/#{ex.message}"
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  video.to_json(locale, config, Kemal.config, decrypt_function)
end

get "/api/v1/trending" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  region = env.params.query["region"]?
  trending_type = env.params.query["type"]?

  begin
    trending, plid = fetch_trending(trending_type, proxies, region, locale)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  videos = JSON.build do |json|
    json.array do
      trending.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id
          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id, config, Kemal.config)
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

  videos
end

get "/api/v1/popular" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  JSON.build do |json|
    json.array do
      popular_videos.each do |video|
        video.to_json(locale, config, Kemal.config, json)
      end
    end
  end
end

get "/api/v1/top" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  if !config.top_enabled
    error_message = {"error" => "Administrator has disabled this endpoint."}.to_json
    env.response.status_code = 400
    next error_message
  end

  videos = JSON.build do |json|
    json.array do
      top_videos.each do |video|
        json.object do
          json.field "title", video.title
          json.field "videoId", video.id
          json.field "videoThumbnails" do
            generate_thumbnails(json, video.id, config, Kemal.config)
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

  videos
end

get "/api/v1/channels/:ucid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  ucid = env.params.url["ucid"]
  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "newest"

  begin
    author, ucid, auto_generated = get_about_info(ucid, locale)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
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
      env.response.status_code = 500
      next error_message
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
      total_views = item.content.gsub(/\D/, "").to_i64
    when .includes? "subscribers"
      sub_count = item.content.delete("subscribers").gsub(/\D/, "").to_i64
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
          qualities = {
            {width: 2560, height: 424},
            {width: 2120, height: 351},
            {width: 1060, height: 175},
          }
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
          qualities = {32, 48, 76, 100, 176, 512}

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
                generate_thumbnails(json, video.id, config, Kemal.config)
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
                  qualities = {32, 48, 76, 100, 176, 512}

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

  channel_info
end

{"/api/v1/channels/:ucid/videos", "/api/v1/channels/videos/:ucid"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
      env.response.status_code = 500
      next error_message
    end

    begin
      videos, count = get_60_videos(ucid, page, auto_generated, sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
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
              generate_thumbnails(json, video.id, config, Kemal.config)
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

    result
  end
end

{"/api/v1/channels/:ucid/latest", "/api/v1/channels/latest/:ucid"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]

    begin
      videos = get_latest_videos(ucid)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end

    JSON.build do |json|
      json.array do
        videos.each do |video|
          json.object do
            json.field "title", video.title
            json.field "videoId", video.id

            json.field "authorId", ucid
            json.field "authorUrl", "/channel/#{ucid}"

            json.field "videoThumbnails" do
              generate_thumbnails(json, video.id, config, Kemal.config)
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
  end
end

{"/api/v1/channels/:ucid/playlists", "/api/v1/channels/playlists/:ucid"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?
    sort_by = env.params.query["sort"]?.try &.downcase
    sort_by ||= env.params.query["sort_by"]?.try &.downcase
    sort_by ||= "last"

    begin
      author, ucid, auto_generated = get_about_info(ucid, locale)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
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
                            generate_thumbnails(json, video.id, config, Kemal.config)
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

    response
  end
end

get "/api/v1/channels/search/:ucid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
              generate_thumbnails(json, item.id, config, Kemal.config)
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
                      generate_thumbnails(json, video.id, config, Kemal.config)
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
                qualities = {32, 48, 76, 100, 176, 512}

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

  response
end

get "/api/v1/search" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
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
              generate_thumbnails(json, item.id, config, Kemal.config)
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
                      generate_thumbnails(json, video.id, config, Kemal.config)
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
                qualities = {32, 48, 76, 100, 176, 512}

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

  response
end

get "/api/v1/playlists/:plid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
    env.response.status_code = 500
    next error_message
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
          qualities = {32, 48, 76, 100, 176, 512}

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
                generate_thumbnails(json, video.id, config, Kemal.config)
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

  response
end

get "/api/v1/mixes/:rdid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
    env.response.status_code = 500
    next error_message
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
                  generate_thumbnails(json, video.id, config, Kemal.config)
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

  response
end

get "/api/v1/auth/notifications" do |env|
  topics = env.params.query["topics"]?.try &.split(",").uniq.first(1000)
  topics ||= [] of String

  create_notification_stream(env, proxies, config, Kemal.config, decrypt_function, topics)
end

post "/api/v1/auth/notifications" do |env|
  topics = env.params.body["topics"]?.try &.split(",").uniq.first(1000)
  topics ||= [] of String

  create_notification_stream(env, proxies, config, Kemal.config, decrypt_function, topics)
end

get "/api/v1/auth/preferences" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)
  user.preferences.to_json
end

post "/api/v1/auth/preferences" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  begin
    preferences = Preferences.from_json(env.request.body || "{}")
  rescue
    preferences = user.preferences
  end

  PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)

  env.response.status_code = 204
  ""
end

get "/api/v1/auth/subscriptions" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  if user.subscriptions.empty?
    values = "'{}'"
  else
    values = "VALUES #{user.subscriptions.map { |id| %(('#{id}')) }.join(",")}"
  end

  subscriptions = PG_DB.query_all("SELECT * FROM channels WHERE id = ANY(#{values})", as: InvidiousChannel)

  JSON.build do |json|
    json.array do
      subscriptions.each do |subscription|
        json.object do
          json.field "author", subscription.author
          json.field "authorId", subscription.id
        end
      end
    end
  end
end

post "/api/v1/auth/subscriptions/:ucid" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  ucid = env.params.url["ucid"]

  if !user.subscriptions.includes? ucid
    get_channel(ucid, PG_DB, false, false)
    PG_DB.exec("UPDATE users SET subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)

    payload = {
      "email"  => user.email,
      "action" => "refresh",
    }.to_json
    PG_DB.exec("NOTIFY feeds, E'#{payload}'")
  end

  # For Google accounts, access tokens don't have enough information to
  # make a request on the user's behalf, which is why we don't sync with
  # YouTube.

  env.response.status_code = 204
  ""
end

delete "/api/v1/auth/subscriptions/:ucid" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  ucid = env.params.url["ucid"]

  PG_DB.exec("UPDATE users SET subscriptions = array_remove(subscriptions,$1) WHERE email = $2", ucid, user.email)
  payload = {
    "email"  => user.email,
    "action" => "refresh",
  }.to_json
  PG_DB.exec("NOTIFY feeds, E'#{payload}'")

  env.response.status_code = 204
  ""
end

get "/api/v1/auth/tokens" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)
  scopes = env.get("scopes").as(Array(String))

  tokens = PG_DB.query_all("SELECT id, issued FROM session_ids WHERE email = $1", user.email, as: {session: String, issued: Time})

  JSON.build do |json|
    json.array do
      tokens.each do |token|
        json.object do
          json.field "session", token[:session]
          json.field "issued", token[:issued].to_unix
        end
      end
    end
  end
end

post "/api/v1/auth/tokens/register" do |env|
  user = env.get("user").as(User)
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  case env.request.headers["Content-Type"]?
  when "application/x-www-form-urlencoded"
    scopes = env.params.body.select { |k, v| k.match(/^scopes\[\d+\]$/) }.map { |k, v| v }
    callback_url = env.params.body["callbackUrl"]?
    expire = env.params.body["expire"]?.try &.to_i?
  when "application/json"
    scopes = env.params.json["scopes"].as(Array).map { |v| v.as_s }
    callback_url = env.params.json["callbackUrl"]?.try &.as(String)
    expire = env.params.json["expire"]?.try &.as(Int64)
  else
    error_message = {"error" => "Invalid or missing header 'Content-Type'"}.to_json
    env.response.status_code = 400
    next error_message
  end

  if callback_url && callback_url.empty?
    callback_url = nil
  end

  if callback_url
    callback_url = URI.parse(callback_url)
  end

  if sid = env.get?("sid").try &.as(String)
    env.response.content_type = "text/html"

    csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY, PG_DB, use_nonce: true)
    next templated "authorize_token"
  else
    env.response.content_type = "application/json"

    superset_scopes = env.get("scopes").as(Array(String))

    authorized_scopes = [] of String
    scopes.each do |scope|
      if scopes_include_scope(superset_scopes, scope)
        authorized_scopes << scope
      end
    end

    access_token = generate_token(user.email, authorized_scopes, expire, HMAC_KEY, PG_DB)

    if callback_url
      access_token = URI.escape(access_token)

      if query = callback_url.query
        query = HTTP::Params.parse(query.not_nil!)
      else
        query = HTTP::Params.new
      end

      query["token"] = access_token
      callback_url.query = query.to_s

      env.redirect callback_url.to_s
    else
      access_token
    end
  end
end

post "/api/v1/auth/tokens/unregister" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)
  scopes = env.get("scopes").as(Array(String))

  session = env.params.json["session"]?.try &.as(String)
  session ||= env.get("session").as(String)

  # Allow tokens to revoke other tokens with correct scope
  if session == env.get("session").as(String)
    PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", session)
  elsif scopes_include_scope(scopes, "GET:tokens")
    PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", session)
  else
    error_message = {"error" => "Cannot revoke session #{session}"}.to_json
    env.response.status_code = 400
    next error_message
  end

  env.response.status_code = 204
  ""
end

get "/api/manifest/dash/id/videoplayback" do |env|
  env.response.headers.delete("Content-Type")
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.redirect "/videoplayback?#{env.params.query}"
end

get "/api/manifest/dash/id/videoplayback/*" do |env|
  env.response.headers.delete("Content-Type")
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
    env.response.status_code = 403
    next
  end

  if dashmpd = video.player_response["streamingData"]?.try &.["dashManifestUrl"]?.try &.as_s
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

  audio_streams = video.audio_streams(adaptive_fmts)
  video_streams = video.video_streams(adaptive_fmts)

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
      "profiles": "urn:mpeg:dash:profile:isoff-live:2011", minBufferTime: "PT1.5S", type: "static",
      mediaPresentationDuration: "PT#{video.info["length_seconds"]}S") do
      xml.element("Period") do
        i = 0

        {"audio/mp4", "audio/webm"}.each do |mime_type|
          xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true) do
            audio_streams.select { |stream| stream["type"].starts_with? mime_type }.each do |fmt|
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

          i += 1
        end

        {"video/mp4", "video/webm"}.each do |mime_type|
          xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true, scanType: "progressive") do
            video_streams.select { |stream| stream["type"].starts_with? mime_type }.each do |fmt|
              codecs = fmt["type"].split("codecs=")[1].strip('"')
              bandwidth = fmt["bitrate"]
              itag = fmt["itag"]
              url = fmt["url"]
              width, height = fmt["size"].split("x")

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

          i += 1
        end
      end
    end
  end
end

get "/api/manifest/hls_variant/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    env.response.status_code = manifest.status_code
    next
  end

  local = env.params.query["local"]?.try &.== "true"

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")

  host_url = make_host_url(config, Kemal.config)

  manifest = manifest.body

  if local
    manifest = manifest.gsub("https://www.youtube.com", host_url)
    manifest = manifest.gsub("index.m3u8", "index.m3u8?local=true")
  end

  manifest
end

get "/api/manifest/hls_playlist/*" do |env|
  client = make_client(YT_URL)
  manifest = client.get(env.request.path)

  if manifest.status_code != 200
    env.response.status_code = manifest.status_code
    next
  end

  local = env.params.query["local"]?.try &.== "true"

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")

  host_url = make_host_url(config, Kemal.config)

  manifest = manifest.body

  if local
    manifest = manifest.gsub("https://www.youtube.com", host_url)
    manifest = manifest.gsub(/https:\/\/r\d---.{11}\.c\.youtube\.com/, host_url)
    manifest = manifest.gsub("seg.ts", "seg.ts?local=true")
  end

  fvip = manifest.match(/hls_chunk_host\/r(?<fvip>\d+)---/).not_nil!["fvip"]
  manifest = manifest.gsub("seg.ts", "seg.ts/fvip/#{fvip}")

  manifest
end

# YouTube /videoplayback links expire after 6 hours,
# so we have a mechanism here to redirect to the latest version
get "/latest_version" do |env|
  if env.params.query["download_widget"]?
    download_widget = JSON.parse(env.params.query["download_widget"])

    id = download_widget["id"].as_s
    title = download_widget["title"].as_s

    if label = download_widget["label"]?
      env.redirect "/api/v1/captions/#{id}?label=#{label}&title=#{title}"
      next
    else
      itag = download_widget["itag"].as_s
      local = "true"
    end
  end

  id ||= env.params.query["id"]?
  itag ||= env.params.query["itag"]?

  region = env.params.query["region"]?

  local ||= env.params.query["local"]?
  local ||= "false"
  local = local == "true"

  if !id || !itag
    env.response.status_code = 400
    next
  end

  video = get_video(id, PG_DB, proxies, region: region)

  fmt_stream = video.fmt_stream(decrypt_function)
  adaptive_fmts = video.adaptive_fmts(decrypt_function)

  urls = (fmt_stream + adaptive_fmts).select { |fmt| fmt["itag"] == itag }
  if urls.empty?
    env.response.status_code = 404
    next
  elsif urls.size > 1
    env.response.status_code = 409
    next
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
  env.response.headers.delete("Content-Type")
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/videoplayback/*" do |env|
  env.response.headers.delete("Content-Type")
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/api/manifest/dash/id/videoplayback" do |env|
  env.response.headers.delete("Content-Type")
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

options "/api/manifest/dash/id/videoplayback/*" do |env|
  env.response.headers.delete("Content-Type")
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
  mns = query_params["mn"].split(",")

  if query_params["region"]?
    region = query_params["region"]
    query_params.delete("region")
  end

  if query_params["host"]? && !query_params["host"].empty?
    host = "https://#{query_params["host"]}"
    query_params.delete("host")
  else
    host = "https://r#{fvip}---#{mns.pop}.googlevideo.com"
  end

  url = "/videoplayback?#{query_params.to_s}"

  headers = HTTP::Headers.new
  {"Accept", "Accept-Encoding", "Cache-Control", "Connection", "If-None-Match", "Range"}.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  response = HTTP::Client::Response.new(403)
  5.times do
    begin
      client = make_client(URI.parse(host), proxies, region)
      response = client.head(url, headers)
      break
    rescue Socket::Addrinfo::Error
      if !mns.empty?
        mn = mns.pop
      end
      fvip = "3"

      host = "https://r#{fvip}---#{mn}.googlevideo.com"
    rescue ex
    end
  end

  if response.headers["Location"]?
    url = URI.parse(response.headers["Location"])
    host = url.host
    env.response.headers["Access-Control-Allow-Origin"] = "*"

    url = url.full_path
    url += "&host=#{host}"

    if region
      url += "&region=#{region}"
    end

    next env.redirect url
  end

  if response.status_code >= 400
    env.response.status_code = response.status_code
    next
  end

  client = make_client(URI.parse(host), proxies, region)
  begin
    client.get(url, headers) do |response|
      env.response.status_code = response.status_code

      response.headers.each do |key, value|
        if !{"Access-Control-Allow-Origin", "Alt-Svc", "Server"}.includes? key
          env.response.headers[key] = value
        end
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.headers["Location"]?
        url = URI.parse(response.headers["Location"])
        host = url.host

        url = url.full_path
        url += "&host=#{host}"

        if region
          url += "&region=#{region}"
        end

        next env.redirect url
      end

      if title = query_params["title"]?
        # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
        env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.escape(title)}\"; filename*=UTF-8''#{URI.escape(title)}"
      end

      proxy_file(response, env)
    end
  rescue ex
  end
end

# We need this so the below route works as expected
get "/ggpht*" do |env|
end

get "/ggpht/*" do |env|
  host = "https://yt3.ggpht.com"
  client = make_client(URI.parse(host))
  url = env.request.path.lchop("/ggpht")

  headers = HTTP::Headers.new
  {"Accept", "Accept-Encoding", "Cache-Control", "Connection", "If-None-Match", "Range"}.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    client.get(url, headers) do |response|
      response.headers.each do |key, value|
        if !{"Access-Control-Allow-Origin", "Alt-Svc", "Server"}.includes? key
          env.response.headers[key] = value
        end
      end

      if response.status_code == 304
        break
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      proxy_file(response, env)
    end
  rescue ex
  end
end

options "/sb/:id/:storyboard/:index" do |env|
  env.response.headers.delete("Content-Type")
  env.response.headers["Access-Control-Allow-Origin"] = "*"
  env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
  env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
end

get "/sb/:id/:storyboard/:index" do |env|
  id = env.params.url["id"]
  storyboard = env.params.url["storyboard"]
  index = env.params.url["index"]

  if storyboard.starts_with? "storyboard_live"
    host = "https://i.ytimg.com"
  else
    host = "https://i9.ytimg.com"
  end
  client = make_client(URI.parse(host))

  url = "/sb/#{id}/#{storyboard}/#{index}?#{env.params.query}"

  headers = HTTP::Headers.new
  {"Accept", "Accept-Encoding", "Cache-Control", "Connection", "If-None-Match", "Range"}.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    client.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !{"Access-Control-Allow-Origin", "Alt-Svc", "Server"}.includes? key
          env.response.headers[key] = value
        end
      end

      if response.status_code >= 400
        break
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      proxy_file(response, env)
    end
  rescue ex
  end
end

get "/vi/:id/:name" do |env|
  id = env.params.url["id"]
  name = env.params.url["name"]

  host = "https://i.ytimg.com"
  client = make_client(URI.parse(host))

  if name == "maxres.jpg"
    build_thumbnails(id, config, Kemal.config).each do |thumb|
      if client.head("/vi/#{id}/#{thumb[:url]}.jpg").status_code == 200
        name = thumb[:url] + ".jpg"
        break
      end
    end
  end
  url = "/vi/#{id}/#{name}"

  headers = HTTP::Headers.new
  {"Accept", "Accept-Encoding", "Cache-Control", "Connection", "If-None-Match", "Range"}.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    client.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !{"Access-Control-Allow-Origin", "Alt-Svc", "Server"}.includes? key
          env.response.headers[key] = value
        end
      end

      if response.status_code == 304
        break
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      proxy_file(response, env)
    end
  rescue ex
  end
end

# Undocumented, creates anonymous playlist with specified 'video_ids'
get "/watch_videos" do |env|
  client = make_client(YT_URL)

  response = client.get("#{env.request.path}?#{env.request.query}")
  if url = response.headers["Location"]?
    url = URI.parse(url).full_path
    next env.redirect url
  end

  env.response.status_code = response.status_code
end

error 404 do |env|
  if md = env.request.path.match(/^\/(?<id>([a-zA-Z0-9_-]{11})|(\w+))$/)
    item = md["id"]

    # Check if item is branding URL e.g. https://youtube.com/gaming
    client = make_client(YT_URL)
    response = client.get("/#{item}")

    if response.status_code == 301
      response = client.get(response.headers["Location"])
    end

    html = XML.parse_html(response.body)
    ucid = html.xpath_node(%q(//meta[@itemprop="channelId"]))

    if ucid
      env.response.headers["Location"] = "/channel/#{ucid["content"]}"
      halt env, status_code: 302
    end

    params = [] of String
    env.params.query.each do |k, v|
      params << "#{k}=#{v}"
    end
    params = params.join("&")

    url = "/watch?v=#{item}"
    if !params.empty?
      url += "&#{params}"
    end

    # Check if item is video ID
    client = make_client(YT_URL)
    if item.match(/^[a-zA-Z0-9_-]{11}$/) && client.head("/watch?v=#{item}").status_code != 404
      env.response.headers["Location"] = url
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
    server = HTTP::Server.new do |env|
      redirect_url = "https://#{env.request.host}#{env.request.path}"
      if env.request.query
        redirect_url += "?#{env.request.query}"
      end

      if config.hsts
        env.response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
      end
      env.response.headers["Location"] = redirect_url
      env.response.status_code = 301
    end

    server.bind_tcp "0.0.0.0", 80
    server.listen
  end
end

static_headers do |response, filepath, filestat|
  response.headers.add("Cache-Control", "max-age=2629800")
end

public_folder "assets"

Kemal.config.powered_by_header = false
add_handler FilteredCompressHandler.new
add_handler APIHandler.new
add_handler AuthHandler.new
add_handler DenyFrame.new
add_context_storage_type(Array(String))
add_context_storage_type(Preferences)
add_context_storage_type(User)

Kemal.config.logger = logger
Kemal.run
