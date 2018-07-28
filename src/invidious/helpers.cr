macro add_mapping(mapping)
  def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
  end

  def to_a
    return [{{*mapping.keys.map { |id| "@#{id}".id }}}]
  end

  DB.mapping({{mapping}})
end

macro templated(filename)
  render "src/invidious/views/#{{{filename}}}.ecr", "src/invidious/views/layout.ecr"
end

macro rendered(filename)
  render "src/invidious/views/#{{{filename}}}.ecr"
end

DEFAULT_USER_PREFERENCES = Preferences.from_json({
  "video_loop"  => false,
  "autoplay"    => false,
  "speed"       => 1.0,
  "quality"     => "hd720",
  "volume"      => 100,
  "dark_mode"   => false,
  "thin_mode "  => false,
  "max_results" => 40,
  "sort"        => "published",
  "latest_only" => false,
}.to_json)

class Config
  YAML.mapping({
    crawl_threads:   Int32,
    channel_threads: Int32,
    video_threads:   Int32,
    db:              NamedTuple(
      user: String,
      password: String,
      host: String,
      port: Int32,
      dbname: String,
    ),
    dl_api_key: String?,
    https_only: Bool?,
    hmac_key:   String?,
  })
end

class FilteredCompressHandler < Kemal::Handler
  exclude ["/videoplayback"]

  def call(env)
    return call_next env if exclude_match? env

    {% if flag?(:without_zlib) %}
      call_next env
    {% else %}
      request_headers = env.request.headers

      if request_headers.includes_word?("Accept-Encoding", "gzip")
        env.response.headers["Content-Encoding"] = "gzip"
        env.response.output = Gzip::Writer.new(env.response.output, sync_close: true)
      elsif request_headers.includes_word?("Accept-Encoding", "deflate")
        env.response.headers["Content-Encoding"] = "deflate"
        env.response.output = Flate::Writer.new(env.response.output, sync_close: true)
      end

      call_next env
    {% end %}
  end
end

class Video
  module HTTPParamConverter
    def self.from_rs(rs)
      HTTP::Params.parse(rs.read(String))
    end
  end

  add_mapping({
    id:   String,
    info: {
      type:      HTTP::Params,
      default:   HTTP::Params.parse(""),
      converter: Video::HTTPParamConverter,
    },
    updated:            Time,
    title:              String,
    views:              Int64,
    likes:              Int32,
    dislikes:           Int32,
    wilson_score:       Float64,
    published:          Time,
    description:        String,
    language:           String?,
    author:             String,
    ucid:               String,
    allowed_regions:    Array(String),
    is_family_friendly: Bool,
    genre:              String,
  })
end

class InvidiousChannel
  add_mapping({
    id:      String,
    author:  String,
    updated: Time,
  })
end

class ChannelVideo
  add_mapping({
    id:        String,
    title:     String,
    published: Time,
    updated:   Time,
    ucid:      String,
    author:    String,
  })
end

class User
  module PreferencesConverter
    def self.from_rs(rs)
      begin
        Preferences.from_json(rs.read(String))
      rescue ex
        DEFAULT_USER_PREFERENCES
      end
    end
  end

  add_mapping({
    id:            String,
    updated:       Time,
    notifications: Array(String),
    subscriptions: Array(String),
    email:         String,
    preferences:   {
      type:      Preferences,
      default:   DEFAULT_USER_PREFERENCES,
      converter: PreferencesConverter,
    },
    password: String?,
    token:    String,
  })
end

# TODO: Migrate preferences so this will not be nilable
class Preferences
  JSON.mapping({
    video_loop: Bool,
    autoplay:   Bool,
    speed:      Float32,
    quality:    String,
    volume:     Int32,
    dark_mode:  Bool,
    thin_mode:  {
      type:    Bool,
      nilable: true,
      default: false,
    },
    max_results: Int32,
    sort:        String,
    latest_only: Bool,
  })
end

class RedditThing
  JSON.mapping({
    kind: String,
    data: RedditComment | RedditLink | RedditMore | RedditListing,
  })
end

class RedditComment
  JSON.mapping({
    author:    String,
    body_html: String,
    replies:   RedditThing | String,
    score:     Int32,
    depth:     Int32,
  })
end

class RedditLink
  JSON.mapping({
    author:       String,
    score:        Int32,
    subreddit:    String,
    num_comments: Int32,
    id:           String,
    permalink:    String,
    title:        String,
  })
end

class RedditMore
  JSON.mapping({
    children: Array(String),
    count:    Int32,
    depth:    Int32,
  })
end

class RedditListing
  JSON.mapping({
    children: Array(RedditThing),
    modhash:  String,
  })
