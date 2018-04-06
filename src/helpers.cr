macro add_mapping(mapping)
  def initialize({{*mapping.keys.map { |id| "@#{id}".id }}})
  end

  def to_a
    return [{{*mapping.keys.map { |id| "@#{id}".id }}}]
  end

  DB.mapping({{mapping}})
end

macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

class Config
  YAML.mapping({
    pool_size: Int32,
    threads:   Int32,
    db:        NamedTuple(
      user: String,
      password: String,
      host: String,
      port: Int32,
      dbname: String,
    ),
    dl_api_key: String?,
  })
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
    updated:      Time,
    title:        String,
    views:        Int64,
    likes:        Int32,
    dislikes:     Int32,
    wilson_score: Float64,
    published:    Time,
    description:  String,
    language:     String?,
  })
end

class InvidiousChannel
  module XMLConverter
    def self.from_rs(rs)
      XML.parse_html(rs.read(String))
    end
  end

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
  add_mapping({
    id:            String,
    updated:       Time,
    notifications: Array(String),
    subscriptions: Array(String),
    email:         String,
  })
end

class RedditSubmit
  JSON.mapping({
    data: RedditSubmitData,
  })
end

class RedditSubmitData
  JSON.mapping({
    children: Array(RedditThread),
  })
end

class RedditThread
  JSON.mapping({
    data: RedditThreadData,
  })
end

