require "http/client"
require "json"
require "kemal"
require "pg"
require "time"
require "xml"

PG_DB   = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
URL     = URI.parse("https://www.youtube.com")
CONTEXT = OpenSSL::SSL::Context::Client.new
CONTEXT.verify_mode = OpenSSL::SSL::VerifyMode::NONE
CONTEXT.add_options(
  OpenSSL::SSL::Options::ALL |
  OpenSSL::SSL::Options::NO_SSL_V2 |
  OpenSSL::SSL::Options::NO_SSL_V3
)
POOL = Deque.new(30) do
  HTTP::Client.new(URL, CONTEXT)
end

# Refresh all the connections in the pool by crawling recommended
spawn do
  # Arbitrary start value
  id = "RoEEDKwzNBw"
  loop do
    client = get_client
    time = Time.now

    begin
      video = get_video(id)
    rescue ex
      id = "RoEEDKwzNBw"
      next
    end

    rvs = [] of Hash(String, String)
    video.info["rvs"].split(",").each do |rv|
      rvs << HTTP::Params.parse(rv).to_h
    end

    id = rvs[rand(rvs.size)]["id"]

    puts "#{Time.now} 200 GET #{id} #{elapsed_text(Time.now - time)}"
    POOL << client
  end
end

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
      XML.parse_html(rs.read(String))
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
      default:   XML.parse_html(""),
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

def elapsed_text(elapsed)
  millis = elapsed.total_milliseconds
  return "#{millis.round(2)}ms" if millis >= 1

  "#{(millis * 1000).round(2)}µs"
end

def get_client
  while POOL.empty?
    sleep rand(0..10).milliseconds
  end

  return POOL.shift
end

def fetch_video(id)
  # Grab connection from pool
  client = get_client

  info = client.get("/get_video_info?video_id=#{id}&el=detailpage&ps=default&eurl=&gl=US&hl=en").body
  info = HTTP::Params.parse(info)

  html = client.get("/watch?v=#{id}").body
  html = XML.parse_html(html)

  if info["reason"]?
    raise info["reason"]
  end

  # Return connection to pool
  POOL << client

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
  listen = env.params.query["listen"]? || "false"

  env.params.query.delete_all("listen")

  begin
    video = get_video(id)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  player_response = JSON.parse(video.info["player_response"])

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  adaptive_fmts = [] of HTTP::Params
  video.info["adaptive_fmts"].split(",") do |string|
    adaptive_fmts << HTTP::Params.parse(string)
  end

  likes = video.html.xpath_node(%q(//button[@title="I like this"]/span))
  likes = likes ? likes.content.delete(",").to_i : 1

  dislikes = video.html.xpath_node(%q(//button[@title="I dislike this"]/span))
  dislikes = dislikes ? dislikes.content.delete(",").to_i : 1

  description = video.html.xpath_node(%q(//p[@id="eow-description"]))
  description = description ? description.to_xml : "Could not load description"

  views = video.info["view_count"].to_i64
  rating = video.info["avg_rating"].to_f64

  engagement = ((dislikes.to_f + likes.to_f)/views * 100)
  calculated_rating = (likes.to_f/(likes.to_f + dislikes.to_f) * 4 + 1)

  rvs = [] of Hash(String, String)
  video.info["rvs"].split(",").each do |rv|
    rvs << HTTP::Params.parse(rv).to_h
  end

  templated "watch"
end

get "/search" do |env|
  query = env.params.query["q"]
  page = env.params.query["page"]? && env.params.query["page"].to_i? ? env.params.query["page"].to_i : 1

  client = get_client

  html = client.get("https://www.youtube.com/results?q=#{URI.escape(query)}&page=#{page}&sp=EgIQAVAU").body
  html = XML.parse_html(html)

  videos = Array(Hash(String, String)).new

  html.xpath_nodes(%q(//ol[@class="item-section"]/li)).each do |item|
    root = item.xpath_node(%q(div[contains(@class,"yt-lockup-video")]/div))
    if root
      video = {} of String => String

      link = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/@href))
      if link
        video["link"] = link.content
      else
        video["link"] = "#"
      end

      title = root.xpath_node(%q(div[@class="yt-lockup-content"]/h3/a))
      if title
        video["title"] = title.content
      else
        video["title"] = "Something went wrong"
      end

      thumbnail = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/div/span/img/@src))
      if thumbnail && !thumbnail.content.ends_with?(".gif")
        video["thumbnail"] = thumbnail.content
      else
        thumbnail = root.xpath_node(%q(div[contains(@class,"yt-lockup-thumbnail")]/a/div/span/img/@data-thumb))
        if thumbnail
          video["thumbnail"] = thumbnail.content
        else
          video["thumbnail"] = "http://via.placeholder.com/246x138"
        end
      end

      videos << video
    end
  end

  POOL << client

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
