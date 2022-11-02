def produce_channel_videos_continuation(ucid, page = 1, auto_generated = nil, sort_by = "newest", v2 = false)
  object_inner_2 = {
    "2:0:embedded" => {
      "1:0:varint" => 0_i64,
    },
    "5:varint"  => 50_i64,
    "6:varint"  => 1_i64,
    "7:varint"  => (page * 30).to_i64,
    "9:varint"  => 1_i64,
    "10:varint" => 0_i64,
  }

  object_inner_2_encoded = object_inner_2
    .try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  object_inner_1 = {
    "110:embedded" => {
      "3:embedded" => {
        "15:embedded" => {
          "1:embedded" => {
            "1:string" => object_inner_2_encoded,
            "2:string" => "00000000-0000-0000-0000-000000000000",
          },
          "3:varint" => 1_i64,
        },
      },
    },
  }

  object_inner_1_encoded = object_inner_1
    .try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  object = {
    "80226972:embedded" => {
      "2:string"  => ucid,
      "3:string"  => object_inner_1_encoded,
      "35:string" => "browse-feed#{ucid}videos102",
    },
  }

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

  # 2.times do |i|
  # initial_data = get_channel_videos_response(ucid, page * 2 + (i - 1), auto_generated: auto_generated, sort_by: sort_by)
  initial_data = get_channel_videos_response(ucid, 1, auto_generated: auto_generated, sort_by: sort_by)
  videos = extract_videos(initial_data, author, ucid)
  # end

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
