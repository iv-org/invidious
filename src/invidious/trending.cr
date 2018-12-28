def fetch_trending(trending_type, proxies, region, locale)
  client = make_client(YT_URL)
  headers = HTTP::Headers.new
  headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36"

  region ||= "US"
  region = region.upcase

  trending = ""
  if trending_type && trending_type != "Default"
    trending_type = trending_type.downcase.capitalize

    response = client.get("/feed/trending?gl=#{region}&hl=en", headers).body

    yt_data = response.match(/window\["ytInitialData"\] = (?<data>.*);/)
    if yt_data
      yt_data = JSON.parse(yt_data["data"].rchop(";"))
    else
      raise translate(locale, "Could not pull trending pages.")
    end

    tabs = yt_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][0]["tabRenderer"]["content"]["sectionListRenderer"]["subMenu"]["channelListSubMenuRenderer"]["contents"].as_a
    url = tabs.select { |tab| tab["channelListSubMenuAvatarRenderer"]["title"]["simpleText"] == trending_type }[0]?

    if url
      url = url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
      url += "&disable_polymer=1&gl=#{region}&hl=en"
      trending = client.get(url).body
    else
      trending = client.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
    end
  else
    trending = client.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
  end

  trending = XML.parse_html(trending)
  nodeset = trending.xpath_nodes(%q(//ul/li[@class="expanded-shelf-content-item-wrapper"]))
  trending = extract_videos(nodeset)

  return trending
end
