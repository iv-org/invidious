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
require "openssl/hmac"
require "option_parser"
require "pg"
require "sqlite3"
require "xml"
require "yaml"
require "compress/zip"
require "protodec/utils"
require "./invidious/helpers/*"
require "./invidious/*"
require "./invidious/routes/**"
require "./invidious/jobs/**"

ENV_CONFIG_NAME = "INVIDIOUS_CONFIG"

CONFIG_STR = ENV.has_key?(ENV_CONFIG_NAME) ? ENV.fetch(ENV_CONFIG_NAME) : File.read("config/config.yml")
CONFIG     = Config.from_yaml(CONFIG_STR)
HMAC_KEY   = CONFIG.hmac_key || Random::Secure.hex(32)

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
TEXTCAPTCHA_URL = URI.parse("https://textcaptcha.com")
YT_URL          = URI.parse("https://www.youtube.com")
HOST_URL        = make_host_url(CONFIG, Kemal.config)

CHARS_SAFE         = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
TEST_IDS           = {"AgbeGFYluEA", "BaW_jenozKc", "a9LDPn-MO4I", "ddFvjfvPnqk", "iqKdEhx-dD4"}
MAX_ITEMS_PER_PAGE = 1500

REQUEST_HEADERS_WHITELIST  = {"accept", "accept-encoding", "cache-control", "content-length", "if-none-match", "range"}
RESPONSE_HEADERS_BLACKLIST = {"access-control-allow-origin", "alt-svc", "server"}
HTTP_CHUNK_SIZE            = 10485760 # ~10MB

CURRENT_BRANCH  = {{ "#{`git branch | sed -n '/* /s///p'`.strip}" }}
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
  "hu"    => load_locale("hu-HU"),
  "is"    => load_locale("is"),
  "it"    => load_locale("it"),
  "ja"    => load_locale("ja"),
  "nb-NO" => load_locale("nb-NO"),
  "nl"    => load_locale("nl"),
  "pl"    => load_locale("pl"),
  "pt-BR" => load_locale("pt-BR"),
  "pt-PT" => load_locale("pt-PT"),
  "ro"    => load_locale("ro"),
  "ru"    => load_locale("ru"),
  "sv"    => load_locale("sv-SE"),
  "tr"    => load_locale("tr"),
  "uk"    => load_locale("uk"),
  "zh-CN" => load_locale("zh-CN"),
  "zh-TW" => load_locale("zh-TW"),
}

YT_POOL = QUICPool.new(YT_URL, capacity: CONFIG.pool_size, timeout: 0.1)

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
  check_enum(PG_DB, logger, "privacy", PlaylistPrivacy)

  check_table(PG_DB, logger, "channels", InvidiousChannel)
  check_table(PG_DB, logger, "channel_videos", ChannelVideo)
  check_table(PG_DB, logger, "playlists", InvidiousPlaylist)
  check_table(PG_DB, logger, "playlist_videos", PlaylistVideo)
  check_table(PG_DB, logger, "nonces", Nonce)
  check_table(PG_DB, logger, "session_ids", SessionId)
  check_table(PG_DB, logger, "users", User)
  check_table(PG_DB, logger, "videos", Video)

  if CONFIG.cache_annotations
    check_table(PG_DB, logger, "annotations", Annotation)
  end
end

# Start jobs

Invidious::Jobs.register Invidious::Jobs::RefreshChannelsJob.new(PG_DB, logger, config)
Invidious::Jobs.register Invidious::Jobs::RefreshFeedsJob.new(PG_DB, logger, config)
Invidious::Jobs.register Invidious::Jobs::SubscribeToFeedsJob.new(PG_DB, logger, config, HMAC_KEY)
Invidious::Jobs.register Invidious::Jobs::PullPopularVideosJob.new(PG_DB)
Invidious::Jobs.register Invidious::Jobs::UpdateDecryptFunctionJob.new

if config.statistics_enabled
  Invidious::Jobs.register Invidious::Jobs::StatisticsRefreshJob.new(PG_DB, config, SOFTWARE)
end

if config.captcha_key
  Invidious::Jobs.register Invidious::Jobs::BypassCaptchaJob.new(logger, config)
end

connection_channel = Channel({Bool, Channel(PQ::Notification)}).new(32)
Invidious::Jobs.register Invidious::Jobs::NotificationJob.new(connection_channel, PG_URL)

Invidious::Jobs.start_all

def popular_videos
  Invidious::Jobs::PullPopularVideosJob::POPULAR_VIDEOS.get
end

DECRYPT_FUNCTION = Invidious::Jobs::UpdateDecryptFunctionJob::DECRYPT_FUNCTION

before_all do |env|
  preferences = begin
    Preferences.from_json(env.request.cookies["PREFS"]?.try &.value || "{}")
  rescue
    Preferences.from_json("{}")
  end

  env.set "preferences", preferences
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
  env.response.headers["X-Content-Type-Options"] = "nosniff"
  extra_media_csp = ""
  if CONFIG.disabled?("local") || !preferences.local
    extra_media_csp += " https://*.googlevideo.com:443"
  end
  # TODO: Remove style-src's 'unsafe-inline', requires to remove all inline styles (<style> [..] </style>, style=" [..] ")
  env.response.headers["Content-Security-Policy"] = "default-src 'none'; script-src 'self'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; font-src 'self' data:; connect-src 'self'; manifest-src 'self'; media-src 'self' blob:#{extra_media_csp}"
  env.response.headers["Referrer-Policy"] = "same-origin"

  if (Kemal.config.ssl || config.https_only) && config.hsts
    env.response.headers["Strict-Transport-Security"] = "max-age=31536000; includeSubDomains; preload"
  end

  next if {
            "/sb/",
            "/vi/",
            "/s_p/",
            "/yts/",
            "/ggpht/",
            "/api/manifest/",
            "/videoplayback",
            "/latest_version",
          }.any? { |r| env.request.resource.starts_with? r }

  if env.request.cookies.has_key? "SID"
    sid = env.request.cookies["SID"].value

    if sid.starts_with? "v1:"
      raise "Cannot use token as SID"
    end

    # Invidious users only have SID
    if !env.request.cookies.has_key? "SSID"
      if email = PG_DB.query_one?("SELECT email FROM session_ids WHERE id = $1", sid, as: String)
        user = PG_DB.query_one("SELECT * FROM users WHERE email = $1", email, as: User)
        csrf_token = generate_response(sid, {
          ":authorize_token",
          ":playlist_ajax",
          ":signout",
          ":subscription_ajax",
          ":token_ajax",
          ":watch_ajax",
        }, HMAC_KEY, PG_DB, 1.week)

        preferences = user.preferences
        env.set "preferences", preferences

        env.set "sid", sid
        env.set "csrf_token", csrf_token
        env.set "user", user
      end
    else
      headers = HTTP::Headers.new
      headers["Cookie"] = env.request.headers["Cookie"]

      begin
        user, sid = get_user(sid, headers, PG_DB, false)
        csrf_token = generate_response(sid, {
          ":authorize_token",
          ":playlist_ajax",
          ":signout",
          ":subscription_ajax",
          ":token_ajax",
          ":watch_ajax",
        }, HMAC_KEY, PG_DB, 1.week)

        preferences = user.preferences
        env.set "preferences", preferences

        env.set "sid", sid
        env.set "csrf_token", csrf_token
        env.set "user", user
      rescue ex
      end
    end
  end

  dark_mode = convert_theme(env.params.query["dark_mode"]?) || preferences.dark_mode.to_s
  thin_mode = env.params.query["thin_mode"]? || preferences.thin_mode.to_s
  thin_mode = thin_mode == "true"
  locale = env.params.query["hl"]? || preferences.locale

  preferences.dark_mode = dark_mode
  preferences.thin_mode = thin_mode
  preferences.locale = locale

  current_page = env.request.path
  if env.request.query
    query = HTTP::Params.parse(env.request.query.not_nil!)

    if query["referer"]?
      query["referer"] = get_referer(env, "/")
    end

    current_page += "?#{query}"
  end

  env.set "current_page", URI.encode_www_form(current_page)
end

