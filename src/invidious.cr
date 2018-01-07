require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"
require "time"

PG_DB   = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
CONTEXT = OpenSSL::SSL::Context::Client.insecure

macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

class Video
  module HTTPParamConverter
    def self.from_rs(rs)
      HTTP::Params.parse(rs.read(String))
    end
  end

  module XMLConverter
    def self.from_rs(rs)
      XML.parse(rs.read(String))
    end
  end

  def initialize(id, info, html, updated)
    @id = id
    @info = info
    @html = html
    @updated = updated
  end

  def to_a
    return [@id, @info, @html, @updated]
  end

  DB.mapping({
    id:   String,
    info: {
      type:      HTTP::Params,
      default:   HTTP::Params.parse(""),
      converter: Video::HTTPParamConverter,
    },
    html: {
      type:      XML::Node,
      default:   XML.parse(""),
      converter: Video::XMLConverter,
    },
    updated: Time,
  })
end

# See http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
def ci_lower_bound(pos, n)
  if n == 0
    return 0
  end

  # z value here represents a confidence level of 0.95
  z = 1.96
  phat = 1.0*pos/n

  return (phat + z*z/(2*n) - z * Math.sqrt((phat*(1 - phat) + z*z/(4*n))/n))/(1 + z*z/n)
end

def fetch_video(id)
  client = HTTP::Client.new("www.youtube.com", 443, CONTEXT)
  info = client.get("/get_video_info?video_id=#{id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(info)

  html = client.get("/watch?v=#{id}").body
  html = XML.parse(html)

  if info["reason"]?
    raise info["reason"]
  end

  video = Video.new(id, info, html, Time.now)

  return video
end

def get_video(id, refresh = true)
  if PG_DB.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", id, as: Bool)
    video = PG_DB.query_one("SELECT * FROM videos WHERE id = $1", id, as: Video)

    # If record was last updated more than 5 hours ago, refresh (expire param in response lasts for 6 hours)
    if refresh && Time.now - video.updated > Time::Span.new(0, 5, 0, 0)
      video = fetch_video(id)
      PG_DB.exec("UPDATE videos SET info = $2, html = $3, updated = $4 WHERE id = $1", video.to_a)
    end
  else
    video = fetch_video(id)
    PG_DB.exec("INSERT INTO videos VALUES ($1, $2, $3, $4)", video.to_a)
  end

  return video
end

get "/" do |env|
  templated "index"
end

get "/watch" do |env|
  id = env.params.query["v"]

  begin
    video = get_video(id)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  query = HTTP::Params.parse(env.request.query.not_nil!)
  if query["listen"]? && query["listen"] == "true"
    query.delete_all("listen")
    listen = true
  else
    query["listen"] = "true"
    listen = false
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  adaptive_fmts = [] of HTTP::Params
  video.info["adaptive_fmts"].split(",") do |string|
    adaptive_fmts << HTTP::Params.parse(string)
  end

  related_videos = video.html.xpath_nodes(%q(//li/div/a[contains(@class,"content-link")]/@href))
  if related_videos.empty?
    related_videos = video.html.xpath_nodes(%q(//ytd-compact-video-renderer/div/a/@href))
  end

  related_videos_list = [] of Video
  related_videos.each do |related_video|
    related_id = related_video.content.split("=")[1]
    begin
      related_videos_list << get_video(related_id, false)
    rescue ex
      p "#{related_id}: #{ex.message}"
    end
  end

  likes = video.html.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content.delete(",").to_i
  else
    likes = 1
  end

  dislikes = video.html.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes = dislikes.content.delete(",").to_i
  else
    dislikes = 1
  end

  description = video.html.xpath_node(%q(//p[@id="eow-description"]))
  if description
    description = description.to_xml
  else
    description = ""
  end

  views = video.info["view_count"].to_i64
  rating = video.info["avg_rating"].to_f64

  likes = likes.to_f
  dislikes = dislikes.to_f
  views = views.to_f

  engagement = ((dislikes + likes)/views * 100)
  calculated_rating = (likes/(likes + dislikes) * 4 + 1)

  templated "watch"
end

get "/search" do |env|
  query = env.params.query["q"]

  client = HTTP::Client.new("www.youtube.com", 443, CONTEXT)
  html = client.get("https://www.youtube.com/results?q=#{URI.escape(query)}&page=1").body
  html = XML.parse(html)

  videos = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-video")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
  channels = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-channel")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))

  if videos.empty?
    videos = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-video")]/div/div[@class="yt-lockup-content"]/h3/a/@href))
    channels = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-channel")]/div[@class="yt-lockup-content"]/h3/a/@href))
  end

  videos_list = [] of Video
  videos.each do |video|
    id = video.content.split("=")[1]
    begin
      videos_list << get_video(id, false)
    rescue ex
      p "#{id}: #{ex.message}"
    end
  end

  templated "search"
end

error 404 do |env|
  templated "index"
end

error 500 do |env|
  templated "index"
end

public_folder "assets"

Kemal.run
