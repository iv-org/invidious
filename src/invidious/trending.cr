def fetch_trending(trending_type, region, locale)
  headers = HTTP::Headers.new
  headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36"

  region ||= "US"
  region = region.upcase

  trending = ""
  plid = nil

  if trending_type && trending_type != "Default"
    trending_type = trending_type.downcase.capitalize

    response = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en", headers).body

    initial_data = extract_initial_data(response)

    tabs = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][0]["tabRenderer"]["content"]["sectionListRenderer"]["subMenu"]["channelListSubMenuRenderer"]["contents"].as_a
    url = tabs.select { |tab| tab["channelListSubMenuAvatarRenderer"]["title"]["simpleText"] == trending_type }[0]?

    if url
      url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"]
      url = url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
      url += "&disable_polymer=1&gl=#{region}&hl=en"
      trending = YT_POOL.client &.get(url).body
      plid = extract_plid(url)
    else
      trending = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
    end
  else
    trending = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
  end

  trending = XML.parse_html(trending)
  nodeset = trending.xpath_nodes(%q(//ul/li[@class="expanded-shelf-content-item-wrapper"]))
  trending = extract_videos(nodeset)

  return {trending, plid}
end

def extract_plid(url)
  plid = URI.parse(url)
    .try { |i| HTTP::Params.parse(i.query.not_nil!)["bp"] }
    .try { |i| URI.decode_www_form(i) }
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try { |i| i["44:0:embedded"]["2:1:string"].as_s }

  return plid
end