Invidious::Routing.get "/", Invidious::Routes::Home
Invidious::Routing.get "/privacy", Invidious::Routes::Privacy
Invidious::Routing.get "/licenses", Invidious::Routes::Licenses

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
      env.response.status_code = 400
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

  plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
  continuation = process_continuation(PG_DB, env.params.query, plid, id)

  nojs = env.params.query["nojs"]?

  nojs ||= "0"
  nojs = nojs == "1"

  preferences = env.get("preferences").as(Preferences)

  user = env.get?("user").try &.as(User)
  if user
    subscriptions = user.subscriptions
    watched = user.watched
    notifications = user.notifications
  end
  subscriptions ||= [] of String

  params = process_video_params(env.params.query, preferences)
  env.params.query.delete_all("listen")

  begin
    video = get_video(id, PG_DB, region: params.region)
  rescue ex : VideoRedirect
    next env.redirect env.request.resource.gsub(id, ex.video_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    logger.puts("#{id} : #{ex.message}")
    next templated "error"
  end

  if preferences.annotations_subscribed &&
     subscriptions.includes?(video.ucid) &&
     (env.params.query["iv_load_policy"]? || "1") == "1"
    params.annotations = true
  end
  env.params.query.delete_all("iv_load_policy")

  if watched && !watched.includes? id
    PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
  end

  if notifications && notifications.includes? id
    PG_DB.exec("UPDATE users SET notifications = array_remove(notifications, $1) WHERE email = $2", id, user.as(User).email)
    env.get("user").as(User).notifications.delete(id)
    notifications.delete(id)
  end

  if nojs
    if preferences
      source = preferences.comments[0]
      if source.empty?
        source = preferences.comments[1]
      end

      if source == "youtube"
        begin
          comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
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
            comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
          end
        end
      end
    else
      comment_html = JSON.parse(fetch_youtube_comments(id, PG_DB, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
    end

    comment_html ||= ""
  end

  fmt_stream = video.fmt_stream
  adaptive_fmts = video.adaptive_fmts

  if params.local
    fmt_stream.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
    adaptive_fmts.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
  end

  video_streams = video.video_streams
  audio_streams = video.audio_streams

  # Older videos may not have audio sources available.
  # We redirect here so they're not unplayable
  if audio_streams.empty? && !video.live_now
    if params.quality == "dash"
      env.params.query.delete_all("quality")
      env.params.query["quality"] = "medium"
      next env.redirect "/watch?#{env.params.query}"
    elsif params.listen
      env.params.query.delete_all("listen")
      env.params.query["listen"] = "0"
      next env.redirect "/watch?#{env.params.query}"
    end
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

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params.raw
    if params.listen
      url = audio_streams[0]["url"].as_s

      audio_streams.each do |fmt|
        if fmt["bitrate"].as_i == params.quality.rchop("k").to_i
          url = fmt["url"].as_s
        end
      end
    else
      url = fmt_stream[0]["url"].as_s

      fmt_stream.each do |fmt|
        if fmt["quality"].as_s == params.quality
          url = fmt["url"].as_s
        end
      end
    end

    next env.redirect url
  end

  templated "watch"
end

get "/embed/" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  if plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    begin
      playlist = get_playlist(PG_DB, plid, locale: locale)
      offset = env.params.query["index"]?.try &.to_i? || 0
      videos = get_playlist_videos(PG_DB, playlist, offset: offset, locale: locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 500
      next templated "error"
    end

    url = "/embed/#{videos[0].id}?#{env.params.query}"

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end
  else
    url = "/"
  end

  env.redirect url
end

get "/embed/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  id = env.params.url["id"]

  plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
  continuation = process_continuation(PG_DB, env.params.query, plid, id)

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
  case id
  when "videoseries"
    url = ""

    if plid
      begin
        playlist = get_playlist(PG_DB, plid, locale: locale)
        offset = env.params.query["index"]?.try &.to_i? || 0
        videos = get_playlist_videos(PG_DB, playlist, offset: offset, locale: locale)
      rescue ex
        error_message = ex.message
        env.response.status_code = 500
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
  when "live_stream"
    response = YT_POOL.client &.get("/embed/live_stream?channel=#{env.params.query["channel"]? || ""}")
    video_id = response.body.match(/"video_id":"(?<video_id>[a-zA-Z0-9_-]{11})"/).try &.["video_id"]

    env.params.query.delete_all("channel")

    if !video_id || video_id == "live_stream"
      error_message = "Video is unavailable."
      next templated "error"
    end

    url = "/embed/#{video_id}"

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    next env.redirect url
  when id.size > 11
    url = "/embed/#{id[0, 11]}"

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    next env.redirect url
  else nil # Continue
  end

  params = process_video_params(env.params.query, preferences)

  user = env.get?("user").try &.as(User)
  if user
    subscriptions = user.subscriptions
    watched = user.watched
    notifications = user.notifications
  end
  subscriptions ||= [] of String

  begin
    video = get_video(id, PG_DB, region: params.region)
  rescue ex : VideoRedirect
    next env.redirect env.request.resource.gsub(id, ex.video_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  if preferences.annotations_subscribed &&
     subscriptions.includes?(video.ucid) &&
     (env.params.query["iv_load_policy"]? || "1") == "1"
    params.annotations = true
  end

  # if watched && !watched.includes? id
  #   PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
  # end

  if notifications && notifications.includes? id
    PG_DB.exec("UPDATE users SET notifications = array_remove(notifications, $1) WHERE email = $2", id, user.as(User).email)
    env.get("user").as(User).notifications.delete(id)
    notifications.delete(id)
  end

  fmt_stream = video.fmt_stream
  adaptive_fmts = video.adaptive_fmts

  if params.local
    fmt_stream.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
    adaptive_fmts.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
  end

  video_streams = video.video_streams
  audio_streams = video.audio_streams

  if audio_streams.empty? && !video.live_now
    if params.quality == "dash"
      env.params.query.delete_all("quality")
      next env.redirect "/embed/#{id}?#{env.params.query}"
    elsif params.listen
      env.params.query.delete_all("listen")
      env.params.query["listen"] = "0"
      next env.redirect "/embed/#{id}?#{env.params.query}"
    end
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

  aspect_ratio = nil

  thumbnail = "/vi/#{video.id}/maxres.jpg"

  if params.raw
    url = fmt_stream[0]["url"].as_s

    fmt_stream.each do |fmt|
      url = fmt["url"].as_s if fmt["quality"].as_s == params.quality
    end

    next env.redirect url
  end

  rendered "embed"
end

# Playlists

get "/feed/playlists" do |env|
  env.redirect "/view_all_playlists"
end

get "/view_all_playlists" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)

  items_created = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1 AND id LIKE 'IV%' ORDER BY created", user.email, as: InvidiousPlaylist)
  items_created.map! do |item|
    item.author = ""
    item
  end

  items_saved = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1 AND id NOT LIKE 'IV%' ORDER BY created", user.email, as: InvidiousPlaylist)
  items_saved.map! do |item|
    item.author = ""
    item
  end

  templated "view_all_playlists"
end

get "/create_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":create_playlist"}, HMAC_KEY, PG_DB)

  templated "create_playlist"
end

post "/create_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

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

  title = env.params.body["title"]?.try &.as(String)
  if !title || title.empty?
    error_message = "Title cannot be empty."
    next templated "error"
  end

  privacy = PlaylistPrivacy.parse?(env.params.body["privacy"]?.try &.as(String) || "")
  if !privacy
    error_message = "Invalid privacy setting."
    next templated "error"
  end

  if PG_DB.query_one("SELECT count(*) FROM playlists WHERE author = $1", user.email, as: Int64) >= 100
    error_message = "User cannot have more than 100 playlists."
    next templated "error"
  end

  playlist = create_playlist(PG_DB, title, privacy, user)

  env.redirect "/playlist?list=#{playlist.id}"
end

get "/subscribe_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)

  playlist_id = env.params.query["list"]
  playlist = get_playlist(PG_DB, playlist_id, locale)
  subscribe_playlist(PG_DB, user, playlist)

  env.redirect "/playlist?list=#{playlist.id}"
end

get "/delete_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)
  sid = sid.as(String)

  plid = env.params.query["list"]?
  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email
    next env.redirect referer
  end

  csrf_token = generate_response(sid, {":delete_playlist"}, HMAC_KEY, PG_DB)

  templated "delete_playlist"
end

post "/delete_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  plid = env.params.query["list"]?
  if !plid
    next env.redirect referer
  end

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

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email
    next env.redirect referer
  end

  PG_DB.exec("DELETE FROM playlist_videos * WHERE plid = $1", plid)
  PG_DB.exec("DELETE FROM playlists * WHERE id = $1", plid)

  env.redirect "/view_all_playlists"
end

get "/edit_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)
  sid = sid.as(String)

  plid = env.params.query["list"]?
  if !plid || !plid.starts_with?("IV")
    next env.redirect referer
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  begin
    playlist = PG_DB.query_one("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      next env.redirect referer
    end
  rescue ex
    next env.redirect referer
  end

  begin
    videos = get_playlist_videos(PG_DB, playlist, offset: (page - 1) * 100, locale: locale)
  rescue ex
    videos = [] of PlaylistVideo
  end

  csrf_token = generate_response(sid, {":edit_playlist"}, HMAC_KEY, PG_DB)

  templated "edit_playlist"
end

post "/edit_playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  plid = env.params.query["list"]?
  if !plid
    next env.redirect referer
  end

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

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email
    next env.redirect referer
  end

  title = env.params.body["title"]?.try &.delete("<>") || ""
  privacy = PlaylistPrivacy.parse(env.params.body["privacy"]? || "Public")
  description = env.params.body["description"]?.try &.delete("\r") || ""

  if title != playlist.title ||
     privacy != playlist.privacy ||
     description != playlist.description
    updated = Time.utc
  else
    updated = playlist.updated
  end

  PG_DB.exec("UPDATE playlists SET title = $1, privacy = $2, description = $3, updated = $4 WHERE id = $5", title, privacy, description, updated, plid)

  env.redirect "/playlist?list=#{plid}"
end

get "/add_playlist_items" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect "/"
  end

  user = user.as(User)
  sid = sid.as(String)

  plid = env.params.query["list"]?
  if !plid || !plid.starts_with?("IV")
    next env.redirect referer
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  begin
    playlist = PG_DB.query_one("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      next env.redirect referer
    end
  rescue ex
    next env.redirect referer
  end

  query = env.params.query["q"]?
  if query
    begin
      search_query, count, items = process_search_query(query, page, user, region: nil)
      videos = items.select { |item| item.is_a? SearchVideo }.map { |item| item.as(SearchVideo) }
    rescue ex
      videos = [] of SearchVideo
      count = 0
    end
  else
    videos = [] of SearchVideo
    count = 0
  end

  env.set "add_playlist_items", plid
  templated "add_playlist_items"
end

post "/playlist_ajax" do |env|
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

  if env.params.query["action_create_playlist"]?
    action = "action_create_playlist"
  elsif env.params.query["action_delete_playlist"]?
    action = "action_delete_playlist"
  elsif env.params.query["action_edit_playlist"]?
    action = "action_edit_playlist"
  elsif env.params.query["action_add_video"]?
    action = "action_add_video"
    video_id = env.params.query["video_id"]
  elsif env.params.query["action_remove_video"]?
    action = "action_remove_video"
  elsif env.params.query["action_move_video_before"]?
    action = "action_move_video_before"
  else
    next env.redirect referer
  end

  begin
    playlist_id = env.params.query["playlist_id"]
    playlist = get_playlist(PG_DB, playlist_id, locale).as(InvidiousPlaylist)
    raise "Invalid user" if playlist.author != user.email
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

  if !user.password
    # TODO: Playlist stub, sync with YouTube for Google accounts
    # playlist_ajax(playlist_id, action, env.request.headers)
  end
  email = user.email

  case action
  when "action_edit_playlist"
    # TODO: Playlist stub
  when "action_add_video"
    if playlist.index.size >= 500
      env.response.status_code = 400
      if redirect
        error_message = "Playlist cannot have more than 500 videos"
        next templated "error"
      else
        error_message = {"error" => "Playlist cannot have more than 500 videos"}.to_json
        next error_message
      end
    end

    video_id = env.params.query["video_id"]

    begin
      video = get_video(video_id, PG_DB)
    rescue ex
      env.response.status_code = 500
      if redirect
        error_message = ex.message
        next templated "error"
      else
        error_message = {"error" => ex.message}.to_json
        next error_message
      end
    end

    playlist_video = PlaylistVideo.new({
      title:          video.title,
      id:             video.id,
      author:         video.author,
      ucid:           video.ucid,
      length_seconds: video.length_seconds,
      published:      video.published,
      plid:           playlist_id,
      live_now:       video.live_now,
      index:          Random::Secure.rand(0_i64..Int64::MAX),
    })

    video_array = playlist_video.to_a
    args = arg_array(video_array)

    PG_DB.exec("INSERT INTO playlist_videos VALUES (#{args})", args: video_array)
    PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = cardinality(index), updated = $2 WHERE id = $3", playlist_video.index, Time.utc, playlist_id)
  when "action_remove_video"
    index = env.params.query["set_video_id"]
    PG_DB.exec("DELETE FROM playlist_videos * WHERE index = $1", index)
    PG_DB.exec("UPDATE playlists SET index = array_remove(index, $1), video_count = cardinality(index), updated = $2 WHERE id = $3", index, Time.utc, playlist_id)
  when "action_move_video_before"
    # TODO: Playlist stub
  else
    error_message = {"error" => "Unsupported action #{action}"}.to_json
    env.response.status_code = 400
    next error_message
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
end

get "/playlist" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get?("user").try &.as(User)
  referer = get_referer(env)

  plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
  if !plid
    next env.redirect "/"
  end

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if plid.starts_with? "RD"
    next env.redirect "/mix?list=#{plid}"
  end

  begin
    playlist = get_playlist(PG_DB, plid, locale)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  if playlist.privacy == PlaylistPrivacy::Private && playlist.author != user.try &.email
    error_message = "This playlist is private."
    env.response.status_code = 403
    next templated "error"
  end

  begin
    videos = get_playlist_videos(PG_DB, playlist, offset: (page - 1) * 100, locale: locale)
  rescue ex
    videos = [] of PlaylistVideo
  end

  if playlist.author == user.try &.email
    env.set "remove_playlist_items", plid
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
    env.response.status_code = 500
    next templated "error"
  end

  templated "mix"
end

# Search

get "/opensearch.xml" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  env.response.content_type = "application/opensearchdescription+xml"

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("OpenSearchDescription", xmlns: "http://a9.com/-/spec/opensearch/1.1/") do
      xml.element("ShortName") { xml.text "Invidious" }
      xml.element("LongName") { xml.text "Invidious Search" }
      xml.element("Description") { xml.text "Search for videos, channels, and playlists on Invidious" }
      xml.element("InputEncoding") { xml.text "UTF-8" }
      xml.element("Image", width: 48, height: 48, type: "image/x-icon") { xml.text "#{HOST_URL}/favicon.ico" }
      xml.element("Url", type: "text/html", method: "get", template: "#{HOST_URL}/search?q={searchTerms}")
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
    env.redirect "/search?q=#{URI.encode_www_form(query)}&page=#{page}"
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

  begin
    search_query, count, videos = process_search_query(query, page, user, region: nil)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  env.set "search", query
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
    env.response.status_code = 400
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
  prompt = nil

  templated "login"
end

post "/login" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  referer = get_referer(env, "/feed/subscriptions")

  if !config.login_enabled
    error_message = "Login has been disabled by administrator."
    env.response.status_code = 403
    next templated "error"
  end

  # https://stackoverflow.com/a/574698
  email = env.params.body["email"]?.try &.downcase.byte_slice(0, 254)
  password = env.params.body["password"]?

  account_type = env.params.query["type"]?
  account_type ||= "invidious"

  case account_type
  when "google"
    tfa_code = env.params.body["tfa"]?.try &.lchop("G-")
    traceback = IO::Memory.new

    # See https://github.com/ytdl-org/youtube-dl/blob/2019.04.07/youtube_dl/extractor/youtube.py#L82
    begin
      client = QUIC::Client.new(LOGIN_URL)
      headers = HTTP::Headers.new

      login_page = client.get("/ServiceLogin")
      headers = login_page.cookies.add_request_headers(headers)

      lookup_req = {
        email, nil, [] of String, nil, "US", nil, nil, 2, false, true,
        {nil, nil,
         {2, 1, nil, 1,
          "https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn",
          nil, [] of String, 4},
         1,
         {nil, nil, [] of String},
         nil, nil, nil, true,
        },
        email,
      }.to_json

      traceback << "Getting lookup..."

      headers["Content-Type"] = "application/x-www-form-urlencoded;charset=utf-8"
      headers["Google-Accounts-XSRF"] = "1"

      response = client.post("/_/signin/sl/lookup", headers, login_req(lookup_req))
      lookup_results = JSON.parse(response.body[5..-1])

      traceback << "done, returned #{response.status_code}.<br/>"

      user_hash = lookup_results[0][2]

      if token = env.params.body["token"]?
        answer = env.params.body["answer"]?
        captcha = {token, answer}
      else
        captcha = nil
      end

      challenge_req = {
        user_hash, nil, 1, nil,
        {1, nil, nil, nil,
         {password, captcha, true},
        },
        {nil, nil,
         {2, 1, nil, 1,
          "https://accounts.google.com/ServiceLogin?passive=true&continue=https%3A%2F%2Fwww.youtube.com%2Fsignin%3Fnext%3D%252F%26action_handle_signin%3Dtrue%26hl%3Den%26app%3Ddesktop%26feature%3Dsign_in_button&hl=en&service=youtube&uilel=3&requestPath=%2FServiceLogin&Page=PasswordSeparationSignIn",
          nil, [] of String, 4},
         1,
         {nil, nil, [] of String},
         nil, nil, nil, true,
        },
      }.to_json

      traceback << "Getting challenge..."

      response = client.post("/_/signin/sl/challenge", headers, login_req(challenge_req))
      headers = response.cookies.add_request_headers(headers)
      challenge_results = JSON.parse(response.body[5..-1])

      traceback << "done, returned #{response.status_code}.<br/>"

      headers["Cookie"] = URI.decode_www_form(headers["Cookie"])

      if challenge_results[0][3]?.try &.== 7
        error_message = translate(locale, "Account has temporarily been disabled")
        env.response.status_code = 423
        next templated "error"
      end

      if token = challenge_results[0][-1]?.try &.[-1]?.try &.as_h?.try &.["5001"]?.try &.[-1].as_a?.try &.[-1].as_s
        account_type = "google"
        captcha_type = "image"
        prompt = nil
        tfa = tfa_code
        captcha = {tokens: [token], question: ""}

        next templated "login"
      end

      if challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED"
        error_message = translate(locale, "Incorrect password")
        env.response.status_code = 401
        next templated "error"
      end

      prompt_type = challenge_results[0][-1]?.try &.[0].as_a?.try &.[0][2]?
      if {"TWO_STEP_VERIFICATION", "LOGIN_CHALLENGE"}.includes? prompt_type
        traceback << "Handling prompt #{prompt_type}.<br/>"
        case prompt_type
        when "TWO_STEP_VERIFICATION"
          prompt_type = 2
        else # "LOGIN_CHALLENGE"
          prompt_type = 4
        end

        # Prefer Authenticator app and SMS over unsupported protocols
        if !{6, 9, 12, 15}.includes?(challenge_results[0][-1][0][0][8].as_i) && prompt_type == 2
          tfa = challenge_results[0][-1][0].as_a.select { |auth_type| {6, 9, 12, 15}.includes? auth_type[8] }[0]

          traceback << "Selecting challenge #{tfa[8]}..."
          select_challenge = {prompt_type, nil, nil, nil, {tfa[8]}}.to_json

          tl = challenge_results[1][2]

          tfa = client.post("/_/signin/selectchallenge?TL=#{tl}", headers, login_req(select_challenge)).body
          tfa = tfa[5..-1]
          tfa = JSON.parse(tfa)[0][-1]

          traceback << "done.<br/>"
        else
          traceback << "Using challenge #{challenge_results[0][-1][0][0][8]}.<br/>"
          tfa = challenge_results[0][-1][0][0]
        end

        if tfa[5] == "QUOTA_EXCEEDED"
          error_message = translate(locale, "Quota exceeded, try again in a few hours")
          env.response.status_code = 423
          next templated "error"
        end

        if !tfa_code
          account_type = "google"
          captcha_type = "image"

          case tfa[8]
          when 6, 9
            prompt = "Google verification code"
          when 12
            prompt = "Login verification, recovery email: #{tfa[-1][tfa[-1].as_h.keys[0]][0]}"
          when 15
            prompt = "Login verification, security question: #{tfa[-1][tfa[-1].as_h.keys[0]][0]}"
          else
            prompt = "Google verification code"
          end

          tfa = nil
          captcha = nil
          next templated "login"
        end

        tl = challenge_results[1][2]

        request_type = tfa[8]
        case request_type
        when 6 # Authenticator app
          tfa_req = {
            user_hash, nil, 2, nil,
            {6, nil, nil, nil, nil,
             {tfa_code, false},
            },
          }.to_json
        when 9 # Voice or text message
          tfa_req = {
            user_hash, nil, 2, nil,
            {9, nil, nil, nil, nil, nil, nil, nil,
             {nil, tfa_code, false, 2},
            },
          }.to_json
        when 12 # Recovery email
          tfa_req = {
            user_hash, nil, 4, nil,
            {12, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
             {tfa_code},
            },
          }.to_json
        when 15 # Security question
          tfa_req = {
            user_hash, nil, 5, nil,
            {15, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil, nil,
             {tfa_code},
            },
          }.to_json
        else
          error_message = translate(locale, "Unable to log in, make sure two-factor authentication (Authenticator or SMS) is turned on.")
          env.response.status_code = 500
          next templated "error"
        end

        traceback << "Submitting challenge..."

        response = client.post("/_/signin/challenge?hl=en&TL=#{tl}", headers, login_req(tfa_req))
        headers = response.cookies.add_request_headers(headers)
        challenge_results = JSON.parse(response.body[5..-1])

        if (challenge_results[0][-1]?.try &.[5] == "INCORRECT_ANSWER_ENTERED") ||
           (challenge_results[0][-1]?.try &.[5] == "INVALID_INPUT")
          error_message = translate(locale, "Invalid TFA code")
          env.response.status_code = 401
          next templated "error"
        end

        traceback << "done.<br/>"
      end

      traceback << "Logging in..."

      location = URI.parse(challenge_results[0][-1][2].to_s)
      cookies = HTTP::Cookies.from_headers(headers)

      headers.delete("Content-Type")
      headers.delete("Google-Accounts-XSRF")

      loop do
        if !location || location.path == "/ManageAccount"
          break
        end

        # Occasionally there will be a second page after login confirming
        # the user's phone number ("/b/0/SmsAuthInterstitial"), which we currently don't handle.

        if location.path.starts_with? "/b/0/SmsAuthInterstitial"
          traceback << "Unhandled dialog /b/0/SmsAuthInterstitial."
        end

        login = client.get(location.full_path, headers)

        headers = login.cookies.add_request_headers(headers)
        location = login.headers["Location"]?.try { |u| URI.parse(u) }
      end

      cookies = HTTP::Cookies.from_headers(headers)
      sid = cookies["SID"]?.try &.value
      if !sid
        raise "Couldn't get SID."
      end

      user, sid = get_user(sid, headers, PG_DB)

      # We are now logged in
      traceback << "done.<br/>"

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
        cookie.expires = Time.utc(1990, 1, 1)
        env.response.cookies << cookie
      end

      env.redirect referer
    rescue ex
      traceback.rewind
      # error_message = translate(locale, "Login failed. This may be because two-factor authentication is not turned on for your account.")
      error_message = %(#{ex.message}<br/>Traceback:<br/><div style="padding-left:2em" id="traceback">#{traceback.gets_to_end}</div>)
      env.response.status_code = 500
      next templated "error"
    end
  when "invidious"
    if !email
      error_message = translate(locale, "User ID is a required field")
      env.response.status_code = 401
      next templated "error"
    end

    if !password
      error_message = translate(locale, "Password is a required field")
      env.response.status_code = 401
      next templated "error"
    end

    user = PG_DB.query_one?("SELECT * FROM users WHERE email = $1", email, as: User)

    if user
      if !user.password
        error_message = translate(locale, "Please sign in using 'Log in with Google'")
        env.response.status_code = 400
        next templated "error"
      end

      if Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
        sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
        PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.utc)

        if Kemal.config.ssl || config.https_only
          secure = true
        else
          secure = false
        end

        if config.domain
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{config.domain}", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true)
        else
          env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.utc + 2.years,
            secure: secure, http_only: true)
        end
      else
        error_message = translate(locale, "Wrong username or password")
        env.response.status_code = 401
        next templated "error"
      end

      # Since this user has already registered, we don't want to overwrite their preferences
      if env.request.cookies["PREFS"]?
        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.utc(1990, 1, 1)
        env.response.cookies << cookie
      end
    else
      if !config.registration_enabled
        error_message = "Registration has been disabled by administrator."
        env.response.status_code = 400
        next templated "error"
      end

      if password.empty?
        error_message = translate(locale, "Password cannot be empty")
        env.response.status_code = 401
        next templated "error"
      end

      # See https://security.stackexchange.com/a/39851
      if password.bytesize > 55
        error_message = translate(locale, "Password should not be longer than 55 characters")
        env.response.status_code = 400
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
          prompt = ""

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
        else # "text"
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
            env.response.status_code = 500
            next templated "error"
          end
        end
      end

      sid = Base64.urlsafe_encode(Random::Secure.random_bytes(32))
      user, sid = create_user(sid, email, password)
      user_array = user.to_a
      user_array[4] = user_array[4].to_json # User preferences

      args = arg_array(user_array)

      PG_DB.exec("INSERT INTO users VALUES (#{args})", args: user_array)
      PG_DB.exec("INSERT INTO session_ids VALUES ($1, $2, $3)", sid, email, Time.utc)

      view_name = "subscriptions_#{sha256(user.email)}"
      PG_DB.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(user.email)}")

      if Kemal.config.ssl || config.https_only
        secure = true
      else
        secure = false
      end

      if config.domain
        env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", domain: "#{config.domain}", value: sid, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["SID"] = HTTP::Cookie.new(name: "SID", value: sid, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      end

      if env.request.cookies["PREFS"]?
        preferences = env.get("preferences").as(Preferences)
        PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)

        cookie = env.request.cookies["PREFS"]
        cookie.expires = Time.utc(1990, 1, 1)
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

  if !user
    next env.redirect referer
  end

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
    cookie.expires = Time.utc(1990, 1, 1)
    env.response.cookies << cookie
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

  speed = env.params.body["speed"]?.try &.as(String).to_f32?
  speed ||= CONFIG.default_user_preferences.speed

  player_style = env.params.body["player_style"]?.try &.as(String)
  player_style ||= CONFIG.default_user_preferences.player_style

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

  default_home = env.params.body["default_home"]?.try &.as(String) || CONFIG.default_user_preferences.default_home

  feed_menu = [] of String
  5.times do |index|
    option = env.params.body["feed_menu[#{index}]"]?.try &.as(String) || ""
    if !option.empty?
      feed_menu << option
    end
  end

  locale = env.params.body["locale"]?.try &.as(String)
  locale ||= CONFIG.default_user_preferences.locale

  dark_mode = env.params.body["dark_mode"]?.try &.as(String)
  dark_mode ||= CONFIG.default_user_preferences.dark_mode

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

  # Convert to JSON and back again to take advantage of converters used for compatability
  preferences = Preferences.from_json({
    annotations:            annotations,
    annotations_subscribed: annotations_subscribed,
    autoplay:               autoplay,
    captions:               captions,
    comments:               comments,
    continue:               continue,
    continue_autoplay:      continue_autoplay,
    dark_mode:              dark_mode,
    latest_only:            latest_only,
    listen:                 listen,
    local:                  local,
    locale:                 locale,
    max_results:            max_results,
    notifications_only:     notifications_only,
    player_style:           player_style,
    quality:                quality,
    default_home:           default_home,
    feed_menu:              feed_menu,
    related_videos:         related_videos,
    sort:                   sort,
    speed:                  speed,
    thin_mode:              thin_mode,
    unseen_only:            unseen_only,
    video_loop:             video_loop,
    volume:                 volume,
  }.to_json).to_json

  if user = env.get? "user"
    user = user.as(User)
    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)

    if config.admins.includes? user.email
      config.default_user_preferences.default_home = env.params.body["admin_default_home"]?.try &.as(String) || config.default_user_preferences.default_home

      admin_feed_menu = [] of String
      5.times do |index|
        option = env.params.body["admin_feed_menu[#{index}]"]?.try &.as(String) || ""
        if !option.empty?
          admin_feed_menu << option
        end
      end
      config.default_user_preferences.feed_menu = admin_feed_menu

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

      CONFIG.default_user_preferences = config.default_user_preferences
      File.write("config/config.yml", config.to_yaml)
    end
  else
    if Kemal.config.ssl || config.https_only
      secure = true
    else
      secure = false
    end

    if config.domain
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{config.domain}", value: preferences, expires: Time.utc + 2.years,
        secure: secure, http_only: true)
    else
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.utc + 2.years,
        secure: secure, http_only: true)
    end
  end

  env.redirect referer
