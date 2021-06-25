def fetch_channel_home(ucid, channel)
  initial_data = request_youtube_api_browse(ucid, "EghmZWF0dXJlZA%3D%3D")
  items = extract_items(initial_data, channel.author, channel.ucid)

  # Channel trailer needs some slight special handling
  home_tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])
  trailer = home_tab["content"]["sectionListRenderer"]["contents"][0]["itemSectionRenderer"]["contents"][0]["channelVideoPlayerRenderer"]? || nil

  home_sections = [] of (Category | Video)
  if trailer
    trailer = get_video(trailer["videoId"].as_s, PG_DB)
    home_sections << trailer
  end

  items.each do |category|
    if category.is_a? Category
      home_sections << category
    end
  end

  return home_sections
end
