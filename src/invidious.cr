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
require "athena-negotiation"
require "openssl/hmac"
require "option_parser"
require "pg"
require "sqlite3"
require "xml"
require "yaml"
require "compress/zip"
require "protodec/utils"
require "./invidious/helpers/*"
require "./invidious/yt_backend/*"
require "./invidious/*"
require "./invidious/channels/*"
require "./invidious/user/*"
require "./invidious/routes/**"
require "./invidious/jobs/**"

CONFIG   = Config.load
HMAC_KEY = CONFIG.hmac_key || Random::Secure.hex(32)

PG_DB           = DB.open CONFIG.database_url
ARCHIVE_URL     = URI.parse("https://archive.org")
LOGIN_URL       = URI.parse("https://accounts.google.com")
PUBSUB_URL      = URI.parse("https://pubsubhubbub.appspot.com")
REDDIT_URL      = URI.parse("https://www.reddit.com")
TEXTCAPTCHA_URL = URI.parse("https://textcaptcha.com")
YT_URL          = URI.parse("https://www.youtube.com")
HOST_URL        = make_host_url(Kemal.config)

CHARS_SAFE         = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"
TEST_IDS           = {"AgbeGFYluEA", "BaW_jenozKc", "a9LDPn-MO4I", "ddFvjfvPnqk", "iqKdEhx-dD4"}
MAX_ITEMS_PER_PAGE = 1500

REQUEST_HEADERS_WHITELIST  = {"accept", "accept-encoding", "cache-control", "content-length", "if-none-match", "range"}
RESPONSE_HEADERS_BLACKLIST = {"access-control-allow-origin", "alt-svc", "server"}
HTTP_CHUNK_SIZE            = 10485760 # ~10MB

CURRENT_BRANCH  = {{ "#{`git branch | sed -n '/* /s///p'`.strip}" }}
CURRENT_COMMIT  = {{ "#{`git rev-list HEAD --max-count=1 --abbrev-commit`.strip}" }}
CURRENT_VERSION = {{ "#{`git log -1 --format=%ci | awk '{print $1}' | sed s/-/./g`.strip}" }}

# This is used to determine the `?v=` on the end of file URLs (for cache busting). We
# only need to expire modified assets, so we can use this to find the last commit that changes
# any assets
ASSET_COMMIT = {{ "#{`git rev-list HEAD --max-count=1 --abbrev-commit -- assets`.strip}" }}

SOFTWARE = {
  "name"    => "invidious",
  "version" => "#{CURRENT_VERSION}-#{CURRENT_COMMIT}",
  "branch"  => "#{CURRENT_BRANCH}",
}

YT_POOL = YoutubeConnectionPool.new(YT_URL, capacity: CONFIG.pool_size, use_quic: CONFIG.use_quic)

