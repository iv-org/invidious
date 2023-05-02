def fetch_trending(trending_type, region, locale)
  region ||= "US"
  region = region.upcase

  plid = nil

  case trending_type.try &.downcase
  when "music"
    params = "4gINGgt5dG1hX2NoYXJ0cw%3D%3D"
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

  items.each do |itm|
    if itm.is_a?(Category)
      # Ignore the smaller categories, as they generally contain a sponsored
      # channel, which brings a lot of noise on the trending page.
      # See: https://github.com/iv-org/invidious/issues/2989
      next if itm.contents.size < 24

      extracted.concat extract_category(itm)
    else
      extracted << itm
    end
  end

  # Deduplicate items before returning results
  return extracted.select(SearchVideo).uniq!(&.id), plid
end
