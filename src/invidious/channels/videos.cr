module Invidious::Channel::Tabs
  extend self

  # -------------------
  #  Regular videos
  # -------------------

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
    continuation ||= make_initial_videos_ctoken(ucid, sort_by)
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

  def get_shorts(channel : AboutChannel, *, continuation : String? = nil, sort_by = "newest")
    continuation ||= make_initial_shorts_ctoken(channel.ucid, sort_by)
    initial_data = YoutubeAPI.browse(continuation: continuation)

    return extract_items(initial_data, channel.author, channel.ucid)
  end

  # -------------------
  #  Livestreams
  # -------------------

  def get_livestreams(channel : AboutChannel, *, continuation : String? = nil, sort_by = "newest")
    continuation ||= make_initial_livestreams_ctoken(channel.ucid, sort_by)
    initial_data = YoutubeAPI.browse(continuation: continuation)

    return extract_items(initial_data, channel.author, channel.ucid)
  end

  def get_60_livestreams(channel : AboutChannel, *, continuation : String? = nil, sort_by = "newest")
    if continuation.nil?
      # Fetch the first "page" of stream
      items, next_continuation = get_livestreams(channel, sort_by: sort_by)
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

  # -------------------
  #  C-tokens
  # -------------------

  private def sort_options_videos_short(sort_by : String)
    case sort_by
    when "newest"  then return 4_i64
    when "popular" then return 2_i64
    when "oldest"  then return 5_i64
    else                return 4_i64 # Fallback to "newest"
    end
  end

  # Generate the initial "continuation token" to get the first page of the
  # "videos" tab. The following page requires the ctoken provided in that
  # first page, and so on.
  private def make_initial_videos_ctoken(ucid : String, sort_by = "newest")
    object = {
      "15:embedded" => {
        "2:embedded" => {
          "1:string" => "00000000-0000-0000-0000-000000000000",
        },
        "4:varint" => sort_options_videos_short(sort_by),
      },
    }

    return channel_ctoken_wrap(ucid, object)
  end

  # Generate the initial "continuation token" to get the first page of the
  # "shorts" tab. The following page requires the ctoken provided in that
  # first page, and so on.
  private def make_initial_shorts_ctoken(ucid : String, sort_by = "newest")
    object = {
      "10:embedded" => {
        "2:embedded" => {
          "1:string" => "00000000-0000-0000-0000-000000000000",
        },
        "4:varint" => sort_options_videos_short(sort_by),
      },
    }

    return channel_ctoken_wrap(ucid, object)
  end

  # Generate the initial "continuation token" to get the first page of the
  # "livestreams" tab. The following page requires the ctoken provided in that
  # first page, and so on.
  private def make_initial_livestreams_ctoken(ucid : String, sort_by = "newest")
    sort_by_numerical =
      case sort_by
      when "newest"  then 12_i64
      when "popular" then 14_i64
      when "oldest"  then 13_i64
      else                12_i64 # Fallback to "newest"
      end

    object = {
      "14:embedded" => {
        "2:embedded" => {
          "1:string" => "00000000-0000-0000-0000-000000000000",
        },
        "5:varint" => sort_by_numerical,
      },
    }

    return channel_ctoken_wrap(ucid, object)
  end

  # The protobuf structure common between videos/shorts/livestreams
  private def channel_ctoken_wrap(ucid : String, object)
    object_inner = {
      "110:embedded" => {
        "3:embedded" => object,
      },
    }

    object_inner_encoded = object_inner
      .try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    object = {
      "80226972:embedded" => {
        "2:string" => ucid,
        "3:string" => object_inner_encoded,
      },
    }

    continuation = object.try { |i| Protodec::Any.cast_json(i) }
      .try { |i| Protodec::Any.from_json(i) }
      .try { |i| Base64.urlsafe_encode(i) }
      .try { |i| URI.encode_www_form(i) }

    return continuation
  end
end
