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
  channel_videos, notifications = get_subscription_feed(user, 5, 1)

  videos = [] of SearchVideo
  channel_videos.each do |video|
    video = get_video(video.id)
    related = video.related_videos
    related.each do |related_video|
      related_id = related_video["id"]
      videos << SearchVideo.new({
        title:              related_video["title"],
        id:                 related_video["id"],
        author:             related_video["author"],
        ucid:               related_video["ucid"]? || "",
        published:          related_video["published"]?.try { |p| Time.parse_rfc3339(p) } || Time.utc,
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
