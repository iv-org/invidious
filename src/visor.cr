require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"
require "./url_encoded"

macro templated(filename)
  render "views/#{{{filename}}}.ecr", "views/layout.ecr"
end

context = OpenSSL::SSL::Context::Client.insecure
fmt_file = File.open("temp/fmt_stream")

get "/" do |env|
  templated "index"
end


get "/watch/:video_id" do |env|
  video_id = env.params.url["video_id"]

  client = HTTP::Client.new("www.youtube.com", 443, context)
  video_info = client.get("/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en").body
  video_info = HTTP::Params.parse(video_info)
  pageContent = client.get("/watch?v=#{video_id}").body
  doc = XML.parse(pageContent)

  fmt_stream = [] of HTTP::Params
  video_info["url_encoded_fmt_stream_map"].split(",") do |string|
    fmt_stream << HTTP::Params.parse(string)
  end

  File.write("temp/#{video_id}", video_info)
  File.write("temp/#{video_id}_manifest", video_info["dashmpd"])
  File.open("temp/#{video_id}_fmt_stream_0", "a+").puts fmt_stream[0]["url"]
  File.open("temp/#{video_id}_fmt_stream_1", "a+").puts fmt_stream[1]["url"]
  File.open("temp/#{video_id}_fmt_stream_2", "a+").puts fmt_stream[2]["url"]
  File.open("temp/#{video_id}_fmt_stream_3", "a+").puts fmt_stream[3]["url"]
  fmt_stream.reverse! # We want lowest quality first
  # css query [title="I like this"] > span
  likes = doc.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content.delete(",").to_i
  else
    likes = 1
  end

  # css query [title="I dislike this"] > span
  dislikes = doc.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes = dislikes.content.delete(",").to_i
  else
    dislikes = 1
  end

  engagement = ((dislikes.to_f32 + likes.to_f32)*100 / video_info["view_count"].to_i).to_i
  calculated_rating = likes.to_f32/(likes.to_f32 + dislikes.to_f32)*4 + 1

  templated "watch"
end

public_folder "assets"

Kemal.run