class RedditThreadData
  JSON.mapping({
    subreddit:    String,
    id:           String,
    num_comments: Int32,
    score:        Int32,
    author:       String,
    permalink:    String,
    title:        String,
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

def get_client(pool)
  while pool.empty?
    sleep rand(0..10).milliseconds
  end

  return pool.shift
end

def fetch_video(id, client)
  info = client.get("/get_video_info?video_id=#{id}&el=detailpage&ps=default&eurl=&gl=US&hl=en").body
  html = client.get("/watch?v=#{id}&bpctr=#{Time.new.epoch + 2000}").body

  html = XML.parse_html(html)
  info = HTTP::Params.parse(info)

  if info["reason"]?
    info = client.get("/get_video_info?video_id=#{id}&ps=default&eurl=&gl=US&hl=en").body
    info = HTTP::Params.parse(info)
    if info["reason"]?
      raise info["reason"]
    end
  end

  title = info["title"]

  views = info["view_count"].to_i64

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  likes = likes.try &.content.delete(",").try &.to_i
  likes ||= 0

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  dislikes = dislikes.try &.content.delete(",").try &.to_i
  dislikes ||= 0

  description = html.xpath_node(%q(//p[@id="eow-description"]))
  description = description ? description.to_xml : ""

  wilson_score = ci_lower_bound(likes, likes + dislikes)

  published = html.xpath_node(%q(//strong[contains(@class,"watch-time-text")]))
  if published
    published = published.content
  else
    raise "Could not find date published"
  end

  published = published.lchop("Published ")
  published = published.lchop("Started streaming ")
  published = published.lchop("Streamed live ")
  published = published.lchop("Uploaded ")
  published = published.lchop("on ")
  published = published.lchop("Scheduled for ")
  if !published.includes?("ago")
    published = Time.parse(published, "%b %-d, %Y")
  else
    # Time matches format "20 hours ago", "40 minutes ago"...
    delta = published.split(" ")[0].to_i
    case published
    when .includes? "minute"
      published = Time.now - delta.minutes
    when .includes? "hour"
      published = Time.now - delta.hours
    else
      raise "Could not parse #{published}"
    end
  end

  video = Video.new(id, info, Time.now, title, views, likes, dislikes, wilson_score, published, description, nil)

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

        db.exec("UPDATE videos SET (info,updated,title,views,likes,dislikes,wilson_score,published,description,language)\
        = (#{args}) WHERE id = $1", video_array)
      rescue ex
        db.exec("DELETE FROM videos * WHERE id = $1", id)
      end
    end
  else
    video = fetch_video(id, client)
    args = arg_array(video.to_a)
    db.exec("INSERT INTO videos VALUES (#{args})", video.to_a)
  end

  return video
end

def search(query, client)
  html = client.get("https://www.youtube.com/results?q=#{query}&sp=EgIQAVAU").body

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

def decrypt_signature(a)
  a = a.split("")

  a.reverse!
  a.delete_at(0..2)
  a.reverse!
  a.delete_at(0..2)
  a = splice(a, 38)
  a.delete_at(0..0)
  a = splice(a, 64)
  a.reverse!
  a.delete_at(0..1)

  return a.join("")
end

def rank_videos(db, n, pool, filter)
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
        client = get_client(pool)
        begin
          video = get_video(id, client, db)
        rescue ex
          next
        end

        pool << client

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
    search_results = RedditSubmit.from_json(search_results.body)

    thread = search_results.data.children.sort_by { |child| child.data.score }[-1]
    result = client.get("/r/#{thread.data.subreddit}/comments/#{thread.data.id}?limit=100&sort=top", headers).body
    result = JSON.parse(result)
  elsif search_results.status_code == 302
    search_results = client.get(search_results.headers["Location"], headers).body

    result = JSON.parse(search_results)
    thread = RedditThread.from_json(result[0]["data"]["children"][0].to_json)
  else
    raise "Got error code #{search_results.status_code}"
  end

  comments = result[1]["data"]["children"]
  return comments, thread
end

def template_comments(root)
  html = ""
  root.each do |child|
    if child["data"]["body_html"]?
      author = child["data"]["author"]
      score = child["data"]["score"]
      body_html = HTML.unescape(child["data"]["body_html"].as_s)

      replies_html = ""
      if child["data"]["replies"] != ""
        replies_html = template_comments(child["data"]["replies"]["data"]["children"])
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

      if child["data"]["depth"].as_i > 0
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

    if ["www.youtube.com", "m.youtube.com"].includes?(url.host) && url.path == "/watch"
      alt_link = <<-END_HTML
      <a href="#{url.full_path}">
        <i class="fa fa-link" aria-hidden="true"></i>
      </a>
      END_HTML
    elsif url.host == "youtu.be"
      alt_link = <<-END_HTML
      <a href="/watch?v=#{url.full_path.lchop("/")}">
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

  data = data.merge(login_form)

  return HTTP::Params.encode(data)
end

def get_channel(id, client, db)
  if db.query_one?("SELECT EXISTS (SELECT true FROM channels WHERE id = $1)", id, as: Bool)
    channel = db.query_one("SELECT * FROM channels WHERE id = $1", id, as: InvidiousChannel)

    if Time.now - channel.updated > 1.minutes
      channel = fetch_channel(id, client, db)
      channel_array = channel.to_a
      args = arg_array(channel_array)

      db.exec("INSERT INTO channels VALUES (#{args}) \
      ON CONFLICT (id) DO UPDATE SET updated = $3", channel_array)
    end
  else
    channel = fetch_channel(id, client, db)
    args = arg_array(channel.to_a)
    db.exec("INSERT INTO channels VALUES (#{args})", channel.to_a)
  end

  return channel
end

def fetch_channel(id, client, db)
  rss = client.get("/feeds/videos.xml?channel_id=#{id}").body
  rss = XML.parse_html(rss)

  db.exec("DELETE FROM channel_videos * WHERE ucid = $1", id)

  rss.xpath_nodes("//feed/entry").each do |entry|
    video_id = entry.xpath_node("videoid").not_nil!.content
    title = entry.xpath_node("title").not_nil!.content
    published = Time.parse(entry.xpath_node("published").not_nil!.content, "%FT%X%z")
    updated = Time.parse(entry.xpath_node("updated").not_nil!.content, "%FT%X%z")
    author = entry.xpath_node("author/name").not_nil!.content
    ucid = entry.xpath_node("channelid").not_nil!.content

    video = ChannelVideo.new(video_id, title, published, updated, ucid, author)

    video_array = video.to_a
    args = arg_array(video_array)

    db.exec("UPDATE users SET notifications = notifications || $1 \
    WHERE updated < $2 AND $3 = ANY(subscriptions) AND $1 <> ALL(notifications)", video_id, published, ucid)

    # TODO: Update record on conflict
    db.exec("INSERT INTO channel_videos VALUES (#{args})\
      ON CONFLICT (id) DO NOTHING", video_array)
  end

  author = rss.xpath_node("//feed/author/name").not_nil!.content

  channel = InvidiousChannel.new(id, author, Time.now)

  return channel
end

def get_user(sid, client, headers, db)
  if db.query_one?("SELECT EXISTS (SELECT true FROM users WHERE id = $1)", sid, as: Bool)
    user = db.query_one("SELECT * FROM users WHERE id = $1", sid, as: User)

    if Time.now - user.updated > 1.minutes
      user = fetch_user(sid, client, headers)
      user_array = user.to_a
      args = arg_array(user_array)

      db.exec("INSERT INTO users VALUES (#{args}) \
      ON CONFLICT (email) DO UPDATE SET id = $1, updated = $2, notifications = $3, subscriptions = $4", user_array)
    end
  else
    user = fetch_user(sid, client, headers)
    user_array = user.to_a
    args = arg_array(user.to_a)

    db.exec("INSERT INTO users VALUES (#{args}) \
    ON CONFLICT (email) DO UPDATE SET id = $1, updated = $2, subscriptions = $4", user_array)
  end

  return user
end

def fetch_user(sid, client, headers)
  feed = client.get("/subscription_manager?disable_polymer=1", headers).body

  channels = [] of String
  feed = XML.parse_html(feed)

  feed.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
    channel_id = channel.content.lstrip("/channel/").not_nil!
    get_channel(channel_id, client, PG_DB)

    channels << channel_id
  end

  email = feed.xpath_node(%q(//a[@class="yt-masthead-picker-header yt-masthead-picker-active-account"]))
  if email
    email = email.content.lstrip.rstrip
  else
    email = ""
  end

  user = User.new(sid, Time.now, [] of String, channels, email)
  return user
end
