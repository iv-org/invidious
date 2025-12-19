def fetch_trending(trending_type, region, locale)
  region ||= "US"
  region = region.upcase

  plid = nil

  browse_id = ""

  case trending_type.try &.downcase
  when "gaming"
    browse_id = "UCOpNcN46UbXVtpKMrmU4Abg"
    params = "Egh0cmVuZGluZw%3D%3D"
  when "livestreams"
    browse_id = "UC4R8DWoMoI7CAwX8_LjQHig"
    params = "EgdsaXZldGFikgEDCKEK"
  else
    # Livestreams is the default one as Youtube removed
    # the aggregated trending page
    # https://github.com/iv-org/invidious/issues/5397#issuecomment-3218928458
    browse_id = "UC4R8DWoMoI7CAwX8_LjQHig"
    params = "EgdsaXZldGFikgEDCKEK"
  end

  client_config = YoutubeAPI::ClientConfig.new(region: region)
  initial_data = YoutubeAPI.browse(browse_id, params: params, client_config: client_config)

  items, _ = extract_items(initial_data)

  extracted = [] of SearchItem

  deduplicate = items.size > 1

  items.each do |itm|
    if itm.is_a?(Category)
      # Ignore the smaller categories, as they generally contain a sponsored
      # channel, which brings a lot of noise on the trending page.
      # See: https://github.com/iv-org/invidious/issues/2989
      next if (itm.contents.size < 24 && deduplicate)

      extracted.concat itm.contents.select(SearchItem)
    else
      extracted << itm
    end
  end

  # Deduplicate items before returning results
  return extracted.select(SearchVideo | ProblematicTimelineItem).uniq!(&.id), plid
end
