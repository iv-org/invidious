def fetch_trending(trending_type, region, locale)
  region ||= "US"
  region = region.upcase

  trending = ""
  plid = nil

  if trending_type && trending_type != "Default"
    if trending_type == "Music"
      trending_type = 1
    elsif trending_type == "Gaming"
      trending_type = 2
    elsif trending_type == "Movies"
      trending_type = 3
    end

    response = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en").body

    initial_data = extract_initial_data(response)
    url = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][trending_type]["tabRenderer"]["endpoint"]["commandMetadata"]["webCommandMetadata"]["url"]
    bp = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][trending_type]["tabRenderer"]["endpoint"]["browseEndpoint"]["params"].to_s

    trending = YT_POOL.client &.get("#{url}&gl=#{region}&hl=en").body
    plid = extract_plid(bp)
  else
    trending = YT_POOL.client &.get("/feed/trending?gl=#{region}&hl=en").body
  end

  initial_data = extract_initial_data(trending)
  trending = extract_videos(initial_data)

  return {trending, plid}
end

def extract_plid(bp)
  return bp.try { |i| URI.decode_www_form(i) }
    .try { |i| Base64.decode(i) }
    .try { |i| IO::Memory.new(i) }
    .try { |i| Protodec::Any.parse(i) }
    .try &.["44:0:embedded"]?.try &.["3:0:string"]?.try &.as_s
end
