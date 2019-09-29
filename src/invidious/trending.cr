# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

def fetch_trending(trending_type, region, locale)
  client = make_client(YT_URL)
  headers = HTTP::Headers.new
  headers["User-Agent"] = "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/68.0.3440.106 Safari/537.36"

  region ||= "US"
  region = region.upcase

  trending = ""
  plid = nil

  if trending_type && trending_type != "Default"
    trending_type = trending_type.downcase.capitalize

    response = client.get("/feed/trending?gl=#{region}&hl=en", headers).body

    initial_data = extract_initial_data(response)

    tabs = initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"][0]["tabRenderer"]["content"]["sectionListRenderer"]["subMenu"]["channelListSubMenuRenderer"]["contents"].as_a
    url = tabs.select { |tab| tab["channelListSubMenuAvatarRenderer"]["title"]["simpleText"] == trending_type }[0]?

    if url
      url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"]
      url = url["channelListSubMenuAvatarRenderer"]["navigationEndpoint"]["commandMetadata"]["webCommandMetadata"]["url"].as_s
      url += "&disable_polymer=1&gl=#{region}&hl=en"
      trending = client.get(url).body
      plid = extract_plid(url)
    else
      trending = client.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
    end
  else
    trending = client.get("/feed/trending?gl=#{region}&hl=en&disable_polymer=1").body
  end

  trending = XML.parse_html(trending)
  nodeset = trending.xpath_nodes(%q(//ul/li[@class="expanded-shelf-content-item-wrapper"]))
  trending = extract_videos(nodeset)

  return {trending, plid}
end

def extract_plid(url)
  wrapper = HTTP::Params.parse(URI.parse(url).query.not_nil!)["bp"]

  wrapper = URI.decode_www_form(wrapper)
  wrapper = Base64.decode(wrapper)

  # 0xe2 0x02 0x2e
  wrapper += 3

  # 0x0a
  wrapper += 1

  # Looks like "/m/[a-z0-9]{5}", not sure what it does here

  item_size = wrapper[0]
  wrapper += 1
  item = wrapper[0, item_size]
  wrapper += item.size

  # 0x12
  wrapper += 1

  plid_size = wrapper[0]
  wrapper += 1
  plid = wrapper[0, plid_size]
  wrapper += plid.size

  plid = String.new(plid)

  return plid
end