end

get "/toggle_theme" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  referer = get_referer(env, unroll: false)

  redirect = env.params.query["redirect"]?
  redirect ||= "true"
  redirect = redirect == "true"

  if user = env.get? "user"
    user = user.as(User)
    preferences = user.preferences

    case preferences.dark_mode
    when "dark"
      preferences.dark_mode = "light"
    else
      preferences.dark_mode = "dark"
    end

    preferences = preferences.to_json

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)
  else
    preferences = env.get("preferences").as(Preferences)

    case preferences.dark_mode
    when "dark"
      preferences.dark_mode = "light"
    else
      preferences.dark_mode = "dark"
    end

    preferences = preferences.to_json

    if Kemal.config.ssl || config.https_only
      secure = true
    else
      secure = false
    end

    if config.domain
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{config.domain}", value: preferences, expires: Time.utc + 2.years,
        secure: secure, http_only: true)
    else
      env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.utc + 2.years,
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
    env.response.status_code = 400
    if redirect
      error_message = ex.message
      next templated "error"
    else
      error_message = {"error" => ex.message}.to_json
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
      PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.email)
    end
  when "action_mark_unwatched"
    PG_DB.exec("UPDATE users SET watched = array_remove(watched, $1) WHERE email = $2", id, user.email)
  else
    error_message = {"error" => "Unsupported action #{action}"}.to_json
    env.response.status_code = 400
    next error_message
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

    html = YT_POOL.client &.get("/subscription_manager?disable_polymer=1", headers)

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

    if match = html.body.match(/'XSRF_TOKEN': "(?<session_token>[^"]+)"/)
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

      YT_POOL.client &.post("/subscription_ajax?action_update_subscription_preferences=1", headers, form: channel_req)
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

  if env.params.query["action_create_subscription_to_channel"]?.try &.to_i?.try &.== 1
    action = "action_create_subscription_to_channel"
  elsif env.params.query["action_remove_subscriptions"]?.try &.to_i?.try &.== 1
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
  when "action_create_subscription_to_channel"
    if !user.subscriptions.includes? channel_id
      get_channel(channel_id, PG_DB, false, false)
      PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_append(subscriptions, $1) WHERE email = $2", channel_id, email)
    end
  when "action_remove_subscriptions"
    PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_remove(subscriptions, $1) WHERE email = $2", channel_id, email)
  else
    error_message = {"error" => "Unsupported action #{action}"}.to_json
    env.response.status_code = 400
    next error_message
  end

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
    if format == "json"
      env.response.content_type = "application/json"
      env.response.headers["content-disposition"] = "attachment"
      playlists = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1 AND id LIKE 'IV%' ORDER BY created", user.email, as: InvidiousPlaylist)

      next JSON.build do |json|
        json.object do
          json.field "subscriptions", user.subscriptions
          json.field "watch_history", user.watched
          json.field "preferences", user.preferences
          json.field "playlists" do
            json.array do
              playlists.each do |playlist|
                json.object do
                  json.field "title", playlist.title
                  json.field "description", html_to_content(playlist.description_html)
                  json.field "privacy", playlist.privacy.to_s
                  json.field "videos" do
                    json.array do
                      PG_DB.query_all("SELECT id FROM playlist_videos WHERE plid = $1 ORDER BY array_position($2, index) LIMIT 500", playlist.id, playlist.index, as: String).each do |video_id|
                        json.string video_id
                      end
                    end
                  end
                end
              end
            end
          end
        end
      end
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
                  xmlUrl = "#{HOST_URL}/feed/channel/#{channel.id}"
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

  if !user
    next env.redirect referer
  end

  user = user.as(User)

  templated "data_control"
