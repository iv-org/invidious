def fetch_trending(trending_type, region, locale)
  region ||= "US"
  region = region.upcase

  trending = ""
  plid = nil

  if trending_type && trending_type != "Default"
    trending_type = trending_type.downcase.capitalize

    response = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en").body

    initial_data = extract_initial_data(response)

    tabs = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][0]["tabRenderer"]["content"]["sectionListRenderer"]["subMenu"]["channelListSubMenuRenderer"]["contents"].as_a
    url = tabs.select { |tab| tab["channelListSubMenuAvatarRenderer"]["title"]["simpleText"] == trending_type }[0]?

    if url
      url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"]
      url = url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
      url = "#{url}&gl=#{region}&hl=en"
      trending = YT_POOL.client &.get(url).body
      plid = extract_plid(url)
    else
      trending = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en").body
    end
  else
    trending = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en").body
  end

  initial_data = extract_initial_data(trending)
  trending = extract_videos(initial_data)

  return {trending, plid}
end

def extract_plid(url)
  return url.try { |i| URI.parse(i).query }
    .try { |i| HTTP::Params.parse(i)["bp"] }
    .try { |i| URI.decode_www_form(i) }
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try &.["44:0:embedded"]?.try &.["2:1:string"]?.try &.as_s
end
