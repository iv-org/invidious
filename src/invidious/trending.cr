def fetch_trending(trending_type, region, locale, env)
  region ||= "US"
  region = region.upcase

  plid = nil

  case trending_type.try &.downcase
  when "music"
    # params = "4gINGgt5dG1hX2NoYXJ0cw%3D%3D"
    return fetch_subscription_related_videoids(env, region, locale)
  when "gaming"
    params = "4gIcGhpnYW1pbmdfY29ycHVzX21vc3RfcG9wdWxhcg%3D%3D"
  when "movies"
    params = "4gIKGgh0cmFpbGVycw%3D%3D"
  else # Default
    params = ""
  end

  client_config = YoutubeAPI::ClientConfig.new(region: region)
  initial_data = YoutubeAPI.browse("FEtrending", params: params, client_config: client_config)

  items, _ = extract_items(initial_data)

  extracted = [] of SearchItem

  deduplicate = items.size > 1

  items.each do |itm|
    if itm.is_a?(Category)
      # Ignore the smaller categories, as they generally contain a sponsored
      # channel, which brings a lot of noise on the trending page.
      # See: https://github.com/iv-org/invidious/issues/2989
      next if (itm.contents.size < 24 && deduplicate)

      extracted.concat extract_category(itm)
    else
      extracted << itm
    end
  end

  # Deduplicate items before returning results
  return extracted.select(SearchVideo).uniq!(&.id), plid
end

def fetch_subscription_related_videoids(env, region, locale)
  user = env.get("user").as(Invidious::User)

  # Filter valid channel videos
  channel_videos, _ = get_subscription_feed(user, 10, 1)
  valid_channel_videoids = channel_videos.select do |v|
    !v.live_now && v.premiere_timestamp.nil? && (v.length_seconds || 0) > 0 && (v.views || 0) > 0
  end.map(&.id)

  # Sample more from watched, fewer from channels
  watched_video_ids = user.watched.sample(10)

  video_ids = watched_video_ids + valid_channel_videoids
  video_ids = video_ids.uniq
  video_ids = video_ids.reject(&.nil?)
  video_ids = video_ids.reject(&.empty?)
  video_ids = video_ids.sample(10) if video_ids.size > 10

  videos = [] of SearchVideo
  video_ids.each do |video_id|
    video = get_video(video_id)
    next unless video.video_type == VideoType::Video

    related = video.related_videos.sample(10) # pick random related videos
    related.each do |related_video|
      next unless id = related_video["id"]?
      next unless related_video["view_count"]? && related_video["view_count"]? != 0
      next unless related_video["published"]?
      next unless related_video["length_seconds"]? && related_video["length_seconds"]? != 0
      
      videos << SearchVideo.new({
        title:              related_video["title"],
        id:                 id,
        author:             related_video["author"],
        ucid:               related_video["ucid"]? || "",
        published:          (Time.parse_rfc3339(related_video["published"].to_s) rescue Time.utc),
        views:              related_video["view_count"]?.try &.to_i64 || 0_i64,
        description_html:   "", # not available
        length_seconds:     related_video["length_seconds"]?.try &.to_i || 0,
        premiere_timestamp: nil,
        author_verified:    related_video["author_verified"]? == "true",
        author_thumbnail:   related_video["author_thumbnail"]?,
        badges:             VideoBadges::None,
      })
    end
  end

  return videos.uniq!(&.id), nil
end