end

post "/data_control" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  referer = get_referer(env)

  if user
    user = user.as(User)

    # TODO: Find a way to prevent browser timeout

    HTTP::FormData.parse(env.request) do |part|
      body = part.body.gets_to_end
      next if body.empty?

      # TODO: Unify into single import based on content-type
      case part.name
      when "import_invidious"
        body = JSON.parse(body)

        if body["subscriptions"]?
          user.subscriptions += body["subscriptions"].as_a.map { |a| a.as_s }
          user.subscriptions.uniq!

          user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

          PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
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

        if playlists = body["playlists"]?.try &.as_a?
          playlists.each do |item|
            title = item["title"]?.try &.as_s?.try &.delete("<>")
            description = item["description"]?.try &.as_s?.try &.delete("\r")
            privacy = item["privacy"]?.try &.as_s?.try { |privacy| PlaylistPrivacy.parse? privacy }

            next if !title
            next if !description
            next if !privacy

            playlist = create_playlist(PG_DB, title, privacy, user)
            PG_DB.exec("UPDATE playlists SET description = $1 WHERE id = $2", description, playlist.id)

            videos = item["videos"]?.try &.as_a?.try &.each_with_index do |video_id, idx|
              raise "Playlist cannot have more than 500 videos" if idx > 500

              video_id = video_id.try &.as_s?
              next if !video_id

              begin
                video = get_video(video_id, PG_DB)
              rescue ex
                next
              end

              playlist_video = PlaylistVideo.new({
                title:          video.title,
                id:             video.id,
                author:         video.author,
                ucid:           video.ucid,
                length_seconds: video.length_seconds,
                published:      video.published,
                plid:           playlist.id,
                live_now:       video.live_now,
                index:          Random::Secure.rand(0_i64..Int64::MAX),
              })

              video_array = playlist_video.to_a
              args = arg_array(video_array)

              PG_DB.exec("INSERT INTO playlist_videos VALUES (#{args})", args: video_array)
              PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = cardinality(index), updated = $2 WHERE id = $3", playlist_video.index, Time.utc, playlist.id)
            end
          end
        end
      when "import_youtube"
        subscriptions = XML.parse(body)
        user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
          channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_freetube"
        user.subscriptions += body.scan(/"channelId":"(?<channel_id>[a-zA-Z0-9_-]{24})"/).map do |md|
          md["channel_id"]
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_newpipe_subscriptions"
        body = JSON.parse(body)
        user.subscriptions += body["subscriptions"].as_a.compact_map do |channel|
          if match = channel["url"].as_s.match(/\/channel\/(?<channel>UC[a-zA-Z0-9_-]{22})/)
            next match["channel"]
          elsif match = channel["url"].as_s.match(/\/user\/(?<user>.+)/)
            response = YT_POOL.client &.get("/user/#{match["user"]}?disable_polymer=1&hl=en&gl=US")
            html = XML.parse_html(response.body)
            ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]
            next ucid if ucid
          end

          nil
        end
        user.subscriptions.uniq!

        user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

        PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
      when "import_newpipe"
        Compress::Zip::Reader.open(IO::Memory.new(body)) do |file|
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

              PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)

              db.close
              tempfile.delete
            end
          end
        end
      else nil # Ignore
      end
    end
  end

  env.redirect referer
end

get "/change_password" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":change_password"}, HMAC_KEY, PG_DB)

  templated "change_password"
end

post "/change_password" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  # We don't store passwords for Google accounts
  if !user.password
    error_message = "Cannot change password for Google accounts"
    env.response.status_code = 400
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
    env.response.status_code = 401
    next templated "error"
  end

  new_passwords = env.params.body.select { |k, v| k.match(/^new_password\[\d+\]$/) }.map { |k, v| v }

  if new_passwords.size <= 1 || new_passwords.uniq.size != 1
    error_message = translate(locale, "New passwords must match")
    env.response.status_code = 400
    next templated "error"
  end

  new_password = new_passwords.uniq[0]
  if new_password.empty?
    error_message = translate(locale, "Password cannot be empty")
    env.response.status_code = 401
    next templated "error"
  end

  if new_password.bytesize > 55
    error_message = translate(locale, "Password should not be longer than 55 characters")
    env.response.status_code = 400
    next templated "error"
  end

  if !Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
    error_message = translate(locale, "Incorrect password")
    env.response.status_code = 401
    next templated "error"
  end

  new_password = Crypto::Bcrypt::Password.create(new_password, cost: 10)
  PG_DB.exec("UPDATE users SET password = $1 WHERE email = $2", new_password.to_s, user.email)

  env.redirect referer
end

get "/delete_account" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":delete_account"}, HMAC_KEY, PG_DB)

  templated "delete_account"
end

post "/delete_account" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

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
    cookie.expires = Time.utc(1990, 1, 1)
    env.response.cookies << cookie
  end

  env.redirect referer
end

get "/clear_watch_history" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":clear_watch_history"}, HMAC_KEY, PG_DB)

  templated "clear_watch_history"
end

post "/clear_watch_history" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

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
  env.redirect referer
end

get "/authorize_token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

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
end

post "/authorize_token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

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
    access_token = URI.encode_www_form(access_token)
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
      env.response.status_code = 400
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
  else
    error_message = {"error" => "Unsupported action #{action}"}.to_json
    env.response.status_code = 400
    next error_message
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
  env.redirect "/"
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
    trending, plid = fetch_trending(trending_type, region, locale)
  rescue ex
    error_message = "#{ex.message}"
    env.response.status_code = 500
    next templated "error"
  end

  templated "trending"
end

get "/feed/subscriptions" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  token = user.token

  if user.preferences.unseen_only
    env.set "show_watched", true
  end

  # Refresh account
  headers = HTTP::Headers.new
  headers["Cookie"] = env.request.headers["Cookie"]

  if !user.password
    user, sid = get_user(sid, headers, PG_DB)
  end

  max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
  max_results ||= user.preferences.max_results
  max_results ||= CONFIG.default_user_preferences.max_results

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  videos, notifications = get_subscription_feed(PG_DB, user, max_results, page)

  # "updated" here is used for delivering new notifications, so if
  # we know a user has looked at their feed e.g. in the past 10 minutes,
  # they've already seen a video posted 20 minutes ago, and don't need
  # to be notified.
  PG_DB.exec("UPDATE users SET notifications = $1, updated = $2 WHERE email = $3", [] of String, Time.utc,
    user.email)
  user.notifications = [] of String
  env.set "user", user

  templated "subscriptions"
