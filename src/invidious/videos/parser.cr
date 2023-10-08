require "json"

# Use to parse both "compactVideoRenderer" and "endScreenVideoRenderer".
# The former is preferred as it has more videos in it. The second has
# the same 11 first entries as the compact rendered.
#
# TODO: "compactRadioRenderer" (Mix) and
# TODO: Use a proper struct/class instead of a hacky JSON object
def parse_related_video(related : JSON::Any) : Hash(String, JSON::Any)?
  return nil if !related["videoId"]?

  # The compact renderer has video length in seconds, where the end
  # screen rendered has a full text version ("42:40")
  length = related["lengthInSeconds"]?.try &.as_i.to_s
  length ||= related.dig?("lengthText", "simpleText").try do |box|
    decode_length_seconds(box.as_s).to_s
  end

  # Both have "short", so the "long" option shouldn't be required
  channel_info = (related["shortBylineText"]? || related["longBylineText"]?)
    .try &.dig?("runs", 0)

  author = channel_info.try &.dig?("text")
  author_verified = has_verified_badge?(related["ownerBadges"]?).to_s

  ucid = channel_info.try { |ci| HelperExtractors.get_browse_id(ci) }

  # "4,088,033 views", only available on compact renderer
  # and when video is not a livestream
  view_count = related.dig?("viewCountText", "simpleText")
    .try &.as_s.gsub(/\D/, "")

  short_view_count = related.try do |r|
    HelperExtractors.get_short_view_count(r).to_s
  end

  LOGGER.trace("parse_related_video: Found \"watchNextEndScreenRenderer\" container")

  # TODO: when refactoring video types, make a struct for related videos
  # or reuse an existing type, if that fits.
  return {
    "id"               => related["videoId"],
    "title"            => related["title"]["simpleText"],
    "author"           => author || JSON::Any.new(""),
    "ucid"             => JSON::Any.new(ucid || ""),
    "length_seconds"   => JSON::Any.new(length || "0"),
    "view_count"       => JSON::Any.new(view_count || "0"),
    "short_view_count" => JSON::Any.new(short_view_count || "0"),
    "author_verified"  => JSON::Any.new(author_verified),
  }
end

def extract_video_info(video_id : String, proxy_region : String? = nil)
  # Init client config for the API
  client_config = YoutubeAPI::ClientConfig.new(proxy_region: proxy_region)

  # Fetch data from the player endpoint
  player_response = YoutubeAPI.player(video_id: video_id, params: "", client_config: client_config)

  playability_status = player_response.dig?("playabilityStatus", "status").try &.as_s

  if playability_status != "OK"
    subreason = player_response.dig?("playabilityStatus", "errorScreen", "playerErrorMessageRenderer", "subreason")
    reason = subreason.try &.[]?("simpleText").try &.as_s
    reason ||= subreason.try &.[]("runs").as_a.map(&.[]("text")).join("")
    reason ||= player_response.dig("playabilityStatus", "reason").as_s

    # Stop here if video is not a scheduled livestream or
    # for LOGIN_REQUIRED when videoDetails element is not found because retrying won't help
    if !{"LIVE_STREAM_OFFLINE", "LOGIN_REQUIRED"}.any?(playability_status) ||
       playability_status == "LOGIN_REQUIRED" && !player_response.dig?("videoDetails")
      return {
        "version" => JSON::Any.new(Video::SCHEMA_VERSION.to_i64),
        "reason"  => JSON::Any.new(reason),
      }
    end
  elsif video_id != player_response.dig("videoDetails", "videoId")
    # YouTube may return a different video player response than expected.
    # See: https://github.com/TeamNewPipe/NewPipe/issues/8713
    # Line to be reverted if one day we solve the video not available issue.
    return {
      "version" => JSON::Any.new(Video::SCHEMA_VERSION.to_i64),
      "reason"  => JSON::Any.new("Can't load the video on this Invidious instance. YouTube is currently trying to block Invidious instances. <a href=\"https://github.com/iv-org/invidious/issues/3822\">Click here for more info about the issue.</a>"),
    }
  else
    reason = nil
  end

  # Don't fetch the next endpoint if the video is unavailable.
  if {"OK", "LIVE_STREAM_OFFLINE", "LOGIN_REQUIRED"}.any?(playability_status)
    next_response = YoutubeAPI.next({"videoId": video_id, "params": ""})
    player_response = player_response.merge(next_response)
  end

  params = parse_video_info(video_id, player_response)
  params["reason"] = JSON::Any.new(reason) if reason

  new_player_response = nil

  if reason.nil?
    # Fetch the video streams using an Android client in order to get the
    # decrypted URLs and maybe fix throttling issues (#2194). See the
    # following issue for an explanation about decrypted URLs:
    # https://github.com/TeamNewPipe/NewPipeExtractor/issues/562
    client_config.client_type = YoutubeAPI::ClientType::Android
    new_player_response = try_fetch_streaming_data(video_id, client_config)
  elsif !reason.includes?("your country") # Handled separately
    # The Android embedded client could help here
    client_config.client_type = YoutubeAPI::ClientType::AndroidScreenEmbed
    new_player_response = try_fetch_streaming_data(video_id, client_config)
  end

  # Last hope
  if new_player_response.nil?
    client_config.client_type = YoutubeAPI::ClientType::TvHtml5ScreenEmbed
    new_player_response = try_fetch_streaming_data(video_id, client_config)
  end

  # Replace player response and reset reason
  if !new_player_response.nil?
    # Preserve storyboard data before replacement
    new_player_response["storyboards"] = player_response["storyboards"] if player_response["storyboards"]?

    player_response = new_player_response
    params.delete("reason")
  end

  {"captions", "playabilityStatus", "playerConfig", "storyboards", "streamingData"}.each do |f|
    params[f] = player_response[f] if player_response[f]?
  end

  # Data structure version, for cache control
  params["version"] = JSON::Any.new(Video::SCHEMA_VERSION.to_i64)

  return params
