def produce_channel_videos_continuation(ucid, page = 1, auto_generated = nil, sort_by = "newest", v2 = false)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "videos",
        "6:varint"  => 2_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "13:string" => "",
        "23:varint" => 0_i64,
      },
    },
  }

  if !v2
    if auto_generated
      seed = Time.unix(1525757349)
      until seed >= Time.utc
        seed += 1.month
      end
      timestamp = seed - (page - 1).months

      object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0x36_i64
      object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = "#{timestamp.to_unix}"
    else
      object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0_i64
      object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = "#{page}"
    end
  else
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0_i64

    object["80226972:embedded"]["3:base64"].as(Hash)["61:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json({
      "1:string" => Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json({
        "1:varint" => 30_i64 * (page - 1),
      }))),
    })))
  end

  case sort_by
  when "newest"
  when "popular"
    object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 0x01_i64
  when "oldest"
    object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 0x02_i64
  else nil # Ignore
  end

  object["80226972:embedded"]["3:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json(object["80226972:embedded"]["3:base64"])))
  object["80226972:embedded"].delete("3:base64")

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end

def get_channel_videos_response(ucid, page = 1, auto_generated = nil, sort_by = "newest")
  continuation = produce_channel_videos_continuation(ucid, page,
    auto_generated: auto_generated, sort_by: sort_by, v2: true)

  return YoutubeAPI.browse(continuation)
end

def get_60_videos(ucid, author, page, auto_generated, sort_by = "newest")
  videos = [] of SearchVideo

  2.times do |i|
    initial_data = get_channel_videos_response(ucid, page * 2 + (i - 1), auto_generated: auto_generated, sort_by: sort_by)
    videos.concat extract_videos(initial_data, author, ucid)
  end

  return videos.size, videos
end

def get_latest_videos(ucid)
  initial_data = get_channel_videos_response(ucid)
  author = initial_data["metadata"]?.try &.["channelMetadataRenderer"]?.try &.["title"]?.try &.as_s

  return extract_videos(initial_data, author, ucid)
end

# Used in bypass_captcha_job.cr
def produce_channel_videos_url(ucid, page = 1, auto_generated = nil, sort_by = "newest", v2 = false)
  continuation = produce_channel_videos_continuation(ucid, page, auto_generated, sort_by, v2)
  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end