end

get "/feed/history" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  referer = get_referer(env)

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  if !user
    next env.redirect referer
  end

  user = user.as(User)

  max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
  max_results ||= user.preferences.max_results
  max_results ||= CONFIG.default_user_preferences.max_results

  if user.watched[(page - 1) * max_results]?
    watched = user.watched.reverse[(page - 1) * max_results, max_results]
  end
  watched ||= [] of String

  templated "history"
end

get "/feed/channel/:ucid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/atom+xml"

  ucid = env.params.url["ucid"]

  params = HTTP::Params.parse(env.params.query["params"]? || "")

  begin
    channel = get_about_info(ucid, locale)
  rescue ex : ChannelRedirect
    next env.redirect env.request.resource.gsub(ucid, ex.channel_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next error_message
  end

  response = YT_POOL.client &.get("/feeds/videos.xml?channel_id=#{channel.ucid}")
  rss = XML.parse_html(response.body)

  videos = rss.xpath_nodes("//feed/entry").map do |entry|
    video_id = entry.xpath_node("videoid").not_nil!.content
    title = entry.xpath_node("title").not_nil!.content

    published = Time.parse_rfc3339(entry.xpath_node("published").not_nil!.content)
    updated = Time.parse_rfc3339(entry.xpath_node("updated").not_nil!.content)

    author = entry.xpath_node("author/name").not_nil!.content
    ucid = entry.xpath_node("channelid").not_nil!.content
    description_html = entry.xpath_node("group/description").not_nil!.to_s
    views = entry.xpath_node("group/community/statistics").not_nil!.["views"].to_i64

    SearchVideo.new({
      title:              title,
      id:                 video_id,
      author:             author,
      ucid:               ucid,
      published:          published,
      views:              views,
      description_html:   description_html,
      length_seconds:     0,
      live_now:           false,
      paid:               false,
      premium:            false,
      premiere_timestamp: nil,
    })
  end

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
      "xml:lang": "en-US") do
      xml.element("link", rel: "self", href: "#{HOST_URL}#{env.request.resource}")
      xml.element("id") { xml.text "yt:channel:#{channel.ucid}" }
      xml.element("yt:channelId") { xml.text channel.ucid }
      xml.element("title") { xml.text channel.author }
      xml.element("link", rel: "alternate", href: "#{HOST_URL}/channel/#{channel.ucid}")

      xml.element("author") do
        xml.element("name") { xml.text channel.author }
        xml.element("uri") { xml.text "#{HOST_URL}/channel/#{channel.ucid}" }
      end

      videos.each do |video|
        video.to_xml(channel.auto_generated, params, xml)
      end
    end
  end
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

  max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
  max_results ||= user.preferences.max_results
  max_results ||= CONFIG.default_user_preferences.max_results

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  params = HTTP::Params.parse(env.params.query["params"]? || "")

  videos, notifications = get_subscription_feed(PG_DB, user, max_results, page)

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
      "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
      "xml:lang": "en-US") do
      xml.element("link", "type": "text/html", rel: "alternate", href: "#{HOST_URL}/feed/subscriptions")
      xml.element("link", "type": "application/atom+xml", rel: "self",
        href: "#{HOST_URL}#{env.request.resource}")
      xml.element("title") { xml.text translate(locale, "Invidious Private Feed for `x`", user.email) }

      (notifications + videos).each do |video|
        video.to_xml(locale, params, xml)
      end
    end
  end
end