end

# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0.0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def fetch_video(id, client)
  info_channel = Channel(HTTP::Params).new
  html_channel = Channel(XML::Node).new

  spawn do
    html = client.get("/watch?v=#{id}&bpctr=#{Time.new.epoch + 2000}&disable_polymer=1").body
    html = XML.parse_html(html)

    html_channel.send(html)
  end

  spawn do
    info = client.get("/get_video_info?video_id=#{id}&el=detailpage&ps=default&eurl=&gl=US&hl=en&disable_polymer=1").body
    info = HTTP::Params.parse(info)

    if info["reason"]?
      info = client.get("/get_video_info?video_id=#{id}&ps=default&eurl=&gl=US&hl=en&disable_polymer=1").body
      info = HTTP::Params.parse(info)
    end

    info_channel.send(info)
  end

  html = html_channel.receive
  info = info_channel.receive

  if info["reson"]?
    raise info["reason"]
  end

  title = info["title"]
  views = info["view_count"].to_i64
  author = info["author"]
  ucid = info["ucid"]

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  likes = likes.try &.content.delete(",").try &.to_i
  likes ||= 0

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  dislikes = dislikes.try &.content.delete(",").try &.to_i
  dislikes ||= 0

  description = html.xpath_node(%q(//p[@id="eow-description"]))
  description = description ? description.to_xml : ""

  wilson_score = ci_lower_bound(likes, likes + dislikes)

  published = html.xpath_node(%q(//meta[@itemprop="datePublished"])).not_nil!["content"]
  published = Time.parse(published, "%Y-%m-%d", Time::Location.local)

  allowed_regions = html.xpath_node(%q(//meta[@itemprop="regionsAllowed"])).not_nil!["content"].split(",")
  is_family_friendly = html.xpath_node(%q(//meta[@itemprop="isFamilyFriendly"])).not_nil!["content"] == "True"
  genre = html.xpath_node(%q(//meta[@itemprop="genre"])).not_nil!["content"]

  video = Video.new(id, info, Time.now, title, views, likes, dislikes, wilson_score, published, description, nil, author, ucid, allowed_regions, is_family_friendly, genre)

  return video
end

def get_video(id, client, db, refresh = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool)
    video = db.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated over an hour ago, refresh (expire param in response lasts for 6 hours)
    if refresh && Time.now - video.updated > 1.hour
      begin
        video = fetch_video(id, client)
        video_array = video.to_a
        args = arg_array(video_array[1..-1], 2)

        db.exec("UPDATE videos SET (info,updated,title,views,likes,dislikes,wilson_score,\
        published,description,language,author,ucid, allowed_regions, is_family_friendly, genre)\
        = (#{args}) WHERE id = $1", video_array)
      rescue ex
        db.exec("DELETE FROM videos * WHERE id = $1", id)
      end
    end
  else
    video = fetch_video(id, client)
    video_array = video.to_a
    args = arg_array(video_array)

    db.exec("INSERT INTO videos VALUES (#{args}) ON CONFLICT (id) DO NOTHING", video_array)
  end

  return video
end

def search(query, client, &block)
  html = client.get("/results?q=#{query}&sp=EgIQAVAU&disable_polymer=1").body
  html = XML.parse_html(html)

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if root
      link = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
      if link
        yield link.content.split("=")[1]
      end
    end
  end
end

def splice(a, b)
  c = a[0]
  a[0] = a[b % a.size]
  a[b % a.size] = c
  return a
end

def decrypt_signature(a, code)
  a = a.split("")

  code.each do |item|
    case item[:name]
    when "a"
      a.reverse!
    when "b"
      a.delete_at(0..(item[:value] - 1))
    when "c"
      a = splice(a, item[:value])
    end
  end

  return a.join("")
end

def update_decrypt_function(client)
  # Video with signature
  document = client.get("/watch?v=CvFH_6DNRCY").body
  url = document.match(/src="(?<url>\/yts\/jsbin\/player-.{9}\/en_US\/base.js)"/).not_nil!["url"]
  player = client.get(url).body

  function_name = player.match(/\(b\|\|\(b="signature"\),d.set\(b,(?<name>[a-zA-Z0-9]{2})\(c\)\)\)/).not_nil!["name"]
  function_body = player.match(/#{function_name}=function\(a\){(?<body>[^}]+)}/).not_nil!["body"]
  function_body = function_body.split(";")[1..-2]

  var_name = function_body[0][0, 2]

  operations = {} of String => String
  matches = player.delete("\n").match(/var #{var_name}={(?<op1>[a-zA-Z0-9]{2}:[^}]+}),(?<op2>[a-zA-Z0-9]{2}:[^}]+}),(?<op3>[a-zA-Z0-9]{2}:[^}]+})};/).not_nil!
  3.times do |i|
    operation = matches["op#{i + 1}"]
    op_name = operation[0, 2]

    op_body = operation.match(/\{[^}]+\}/).not_nil![0]
    case op_body
    when "{a.reverse()}"
      operations[op_name] = "a"
    when "{a.splice(0,b)}"
      operations[op_name] = "b"
    else
      operations[op_name] = "c"
    end
  end

  decrypt_function = [] of {name: String, value: Int32}
  function_body.each do |function|
    function = function.lchop(var_name + ".")
    op_name = function[0, 2]

    function = function.lchop(op_name + "(a,")
    value = function.rchop(")").to_i

    decrypt_function << {name: operations[op_name], value: value}
  end

  return decrypt_function
end

def rank_videos(db, n, filter, url)
  top = [] of {Float64, String}

  db.query("SELECT id, wilson_score, published FROM videos WHERE views > 5000 ORDER BY published DESC LIMIT 1000") do |rs|
    rs.each do
      id = rs.read(String)
      wilson_score = rs.read(Float64)
      published = rs.read(Time)

      # Exponential decay, older videos tend to rank lower
      temperature = wilson_score * Math.exp(-0.000005*((Time.now - published).total_minutes))
      top << {temperature, id}
    end
  end

  top.sort!

  # Make hottest come first
  top.reverse!
  top = top.map { |a, b| b }

  if filter
    language_list = [] of String
    top.each do |id|
      if language_list.size == n
        break
      else
        client = make_client(url)
        begin
          video = get_video(id, client, db)
        rescue ex
          next
        end

        if video.language
          language = video.language
        else
          description = XML.parse(video.description)
          content = [video.title, description.content].join(" ")
          content = content[0, 10000]

          results = DetectLanguage.detect(content)
          language = results[0].language

          db.exec("UPDATE videos SET language = $1 WHERE id = $2", language, id)
        end

        if language == "en"
          language_list << id
        end
      end
    end
    return language_list
  else
    return top[0..n - 1]
  end
end

def make_client(url)
  context = OpenSSL::SSL::Context::Client.new
  context.add_options(
    OpenSSL::SSL::Options::ALL |
    OpenSSL::SSL::Options::NO_SSL_V2 |
    OpenSSL::SSL::Options::NO_SSL_V3
  )
  client = HTTP::Client.new(url, context)
  client.read_timeout = 10.seconds
  client.connect_timeout = 10.seconds
  return client
end

def get_reddit_comments(id, client, headers)
  query = "(url:3D#{id}%20OR%20url:#{id})%20(site:youtube.com%20OR%20site:youtu.be)"
  search_results = client.get("/search.json?q=#{query}", headers)

  if search_results.status_code == 200
    search_results = RedditThing.from_json(search_results.body)

    thread = search_results.data.as(RedditListing).children.sort_by { |child| child.data.as(RedditLink).score }[-1]
    thread = thread.data.as(RedditLink)

    result = client.get("/r/#{thread.subreddit}/comments/#{thread.id}?limit=100&sort=top", headers).body
    result = Array(RedditThing).from_json(result)
  elsif search_results.status_code == 302
    result = client.get(search_results.headers["Location"], headers).body
    result = Array(RedditThing).from_json(result)

    thread = result[0].data.as(RedditListing).children[0].data.as(RedditLink)
  else
    raise "Got error code #{search_results.status_code}"
  end

  comments = result[1].data.as(RedditListing).children
  return comments, thread
end

def template_comments(root)
  html = ""
  root.each do |child|
    if child.data.is_a?(RedditComment)
      child = child.data.as(RedditComment)
      author = child.author
      score = child.score
      body_html = HTML.unescape(child.body_html)

      replies_html = ""
      if child.replies.is_a?(RedditThing)
        replies = child.replies.as(RedditThing)
        replies_html = template_comments(replies.data.as(RedditListing).children)
      end

      content = <<-END_HTML
      <p>
        <a href="javascript:void(0)" onclick="toggle(this)">[ - ]</a> #{score} <b>#{author}</b> 
      </p>
      <div>
      #{body_html}
      #{replies_html}
      </div>
      END_HTML

      if child.depth > 0
        html += <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1-24">
          </div>
          <div class="pure-u-23-24">
          #{content}
          </div>
          </div>
        END_HTML
      else
        html += <<-END_HTML
          <div class="pure-g">
          <div class="pure-u-1">
          #{content}
          </div>
          </div>
        END_HTML
      end
    end
  end

  return html
end

def number_with_separator(number)
  number.to_s.reverse.gsub(/(\d{3})(?=\d)/, "\\1,").reverse
end

def arg_array(array, start = 1)
  if array.size == 0
    args = "NULL"
  else
    args = [] of String
    (start..array.size + start - 1).each { |i| args << "($#{i})" }
    args = args.join(",")
  end

  return args
end

def add_alt_links(html)
  alt_links = [] of {Int32, String}

  # This is painful but is likely the only way to accomplish this in Crystal,
  # as Crystigiri and others are not able to insert XML Nodes into a document.
  # The goal here is to use as little regex as possible
  html.scan(/<a[^>]*>([^<]+)<\/a>/) do |match|
    anchor = XML.parse_html(match[0])
    anchor = anchor.xpath_node("//a").not_nil!
    url = URI.parse(HTML.unescape(anchor["href"]))

    if ["www.youtube.com", "m.youtube.com"].includes?(url.host)
      alt_link = <<-END_HTML
      <a href="#{url.full_path}">
        <i class="fa fa-link" aria-hidden="true"></i>
      </a>
      END_HTML
    elsif url.host == "youtu.be"
      alt_link = <<-END_HTML
      <a href="/watch?v=#{url.path.try &.lchop("/")}&#{url.query}">
        <i class="fa fa-link" aria-hidden="true"></i>
      </a>
      END_HTML
    else
      alt_link = ""
    end

    alt_links << {match.end.not_nil!, alt_link}
  end

  alt_links.reverse!
  alt_links.each do |position, alt_link|
    html = html.insert(position, alt_link)
  end

  return html
end

def fill_links(html, scheme, host)
  html = XML.parse_html(html)

  html.xpath_nodes("//a").each do |match|
    url = URI.parse(match["href"])
    # Reddit links don't have host
    if !url.host && !match["href"].starts_with?("javascript")
      url.scheme = scheme
      url.host = host
      match["href"] = url
    end
  end

  html = html.to_xml
end

def login_req(login_form, f_req)
  data = {
    "pstMsg"          => "1",
    "checkConnection" => "youtube",
    "checkedDomains"  => "youtube",
    "hl"              => "en",
    "deviceinfo"      => %q([null,null,null,[],null,"US",null,null,[],"GlifWebSignIn",null,[null,null,[]]]),
    "f.req"           => f_req,
    "flowName"        => "GlifWebSignIn",
    "flowEntry"       => "ServiceLogin",
  }

  data = login_form.merge(data)

  return HTTP::Params.encode(data)
end

def get_channel(id, client, db, refresh = true, pull_all_videos = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM channels WHERE id = $1)", id, as: Bool)
    channel = db.query_one("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)

    if refresh && Time.now - channel.updated > 10.minutes
      channel = fetch_channel(id, client, db, pull_all_videos)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
      ON CONFLICT (id) DO UPDATE SET updated = $3", channel_array)
    end
  else
    channel = fetch_channel(id, client, db, pull_all_videos)
    args = arg_array(channel.to_a)
    db.exec("INSERT INTO channels VALUES (#{args})", channel.to_a)
  end

  return channel
end

def fetch_channel(ucid, client, db, pull_all_videos = true)
  rss = client.get("/feeds/videos.xml?channel_id=#{ucid}").body
  rss = XML.parse_html(rss)

  author = rss.xpath_node(%q(//feed/title))
  if !author
    raise "Deleted or invalid channel"
  end
  author = author.content

  if !pull_all_videos
    rss.xpath_nodes("//feed/entry").each do |entry|
      video_id = entry.xpath_node("videoid").not_nil!.content
      title = entry.xpath_node("title").not_nil!.content
      published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z", Time::Location.local)
      updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z", Time::Location.local)
      author = entry.xpath_node("author/name").not_nil!.content
      ucid = entry.xpath_node("channelid").not_nil!.content

      video = ChannelVideo.new(video_id, title, published, Time.now, ucid, author)

      db.exec("UPDATE users SET notifications = notifications || $1 \
      WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, ucid)

      video_array = video.to_a
      args = arg_array(video_array)
      db.exec("INSERT INTO channel_videos VALUES (#{args}) \
      ON CONFLICT (id) DO UPDATE SET title = $2, published = $3, \
      updated = $4, ucid = $5, author = $6", video_array)
    end
  else
    videos = [] of ChannelVideo
    page = 1

    loop do
      url = produce_videos_url(ucid, page)
      response = client.get(url)

      json = JSON.parse(response.body)
      content_html = json["content_html"].as_s
      if content_html.empty?
        # If we don't get anything, move on
        break
      end
      document = XML.parse_html(content_html)

      document.xpath_nodes(%q(//li[contains(@class, "feed-item-container")])).each do |item|
        anchor = item.xpath_node(%q(.//h3[contains(@class,"yt-lockup-title")]/a))
        if !anchor
          raise "could not find anchor"
        end

        title = anchor.content.strip
        video_id = anchor["href"].lchop("/watch?v=")

        published = item.xpath_node(%q(.//div[@class="yt-lockup-meta"]/ul/li[1]))
        if !published
          # This happens on Youtube red videos, here we just skip them
          next
        end
        published = published.content
        published = decode_date(published)

        videos << ChannelVideo.new(video_id, title, published, Time.now, ucid, author)
      end

      if document.xpath_nodes(%q(//li[contains(@class, "channels-content-item")])).size < 30
        break
      end

      page += 1
    end

    video_ids = [] of String
    videos.each do |video|
      db.exec("UPDATE users SET notifications = notifications || $1 \
      WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video.id, video.published, ucid)
      video_ids << video.id

      video_array = video.to_a
      args = arg_array(video_array)
      db.exec("INSERT INTO channel_videos VALUES (#{args}) ON CONFLICT (id) DO NOTHING", video_array)
    end

    # When a video is deleted from a channel, we find and remove it here
    db.exec("DELETE FROM channel_videos * WHERE NOT id = ANY ('{#{video_ids.map { |a| %("#{a}") }.join(",")}}') AND ucid = $1", ucid)
  end

  channel = InvidiousChannel.new(ucid, author, Time.now)

  return channel
end

def get_user(sid, client, headers, db, refresh = true)
  if db.query_one?("SELECT EXISTS (SELECT true FROM users WHERE id = $1)", sid, as: Bool)
    user = db.query_one("SELECT * FROM users WHERE id = $1", sid, as: User)

    if refresh && Time.now - user.updated > 1.minute
      user = fetch_user(sid, client, headers, db)
      user_array = user.to_a
      user_array[5] = user_array[5].to_json
      args = arg_array(user_array)

      db.exec("INSERT INTO users VALUES (#{args}) \
      ON CONFLICT (email) DO UPDATE SET id = $1, updated = $2, subscriptions = $4", user_array)
    end
  else
    user = fetch_user(sid, client, headers, db)
    user_array = user.to_a
    user_array[5] = user_array[5].to_json
    args = arg_array(user.to_a)

    db.exec("INSERT INTO users VALUES (#{args}) \
    ON CONFLICT (email) DO UPDATE SET id = $1, updated = $2, subscriptions = $4", user_array)
  end

  return user
end

def fetch_user(sid, client, headers, db)
  feed = client.get("/subscription_manager?disable_polymer=1", headers)
  feed = XML.parse_html(feed.body)

  channels = [] of String
  feed.xpath_nodes(%q(//ul[@id="guide-channels"]/li/a)).each do |channel|
    if !["Popular on YouTube", "Music", "Sports", "Gaming"].includes? channel["title"]
      channel_id = channel["href"].lstrip("/channel/")

      begin
        channel = get_channel(channel_id, client, db, false, false)
        channels << channel.id
      rescue ex
        next
      end
    end
  end

  email = feed.xpath_node(%q(//a[@class="yt-masthead-picker-header yt-masthead-picker-active-account"]))
  if email
    email = email.content.strip
  else
    email = ""
  end

  token = Base64.encode(Random::Secure.random_bytes(32))

  user = User.new(sid, Time.now, [] of String, channels, email, DEFAULT_USER_PREFERENCES, nil, token)
  return user
end

def create_user(sid, email, password)
  password = Crypto::Bcrypt::Password.create(password, cost: 10)
  token = Base64.encode(Random::Secure.random_bytes(32))

  user = User.new(sid, Time.now, [] of String, [] of String, email, DEFAULT_USER_PREFERENCES, password.to_s, token)

  return user
end

def decode_time(string)
  time = string.try &.to_f?

  if !time
    hours = /(?<hours>\d+)h/.match(string).try &.["hours"].try &.to_i
    hours ||= 0

    minutes = /(?<minutes>\d+)m(?!s)/.match(string).try &.["minutes"].try &.to_i
    minutes ||= 0

    seconds = /(?<seconds>\d+)s/.match(string).try &.["seconds"].try &.to_i
    seconds ||= 0

    millis = /(?<millis>\d+)ms/.match(string).try &.["millis"].try &.to_i
    millis ||= 0

    time = hours * 3600 + minutes * 60 + seconds + millis / 1000
  end

  return time
end

def decode_date(date : String)
  # Time matches format "20 hours ago", "40 minutes ago"...
  delta = date.split(" ")[0].to_i
  case date
  when .includes? "minute"
    delta = delta.minutes
  when .includes? "hour"
    delta = delta.hours
  when .includes? "day"
    delta = delta.days
  when .includes? "week"
    delta = delta.weeks
  when .includes? "month"
    delta = delta.months
  when .includes? "year"
    delta = delta.years
  else
    raise "Could not parse #{date}"
  end

  return Time.now - delta
end

def produce_playlist_url(ucid, index)
  ucid = ucid.lchop("UC")
  ucid = "VLUU" + ucid

  continuation = write_var_int(index)
  continuation.unshift(0x08_u8)
  slice = continuation.to_unsafe.to_slice(continuation.size)

  continuation = Base64.urlsafe_encode(slice, false)
  continuation = "PT:" + continuation
  continuation = continuation.bytes
  continuation.unshift(0x7a_u8, continuation.size.to_u8)

  slice = continuation.to_unsafe.to_slice(continuation.size)
  continuation = Base64.urlsafe_encode(slice)
  continuation = URI.escape(continuation)
  continuation = continuation.bytes
  continuation.unshift(continuation.size.to_u8)

  continuation.unshift(ucid.size.to_u8)
  continuation = ucid.bytes + continuation
  continuation.unshift(0x12.to_u8, ucid.size.to_u8)
  continuation.unshift(0xe2_u8, 0xa9_u8, 0x85_u8, 0xb2_u8, 2_u8, continuation.size.to_u8)

  slice = continuation.to_unsafe.to_slice(continuation.size)
  continuation = Base64.urlsafe_encode(slice)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?action_continuation=1&continuation=#{continuation}"

  return url
end

def produce_videos_url(ucid, page)
  page = "#{page}"

  meta = "\x12\x06videos \x00\x30\x02\x38\x01\x60\x01\x6a\x00\x7a"
  meta += page.size.to_u8.unsafe_chr
  meta += page
  meta += "\xb8\x01\x00"

  meta = Base64.urlsafe_encode(meta)
  meta = URI.escape(meta)

  continuation = "\x12"
  continuation += ucid.size.to_u8.unsafe_chr
  continuation += ucid
  continuation += "\x1a"
  continuation += meta.size.to_u8.unsafe_chr
  continuation += meta

  continuation = continuation.size.to_u8.unsafe_chr + continuation
  continuation = "\xe2\xa9\x85\xb2\x02" + continuation

  continuation = Base64.urlsafe_encode(continuation)
  continuation = URI.escape(continuation)

  url = "/browse_ajax?continuation=#{continuation}"

  return url
end

def read_var_int(bytes)
  numRead = 0
  result = 0

  read = bytes[numRead]

  if bytes.size == 1
    result = bytes[0].to_i32
  else
    while ((read & 0b10000000) != 0)
      read = bytes[numRead].to_u64
      value = (read & 0b01111111)
      result |= (value << (7 * numRead))

      numRead += 1
      if numRead > 5
        raise "VarInt is too big"
      end
    end
  end

  return result
end

def write_var_int(value : Int)
  bytes = [] of UInt8
  value = value.to_u32

  if value == 0
    bytes = [0_u8]
  else
    while value != 0
      temp = (value & 0b01111111).to_u8
      value = value >> 7

      if value != 0
        temp |= 0b10000000
      end

      bytes << temp
    end
  end

  return bytes
end

def generate_captcha(key)
  minute = Random::Secure.rand(12)
  minute_angle = minute * 30
  minute = minute * 5

  hour = Random::Secure.rand(12)
  hour_angle = hour * 30 + minute_angle.to_f / 12
  if hour == 0
    hour = 12
  end

  clock_svg = <<-END_SVG
  <svg viewBox="0 0 100 100" width="200px">
  <circle cx="50" cy="50" r="45" fill="#eee" stroke="black" stroke-width="2"></circle>
  
  <text x="69"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 1</text>
  <text x="82.909" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 2</text>
  <text x="88"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 3</text>
  <text x="82.909" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 4</text>
  <text x="69"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 5</text>
  <text x="50"     y="91"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 6</text>
  <text x="31"     y="85.909" text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 7</text>
  <text x="17.091" y="72"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 8</text>
  <text x="12"     y="53"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px"> 9</text>
  <text x="17.091" y="34"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">10</text>
  <text x="31"     y="20.091" text-anchor="middle" fill="black" font-family="Arial" font-size="10px">11</text>
  <text x="50"     y="15"     text-anchor="middle" fill="black" font-family="Arial" font-size="10px">12</text>

  <circle cx="50" cy="50" r="3" fill="black"></circle>
  <line id="minute" transform="rotate(#{minute_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="16" fill="black" stroke="black" stroke-width="2"></line>
  <line id="hour"   transform="rotate(#{hour_angle}, 50, 50)" x1="50" y1="50" x2="50" y2="24" fill="black" stroke="black" stroke-width="2"></line>
  </svg>
  END_SVG

  challenge = ""
  convert = Process.run(%(convert -density 1200 -resize 400x400 -background none svg:- png:-), shell: true, input: IO::Memory.new(clock_svg), output: Process::Redirect::Pipe) do |proc|
    challenge = proc.output.gets_to_end
    challenge = Base64.strict_encode(challenge)
    challenge = "data:image/png;base64,#{challenge}"
  end

  answer = "#{hour}:#{minute.to_s.rjust(2, '0')}"
  token = OpenSSL::HMAC.digest(:sha256, key, answer)
  token = Base64.encode(token)

  return {challenge: challenge, token: token}
end

def itag_to_metadata(itag : String)
  # See https://github.com/rg3/youtube-dl/blob/master/youtube_dl/extractor/youtube.py#L380-#L476
  formats = {"5"  => {"ext" => "flv", "width" => 400, "height" => 240, "acodec" => "mp3", "abr" => 64, "vcodec" => "h263"},
             "6"  => {"ext" => "flv", "width" => 450, "height" => 270, "acodec" => "mp3", "abr" => 64, "vcodec" => "h263"},
             "13" => {"ext" => "3gp", "acodec" => "aac", "vcodec" => "mp4v"},
             "17" => {"ext" => "3gp", "width" => 176, "height" => 144, "acodec" => "aac", "abr" => 24, "vcodec" => "mp4v"},
             "18" => {"ext" => "mp4", "width" => 640, "height" => 360, "acodec" => "aac", "abr" => 96, "vcodec" => "h264"},
             "22" => {"ext" => "mp4", "width" => 1280, "height" => 720, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
             "34" => {"ext" => "flv", "width" => 640, "height" => 360, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "35" => {"ext" => "flv", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},

             "36" => {"ext" => "3gp", "width" => 320, "acodec" => "aac", "vcodec" => "mp4v"},
             "37" => {"ext" => "mp4", "width" => 1920, "height" => 1080, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
             "38" => {"ext" => "mp4", "width" => 4096, "height" => 3072, "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
             "43" => {"ext" => "webm", "width" => 640, "height" => 360, "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
             "44" => {"ext" => "webm", "width" => 854, "height" => 480, "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
             "45" => {"ext" => "webm", "width" => 1280, "height" => 720, "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
             "46" => {"ext" => "webm", "width" => 1920, "height" => 1080, "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
             "59" => {"ext" => "mp4", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "78" => {"ext" => "mp4", "width" => 854, "height" => 480, "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},

             # 3D videos
             "82"  => {"ext" => "mp4", "height" => 360, "format" => "3D", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "83"  => {"ext" => "mp4", "height" => 480, "format" => "3D", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "84"  => {"ext" => "mp4", "height" => 720, "format" => "3D", "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
             "85"  => {"ext" => "mp4", "height" => 1080, "format" => "3D", "acodec" => "aac", "abr" => 192, "vcodec" => "h264"},
             "100" => {"ext" => "webm", "height" => 360, "format" => "3D", "acodec" => "vorbis", "abr" => 128, "vcodec" => "vp8"},
             "101" => {"ext" => "webm", "height" => 480, "format" => "3D", "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},
             "102" => {"ext" => "webm", "height" => 720, "format" => "3D", "acodec" => "vorbis", "abr" => 192, "vcodec" => "vp8"},

             # Apple HTTP Live Streaming
             "91"  => {"ext" => "mp4", "height" => 144, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
             "92"  => {"ext" => "mp4", "height" => 240, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
             "93"  => {"ext" => "mp4", "height" => 360, "format" => "HLS", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "94"  => {"ext" => "mp4", "height" => 480, "format" => "HLS", "acodec" => "aac", "abr" => 128, "vcodec" => "h264"},
             "95"  => {"ext" => "mp4", "height" => 720, "format" => "HLS", "acodec" => "aac", "abr" => 256, "vcodec" => "h264"},
             "96"  => {"ext" => "mp4", "height" => 1080, "format" => "HLS", "acodec" => "aac", "abr" => 256, "vcodec" => "h264"},
             "132" => {"ext" => "mp4", "height" => 240, "format" => "HLS", "acodec" => "aac", "abr" => 48, "vcodec" => "h264"},
             "151" => {"ext" => "mp4", "height" => 72, "format" => "HLS", "acodec" => "aac", "abr" => 24, "vcodec" => "h264"},

             # DASH mp4 video
             "133" => {"ext" => "mp4", "height" => 240, "format" => "DASH video", "vcodec" => "h264"},
             "134" => {"ext" => "mp4", "height" => 360, "format" => "DASH video", "vcodec" => "h264"},
             "135" => {"ext" => "mp4", "height" => 480, "format" => "DASH video", "vcodec" => "h264"},
             "136" => {"ext" => "mp4", "height" => 720, "format" => "DASH video", "vcodec" => "h264"},
             "137" => {"ext" => "mp4", "height" => 1080, "format" => "DASH video", "vcodec" => "h264"},
             "138" => {"ext" => "mp4", "format" => "DASH video", "vcodec" => "h264"}, # Height can vary (https=>//github.com/rg3/youtube-dl/issues/4559)
             "160" => {"ext" => "mp4", "height" => 144, "format" => "DASH video", "vcodec" => "h264"},
             "212" => {"ext" => "mp4", "height" => 480, "format" => "DASH video", "vcodec" => "h264"},
             "264" => {"ext" => "mp4", "height" => 1440, "format" => "DASH video", "vcodec" => "h264"},
             "298" => {"ext" => "mp4", "height" => 720, "format" => "DASH video", "vcodec" => "h264", "fps" => 60},
             "299" => {"ext" => "mp4", "height" => 1080, "format" => "DASH video", "vcodec" => "h264", "fps" => 60},
             "266" => {"ext" => "mp4", "height" => 2160, "format" => "DASH video", "vcodec" => "h264"},

             # Dash mp4 audio
             "139" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 48, "container" => "m4a_dash"},
             "140" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 128, "container" => "m4a_dash"},
             "141" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "abr" => 256, "container" => "m4a_dash"},
             "256" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "container" => "m4a_dash"},
             "258" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "aac", "container" => "m4a_dash"},
             "325" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "dtse", "container" => "m4a_dash"},
             "328" => {"ext" => "m4a", "format" => "DASH audio", "acodec" => "ec-3", "container" => "m4a_dash"},

             # Dash webm
             "167" => {"ext" => "webm", "height" => 360, "width" => 640, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "168" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "169" => {"ext" => "webm", "height" => 720, "width" => 1280, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "170" => {"ext" => "webm", "height" => 1080, "width" => 1920, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "218" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "219" => {"ext" => "webm", "height" => 480, "width" => 854, "format" => "DASH video", "container" => "webm", "vcodec" => "vp8"},
             "278" => {"ext" => "webm", "height" => 144, "format" => "DASH video", "container" => "webm", "vcodec" => "vp9"},
             "242" => {"ext" => "webm", "height" => 240, "format" => "DASH video", "vcodec" => "vp9"},
             "243" => {"ext" => "webm", "height" => 360, "format" => "DASH video", "vcodec" => "vp9"},
             "244" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
             "245" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
             "246" => {"ext" => "webm", "height" => 480, "format" => "DASH video", "vcodec" => "vp9"},
             "247" => {"ext" => "webm", "height" => 720, "format" => "DASH video", "vcodec" => "vp9"},
             "248" => {"ext" => "webm", "height" => 1080, "format" => "DASH video", "vcodec" => "vp9"},
             "271" => {"ext" => "webm", "height" => 1440, "format" => "DASH video", "vcodec" => "vp9"},
             # itag 272 videos are either 3840x2160 (e.g. RtoitU2A-3E) or 7680x4320 (sLprVF6d7Ug)
             "272" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9"},
             "302" => {"ext" => "webm", "height" => 720, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
             "303" => {"ext" => "webm", "height" => 1080, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
             "308" => {"ext" => "webm", "height" => 1440, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},
             "313" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9"},
             "315" => {"ext" => "webm", "height" => 2160, "format" => "DASH video", "vcodec" => "vp9", "fps" => 60},

             # Dash webm audio
             "171" => {"ext" => "webm", "acodec" => "vorbis", "format" => "DASH audio", "abr" => 128},
             "172" => {"ext" => "webm", "acodec" => "vorbis", "format" => "DASH audio", "abr" => 256},

             # Dash webm audio with opus inside
             "249" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 50},
             "250" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 70},
             "251" => {"ext" => "webm", "format" => "DASH audio", "acodec" => "opus", "abr" => 160},
  }

  return formats[itag]
end