end

def try_fetch_streaming_data(id : String, client_config : YoutubeAPI::ClientConfig) : Hash(String, JSON::Any)?
  LOGGER.debug("try_fetch_streaming_data: [#{id}] Using #{client_config.client_type} client.")
  # CgIQBg is a workaround for streaming URLs that returns a 403.
  # See https://github.com/iv-org/invidious/issues/4027#issuecomment-1666944520
  response = YoutubeAPI.player(video_id: id, params: "CgIQBg", client_config: client_config)

  playability_status = response["playabilityStatus"]["status"]
  LOGGER.debug("try_fetch_streaming_data: [#{id}] Got playabilityStatus == #{playability_status}.")

  if id != response.dig("videoDetails", "videoId")
    # YouTube may return a different video player response than expected.
    # See: https://github.com/TeamNewPipe/NewPipe/issues/8713
    raise VideoNotAvailableException.new(
      "The video returned by YouTube isn't the requested one. (#{client_config.client_type} client)"
    )
  elsif playability_status == "OK"
    return response
  else
    return nil
  end
end

def parse_video_info(video_id : String, player_response : Hash(String, JSON::Any)) : Hash(String, JSON::Any)
  # Top level elements

  main_results = player_response.dig?("contents", "twoColumnWatchNextResults")

  raise BrokenTubeException.new("twoColumnWatchNextResults") if !main_results

  # Primary results are not available on Music videos
  # See: https://github.com/iv-org/invidious/pull/3238#issuecomment-1207193725
  if primary_results = main_results.dig?("results", "results", "contents")
    video_primary_renderer = primary_results
      .as_a.find(&.["videoPrimaryInfoRenderer"]?)
      .try &.["videoPrimaryInfoRenderer"]

    video_secondary_renderer = primary_results
      .as_a.find(&.["videoSecondaryInfoRenderer"]?)
      .try &.["videoSecondaryInfoRenderer"]

    raise BrokenTubeException.new("videoPrimaryInfoRenderer") if !video_primary_renderer
    raise BrokenTubeException.new("videoSecondaryInfoRenderer") if !video_secondary_renderer
  end

  video_details = player_response.dig?("videoDetails")
  microformat = player_response.dig?("microformat", "playerMicroformatRenderer")

  raise BrokenTubeException.new("videoDetails") if !video_details
  raise BrokenTubeException.new("microformat") if !microformat

  # Basic video infos

  title = video_details["title"]?.try &.as_s

  # We have to try to extract viewCount from videoPrimaryInfoRenderer first,
  # then from videoDetails, as the latter is "0" for livestreams (we want
  # to get the amount of viewers watching).
  views_txt = extract_text(
    video_primary_renderer
      .try &.dig?("viewCount", "videoViewCountRenderer", "viewCount")
  )
  views_txt ||= video_details["viewCount"]?.try &.as_s || ""
  views = views_txt.gsub(/\D/, "").to_i64?

  length_txt = (microformat["lengthSeconds"]? || video_details["lengthSeconds"])
    .try &.as_s.to_i64

  published = microformat["publishDate"]?
    .try { |t| Time.parse(t.as_s, "%Y-%m-%d", Time::Location::UTC) } || Time.utc

  premiere_timestamp = microformat.dig?("liveBroadcastDetails", "startTimestamp")
    .try { |t| Time.parse_rfc3339(t.as_s) }

  live_now = microformat.dig?("liveBroadcastDetails", "isLiveNow")
    .try &.as_bool || false

  # Extra video infos

  allowed_regions = microformat["availableCountries"]?
    .try &.as_a.map &.as_s || [] of String

  allow_ratings = video_details["allowRatings"]?.try &.as_bool
  family_friendly = microformat["isFamilySafe"].try &.as_bool
  is_listed = video_details["isCrawlable"]?.try &.as_bool
  is_upcoming = video_details["isUpcoming"]?.try &.as_bool

  keywords = video_details["keywords"]?
    .try &.as_a.map &.as_s || [] of String

  # Related videos

  LOGGER.debug("extract_video_info: parsing related videos...")

  related = [] of JSON::Any

  # Parse "compactVideoRenderer" items (under secondary results)
  secondary_results = main_results
    .dig?("secondaryResults", "secondaryResults", "results")
  secondary_results.try &.as_a.each do |element|
    if item = element["compactVideoRenderer"]?
      related_video = parse_related_video(item)
      related << JSON::Any.new(related_video) if related_video
    end
  end

  # If nothing was found previously, fall back to end screen renderer
  if related.empty?
    # Container for "endScreenVideoRenderer" items
    player_overlays = player_response.dig?(
      "playerOverlays", "playerOverlayRenderer",
      "endScreen", "watchNextEndScreenRenderer", "results"
    )

    player_overlays.try &.as_a.each do |element|
      if item = element["endScreenVideoRenderer"]?
        related_video = parse_related_video(item)
        related << JSON::Any.new(related_video) if related_video
      end
    end
  end

  # Likes

  toplevel_buttons = video_primary_renderer
    .try &.dig?("videoActions", "menuRenderer", "topLevelButtons")

  if toplevel_buttons
    likes_button = toplevel_buttons.try &.as_a
      .find(&.dig?("toggleButtonRenderer", "defaultIcon", "iconType").=== "LIKE")
      .try &.["toggleButtonRenderer"]

    # New format as of september 2022
    likes_button ||= toplevel_buttons.try &.as_a
      .find(&.["segmentedLikeDislikeButtonRenderer"]?)
      .try &.dig?(
        "segmentedLikeDislikeButtonRenderer",
        "likeButton", "toggleButtonRenderer"
      )

    if likes_button
      # Note: The like count from `toggledText` is off by one, as it would
      # represent the new like count in the event where the user clicks on "like".
      likes_txt = (likes_button["defaultText"]? || likes_button["toggledText"]?)
        .try &.dig?("accessibility", "accessibilityData", "label")
      likes = likes_txt.as_s.gsub(/\D/, "").to_i64? if likes_txt

      LOGGER.trace("extract_video_info: Found \"likes\" button. Button text is \"#{likes_txt}\"")
      LOGGER.debug("extract_video_info: Likes count is #{likes}") if likes
    end
  end

  # Description

  description = microformat.dig?("description", "simpleText").try &.as_s || ""
  short_description = player_response.dig?("videoDetails", "shortDescription")

  # description_html = video_secondary_renderer.try &.dig?("description", "runs")
  #  .try &.as_a.try { |t| content_to_comment_html(t, video_id) }

  description_html = parse_description(video_secondary_renderer.try &.dig?("attributedDescription"), video_id)

  # Video metadata

  metadata = video_secondary_renderer
    .try &.dig?("metadataRowContainer", "metadataRowContainerRenderer", "rows")
      .try &.as_a

  genre = microformat["category"]?
  genre_ucid = nil
  license = nil

  metadata.try &.each do |row|
    metadata_title = extract_text(row.dig?("metadataRowRenderer", "title"))
    contents = row.dig?("metadataRowRenderer", "contents", 0)

    if metadata_title == "Category"
      contents = contents.try &.dig?("runs", 0)

      genre = contents.try &.["text"]?
      genre_ucid = contents.try &.dig?("navigationEndpoint", "browseEndpoint", "browseId")
    elsif metadata_title == "License"
      license = contents.try &.dig?("runs", 0, "text")
    elsif metadata_title == "Licensed to YouTube by"
      license = contents.try &.["simpleText"]?
    end
  end

  # Music section

  music_list = [] of VideoMusic
  music_desclist = player_response.dig?(
    "engagementPanels", 1, "engagementPanelSectionListRenderer",
    "content", "structuredDescriptionContentRenderer", "items", 2,
    "videoDescriptionMusicSectionRenderer", "carouselLockups"
  )

  music_desclist.try &.as_a.each do |music_desc|
    artist = nil
    album = nil
    music_license = nil

    # Used when the video has multiple songs
    if song_title = music_desc.dig?("carouselLockupRenderer", "videoLockup", "compactVideoRenderer", "title")
      # "simpleText" for plain text / "runs" when song has a link
      song = song_title["simpleText"]? || song_title.dig?("runs", 0, "text")

      # some videos can have empty tracks. See: https://www.youtube.com/watch?v=eBGIQ7ZuuiU
      next if !song
    end

    music_desc.dig?("carouselLockupRenderer", "infoRows").try &.as_a.each do |desc|
      desc_title = extract_text(desc.dig?("infoRowRenderer", "title"))
      if desc_title == "ARTIST"
        artist = extract_text(desc.dig?("infoRowRenderer", "defaultMetadata"))
      elsif desc_title == "SONG"
        song = extract_text(desc.dig?("infoRowRenderer", "defaultMetadata"))
      elsif desc_title == "ALBUM"
        album = extract_text(desc.dig?("infoRowRenderer", "defaultMetadata"))
      elsif desc_title == "LICENSES"
        music_license = extract_text(desc.dig?("infoRowRenderer", "expandedMetadata"))
      end
    end
    music_list << VideoMusic.new(song.to_s, album.to_s, artist.to_s, music_license.to_s)
  end

  # Author infos

  author = video_details["author"]?.try &.as_s
  ucid = video_details["channelId"]?.try &.as_s

  if author_info = video_secondary_renderer.try &.dig?("owner", "videoOwnerRenderer")
    author_thumbnail = author_info.dig?("thumbnail", "thumbnails", 0, "url")
    author_verified = has_verified_badge?(author_info["badges"]?)

    subs_text = author_info["subscriberCountText"]?
      .try { |t| t["simpleText"]? || t.dig?("runs", 0, "text") }
      .try &.as_s.split(" ", 2)[0]
  end

  # Return data

  if live_now
    video_type = VideoType::Livestream
  elsif !premiere_timestamp.nil?
    video_type = VideoType::Scheduled
    published = premiere_timestamp || Time.utc
  else
    video_type = VideoType::Video
  end

  params = {
    "videoType" => JSON::Any.new(video_type.to_s),
    # Basic video infos
    "title"         => JSON::Any.new(title || ""),
    "views"         => JSON::Any.new(views || 0_i64),
    "likes"         => JSON::Any.new(likes || 0_i64),
    "lengthSeconds" => JSON::Any.new(length_txt || 0_i64),
    "published"     => JSON::Any.new(published.to_rfc3339),
    # Extra video infos
    "allowedRegions"   => JSON::Any.new(allowed_regions.map { |v| JSON::Any.new(v) }),
    "allowRatings"     => JSON::Any.new(allow_ratings || false),
    "isFamilyFriendly" => JSON::Any.new(family_friendly || false),
    "isListed"         => JSON::Any.new(is_listed || false),
    "isUpcoming"       => JSON::Any.new(is_upcoming || false),
    "keywords"         => JSON::Any.new(keywords.map { |v| JSON::Any.new(v) }),
    # Related videos
    "relatedVideos" => JSON::Any.new(related),
    # Description
    "description"      => JSON::Any.new(description || ""),
    "descriptionHtml"  => JSON::Any.new(description_html || "<p></p>"),
    "shortDescription" => JSON::Any.new(short_description.try &.as_s || nil),
    # Video metadata
    "genre"     => JSON::Any.new(genre.try &.as_s || ""),
    "genreUcid" => JSON::Any.new(genre_ucid.try &.as_s || ""),
    "license"   => JSON::Any.new(license.try &.as_s || ""),
    # Music section
    "music" => JSON.parse(music_list.to_json),
    # Author infos
    "author"          => JSON::Any.new(author || ""),
    "ucid"            => JSON::Any.new(ucid || ""),
    "authorThumbnail" => JSON::Any.new(author_thumbnail.try &.as_s || ""),
    "authorVerified"  => JSON::Any.new(author_verified || false),
    "subCountText"    => JSON::Any.new(subs_text || "-"),
  }

  return params
end
