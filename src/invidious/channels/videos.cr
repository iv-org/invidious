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
  continuation = ""
  initial_data = Hash(String, JSON::Any).new

  # Manually generating the continuation works correctly for both 'newest' and 'popular' sort modes,
  # and for page 1 when sorting by 'oldest'. So only fallback to using the db if not in either of these states.
  if sort_by != "oldest" || page == 1
    continuation = produce_channel_videos_continuation(ucid, page, auto_generated: auto_generated, sort_by: sort_by, v2: true)
  elsif channel_continuation = PG_DB.query_one?("SELECT * FROM channel_continuations WHERE id = $1 AND page = $2 AND sort_by = $3", ucid, page, sort_by, as: ChannelContinuation)
    continuation = channel_continuation.continuation
  else
    # This branch should not be needed in normal operation (navigating via the previous/next page buttons).
    # This is just here as a fallback in case someone requests, for example, page 3 without previously requesting page 2.

    # Iterate backwards from the wanted page to page 2 to find a stored continuation.
    start = 1
    ((page - 1)..2).each do |i|
      if channel_continuation = PG_DB.query_one?("SELECT * FROM channel_continuations WHERE id = $1 AND page = $2 AND sort_by = $3", ucid, i, sort_by, as: ChannelContinuation)
        start = i
        continuation = channel_continuation.continuation
        break
      end
    end

    # If a continuation hasn't been found after getting to page 2, manually create the continuation for page 1.
    if start == 1
      continuation = produce_channel_videos_continuation(ucid, 1, auto_generated: auto_generated, sort_by: sort_by, v2: true)
    end

    # Iterate from the found/created continuation until we have the continuation for the wanted page or there are no more pages.
    # Store the returned continuation each time so that it can be found in the db next time the current page is wanted.
    (start..(page - 1)).each do |i|
      initial_data = YoutubeAPI.browse(continuation)
      continuation = fetch_continuation_token(initial_data)

      break if continuation.nil? || continuation.empty?

      channel_continuation = ChannelContinuation.new({
        id:           ucid,
        page:         i,
        sort_by:      sort_by,
        continuation: continuation,
      })
      PG_DB.exec("INSERT INTO channel_continuations VALUES ($1, $2, $3, $4) \
        ON CONFLICT (id, page, sort_by) DO UPDATE SET continuation = $4", *channel_continuation.to_tuple)
    end
  end

  # If we reached the channel's last page in the else loop above return an empty hash.
  if continuation.nil? || continuation.empty?
    initial_data.clear
  else
    # Get the wanted page and store the returned continuation for the next page,
    # if there is one, so that it can be used the next time this function is called requesting that page.
    initial_data = YoutubeAPI.browse(continuation)

    # Only get the continuation and store it if the sort mode is 'oldest'.
    if sort_by == "oldest"
      continuation = fetch_continuation_token(initial_data)

      if !continuation.nil? && !continuation.empty?
        channel_continuation = ChannelContinuation.new({
          id:           ucid,
          page:         page + 1,
          sort_by:      sort_by,
          continuation: continuation,
        })
        PG_DB.exec("INSERT INTO channel_continuations VALUES ($1, $2, $3, $4) \
         ON CONFLICT (id, page, sort_by) DO UPDATE SET continuation = $4", *channel_continuation.to_tuple)
      end
    end
  end

  return initial_data
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