# CLI
Kemal.config.extra_options do |parser|
  parser.banner = "Usage: invidious [arguments]"
  parser.on("-c THREADS", "--channel-threads=THREADS", "Number of threads for refreshing channels (default: #{CONFIG.channel_threads})") do |number|
    begin
      CONFIG.channel_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-f THREADS", "--feed-threads=THREADS", "Number of threads for refreshing feeds (default: #{CONFIG.feed_threads})") do |number|
    begin
      CONFIG.feed_threads = number.to_i
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-o OUTPUT", "--output=OUTPUT", "Redirect output (default: #{CONFIG.output})") do |output|
    CONFIG.output = output
  end
  parser.on("-l LEVEL", "--log-level=LEVEL", "Log level, one of #{LogLevel.values} (default: #{CONFIG.log_level})") do |log_level|
    CONFIG.log_level = LogLevel.parse(log_level)
  end
  parser.on("-v", "--version", "Print version") do
    puts SOFTWARE.to_pretty_json
    exit
  end
end

Kemal::CLI.new ARGV

if CONFIG.output.upcase != "STDOUT"
  FileUtils.mkdir_p(File.dirname(CONFIG.output))
end
OUTPUT = CONFIG.output.upcase == "STDOUT" ? STDOUT : File.open(CONFIG.output, mode: "a")
LOGGER = Invidious::LogHandler.new(OUTPUT, CONFIG.log_level)

# Check table integrity
if CONFIG.check_tables
  check_enum(PG_DB, "privacy", PlaylistPrivacy)

  check_table(PG_DB, "channels", InvidiousChannel)
  check_table(PG_DB, "channel_videos", ChannelVideo)
  check_table(PG_DB, "playlists", InvidiousPlaylist)
  check_table(PG_DB, "playlist_videos", PlaylistVideo)
  check_table(PG_DB, "nonces", Nonce)
  check_table(PG_DB, "session_ids", SessionId)
  check_table(PG_DB, "users", User)
  check_table(PG_DB, "videos", Video)

  if CONFIG.cache_annotations
    check_table(PG_DB, "annotations", Annotation)
  end
end

# Start jobs

if CONFIG.channel_threads > 0
  Invidious::Jobs.register Invidious::Jobs::RefreshChannelsJob.new(PG_DB)
end

if CONFIG.feed_threads > 0
  Invidious::Jobs.register Invidious::Jobs::RefreshFeedsJob.new(PG_DB)
end

DECRYPT_FUNCTION = DecryptFunction.new(CONFIG.decrypt_polling)
if CONFIG.decrypt_polling
  Invidious::Jobs.register Invidious::Jobs::UpdateDecryptFunctionJob.new
end

if CONFIG.statistics_enabled
  Invidious::Jobs.register Invidious::Jobs::StatisticsRefreshJob.new(PG_DB, SOFTWARE)
end

if (CONFIG.use_pubsub_feeds.is_a?(Bool) && CONFIG.use_pubsub_feeds.as(Bool)) || (CONFIG.use_pubsub_feeds.is_a?(Int32) && CONFIG.use_pubsub_feeds.as(Int32) > 0)
  Invidious::Jobs.register Invidious::Jobs::SubscribeToFeedsJob.new(PG_DB, HMAC_KEY)
end

if CONFIG.popular_enabled
  Invidious::Jobs.register Invidious::Jobs::PullPopularVideosJob.new(PG_DB)
end

connection_channel = Channel({Bool, Channel(PQ::Notification)}).new(32)
Invidious::Jobs.register Invidious::Jobs::NotificationJob.new(connection_channel, CONFIG.database_url)

Invidious::Jobs.start_all

def popular_videos
  Invidious::Jobs::PullPopularVideosJob::POPULAR_VIDEOS.get
end

before_all do |env|
  preferences = Preferences.from_json("{}")

  begin
    if prefs_cookie = env.request.cookies["PREFS"]?
      preferences = Preferences.from_json(URI.decode_www_form(prefs_cookie.value))
    else
      if language_header = env.request.headers["Accept-Language"]?
        if language = ANG.language_negotiator.best(language_header, LOCALES.keys)
          preferences.locale = language.header
        end
      end
    end
  rescue
    preferences = Preferences.from_json("{}")
  end

  env.set "preferences", preferences
  env.response.headers["X-XSS-Protection"] = "1; mode=block"
  env.response.headers["X-Content-Type-Options"] = "nosniff"

  # Allow media resources to be loaded from google servers
  # TODO: check if *.youtube.com can be removed
  if CONFIG.disabled?("local") || !preferences.local
    extra_media_csp = " https://*.googlevideo.com:443 https://*.youtube.com:443"
  else
    extra_media_csp = ""
  end

  # Only allow the pages at /embed/* to be embedded
  if env.request.resource.starts_with?("/embed")
    frame_ancestors = "'self' http: https:"
  else
    frame_ancestors = "'none'"
  end

  # TODO: Remove style-src's 'unsafe-inline', requires to remove all
  # inline styles (<style> [..] </style>, style=" [..] ")
  env.response.headers["Content-Security-Policy"] = {
    "default-src 'none'",
    "script-src 'self'",
    "style-src 'self' 'unsafe-inline'",
    "img-src 'self' data:",
    "font-src 'self' data:",
    "connect-src 'self'",
    "manifest-src 'self'",
    "media-src 'self' blob:" + extra_media_csp,
    "child-src 'self' blob:",
    "frame-src 'self'",
    "frame-ancestors " + frame_ancestors,
  }.join("; ")

  env.response.headers["Referrer-Policy"] = "same-origin"

  # Ask the chrom*-based browsers to disable FLoC
  # See: https://blog.runcloud.io/google-floc/
  env.response.headers["Permissions-Policy"] = "interest-cohort=()"

  if (Kemal.config.ssl || CONFIG.https_only) && CONFIG.hsts
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
  env.set "preferences", preferences

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

{% unless flag?(:api_only) %}
  Invidious::Routing.get "/", Invidious::Routes::Misc, :home
  Invidious::Routing.get "/privacy", Invidious::Routes::Misc, :privacy
  Invidious::Routing.get "/licenses", Invidious::Routes::Misc, :licenses

  Invidious::Routing.get "/channel/:ucid", Invidious::Routes::Channels, :home
  Invidious::Routing.get "/channel/:ucid/home", Invidious::Routes::Channels, :home
  Invidious::Routing.get "/channel/:ucid/videos", Invidious::Routes::Channels, :videos
  Invidious::Routing.get "/channel/:ucid/playlists", Invidious::Routes::Channels, :playlists
  Invidious::Routing.get "/channel/:ucid/community", Invidious::Routes::Channels, :community
  Invidious::Routing.get "/channel/:ucid/about", Invidious::Routes::Channels, :about

  ["", "/videos", "/playlists", "/community", "/about"].each do |path|
    # /c/LinusTechTips
    Invidious::Routing.get "/c/:user#{path}", Invidious::Routes::Channels, :brand_redirect
    # /user/linustechtips | Not always the same as /c/
    Invidious::Routing.get "/user/:user#{path}", Invidious::Routes::Channels, :brand_redirect
    # /attribution_link?a=anything&u=/channel/UCZYTClx2T1of7BRZ86-8fow
    Invidious::Routing.get "/attribution_link#{path}", Invidious::Routes::Channels, :brand_redirect
    # /profile?user=linustechtips
    Invidious::Routing.get "/profile/#{path}", Invidious::Routes::Channels, :profile
  end

  Invidious::Routing.get "/watch", Invidious::Routes::Watch, :handle
  Invidious::Routing.get "/watch/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/shorts/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/w/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/v/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/e/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/redirect", Invidious::Routes::Misc, :cross_instance_redirect

  Invidious::Routing.get "/embed/", Invidious::Routes::Embed, :redirect
  Invidious::Routing.get "/embed/:id", Invidious::Routes::Embed, :show

  Invidious::Routing.get "/create_playlist", Invidious::Routes::Playlists, :new
  Invidious::Routing.post "/create_playlist", Invidious::Routes::Playlists, :create
  Invidious::Routing.get "/subscribe_playlist", Invidious::Routes::Playlists, :subscribe
  Invidious::Routing.get "/delete_playlist", Invidious::Routes::Playlists, :delete_page
  Invidious::Routing.post "/delete_playlist", Invidious::Routes::Playlists, :delete
  Invidious::Routing.get "/edit_playlist", Invidious::Routes::Playlists, :edit
  Invidious::Routing.post "/edit_playlist", Invidious::Routes::Playlists, :update
  Invidious::Routing.get "/add_playlist_items", Invidious::Routes::Playlists, :add_playlist_items_page
  Invidious::Routing.post "/playlist_ajax", Invidious::Routes::Playlists, :playlist_ajax
  Invidious::Routing.get "/playlist", Invidious::Routes::Playlists, :show
  Invidious::Routing.get "/mix", Invidious::Routes::Playlists, :mix

  Invidious::Routing.get "/opensearch.xml", Invidious::Routes::Search, :opensearch
  Invidious::Routing.get "/results", Invidious::Routes::Search, :results
  Invidious::Routing.get "/search", Invidious::Routes::Search, :search

  Invidious::Routing.get "/login", Invidious::Routes::Login, :login_page
  Invidious::Routing.post "/login", Invidious::Routes::Login, :login
  Invidious::Routing.post "/signout", Invidious::Routes::Login, :signout

  Invidious::Routing.get "/preferences", Invidious::Routes::PreferencesRoute, :show
  Invidious::Routing.post "/preferences", Invidious::Routes::PreferencesRoute, :update
  Invidious::Routing.get "/toggle_theme", Invidious::Routes::PreferencesRoute, :toggle_theme

  # Feeds
  Invidious::Routing.get "/view_all_playlists", Invidious::Routes::Feeds, :view_all_playlists_redirect
  Invidious::Routing.get "/feed/playlists", Invidious::Routes::Feeds, :playlists
  Invidious::Routing.get "/feed/popular", Invidious::Routes::Feeds, :popular
  Invidious::Routing.get "/feed/trending", Invidious::Routes::Feeds, :trending
  Invidious::Routing.get "/feed/subscriptions", Invidious::Routes::Feeds, :subscriptions
  Invidious::Routing.get "/feed/history", Invidious::Routes::Feeds, :history

  # RSS Feeds
  Invidious::Routing.get "/feed/channel/:ucid", Invidious::Routes::Feeds, :rss_channel
  Invidious::Routing.get "/feed/private", Invidious::Routes::Feeds, :rss_private
  Invidious::Routing.get "/feed/playlist/:plid", Invidious::Routes::Feeds, :rss_playlist
  Invidious::Routing.get "/feeds/videos.xml", Invidious::Routes::Feeds, :rss_videos

  # Support push notifications via PubSubHubbub
  Invidious::Routing.get "/feed/webhook/:token", Invidious::Routes::Feeds, :push_notifications_get
  Invidious::Routing.post "/feed/webhook/:token", Invidious::Routes::Feeds, :push_notifications_post
{% end %}

Invidious::Routing.get "/ggpht/*", Invidious::Routes::Images, :ggpht
Invidious::Routing.options "/sb/:authority/:id/:storyboard/:index", Invidious::Routes::Images, :options_storyboard
Invidious::Routing.get "/sb/:authority/:id/:storyboard/:index", Invidious::Routes::Images, :get_storyboard
Invidious::Routing.get "/s_p/:id/:name", Invidious::Routes::Images, :s_p_image
Invidious::Routing.get "/yts/img/:name", Invidious::Routes::Images, :yts_image
Invidious::Routing.get "/vi/:id/:name", Invidious::Routes::Images, :thumbnails

# API routes (macro)
define_v1_api_routes()

# Video playback (macros)
define_api_manifest_routes()
define_video_playback_routes()

# Users

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
      next error_json(403, "No such user")
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
      next error_template(400, ex)
    else
      next error_json(400, ex)
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
    next error_json(400, "Unsupported action #{action}")
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
      next error_json(403, "No such user")
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

    cookies = HTTP::Cookies.from_client_headers(headers)
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
      next error_json(403, "No such user")
    end
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    if redirect
      next error_template(400, ex)
    else
      next error_json(400, ex)
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
    next error_json(400, "Unsupported action #{action}")
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
  subscriptions.sort_by!(&.author.downcase)

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
                  xml_url = "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel.id}"
                else
                  xml_url = "#{HOST_URL}/feed/channel/#{channel.id}"
                end

                xml.element("outline", text: channel.author, title: channel.author,
                  "type": "rss", xmlUrl: xml_url)
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
          user.subscriptions += body["subscriptions"].as_a.map(&.as_s)
          user.subscriptions.uniq!

          user.subscriptions = get_batch_channels(user.subscriptions, PG_DB, false, false)

          PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = $1 WHERE email = $2", user.subscriptions, user.email)
        end

        if body["watch_history"]?
          user.watched += body["watch_history"].as_a.map(&.as_s)
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
              raise InfoException.new("Playlist cannot have more than 500 videos") if idx > 500

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
              PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = cardinality(index) + 1, updated = $2 WHERE id = $3", playlist_video.index, Time.utc, playlist.id)
            end
          end
        end
      when "import_youtube"
        if body[0..4] == "<opml"
          subscriptions = XML.parse(body)
          user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
            channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
          end
        else
          subscriptions = JSON.parse(body)
          user.subscriptions += subscriptions.as_a.compact_map do |entry|
            entry["snippet"]["resourceId"]["channelId"].as_s
          end
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

              user.watched += db.query_all("SELECT url FROM streams", as: String).map(&.lchop("https://www.youtube.com/watch?v="))
              user.watched.uniq!

              PG_DB.exec("UPDATE users SET watched = $1 WHERE email = $2", user.watched, user.email)

              user.subscriptions += db.query_all("SELECT url FROM subscriptions", as: String).map(&.lchop("https://www.youtube.com/channel/"))
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
    next error_template(400, "Cannot change password for Google accounts")
  end

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    next error_template(400, ex)
  end

  password = env.params.body["password"]?
  if !password
    next error_template(401, "Password is a required field")
  end

  new_passwords = env.params.body.select { |k, v| k.match(/^new_password\[\d+\]$/) }.map { |k, v| v }

  if new_passwords.size <= 1 || new_passwords.uniq.size != 1
    next error_template(400, "New passwords must match")
  end

  new_password = new_passwords.uniq[0]
  if new_password.empty?
    next error_template(401, "Password cannot be empty")
  end

  if new_password.bytesize > 55
    next error_template(400, "Password cannot be longer than 55 characters")
  end

  if !Crypto::Bcrypt::Password.new(user.password.not_nil!).verify(password.byte_slice(0, 55))
    next error_template(401, "Incorrect password")
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
    next error_template(400, ex)
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
    next error_template(400, ex)
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
    next error_template(400, ex)
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
      next error_json(403, "No such user")
    end
  end

  user = user.as(User)
  sid = sid.as(String)
  token = env.params.body["csrf_token"]?

  begin
    validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
  rescue ex
    if redirect
      next error_template(400, ex)
    else
      next error_json(400, ex)
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
    next error_json(400, "Unsupported action #{action}")
  end

  if redirect
    env.redirect referer
  else
    env.response.content_type = "application/json"
    "{}"
  end
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

# Authenticated endpoints

# The notification APIs can't be extracted yet
# due to the requirement of the `connection_channel`
# used by the `NotificationJob`

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
    url = URI.parse(url).request_target
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
      response = YT_POOL.client &.get(URI.parse(response.headers["Location"]).request_target)
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

error 500 do |env, ex|
  locale = LOCALES[env.get("preferences").as(Preferences).locale]?
  error_template(500, ex)
end

static_headers do |response|
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

Kemal.config.logger = LOGGER
Kemal.config.host_binding = Kemal.config.host_binding != "0.0.0.0" ? Kemal.config.host_binding : CONFIG.host_binding
Kemal.config.port = Kemal.config.port != 3000 ? Kemal.config.port : CONFIG.port
Kemal.config.app_name = "Invidious"

# Use in kemal's production mode.
# Users can also set the KEMAL_ENV environmental variable for this to be set automatically.
{% if flag?(:release) || flag?(:production) %}
  Kemal.config.env = "production" if !ENV.has_key?("KEMAL_ENV")
{% end %}

Kemal.run
