require "kemal"
require "xml"
require "http/client"
require "base64"

macro templated(filename)
  render "views/#{{{filename}}}.ecr", "views/layout.ecr"
end

context = OpenSSL::SSL::Context::Client.insecure
client = HTTP::Client.new("www.youtube.com", 443, context)

def params_to_hash(params)
  pairs = params.split("&")
  hash = Hash(String, String).new
  pairs.each do |pair|
    key, value = pair.split("=")
    hash[key] = URI.unescape(value)
  end
  return hash
end

get "/" do |env|
  templated "index"
end

get "/watch/:video_id" do |env|
  video_id = env.params.url["video_id"]

  if File.exists?("video_info/#{video_id}")
    video_info = JSON.parse(File.open("video_info/#{video_id}"))
  else
    video_info_encoded = HTTP::Client.get("https://www.youtube.com/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en", nil, nil, tls = context).body
    video_info = params_to_hash(video_info_encoded)

    File.write("video_info/#{video_id}", video_info.to_json)
  end

  fmt_stream_map = video_info["url_encoded_fmt_stream_map"].to_s.split(",")
  fmt_stream = Array(Hash(String, String)).new
  fmt_stream_map.each do |fmt|
    fmt_stream << params_to_hash(fmt.to_s)
  end
  fmt_stream.reverse!
  templated "watch"
end

get "/listen/:video_id" do |env|
  video_id = env.params.url["video_id"]

  if File.exists?("video_info/#{video_id}")
    video_info = JSON.parse(File.open("video_info/#{video_id}"))
  else
    video_info_encoded = HTTP::Client.get("https://www.youtube.com/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en", nil, nil, tls = context).body
    video_info = params_to_hash(video_info_encoded)

    File.write("video_info/#{video_id}", video_info.to_json)
  end

  adaptive_fmt = Array(Hash(String, String)).new
  video_info["adaptive_fmts"].to_s.split(",") do |fmt|
    adaptive_fmt << params_to_hash(video_info["adaptive_fmts"].to_s)
  end
  templated "listen"
end

public_folder "assets"

Kemal.run
