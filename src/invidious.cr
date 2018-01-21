require "http/client"
require "json"
require "kemal"
require "pg"
require "time"
require "xml"
require "./helpers"

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
  client = HTTP::Client.new(URL, CONTEXT)
  client.connect_timeout = Time::Span.new(0, 0, 0, 5)
  client
end

# Refresh connections by crawling YT
spawn do
  # Start video
  ids = Deque.new(10, "_wbqqI0IgY8")
  random = Random.new

  search(random.base64(3)) do |id|
    ids << id
  end

  loop do
    if ids.size < 5
      search(random.base64) do |id|
        ids << id
        puts "refreshed ids"
      end
    end

    if rand(600) < 1
      client = get_client
      client = HTTP::Client.new(URL, CONTEXT)
      client.connect_timeout = Time::Span.new(0, 0, 0, 5)
      POOL << client
    end

    time = Time.now

    begin
      id = ids[rand(ids.size)]
      video = get_video(id, false)
      ids.delete(id)
    rescue ex
      puts ex
      next
    end

    rvs = [] of Hash(String, String)
    if video.info.has_key?("rvs")
      video.info["rvs"].split(",").each do |rv|
        rvs << HTTP::Params.parse(rv).to_h
      end
    end

    rvs.each do |rv|
      if rv.has_key?("id")
        if !PG_DB.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", rv["id"], as: Bool)
          ids << rv["id"]
          if ids.size == 50
            ids.shift
          end
        end
      end
    end

    puts "#{Time.now} 200 GET www.youtube.com/watch?v=#{video.id} #{elapsed_text(Time.now - time)}"
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

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  fmt_stream.reverse! # We want lowest quality first

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end
  rvs = [] of Hash(String, String)
  if video.info.has_key?("rvs")
    video.info["rvs"].split(",").each do |rv|
      rvs << HTTP::Params.parse(rv).to_h
    end
  end

  player_response = JSON.parse(video.info["player_response"])

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