get "/feed/playlist/:plid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/atom+xml"

  plid = env.params.url["plid"]

  params = HTTP::Params.parse(env.params.query["params"]? || "")
  path = env.request.path

  if plid.starts_with? "IV"
    if playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
      videos = get_playlist_videos(PG_DB, playlist, offset: 0, locale: locale)

      next XML.build(indent: "  ", encoding: "UTF-8") do |xml|
        xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
          "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
          "xml:lang": "en-US") do
          xml.element("link", rel: "self", href: "#{HOST_URL}#{env.request.resource}")
          xml.element("id") { xml.text "iv:playlist:#{plid}" }
          xml.element("iv:playlistId") { xml.text plid }
          xml.element("title") { xml.text playlist.title }
          xml.element("link", rel: "alternate", href: "#{HOST_URL}/playlist?list=#{plid}")

          xml.element("author") do
            xml.element("name") { xml.text playlist.author }
          end

          videos.each do |video|
            video.to_xml(false, xml)
          end
        end
      end
    else
      env.response.status_code = 404
      next
    end
  end

  response = YT_POOL.client &.get("/feeds/videos.xml?playlist_id=#{plid}")
  document = XML.parse(response.body)

  document.xpath_nodes(%q(//*[@href]|//*[@url])).each do |node|
    node.attributes.each do |attribute|
      case attribute.name
      when "url", "href"
        full_path = URI.parse(node[attribute.name]).full_path
        query_string_opt = full_path.starts_with?("/watch?v=") ? "&#{params}" : ""
        node[attribute.name] = "#{HOST_URL}#{full_path}#{query_string_opt}"
      else nil # Skip
      end
    end
  end

  document = document.to_xml(options: XML::SaveOptions::NO_DECL)

  document.scan(/<uri>(?<url>[^<]+)<\/uri>/).each do |match|
    content = "#{HOST_URL}#{URI.parse(match["url"]).full_path}"
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

  mode = env.params.query["hub.mode"]?
  topic = env.params.query["hub.topic"]?
  challenge = env.params.query["hub.challenge"]?

  if !mode || !topic || !challenge
    env.response.status_code = 400
    next
  else
    mode = mode.not_nil!
    topic = topic.not_nil!
    challenge = challenge.not_nil!
  end

  case verify_token
  when .starts_with? "v1"
    _, time, nonce, signature = verify_token.split(":")
    data = "#{time}:#{nonce}"
  when .starts_with? "v2"
    time, signature = verify_token.split(":")
    data = "#{time}"
  else
    env.response.status_code = 400
    next
  end

  # The hub will sometimes check if we're still subscribed after delivery errors,
  # so we reply with a 200 as long as the request hasn't expired
  if Time.utc.to_unix - time.to_i > 432000
    env.response.status_code = 400
    next
  end

  if OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, data) != signature
    env.response.status_code = 400
    next
  end

  if ucid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["channel_id"]?
    PG_DB.exec("UPDATE channels SET subscribed = $1 WHERE id = $2", Time.utc, ucid)
  elsif plid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["playlist_id"]?
    PG_DB.exec("UPDATE playlists SET subscribed = $1 WHERE id = $2", Time.utc, ucid)
  else
    env.response.status_code = 400
    next
  end

  env.response.status_code = 200
  challenge
end

post "/feed/webhook/:token" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  token = env.params.url["token"]
  body = env.request.body.not_nil!.gets_to_end
  signature = env.request.headers["X-Hub-Signature"].lchop("sha1=")

  if signature != OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, body)
    logger.puts("#{token} : Invalid signature")
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

      video = get_video(id, PG_DB, force_refresh: true)

      # Deliver notifications to `/api/v1/auth/notifications`
      payload = {
        "topic"     => video.ucid,
        "videoId"   => video.id,
        "published" => published.to_unix,
      }.to_json
      PG_DB.exec("NOTIFY notifications, E'#{payload}'")

      video = ChannelVideo.new({
        id:                 id,
        title:              video.title,
        published:          published,
        updated:            updated,
        ucid:               video.ucid,
        author:             author,
        length_seconds:     video.length_seconds,
        live_now:           video.live_now,
        premiere_timestamp: video.premiere_timestamp,
        views:              video.views,
      })

      was_insert = PG_DB.query_one("INSERT INTO channel_videos VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) \
        ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
        updated = $4, ucid = $5, author = $6, length_seconds = $7, \
        live_now = $8, premiere_timestamp = $9, views = $10 returning (xmax=0) as was_insert", *video.to_tuple, as: Bool)

      PG_DB.exec("UPDATE users SET notifications = array_append(notifications, $1), \
        feed_needs_update = true WHERE $2 = ANY(subscriptions)", video.id, video.ucid) if was_insert
    end
  end

  env.response.status_code = 200
  next
end

# Channels

{"/channel/:ucid/live", "/user/:user/live", "/c/:user/live"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    # Appears to be a bug in routing, having several routes configured
    # as `/a/:a`, `/b/:a`, `/c/:a` results in 404
    value = env.request.resource.split("/")[2]
    body = ""
    {"channel", "user", "c"}.each do |type|
      response = YT_POOL.client &.get("/#{type}/#{value}/live?disable_polymer=1")
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

  user = env.params.url["user"]

  response = YT_POOL.client &.get("/c/#{user}")
  html = XML.parse_html(response.body)

  ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]
  next env.redirect "/" if !ucid

  env.redirect "/channel/#{ucid}"
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

get "/attribution_link" do |env|
  if query = env.params.query["u"]?
    url = URI.parse(query).full_path
  else
    url = "/"
  end

  env.redirect url
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

get "/user/:user/about" do |env|
  user = env.params.url["user"]
  env.redirect "/channel/#{user}"
end

get "/channel/:ucid/about" do |env|
  ucid = env.params.url["ucid"]
  env.redirect "/channel/#{ucid}"
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
    channel = get_about_info(ucid, locale)
  rescue ex : ChannelRedirect
    next env.redirect env.request.resource.gsub(ucid, ex.channel_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  if channel.auto_generated
    sort_options = {"last", "oldest", "newest"}
    sort_by ||= "last"

    items, continuation = fetch_channel_playlists(channel.ucid, channel.author, channel.auto_generated, continuation, sort_by)
    items.uniq! do |item|
      if item.responds_to?(:title)
        item.title
      elsif item.responds_to?(:author)
        item.author
      end
    end
    items = items.select(&.is_a?(SearchPlaylist)).map(&.as(SearchPlaylist))
    items.each { |item| item.author = "" }
  else
    sort_options = {"newest", "oldest", "popular"}
    sort_by ||= "newest"

    count, items = get_60_videos(channel.ucid, channel.author, page, channel.auto_generated, sort_by)
    items.reject! &.paid

    env.set "search", "channel:#{channel.ucid} "
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
    channel = get_about_info(ucid, locale)
  rescue ex : ChannelRedirect
    next env.redirect env.request.resource.gsub(ucid, ex.channel_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  if channel.auto_generated
    next env.redirect "/channel/#{channel.ucid}"
  end

  items, continuation = fetch_channel_playlists(channel.ucid, channel.author, channel.auto_generated, continuation, sort_by)
  items = items.select { |item| item.is_a?(SearchPlaylist) }.map { |item| item.as(SearchPlaylist) }
  items.each { |item| item.author = "" }

  env.set "search", "channel:#{channel.ucid} "
  templated "playlists"
end

get "/channel/:ucid/community" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  user = env.get? "user"
  if user
    user = user.as(User)
    subscriptions = user.subscriptions
  end
  subscriptions ||= [] of String

  ucid = env.params.url["ucid"]

  thin_mode = env.params.query["thin_mode"]? || env.get("preferences").as(Preferences).thin_mode
  thin_mode = thin_mode == "true"

  continuation = env.params.query["continuation"]?
  # sort_by = env.params.query["sort_by"]?.try &.downcase

  begin
    channel = get_about_info(ucid, locale)
  rescue ex : ChannelRedirect
    next env.redirect env.request.resource.gsub(ucid, ex.channel_id)
  rescue ex
    error_message = ex.message
    env.response.status_code = 500
    next templated "error"
  end

  if !channel.tabs.includes? "community"
    next env.redirect "/channel/#{channel.ucid}"
  end

  begin
    items = JSON.parse(fetch_channel_community(ucid, continuation, locale, "json", thin_mode))
  rescue ex
    env.response.status_code = 500
    error_message = ex.message
  end

  env.set "search", "channel:#{channel.ucid} "
  templated "community"
end

# API Endpoints

get "/api/v1/stats" do |env|
  env.response.content_type = "application/json"

  if !config.statistics_enabled
    error_message = {"error" => "Statistics are not enabled."}.to_json
    env.response.status_code = 400
    next error_message
  end

  Invidious::Jobs::StatisticsRefreshJob::STATISTICS.to_json
end

# YouTube provides "storyboards", which are sprites containing x * y
# preview thumbnails for individual scenes in a video.
# See https://support.jwplayer.com/articles/how-to-add-preview-thumbnails
get "/api/v1/storyboards/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  begin
    video = get_video(id, PG_DB, region: region)
  rescue ex : VideoRedirect
    error_message = {"error" => "Video is unavailable", "videoId" => ex.video_id}.to_json
    env.response.status_code = 302
    env.response.headers["Location"] = env.request.resource.gsub(id, ex.video_id)
    next error_message
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
          generate_storyboards(json, id, storyboards)
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

  String.build do |str|
    str << <<-END_VTT
    WEBVTT


    END_VTT

    start_time = 0.milliseconds
    end_time = storyboard[:interval].milliseconds

    storyboard[:storyboard_count].times do |i|
      url = storyboard[:url].gsub("$M", i).gsub("https://i9.ytimg.com", HOST_URL)

      storyboard[:storyboard_height].times do |j|
        storyboard[:storyboard_width].times do |k|
          str << <<-END_CUE
          #{start_time}.000 --> #{end_time}.000
          #{url}#xywh=#{storyboard[:width] * k},#{storyboard[:height] * j},#{storyboard[:width]},#{storyboard[:height]}


          END_CUE

          start_time += storyboard[:interval].milliseconds
          end_time += storyboard[:interval].milliseconds
        end
      end
    end
  end
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

  begin
    video = get_video(id, PG_DB, region: region)
  rescue ex : VideoRedirect
    error_message = {"error" => "Video is unavailable", "videoId" => ex.video_id}.to_json
    env.response.status_code = 302
    env.response.headers["Location"] = env.request.resource.gsub(id, ex.video_id)
    next error_message
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
                json.field "url", "/api/v1/captions/#{id}?label=#{URI.encode_www_form(caption.name.simpleText)}"
              end
            end
          end
        end
      end
    end

    next response
  end

  env.response.content_type = "text/vtt; charset=UTF-8"

  if lang
    caption = captions.select { |caption| caption.languageCode == lang }
  else
    caption = captions.select { |caption| caption.name.simpleText == label }
  end

  if caption.empty?
    env.response.status_code = 404
    next
  else
    caption = caption[0]
  end

  url = URI.parse("#{caption.baseUrl}&tlang=#{tlang}").full_path

  # Auto-generated captions often have cues that aren't aligned properly with the video,
  # as well as some other markup that makes it cumbersome, so we try to fix that here
  if caption.name.simpleText.includes? "auto-generated"
    caption_xml = YT_POOL.client &.get(url).body
    caption_xml = XML.parse(caption_xml)

    webvtt = String.build do |str|
      str << <<-END_VTT
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

        str << <<-END_CUE
        #{start_time} --> #{end_time}
        #{text}


        END_CUE
      end
    end
  else
    webvtt = YT_POOL.client &.get("#{url}&format=vtt").body
  end

  if title = env.params.query["title"]?
    # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
    env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.encode_www_form(title)}\"; filename*=UTF-8''#{URI.encode_www_form(title)}"
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
      comments = fetch_youtube_comments(id, PG_DB, continuation, format, locale, thin_mode, region, sort_by: sort_by)
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

  error_message = {"error" => "YouTube has removed publicly available analytics."}.to_json
  env.response.status_code = 410
  error_message
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

      file = URI.encode_www_form("#{id[0, 3]}/#{id}.xml")

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
  else # "youtube"
    response = YT_POOL.client &.get("/annotations_invideo?video_id=#{id}")

    if response.status_code != 200
      env.response.status_code = response.status_code
      next
    end

    annotations = response.body
  end

  etag = sha256(annotations)[0, 16]
  if env.request.headers["If-None-Match"]?.try &.== etag
    env.response.status_code = 304
  else
    env.response.headers["ETag"] = etag
    annotations
  end
end

get "/api/v1/videos/:id" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  id = env.params.url["id"]
  region = env.params.query["region"]?

  begin
    video = get_video(id, PG_DB, region: region)
  rescue ex : VideoRedirect
    error_message = {"error" => "Video is unavailable", "videoId" => ex.video_id}.to_json
    env.response.status_code = 302
    env.response.headers["Location"] = env.request.resource.gsub(id, ex.video_id)
    next error_message
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  video.to_json(locale)
end

get "/api/v1/trending" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  region = env.params.query["region"]?
  trending_type = env.params.query["type"]?

  begin
    trending, plid = fetch_trending(trending_type, region, locale)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  videos = JSON.build do |json|
    json.array do
      trending.each do |video|
        video.to_json(locale, json)
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
        video.to_json(locale, json)
      end
    end
  end
end

get "/api/v1/top" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"
  "[]"
end

get "/api/v1/channels/:ucid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"

  ucid = env.params.url["ucid"]
  sort_by = env.params.query["sort_by"]?.try &.downcase
  sort_by ||= "newest"

  begin
    channel = get_about_info(ucid, locale)
  rescue ex : ChannelRedirect
    error_message = {"error" => "Channel is unavailable", "authorId" => ex.channel_id}.to_json
    env.response.status_code = 302
    env.response.headers["Location"] = env.request.resource.gsub(ucid, ex.channel_id)
    next error_message
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  page = 1
  if channel.auto_generated
    videos = [] of SearchVideo
    count = 0
  else
    begin
      count, videos = get_60_videos(channel.ucid, channel.author, page, channel.auto_generated, sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end
  end

  JSON.build do |json|
    # TODO: Refactor into `to_json` for InvidiousChannel
    json.object do
      json.field "author", channel.author
      json.field "authorId", channel.ucid
      json.field "authorUrl", channel.author_url

      json.field "authorBanners" do
        json.array do
          if channel.banner
            qualities = {
              {width: 2560, height: 424},
              {width: 2120, height: 351},
              {width: 1060, height: 175},
            }
            qualities.each do |quality|
              json.object do
                json.field "url", channel.banner.not_nil!.gsub("=w1060-", "=w#{quality[:width]}-")
                json.field "width", quality[:width]
                json.field "height", quality[:height]
              end
            end

            json.object do
              json.field "url", channel.banner.not_nil!.split("=w1060-")[0]
              json.field "width", 512
              json.field "height", 288
            end
          end
        end
      end

      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", channel.author_thumbnail.gsub(/=s\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "subCount", channel.sub_count
      json.field "totalViews", channel.total_views
      json.field "joined", channel.joined.to_unix
      json.field "paid", channel.paid

      json.field "autoGenerated", channel.auto_generated
      json.field "isFamilyFriendly", channel.is_family_friendly
      json.field "description", html_to_content(channel.description_html)
      json.field "descriptionHtml", channel.description_html

      json.field "allowedRegions", channel.allowed_regions

      json.field "latestVideos" do
        json.array do
          videos.each do |video|
            video.to_json(locale, json)
          end
        end
      end

      json.field "relatedChannels" do
        json.array do
          channel.related_channels.each do |related_channel|
            json.object do
              json.field "author", related_channel.author
              json.field "authorId", related_channel.ucid
              json.field "authorUrl", related_channel.author_url

              json.field "authorThumbnails" do
                json.array do
                  qualities = {32, 48, 76, 100, 176, 512}

                  qualities.each do |quality|
                    json.object do
                      json.field "url", related_channel.author_thumbnail.gsub(/=\d+/, "=s#{quality}")
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
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      error_message = {"error" => "Channel is unavailable", "authorId" => ex.channel_id}.to_json
      env.response.status_code = 302
      env.response.headers["Location"] = env.request.resource.gsub(ucid, ex.channel_id)
      next error_message
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end

    begin
      count, videos = get_60_videos(channel.ucid, channel.author, page, channel.auto_generated, sort_by)
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end

    JSON.build do |json|
      json.array do
        videos.each do |video|
          video.to_json(locale, json)
        end
      end
    end
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
          video.to_json(locale, json)
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
    sort_by = env.params.query["sort"]?.try &.downcase ||
              env.params.query["sort_by"]?.try &.downcase ||
              "last"

    begin
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      error_message = {"error" => "Channel is unavailable", "authorId" => ex.channel_id}.to_json
      env.response.status_code = 302
      env.response.headers["Location"] = env.request.resource.gsub(ucid, ex.channel_id)
      next error_message
    rescue ex
      error_message = {"error" => ex.message}.to_json
      env.response.status_code = 500
      next error_message
    end

    items, continuation = fetch_channel_playlists(channel.ucid, channel.author, channel.auto_generated, continuation, sort_by)

    JSON.build do |json|
      json.object do
        json.field "playlists" do
          json.array do
            items.each do |item|
              item.to_json(locale, json) if item.is_a?(SearchPlaylist)
            end
          end
        end

        json.field "continuation", continuation
      end
    end
  end
end

{"/api/v1/channels/:ucid/comments", "/api/v1/channels/comments/:ucid"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    ucid = env.params.url["ucid"]

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    continuation = env.params.query["continuation"]?
    # sort_by = env.params.query["sort_by"]?.try &.downcase

    begin
      fetch_channel_community(ucid, continuation, locale, format, thin_mode)
    rescue ex
      env.response.status_code = 400
      error_message = {"error" => ex.message}.to_json
      next error_message
    end
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
  JSON.build do |json|
    json.array do
      search_results.each do |item|
        item.to_json(locale, json)
      end
    end
  end
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
    error_message = {"error" => ex.message}.to_json
    next error_message
  end

  count, search_results = search(query, page, search_params, region).as(Tuple)
  JSON.build do |json|
    json.array do
      search_results.each do |item|
        item.to_json(locale, json)
      end
    end
  end
end

get "/api/v1/search/suggestions" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  region = env.params.query["region"]?

  env.response.content_type = "application/json"

  query = env.params.query["q"]?
  query ||= ""

  begin
    headers = HTTP::Headers{":authority" => "suggestqueries.google.com"}
    response = YT_POOL.client &.get("/complete/search?hl=en&gl=#{region}&client=youtube&ds=yt&q=#{URI.encode_www_form(query)}&callback=suggestCallback", headers).body

    body = response[35..-2]
    body = JSON.parse(body).as_a
    suggestions = body[1].as_a[0..-2]

    JSON.build do |json|
      json.object do
        json.field "query", body[0].as_s
        json.field "suggestions" do
          json.array do
            suggestions.each do |suggestion|
              json.string suggestion[0].as_s
            end
          end
        end
      end
    end
  rescue ex
    env.response.status_code = 500
    error_message = {"error" => ex.message}.to_json
    next error_message
  end
end

{"/api/v1/playlists/:plid", "/api/v1/auth/playlists/:plid"}.each do |route|
  get route do |env|
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    plid = env.params.url["plid"]

    offset = env.params.query["index"]?.try &.to_i?
    offset ||= env.params.query["page"]?.try &.to_i?.try { |page| (page - 1) * 100 }
    offset ||= 0

    continuation = env.params.query["continuation"]?

    format = env.params.query["format"]?
    format ||= "json"

    if plid.starts_with? "RD"
      next env.redirect "/api/v1/mixes/#{plid}"
    end

    begin
      playlist = get_playlist(PG_DB, plid, locale)
    rescue ex
      env.response.status_code = 404
      error_message = {"error" => "Playlist does not exist."}.to_json
      next error_message
    end

    user = env.get?("user").try &.as(User)
    if !playlist || playlist.privacy.private? && playlist.author != user.try &.email
      env.response.status_code = 404
      error_message = {"error" => "Playlist does not exist."}.to_json
      next error_message
    end

    response = playlist.to_json(offset, locale, continuation: continuation)

    if format == "html"
      response = JSON.parse(response)
      playlist_html = template_playlist(response)
      index, next_video = response["videos"].as_a.skip(1).select { |video| !video["author"].as_s.empty? }[0]?.try { |v| {v["index"], v["videoId"]} } || {nil, nil}

      response = {
        "playlistHtml" => playlist_html,
        "index"        => index,
        "nextVideo"    => next_video,
      }.to_json
    end

    response
  end
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
    next_video = response["videos"].as_a.select { |video| !video["author"].as_s.empty? }[0]?.try &.["videoId"]

    response = {
      "playlistHtml" => playlist_html,
      "nextVideo"    => next_video,
    }.to_json
  end

  response
end

# Authenticated endpoints

get "/api/v1/auth/notifications" do |env|
  env.response.content_type = "text/event-stream"

  topics = env.params.query["topics"]?.try &.split(",").uniq.first(1000)
  topics ||= [] of String

  create_notification_stream(env, topics, connection_channel)
end

post "/api/v1/auth/notifications" do |env|
  env.response.content_type = "text/event-stream"

  topics = env.params.body["topics"]?.try &.split(",").uniq.first(1000)
  topics ||= [] of String

  create_notification_stream(env, topics, connection_channel)
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
end

get "/api/v1/auth/feed" do |env|
  env.response.content_type = "application/json"

  user = env.get("user").as(User)
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  max_results = env.params.query["max_results"]?.try &.to_i?
  max_results ||= user.preferences.max_results
  max_results ||= CONFIG.default_user_preferences.max_results

  page = env.params.query["page"]?.try &.to_i?
  page ||= 1

  videos, notifications = get_subscription_feed(PG_DB, user, max_results, page)

  JSON.build do |json|
    json.object do
      json.field "notifications" do
        json.array do
          notifications.each do |video|
            video.to_json(locale, json)
          end
        end
      end

      json.field "videos" do
        json.array do
          videos.each do |video|
            video.to_json(locale, json)
          end
        end
      end
    end
  end
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
    PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)
  end

  # For Google accounts, access tokens don't have enough information to
  # make a request on the user's behalf, which is why we don't sync with
  # YouTube.

  env.response.status_code = 204
end

delete "/api/v1/auth/subscriptions/:ucid" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  ucid = env.params.url["ucid"]

  PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_remove(subscriptions, $1) WHERE email = $2", ucid, user.email)

  env.response.status_code = 204
end

get "/api/v1/auth/playlists" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  playlists = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1", user.email, as: InvidiousPlaylist)

  JSON.build do |json|
    json.array do
      playlists.each do |playlist|
        playlist.to_json(0, locale, json)
      end
    end
  end
end

post "/api/v1/auth/playlists" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  title = env.params.json["title"]?.try &.as(String).delete("<>").byte_slice(0, 150)
  if !title
    error_message = {"error" => "Invalid title."}.to_json
    env.response.status_code = 400
    next error_message
  end

  privacy = env.params.json["privacy"]?.try { |privacy| PlaylistPrivacy.parse(privacy.as(String).downcase) }
  if !privacy
    error_message = {"error" => "Invalid privacy setting."}.to_json
    env.response.status_code = 400
    next error_message
  end

  if PG_DB.query_one("SELECT count(*) FROM playlists WHERE author = $1", user.email, as: Int64) >= 100
    error_message = {"error" => "User cannot have more than 100 playlists."}.to_json
    env.response.status_code = 400
    next error_message
  end

  playlist = create_playlist(PG_DB, title, privacy, user)
  env.response.headers["Location"] = "#{HOST_URL}/api/v1/auth/playlists/#{playlist.id}"
  env.response.status_code = 201
  {
    "title"      => title,
    "playlistId" => playlist.id,
  }.to_json
end

patch "/api/v1/auth/playlists/:plid" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  plid = env.params.url["plid"]

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email && playlist.privacy.private?
    env.response.status_code = 404
    error_message = {"error" => "Playlist does not exist."}.to_json
    next error_message
  end

  if playlist.author != user.email
    env.response.status_code = 403
    error_message = {"error" => "Invalid user"}.to_json
    next error_message
  end

  title = env.params.json["title"].try &.as(String).delete("<>").byte_slice(0, 150) || playlist.title
  privacy = env.params.json["privacy"]?.try { |privacy| PlaylistPrivacy.parse(privacy.as(String).downcase) } || playlist.privacy
  description = env.params.json["description"]?.try &.as(String).delete("\r") || playlist.description

  if title != playlist.title ||
     privacy != playlist.privacy ||
     description != playlist.description
    updated = Time.utc
  else
    updated = playlist.updated
  end

  PG_DB.exec("UPDATE playlists SET title = $1, privacy = $2, description = $3, updated = $4 WHERE id = $5", title, privacy, description, updated, plid)
  env.response.status_code = 204
end

delete "/api/v1/auth/playlists/:plid" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  plid = env.params.url["plid"]

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email && playlist.privacy.private?
    env.response.status_code = 404
    error_message = {"error" => "Playlist does not exist."}.to_json
    next error_message
  end

  if playlist.author != user.email
    env.response.status_code = 403
    error_message = {"error" => "Invalid user"}.to_json
    next error_message
  end

  PG_DB.exec("DELETE FROM playlist_videos * WHERE plid = $1", plid)
  PG_DB.exec("DELETE FROM playlists * WHERE id = $1", plid)

  env.response.status_code = 204
end

post "/api/v1/auth/playlists/:plid/videos" do |env|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?

  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  plid = env.params.url["plid"]

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email && playlist.privacy.private?
    env.response.status_code = 404
    error_message = {"error" => "Playlist does not exist."}.to_json
    next error_message
  end

  if playlist.author != user.email
    env.response.status_code = 403
    error_message = {"error" => "Invalid user"}.to_json
    next error_message
  end

  if playlist.index.size >= 500
    env.response.status_code = 400
    error_message = {"error" => "Playlist cannot have more than 500 videos"}.to_json
    next error_message
  end

  video_id = env.params.json["videoId"].try &.as(String)
  if !video_id
    env.response.status_code = 403
    error_message = {"error" => "Invalid videoId"}.to_json
    next error_message
  end

  begin
    video = get_video(video_id, PG_DB)
  rescue ex
    error_message = {"error" => ex.message}.to_json
    env.response.status_code = 500
    next error_message
  end

  playlist_video = PlaylistVideo.new({
    title:          video.title,
    id:             video.id,
    author:         video.author,
    ucid:           video.ucid,
    length_seconds: video.length_seconds,
    published:      video.published,
    plid:           plid,
    live_now:       video.live_now,
    index:          Random::Secure.rand(0_i64..Int64::MAX),
  })

  video_array = playlist_video.to_a
  args = arg_array(video_array)

  PG_DB.exec("INSERT INTO playlist_videos VALUES (#{args})", args: video_array)
  PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = video_count + 1, updated = $2 WHERE id = $3", playlist_video.index, Time.utc, plid)

  env.response.headers["Location"] = "#{HOST_URL}/api/v1/auth/playlists/#{plid}/videos/#{playlist_video.index.to_u64.to_s(16).upcase}"
  env.response.status_code = 201
  playlist_video.to_json(locale, index: playlist.index.size)
end

delete "/api/v1/auth/playlists/:plid/videos/:index" do |env|
  env.response.content_type = "application/json"
  user = env.get("user").as(User)

  plid = env.params.url["plid"]
  index = env.params.url["index"].to_i64(16)

  playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
  if !playlist || playlist.author != user.email && playlist.privacy.private?
    env.response.status_code = 404
    error_message = {"error" => "Playlist does not exist."}.to_json
    next error_message
  end

  if playlist.author != user.email
    env.response.status_code = 403
    error_message = {"error" => "Invalid user"}.to_json
    next error_message
  end

  if !playlist.index.includes? index
    env.response.status_code = 404
    error_message = {"error" => "Playlist does not contain index"}.to_json
    next error_message
  end

  PG_DB.exec("DELETE FROM playlist_videos * WHERE index = $1", index)
  PG_DB.exec("UPDATE playlists SET index = array_remove(index, $1), video_count = video_count - 1, updated = $2 WHERE id = $3", index, Time.utc, plid)

  env.response.status_code = 204
end

# patch "/api/v1/auth/playlists/:plid/videos/:index" do |env|
# TODO: Playlist stub
# end

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
      access_token = URI.encode_www_form(access_token)

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

  # Since some implementations create playlists based on resolution regardless of different codecs,
  # we can opt to only add a source to a representation if it has a unique height within that representation
  unique_res = env.params.query["unique_res"]?.try { |q| (q == "true" || q == "1").to_unsafe }

  begin
    video = get_video(id, PG_DB, region: region)
  rescue ex : VideoRedirect
    next env.redirect env.request.resource.gsub(id, ex.video_id)
  rescue ex
    env.response.status_code = 403
    next
  end

  if dashmpd = video.dash_manifest_url
    manifest = YT_POOL.client &.get(URI.parse(dashmpd).full_path).body

    manifest = manifest.gsub(/<BaseURL>[^<]+<\/BaseURL>/) do |baseurl|
      url = baseurl.lchop("<BaseURL>")
      url = url.rchop("</BaseURL>")

      if local
        url = URI.parse(url).full_path
      end

      "<BaseURL>#{url}</BaseURL>"
    end

    next manifest
  end

  adaptive_fmts = video.adaptive_fmts

  if local
    adaptive_fmts.each do |fmt|
      fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path)
    end
  end

  audio_streams = video.audio_streams
  video_streams = video.video_streams.sort_by { |stream| {stream["width"].as_i, stream["fps"].as_i} }.reverse

  XML.build(indent: "  ", encoding: "UTF-8") do |xml|
    xml.element("MPD", "xmlns": "urn:mpeg:dash:schema:mpd:2011",
      "profiles": "urn:mpeg:dash:profile:full:2011", minBufferTime: "PT1.5S", type: "static",
      mediaPresentationDuration: "PT#{video.length_seconds}S") do
      xml.element("Period") do
        i = 0

        {"audio/mp4", "audio/webm"}.each do |mime_type|
          mime_streams = audio_streams.select { |stream| stream["mimeType"].as_s.starts_with? mime_type }
          next if mime_streams.empty?

          xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true) do
            mime_streams.each do |fmt|
              codecs = fmt["mimeType"].as_s.split("codecs=")[1].strip('"')
              bandwidth = fmt["bitrate"].as_i
              itag = fmt["itag"].as_i
              url = fmt["url"].as_s

              xml.element("Representation", id: fmt["itag"], codecs: codecs, bandwidth: bandwidth) do
                xml.element("AudioChannelConfiguration", schemeIdUri: "urn:mpeg:dash:23003:3:audio_channel_configuration:2011",
                  value: "2")
                xml.element("BaseURL") { xml.text url }
                xml.element("SegmentBase", indexRange: "#{fmt["indexRange"]["start"]}-#{fmt["indexRange"]["end"]}") do
                  xml.element("Initialization", range: "#{fmt["initRange"]["start"]}-#{fmt["initRange"]["end"]}")
                end
              end
            end
          end

          i += 1
        end

        potential_heights = {4320, 2160, 1440, 1080, 720, 480, 360, 240, 144}

        {"video/mp4", "video/webm"}.each do |mime_type|
          mime_streams = video_streams.select { |stream| stream["mimeType"].as_s.starts_with? mime_type }
          next if mime_streams.empty?

          heights = [] of Int32
          xml.element("AdaptationSet", id: i, mimeType: mime_type, startWithSAP: 1, subsegmentAlignment: true, scanType: "progressive") do
            mime_streams.each do |fmt|
              codecs = fmt["mimeType"].as_s.split("codecs=")[1].strip('"')
              bandwidth = fmt["bitrate"].as_i
              itag = fmt["itag"].as_i
              url = fmt["url"].as_s
              width = fmt["width"].as_i
              height = fmt["height"].as_i

              # Resolutions reported by YouTube player (may not accurately reflect source)
              height = potential_heights.min_by { |i| (height - i).abs }
              next if unique_res && heights.includes? height
              heights << height

              xml.element("Representation", id: itag, codecs: codecs, width: width, height: height,
                startWithSAP: "1", maxPlayoutRate: "1",
                bandwidth: bandwidth, frameRate: fmt["fps"]) do
                xml.element("BaseURL") { xml.text url }
                xml.element("SegmentBase", indexRange: "#{fmt["indexRange"]["start"]}-#{fmt["indexRange"]["end"]}") do
                  xml.element("Initialization", range: "#{fmt["initRange"]["start"]}-#{fmt["initRange"]["end"]}")
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
  response = YT_POOL.client &.get(env.request.path)

  if response.status_code != 200
    env.response.status_code = response.status_code
    next
  end

  local = env.params.query["local"]?.try &.== "true"

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")

  manifest = response.body

  if local
    manifest = manifest.gsub("https://www.youtube.com", HOST_URL)
    manifest = manifest.gsub("index.m3u8", "index.m3u8?local=true")
  end

  manifest
end

get "/api/manifest/hls_playlist/*" do |env|
  response = YT_POOL.client &.get(env.request.path)

  if response.status_code != 200
    env.response.status_code = response.status_code
    next
  end

  local = env.params.query["local"]?.try &.== "true"

  env.response.content_type = "application/x-mpegURL"
  env.response.headers.add("Access-Control-Allow-Origin", "*")

  manifest = response.body

  if local
    manifest = manifest.gsub(/^https:\/\/r\d---.{11}\.c\.youtube\.com[^\n]*/m) do |match|
      path = URI.parse(match).path

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
        value = URI.decode_www_form(value)

        if raw_params[key]?
          raw_params[key] << value
        else
          raw_params[key] = [value]
        end
      end

      raw_params = HTTP::Params.new(raw_params)
      if fvip = raw_params["hls_chunk_host"].match(/r(?<fvip>\d+)---/)
        raw_params["fvip"] = fvip["fvip"]
      end

      raw_params["local"] = "true"

      "#{HOST_URL}/videoplayback?#{raw_params}"
    end
  end

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
  itag ||= env.params.query["itag"]?.try &.to_i

  region = env.params.query["region"]?

  local ||= env.params.query["local"]?
  local ||= "false"
  local = local == "true"

  if !id || !itag
    env.response.status_code = 400
    next
  end

  video = get_video(id, PG_DB, region: region)

  fmt = video.fmt_stream.find(nil) { |f| f["itag"].as_i == itag } || video.adaptive_fmts.find(nil) { |f| f["itag"].as_i == itag }
  url = fmt.try &.["url"]?.try &.as_s

  if !url
    env.response.status_code = 404
    next
  end

  url = URI.parse(url).full_path.not_nil! if local
  url = "#{url}&title=#{title}" if title

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
    value = URI.decode_www_form(value)

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
  mns = query_params["mn"]?.try &.split(",")
  mns ||= [] of String

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
  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  client = make_client(URI.parse(host), region)
  response = HTTP::Client::Response.new(500)
  error = ""
  5.times do
    begin
      response = client.head(url, headers)

      if response.headers["Location"]?
        location = URI.parse(response.headers["Location"])
        env.response.headers["Access-Control-Allow-Origin"] = "*"

        host = "#{location.scheme}://#{location.host}"
        client = make_client(URI.parse(host), region)

        url = "#{location.full_path}&host=#{location.host}#{region ? "&region=#{region}" : ""}"
      else
        break
      end
    rescue Socket::Addrinfo::Error
      if !mns.empty?
        mn = mns.pop
      end
      fvip = "3"

      host = "https://r#{fvip}---#{mn}.googlevideo.com"
      client = make_client(URI.parse(host), region)
    rescue ex
      error = ex.message
    end
  end

  if response.status_code >= 400
    env.response.status_code = response.status_code
    env.response.content_type = "text/plain"
    next error
  end

  if url.includes? "&file=seg.ts"
    if CONFIG.disabled?("livestreams")
      env.response.status_code = 403
      error_message = "Administrator has disabled this endpoint."
      next templated "error"
    end

    begin
      client = make_client(URI.parse(host), region)
      client.get(url, headers) do |response|
        response.headers.each do |key, value|
          if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
            env.response.headers[key] = value
          end
        end

        env.response.headers["Access-Control-Allow-Origin"] = "*"

        if location = response.headers["Location"]?
          location = URI.parse(location)
          location = "#{location.full_path}&host=#{location.host}"

          if region
            location += "&region=#{region}"
          end

          next env.redirect location
        end

        IO.copy(response.body_io, env.response)
      end
    rescue ex
    end
  else
    if query_params["title"]? && CONFIG.disabled?("downloads") ||
       CONFIG.disabled?("dash")
      env.response.status_code = 403
      error_message = "Administrator has disabled this endpoint."
      next templated "error"
    end

    content_length = nil
    first_chunk = true
    range_start, range_end = parse_range(env.request.headers["Range"]?)
    chunk_start = range_start
    chunk_end = range_end

    if !chunk_end || chunk_end - chunk_start > HTTP_CHUNK_SIZE
      chunk_end = chunk_start + HTTP_CHUNK_SIZE - 1
    end

    client = make_client(URI.parse(host), region)

    # TODO: Record bytes written so we can restart after a chunk fails
    while true
      if !range_end && content_length
        range_end = content_length
      end

      if range_end && chunk_start > range_end
        break
      end

      if range_end && chunk_end > range_end
        chunk_end = range_end
      end

      headers["Range"] = "bytes=#{chunk_start}-#{chunk_end}"

      begin
        client.get(url, headers) do |response|
          if first_chunk
            if !env.request.headers["Range"]? && response.status_code == 206
              env.response.status_code = 200
            else
              env.response.status_code = response.status_code
            end

            response.headers.each do |key, value|
              if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase) && key.downcase != "content-range"
                env.response.headers[key] = value
              end
            end

            env.response.headers["Access-Control-Allow-Origin"] = "*"

            if location = response.headers["Location"]?
              location = URI.parse(location)
              location = "#{location.full_path}&host=#{location.host}#{region ? "&region=#{region}" : ""}"

              env.redirect location
              break
            end

            if title = query_params["title"]?
              # https://blog.fastmail.com/2011/06/24/download-non-english-filenames/
              env.response.headers["Content-Disposition"] = "attachment; filename=\"#{URI.encode_www_form(title)}\"; filename*=UTF-8''#{URI.encode_www_form(title)}"
            end

            if !response.headers.includes_word?("Transfer-Encoding", "chunked")
              content_length = response.headers["Content-Range"].split("/")[-1].to_i64
              if env.request.headers["Range"]?
                env.response.headers["Content-Range"] = "bytes #{range_start}-#{range_end || (content_length - 1)}/#{content_length}"
                env.response.content_length = ((range_end.try &.+ 1) || content_length) - range_start
              else
                env.response.content_length = content_length
              end
            end
          end

          proxy_file(response, env)
        end
      rescue ex
        if ex.message != "Error reading socket: Connection reset by peer"
          break
        else
          client = make_client(URI.parse(host), region)
        end
      end

      chunk_start = chunk_end + 1
      chunk_end += HTTP_CHUNK_SIZE
      first_chunk = false
    end
  end
