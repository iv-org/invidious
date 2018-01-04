require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"
require "time"

macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

class Video
  getter last_updated : Time
  getter video_id : String
  getter video_info : String
  getter video_html : String
  getter views : String
  getter likes : Int32
  getter dislikes : Int32
  getter rating : Float64
  getter description : String

  def initialize(last_updated, video_id, video_info, video_html, views, likes, dislikes, rating, description)
    @last_updated = last_updated
    @video_id = video_id
    @video_info = video_info
    @video_html = video_html
    @views = views
    @likes = likes
    @dislikes = dislikes
    @rating = rating
    @description = description
  end

  def to_a
    return [@last_updated, @video_id, @video_info, @video_html, @views, @likes, @dislikes, @rating, @description]
  end

  DB.mapping({
    last_updated: Time,
    video_id:     String,
    video_info:   String,
    video_html:   String,
    views:        Int64,
    likes:        Int32,
    dislikes:     Int32,
    rating:       Float64,
    description:  String,
  })
end

def get_video(video_id, context)
  client = HTTP::Client.new("www.youtube.com", 443, context)
  video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(video_info)
  video_html = client.get("/watch?v=#{video_id}").body
  html = XML.parse(video_html)
  views = info["view_count"].to_i64
  rating = info["avg_rating"].to_f64

  likes = html.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content.delete(",").to_i
  else
    likes = 1
  end

  dislikes = html.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes = dislikes.content.delete(",").to_i
  else
    dislikes = 1
  end

  description = html.xpath_node(%q(//p[@id="eow-description"]))
  if description
    description = description.to_xml
  else
    description = ""
  end

  video_record = Video.new(Time.now, video_id, video_info, video_html, views, likes, dislikes, rating, description)

  return video_record
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

get "/" do |env|
  templated "index"
end

pg = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
context = OpenSSL::SSL::Context::Client.insecure

get "/watch" do |env|
  video_id = env.params.query["v"]

  if env.params.query["listen"]? && env.params.query["listen"] == "true"
    env.request.query_params.delete_all("listen")
    listen = true
  else
    env.request.query_params["listen"] = "true"
    listen = false
  end

  if pg.query_one?("select exists (select true from videos where video_id = $1)", video_id, as: Bool)
    video_record = pg.query_one("select * from videos where video_id = $1", video_id, as: Video)

    # If record was last updated more than 5 hours ago, refresh (expire param in response lasts for 6 hours)
    if Time.now - video_record.last_updated > Time::Span.new(0, 5, 0, 0)
      video_record = get_video(video_id, context)
      pg.exec("update videos set last_updated = $1, video_info = $3, video_html = $4,\
      views = $5, likes = $6, dislikes = $7, rating = $8, description = $9 where video_id = $2",
        video_record.to_a)
    end
  else
    client = HTTP::Client.new("www.youtube.com", 443, context)
    video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
    info = HTTP::Params.parse(video_info)

    if info["reason"]?
      error_message = info["reason"]
      next templated "error"
    end

    video_record = get_video(video_id, context)
    pg.exec("insert into videos values ($1,$2,$3,$4,$5,$6,$7,$8, $9)", video_record.to_a)
  end

  # last_updated, video_id, video_info, video_html, views, likes, dislikes, rating
  video_info = HTTP::Params.parse(video_record.video_info)
  video_html = XML.parse(video_record.video_html)

  fmt_stream = [] of HTTP::Params
  video_info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  adaptive_fmts = [] of HTTP::Params
  video_info["adaptive_fmts"].split(",") do |string|
    adaptive_fmts << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  related_videos = video_html.xpath_nodes(%q(//li/div/a[contains(@class,"content-link")]/@href))

  if related_videos.empty?
    related_videos = video_html.xpath_nodes(%q(//ytd-compact-video-renderer/div/a/@href))
  end

  likes = video_record.likes.to_f
  dislikes = video_record.dislikes.to_f
  views = video_record.views.to_f

  engagement = ((dislikes + likes)/views * 100)
  calculated_rating = (likes/(likes + dislikes) * 4 + 1)

  templated "watch"
end

get "/search" do |env|
  query = URI.escape(env.params.query["q"])
  client = HTTP::Client.new("www.youtube.com", 443, context)
  results_html = client.get("https://www.youtube.com/results?q=#{query}&page=1").body
  html = XML.parse(results_html)

  videos = html.xpath_nodes(%q(//div[@class="style-scope ytd-item-section-renderer"]/ytd-video-renderer))
  channels = html.xpath_nodes(%q(//div[@class="style-scope ytd-item-section-renderer"]/ytd-channel-renderer))

  if videos.empty?
    videos = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-video")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
    channels = html.xpath_nodes(%q(//div[contains(@class,"yt-lockup-channel")]/div/div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
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
