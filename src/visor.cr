require "http/client"
require "json"
require "kemal"
require "pg"
require "xml"

macro templated(filename)
  render "views/#{{{filename}}}.ecr", "views/layout.ecr"
end

# pg = DB.open("postgres://kemal@visor/dev")

alias Type = String | Hash(String, Type)

def object_to_hash(value)
  object = {} of String => Type
  items = value.split("&")
  items.each do |item|
    key, value = item.split("=")
    value = URI.unescape(value)
    object[key] = parse_uri(value)
  end
  return object
end

def array_to_hash(value)
  array = {} of String => Type
  items = value.split(",")
  count = 0
  items.each do |item|
    array[count.to_s] = parse_uri(item)
    count += 1
  end
  return array
end

def parse_uri(value)
  if value.starts_with?("http") || value.starts_with?("[")
    return value
  else
    if value.includes?(",")
      return array_to_hash(value)
    elsif value.includes?("&")
      return object_to_hash(value)
    else
      return value
    end
  end
end

context = OpenSSL::SSL::Context::Client.insecure
client = HTTP::Client.new("www.youtube.com", 443, context)

get "/" do |env|
  templated "index"
end

get "/watch/:video_id" do |env|
  video_id = env.params.url["video_id"]

  video_info_encoded = HTTP::Client.get("https://www.youtube.com/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en", nil, nil, tls = context).body
  video_info = object_to_hash(video_info_encoded)
  body = client.get("/watch?v=#{video_id}").body
  doc = XML.parse(body)

  likes = doc.xpath_node(%q(//button[@title="I like this"]/span))
  if likes
    likes = likes.content
  else
    likes = "n/a"
  end
  
  dislikes = doc.xpath_node(%q(//button[@title="I dislike this"]/span))
  if dislikes
    dislikes.content
  else
    dislikes = "n/a"
  end

  File.write("video_info/#{video_id}", video_info.to_json)
  templated "watch"
end

# get "/listen/:video_id" do |env|
#   video_id = env.params.url["video_id"]

#   video_info_encoded = HTTP::Client.get("https://www.youtube.com/get_video_info?video_id=#{video_id}&el=info&ps=default&eurl=&gl=US&hl=en", nil, nil, tls = context).body
#   video_info = object_to_hash(video_info_encoded)
#   File.write("video_info/#{video_id}", video_info.to_json)
#   templated "listen"
# end

public_folder "assets"

Kemal.run