end

get "/ggpht/*" do |env|
  url = env.request.path.lchop("/ggpht")

  headers = HTTP::Headers{":authority" => "yt3.ggpht.com"}
  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    YT_POOL.client &.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
          env.response.headers[key] = value
        end
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300
        env.response.headers.delete("Transfer-Encoding")
        break
      end

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

  url = "/sb/#{id}/#{storyboard}/#{index}?#{env.params.query}"

  headers = HTTP::Headers.new

  if storyboard.starts_with? "storyboard_live"
    headers[":authority"] = "i.ytimg.com"
  else
    headers[":authority"] = "i9.ytimg.com"
  end

  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    YT_POOL.client &.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
          env.response.headers[key] = value
        end
      end

      env.response.headers["Connection"] = "close"
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300
        env.response.headers.delete("Transfer-Encoding")
        break
      end

      proxy_file(response, env)
    end
  rescue ex
  end
end

get "/s_p/:id/:name" do |env|
  id = env.params.url["id"]
  name = env.params.url["name"]

  url = env.request.resource

  headers = HTTP::Headers{":authority" => "i9.ytimg.com"}
  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    YT_POOL.client &.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
          env.response.headers[key] = value
        end
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300 && response.status_code != 404
        env.response.headers.delete("Transfer-Encoding")
        break
      end

      proxy_file(response, env)
    end
  rescue ex
  end
