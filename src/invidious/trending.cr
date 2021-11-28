def fetch_trending(trending_type, region, locale)
  region ||= "US"
  region = region.upcase

  plid = nil

  if trending_type == "Music"
    params = "4gINGgt5dG1hX2NoYXJ0cw%3D%3D"
  elsif trending_type == "Gaming"
    params = "4gIcGhpnYW1pbmdfY29ycHVzX21vc3RfcG9wdWxhcg%3D%3D"
  elsif trending_type == "Movies"
    params = "4gIKGgh0cmFpbGVycw%3D%3D"
  else # Default
    params = ""
  end

  client_config = YoutubeAPI::ClientConfig.new(region: region)
  initial_data = YoutubeAPI.browse("FEtrending", params: params, client_config: client_config)
  trending = extract_videos(initial_data)

  return {trending, plid}
end
