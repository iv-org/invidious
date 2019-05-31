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

statistics = {
  "error" => "Statistics are not availabile.",
}

proxies = PROXY_LIST

decrypt_function = [] of {name: String, value: Int32}
spawn do
  update_decrypt_function do |function|
    decrypt_function = function
  end
end

before_all do |env|
  env.response.headers["X-XSS-Protection"] = "1; mode=block;"
  env.response.headers["X-Content-Type-Options"] = "nosniff"

  preferences = CONFIG.default_user_preferences.dup

  locale = env.params.query["hl"]?
  locale ||= "en-US"

  preferences.locale = locale

  env.set "preferences", preferences
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
    video = fetch_video(id, proxies, region: region)
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
    video = fetch_video(id, proxies, region: region)
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
      comments = fetch_youtube_comments(id, continuation, proxies, format, locale, thin_mode, region, sort_by: sort_by)
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
    video = fetch_video(id, proxies, region: region)
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
    video = fetch_video(id, proxies, region: region)
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
              width, height = fmt["size"].split("x").map { |i| i.to_i }

              # Resolutions reported by YouTube player (may not accurately reflect source)
              height = [4320, 2160, 1440, 1080, 720, 480, 360, 240, 144].sort_by { |i| (height - i).abs }[0]

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

  video = fetch_video(id, proxies, region: region)

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

error 404 do |env|
  env.response.content_type = "application/json"

  error_message = "404 Not Found"
  {"error" => error_message}.to_json
end

error 500 do |env|
  env.response.content_type = "application/json"

  error_message = "500 Server Error"
  {"error" => error_message}.to_json
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

Kemal.config.powered_by_header = false
add_handler FilteredCompressHandler.new
add_handler APIHandler.new
add_handler DenyFrame.new
add_context_storage_type(Array(String))
add_context_storage_type(Preferences)
add_context_storage_type(User)

Kemal.config.logger = logger
Kemal.run