end

get "/yts/img/:name" do |env|
  headers = HTTP::Headers.new
  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    YT_POOL.client &.get(env.request.resource, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
          env.response.headers[key] = value
        end
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300 && response.status_code != 404
        env.response.headers.delete("Transfer-Encoding")
        break
      end

      proxy_file(response, env)
    end
  rescue ex
  end
end

get "/vi/:id/:name" do |env|
  id = env.params.url["id"]
  name = env.params.url["name"]

  headers = HTTP::Headers{":authority" => "i.ytimg.com"}

  if name == "maxres.jpg"
    build_thumbnails(id).each do |thumb|
      if YT_POOL.client &.head("/vi/#{id}/#{thumb[:url]}.jpg", headers).status_code == 200
        name = thumb[:url] + ".jpg"
        break
      end
    end
  end
  url = "/vi/#{id}/#{name}"

  REQUEST_HEADERS_WHITELIST.each do |header|
    if env.request.headers[header]?
      headers[header] = env.request.headers[header]
    end
  end

  begin
    YT_POOL.client &.get(url, headers) do |response|
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
          env.response.headers[key] = value
        end
      end

      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300 && response.status_code != 404
        env.response.headers.delete("Transfer-Encoding")
        break
      end

      proxy_file(response, env)
    end
  rescue ex
  end
end

get "/Captcha" do |env|
  headers = HTTP::Headers{":authority" => "accounts.google.com"}
  response = YT_POOL.client &.get(env.request.resource, headers)
  env.response.headers["Content-Type"] = response.headers["Content-Type"]
  response.body
end

# Undocumented, creates anonymous playlist with specified 'video_ids', max 50 videos
get "/watch_videos" do |env|
  response = YT_POOL.client &.get(env.request.resource)
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
    response = YT_POOL.client &.get("/#{item}")

    if response.status_code == 301
      response = YT_POOL.client &.get(URI.parse(response.headers["Location"]).full_path)
    end

    if response.body.empty?
      env.response.headers["Location"] = "/"
      halt env, status_code: 302
    end

    html = XML.parse_html(response.body)
    ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]

    if ucid
      env.response.headers["Location"] = "/channel/#{ucid}"
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
    if item.match(/^[a-zA-Z0-9_-]{11}$/) && YT_POOL.client &.head("/watch?v=#{item}").status_code != 404
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
  <a href="https://github.com/iv-org/invidious/issues">here</a>
  or send an email to
  <a href="mailto:#{CONFIG.admin_email}">#{CONFIG.admin_email}</a>.
  END_HTML
  templated "error"
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
Kemal.config.host_binding = Kemal.config.host_binding != "0.0.0.0" ? Kemal.config.host_binding : CONFIG.host_binding
Kemal.config.port = Kemal.config.port != 3000 ? Kemal.config.port : CONFIG.port
Kemal.run
