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

  sort_by_numerical =
    case sort_by
    when "newest"  then 1_i64
    when "popular" then 2_i64
    when "oldest"  then 3_i64 # Broken as of 10/2022 :c
    else                1_i64 # Fallback to "newest"
    end

  object_inner_1 = {
    "110:embedded" => {
      "3:embedded" => {
        "15:embedded" => {
          "1:embedded" => {
            "1:string" => object_inner_2_encoded,
          },
          "2:embedded" => {
            "1:string" => "00000000-0000-0000-0000-000000000000",
          },
          "3:varint" => sort_by_numerical,
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

# Used in bypass_captcha_job.cr
def produce_channel_videos_url(ucid, page = 1, auto_generated = nil, sort_by = "newest", v2 = false)
  continuation = produce_channel_videos_continuation(ucid, page, auto_generated, sort_by, v2)
  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end

module Invidious::Channel::Tabs
  extend self

  # -------------------
  #  Regular videos
  # -------------------

  def make_initial_video_ctoken(ucid, sort_by) : String
    return produce_channel_videos_continuation(ucid, sort_by: sort_by)
  end

  # Wrapper for AboutChannel, as we still need to call get_videos with
  # an author name and ucid directly (e.g in RSS feeds).
  # TODO: figure out how to get rid of that
  def get_videos(channel : AboutChannel, *, continuation : String? = nil, sort_by = "newest")
    return get_videos(
      channel.author, channel.ucid,
      continuation: continuation, sort_by: sort_by
    )
  end

  # Wrapper for InvidiousChannel, as we still need to call get_videos with
  # an author name and ucid directly (e.g in RSS feeds).
  # TODO: figure out how to get rid of that
  def get_videos(channel : InvidiousChannel, *, continuation : String? = nil, sort_by = "newest")
    return get_videos(
      channel.author, channel.id,
      continuation: continuation, sort_by: sort_by
    )
  end

  def get_videos(author : String, ucid : String, *, continuation : String? = nil, sort_by = "newest")
    continuation ||= make_initial_video_ctoken(ucid, sort_by)
    initial_data = YoutubeAPI.browse(continuation: continuation)

    return extract_items(initial_data, author, ucid)
  end

  def get_60_videos(channel : AboutChannel, *, continuation : String? = nil, sort_by = "newest")
    if continuation.nil?
      # Fetch the first "page" of video
      items, next_continuation = get_videos(channel, sort_by: sort_by)
    else
      # Fetch a "page" of videos using the given continuation token
      items, next_continuation = get_videos(channel, continuation: continuation)
    end

    # If there is more to load, then load a second "page"
    # and replace the previous continuation token
    if !next_continuation.nil?
      items_2, next_continuation = get_videos(channel, continuation: next_continuation)
      items.concat items_2
    end

    return items, next_continuation
  end

  # -------------------
  #  Shorts
  # -------------------

  def get_shorts(channel : AboutChannel, continuation : String? = nil)
    if continuation.nil?
      # EgZzaG9ydHPyBgUKA5oBAA%3D%3D is the protobuf object to load "shorts"
      # TODO: try to extract the continuation tokens that allows other sorting options
      initial_data = YoutubeAPI.browse(channel.ucid, params: "EgZzaG9ydHPyBgUKA5oBAA%3D%3D")
    else
      initial_data = YoutubeAPI.browse(continuation: continuation)
    end
    return extract_items(initial_data, channel.author, channel.ucid)
  end

  # -------------------
  #  Livestreams
  # -------------------

  def get_livestreams(channel : AboutChannel, continuation : String? = nil)
    if continuation.nil?
      # EgdzdHJlYW1z8gYECgJ6AA%3D%3D is the protobuf object to load "streams"
      initial_data = YoutubeAPI.browse(channel.ucid, params: "EgdzdHJlYW1z8gYECgJ6AA%3D%3D")
    else
      initial_data = YoutubeAPI.browse(continuation: continuation)
    end

    return extract_items(initial_data, channel.author, channel.ucid)
  end

  def get_60_livestreams(channel : AboutChannel, continuation : String? = nil)
    if continuation.nil?
      # Fetch the first "page" of streams
      items, next_continuation = get_livestreams(channel)
    else
      # Fetch a "page" of streams using the given continuation token
      items, next_continuation = get_livestreams(channel, continuation: continuation)
    end

    # If there is more to load, then load a second "page"
    # and replace the previous continuation token
    if !next_continuation.nil?
      items_2, next_continuation = get_livestreams(channel, continuation: next_continuation)
      items.concat items_2
    end

    return items, next_continuation
  end
end
