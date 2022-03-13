# TODO: Refactor into either SearchChannel or InvidiousChannel
record AboutChannel,
  ucid : String,
  author : String,
  auto_generated : Bool,
  author_url : String,
  author_thumbnail : String,
  banner : String?,
  description_html : String,
  total_views : Int64,
  sub_count : Int32,
  joined : Time,
  is_family_friendly : Bool,
  allowed_regions : Array(String),
  tabs : Array(String),
  verified : Bool

record AboutRelatedChannel,
  ucid : String,
  author : String,
  author_url : String,
  author_thumbnail : String

def get_about_info(ucid, locale) : AboutChannel
  begin
    # "EgVhYm91dA==" is the base64-encoded protobuf object {"2:string":"about"}
    initdata = YoutubeAPI.browse(browse_id: ucid, params: "EgVhYm91dA==")
  rescue
    raise InfoException.new("Could not get channel info.")
  end

  if initdata.dig?("alerts", 0, "alertRenderer", "type") == "ERROR"
    raise InfoException.new(initdata["alerts"][0]["alertRenderer"]["text"]["simpleText"].as_s)
  end

  if browse_endpoint = initdata["onResponseReceivedActions"]?.try &.[0]?.try &.["navigateAction"]?.try &.["endpoint"]?.try &.["browseEndpoint"]?
    raise ChannelRedirect.new(channel_id: browse_endpoint["browseId"].to_s)
  end

  auto_generated = false
  # Check for special auto generated gaming channels
  if !initdata.has_key?("metadata")
    auto_generated = true
  end

  if auto_generated
    author = initdata["header"]["interactiveTabbedHeaderRenderer"]["title"]["simpleText"].as_s
    author_url = initdata["microformat"]["microformatDataRenderer"]["urlCanonical"].as_s
    author_thumbnail = initdata["header"]["interactiveTabbedHeaderRenderer"]["boxArt"]["thumbnails"][0]["url"].as_s

    # Raises a KeyError on failure.
    banners = initdata["header"]["interactiveTabbedHeaderRenderer"]?.try &.["banner"]?.try &.["thumbnails"]?
    banner = banners.try &.[-1]?.try &.["url"].as_s?

    description = initdata["header"]["interactiveTabbedHeaderRenderer"]["description"]["simpleText"].as_s
    description_html = HTML.escape(description)

    is_family_friendly = initdata["microformat"]["microformatDataRenderer"]["familySafe"].as_bool
    allowed_regions = initdata["microformat"]["microformatDataRenderer"]["availableCountries"].as_a.map(&.as_s)
  else
    author = initdata["metadata"]["channelMetadataRenderer"]["title"].as_s
    author_url = initdata["metadata"]["channelMetadataRenderer"]["channelUrl"].as_s
    author_thumbnail = initdata["metadata"]["channelMetadataRenderer"]["avatar"]["thumbnails"][0]["url"].as_s

    ucid = initdata["metadata"]["channelMetadataRenderer"]["externalId"].as_s

    # Raises a KeyError on failure.
    banners = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["banner"]?.try &.["thumbnails"]?
    banner = banners.try &.[-1]?.try &.["url"].as_s?

    # if banner.includes? "channels/c4/default_banner"
    #  banner = nil
    # end
    # author_verified_badges = initdata["header"]?.try &.["c4TabbedHeaderRenderer"]?.try &.["badges"]?
    author_verified_badge = initdata["header"].dig?("c4TabbedHeaderRenderer", "badges", 0, "metadataBadgeRenderer", "tooltip")
    author_verified = (author_verified_badge && author_verified_badge == "Verified")

    description = initdata["metadata"]["channelMetadataRenderer"]?.try &.["description"]?.try &.as_s? || ""
    description_html = HTML.escape(description)

    is_family_friendly = initdata["microformat"]["microformatDataRenderer"]["familySafe"].as_bool
    allowed_regions = initdata["microformat"]["microformatDataRenderer"]["availableCountries"].as_a.map(&.as_s)
  end

  total_views = 0_i64
  joined = Time.unix(0)

  tabs = [] of String

  tabs_json = initdata["contents"]["twoColumnBrowseResultsRenderer"]["tabs"]?.try &.as_a?
  if !tabs_json.nil?
    # Retrieve information from the tabs array. The index we are looking for varies between channels.
    tabs_json.each do |node|
      # Try to find the about section which is located in only one of the tabs.
      channel_about_meta = node["tabRenderer"]?.try &.["content"]?.try &.["sectionListRenderer"]?
        .try &.["contents"]?.try &.[0]?.try &.["itemSectionRenderer"]?.try &.["contents"]?
          .try &.[0]?.try &.["channelAboutFullMetadataRenderer"]?

      if !channel_about_meta.nil?
        total_views = channel_about_meta["viewCountText"]?.try &.["simpleText"]?.try &.as_s.gsub(/\D/, "").to_i64? || 0_i64

        # The joined text is split to several sub strings. The reduce joins those strings before parsing the date.
        joined = channel_about_meta["joinedDateText"]?.try &.["runs"]?.try &.as_a.reduce("") { |acc, nd| acc + nd["text"].as_s }
          .try { |text| Time.parse(text, "Joined %b %-d, %Y", Time::Location.local) } || Time.unix(0)

        # Normal Auto-generated channels
        # https://support.google.com/youtube/answer/2579942
        # For auto-generated channels, channel_about_meta only has ["description"]["simpleText"] and ["primaryLinks"][0]["title"]["simpleText"]
        if (channel_about_meta["primaryLinks"]?.try &.size || 0) == 1 && (channel_about_meta["primaryLinks"][0]?) &&
           (channel_about_meta["primaryLinks"][0]["title"]?.try &.["simpleText"]?.try &.as_s? || "") == "Auto-generated by YouTube"
          auto_generated = true
        end
      end
    end
    tabs = tabs_json.reject { |node| node["tabRenderer"]?.nil? }.map(&.["tabRenderer"]["title"].as_s.downcase)
  end

  sub_count = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s?
    .try { |text| short_text_to_number(text.split(" ")[0]) } || 0

  AboutChannel.new(
    ucid: ucid,
    author: author,
    auto_generated: auto_generated,
    author_url: author_url,
    author_thumbnail: author_thumbnail,
    banner: banner,
    description_html: description_html,
    total_views: total_views,
    sub_count: sub_count,
    joined: joined,
    is_family_friendly: is_family_friendly,
    allowed_regions: allowed_regions,
    tabs: tabs,
    verified: author_verified || false,
  )
