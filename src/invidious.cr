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
require "sqlite3"
require "xml"
require "yaml"
require "compress/zip"
require "protodec/utils"

require "./invidious/database/*"
require "./invidious/database/migrations/*"
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
  parser.on("--migrate", "Run any migrations") do
    Invidious::Database::Migrator.new(PG_DB).migrate
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
Invidious::Database.check_integrity(CONFIG)

{% if !flag?(:skip_videojs_download) %}
  # Resolve player dependencies. This is done at compile time.
  #
  # Running the script by itself would show some colorful feedback while this doesn't.
  # Perhaps we should just move the script to runtime in order to get that feedback?

  {% puts "\nChecking player dependencies...\n" %}
  {% if flag?(:minified_player_dependencies) %}
    {% puts run("../scripts/fetch-player-dependencies.cr", "--minified").stringify %}
  {% else %}
    {% puts run("../scripts/fetch-player-dependencies.cr").stringify %}
  {% end %}
{% end %}

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
      if email = Invidious::Database::SessionIDs.select_email(sid)
        user = Invidious::Database::Users.select!(email: email)
        csrf_token = generate_response(sid, {
          ":authorize_token",
          ":playlist_ajax",
          ":signout",
          ":subscription_ajax",
          ":token_ajax",
          ":watch_ajax",
        }, HMAC_KEY, 1.week)

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
        user, sid = get_user(sid, headers, false)
        csrf_token = generate_response(sid, {
          ":authorize_token",
          ":playlist_ajax",
          ":signout",
          ":subscription_ajax",
          ":token_ajax",
          ":watch_ajax",
        }, HMAC_KEY, 1.week)

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
  Invidious::Routing.post "/watch_ajax", Invidious::Routes::Watch, :mark_watched
  Invidious::Routing.get "/watch/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/shorts/:id", Invidious::Routes::Watch, :redirect
  Invidious::Routing.get "/clip/:clip", Invidious::Routes::Watch, :clip
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
  Invidious::Routing.get "/data_control", Invidious::Routes::PreferencesRoute, :data_control
  Invidious::Routing.post "/data_control", Invidious::Routes::PreferencesRoute, :update_data_control

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

  Invidious::Routing.get "/modify_notifications", Invidious::Routes::Notifications, :modify

  Invidious::Routing.post "/subscription_ajax", Invidious::Routes::Subscriptions, :toggle_subscription
  Invidious::Routing.get "/subscription_manager", Invidious::Routes::Subscriptions, :subscription_manager
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

get "/change_password" do |env|
  locale = env.get("preferences").as(Preferences).locale

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":change_password"}, HMAC_KEY)

  templated "change_password"
end

post "/change_password" do |env|
  locale = env.get("preferences").as(Preferences).locale

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
    validate_request(token, sid, env.request, HMAC_KEY, locale)
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
  Invidious::Database::Users.update_password(user, new_password.to_s)

  env.redirect referer
end

get "/delete_account" do |env|
  locale = env.get("preferences").as(Preferences).locale

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":delete_account"}, HMAC_KEY)

  templated "delete_account"
end

post "/delete_account" do |env|
  locale = env.get("preferences").as(Preferences).locale

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
    validate_request(token, sid, env.request, HMAC_KEY, locale)
  rescue ex
    next error_template(400, ex)
  end

  view_name = "subscriptions_#{sha256(user.email)}"
  Invidious::Database::Users.delete(user)
  Invidious::Database::SessionIDs.delete(email: user.email)
  PG_DB.exec("DROP MATERIALIZED VIEW #{view_name}")

  env.request.cookies.each do |cookie|
    cookie.expires = Time.utc(1990, 1, 1)
    env.response.cookies << cookie
  end

  env.redirect referer
end

get "/clear_watch_history" do |env|
  locale = env.get("preferences").as(Preferences).locale

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":clear_watch_history"}, HMAC_KEY)

  templated "clear_watch_history"
end

post "/clear_watch_history" do |env|
  locale = env.get("preferences").as(Preferences).locale

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
    validate_request(token, sid, env.request, HMAC_KEY, locale)
  rescue ex
    next error_template(400, ex)
  end

  Invidious::Database::Users.clear_watch_history(user)
  env.redirect referer
end

get "/authorize_token" do |env|
  locale = env.get("preferences").as(Preferences).locale

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env)

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  sid = sid.as(String)
  csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY)

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
  locale = env.get("preferences").as(Preferences).locale

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
    validate_request(token, sid, env.request, HMAC_KEY, locale)
  rescue ex
    next error_template(400, ex)
  end

  scopes = env.params.body.select { |k, v| k.match(/^scopes\[\d+\]$/) }.map { |k, v| v }
  callback_url = env.params.body["callbackUrl"]?
  expire = env.params.body["expire"]?.try &.to_i?

  access_token = generate_token(user.email, scopes, expire, HMAC_KEY)

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
  locale = env.get("preferences").as(Preferences).locale

  user = env.get? "user"
  sid = env.get? "sid"
  referer = get_referer(env, "/subscription_manager")

  if !user
    next env.redirect referer
  end

  user = user.as(User)
  tokens = Invidious::Database::SessionIDs.select_all(user.email)

  templated "token_manager"
end

post "/token_ajax" do |env|
  locale = env.get("preferences").as(Preferences).locale

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
    validate_request(token, sid, env.request, HMAC_KEY, locale)
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
    Invidious::Database::SessionIDs.delete(sid: session, email: user.email)
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
    locale = env.get("preferences").as(Preferences).locale

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
  locale = env.get("preferences").as(Preferences).locale
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
