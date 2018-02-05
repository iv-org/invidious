# "Invidious" (which indexes popular video sites)
# Copyright (C) 2018  Omar Roth
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

require "kemal"
require "option_parser"
require "pg"
require "xml"
require "./helpers"

threads = 10

OptionParser.parse! do |parser|
  parser.banner = "Usage: invidious [arguments]"
  parser.on("-t THREADS", "--threads=THREADS", "Number of threads for crawling") do |number|
    begin
      threads = number.to_i32
    rescue ex
      puts "THREADS must be integer"
      exit
    end
  end
  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
end

PG_DB   = DB.open "postgres://kemal:kemal@localhost:5432/invidious"
URL     = URI.parse("https://www.youtube.com")
CONTEXT = OpenSSL::SSL::Context::Client.new
CONTEXT.verify_mode = OpenSSL::SSL::VerifyMode::NONE
CONTEXT.add_options(
  OpenSSL::SSL::Options::ALL |
  OpenSSL::SSL::Options::NO_SSL_V2 |
  OpenSSL::SSL::Options::NO_SSL_V3
)
pool = Deque.new((threads * 1.2).to_i) do
  client = HTTP::Client.new(URL, CONTEXT)
  client.read_timeout = 5.seconds
  client.connect_timeout = 5.seconds
  client
end

# Refresh pool by crawling YT
threads.times do
  spawn do
    io = STDOUT
    ids = Deque(String).new
    random = Random.new
    client = get_client(pool)

    search(random.base64(3), client) do |id|
      ids << id
    end

    loop do
      if ids.empty?
        search(random.base64(3), client) do |id|
          ids << id
        end
      end

      if rand(300) < 1
        client = HTTP::Client.new(URL, CONTEXT)
        client.read_timeout = 5.seconds
        client.connect_timeout = 5.seconds
        pool << client
      end

      time = Time.now

      begin
        id = ids[0]
        video = get_video(id, client, PG_DB)
      rescue ex
        io << id << " : " << ex << "\n"
        client = HTTP::Client.new(URL, CONTEXT)
        client.read_timeout = 5.seconds
        client.connect_timeout = 5.seconds
        pool << client
        next
      ensure
        ids.delete(id)
      end

      rvs = [] of Hash(String, String)
      if video.info.has_key?("rvs")
        video.info["rvs"].split(",").each do |rv|
          rvs << HTTP::Params.parse(rv).to_h
        end
      end

      rvs.each do |rv|
        if rv.has_key?("id") && !PG_DB.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", rv["id"], as: Bool)
          ids.delete(id)
          ids << rv["id"]
          if ids.size == 150
            ids.shift
          end
        end
      end

      io << Time.now << " 200 GET www.youtube.com/watch?v=" << video.id << " " << elapsed_text(Time.now - time) << "\n"
    end
  end
end

macro templated(filename)
  render "src/views/#{{{filename}}}.ecr", "src/views/layout.ecr"
end

get "/" do |env|
  templated "index"
end

get "/watch" do |env|
  id = env.params.query["v"]
  listen = env.params.query["listen"]? || "false"

  env.params.query.delete_all("listen")

  client = get_client(pool)
  begin
    video = get_video(id, client, PG_DB)
  rescue ex
    error_message = ex.message
    next templated "error"
  end

  fmt_stream = [] of HTTP::Params
  video.info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  if fmt_stream[0]["s"]?
    fmt_stream.each do |fmt|
      fmt["url"] = "#{fmt["url"]}&signature=#{decrypt_signature(fmt["s"])}"
    end
  end

  # We want lowest quality first
  fmt_stream.reverse!

  adaptive_fmts = [] of HTTP::Params
  if video.info.has_key?("adaptive_fmts")
    video.info["adaptive_fmts"].split(",") do |string|
      adaptive_fmts << HTTP::Params.parse(string)
    end
  end

  if adaptive_fmts[0]["s"]?
    adaptive_fmts.each do |fmt|
      fmt["url"] = "#{fmt["url"]}&signature=#{decrypt_signature(fmt["s"])}"
    end
  end

  rvs = [] of Hash(String, String)
  if video.info.has_key?("rvs")
    video.info["rvs"].split(",").each do |rv|
      rvs << HTTP::Params.parse(rv).to_h
    end
  end

  player_response = JSON.parse(video.info["player_response"])

  description = video.html.xpath_node(%q(//p[@id="eow-description"]))
  description = description ? description.to_xml : "Could not load description"

  rating = video.info["avg_rating"].to_f64

  engagement = ((video.dislikes.to_f + video.likes.to_f)/video.views * 100)
  if video.likes > 0 || video.dislikes > 0
  calculated_rating = (video.likes.to_f/(video.likes.to_f + video.dislikes.to_f) * 4 + 1)
  else
    calculated_rating = 0.0
  end

  templated "watch"
end

get "/search" do |env|
  query = env.params.query["q"]
  page = env.params.query["page"]? && env.params.query["page"].to_i? ? env.params.query["page"].to_i : 1

  client = get_client(pool)

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

  pool << client

  templated "search"
end

get "/:path" do |env|
  env.redirect "/"
end

error 500 do |env|
  "Error 500"
end

public_folder "assets"

Kemal.run