end

def fetch_related_channels(about_channel : AboutChannel) : Array(AboutRelatedChannel)
  # params is {"2:string":"channels"} encoded
  channels = YoutubeAPI.browse(browse_id: about_channel.ucid, params: "EghjaGFubmVscw%3D%3D")

  tabs = channels.dig?("contents", "twoColumnBrowseResultsRenderer", "tabs").try(&.as_a?) || [] of JSON::Any
  tab = tabs.find(&.dig?("tabRenderer", "title").try(&.as_s?).try(&.== "Channels"))

  return [] of AboutRelatedChannel if tab.nil?

  items = tab.dig?(
    "tabRenderer", "content",
    "sectionListRenderer", "contents", 0,
    "itemSectionRenderer", "contents", 0,
    "gridRenderer", "items"
  ).try &.as_a?

  related = [] of AboutRelatedChannel
  return related if (items.nil? || items.empty?)

  items.each do |item|
    renderer = item["gridChannelRenderer"]?
    next if !renderer

    related_id = renderer.dig("channelId").as_s
    related_title = renderer.dig("title", "simpleText").as_s
    related_author_url = renderer.dig("navigationEndpoint", "browseEndpoint", "canonicalBaseUrl").as_s
    related_author_thumbnail = HelperExtractors.get_thumbnails(renderer)

    related << AboutRelatedChannel.new(
      ucid: related_id,
      author: related_title,
      author_url: related_author_url,
      author_thumbnail: related_author_thumbnail,
    )
  end

  return related
end
