# TODO: Refactor into either SearchChannel or InvidiousChannel
record AboutChannel,
  ucid : String,
  author : String,
  auto_generated : Bool,
  author_url : String,
  author_thumbnail : String,
  banner : String?,
  description : String,
  description_html : String,
  total_views : Int64,
  sub_count : Int32,
  joined : Time,
  is_family_friendly : Bool,
  allowed_regions : Array(String),
  tabs : Array(String),
  verified : Bool

def get_about_info(ucid, locale) : AboutChannel
  begin
    # Fetch channel information from channel home page
    initdata = YoutubeAPI.browse(browse_id: ucid, params: "")
  rescue
    raise InfoException.new("Could not get channel info.")
  end

  if initdata.dig?("alerts", 0, "alertRenderer", "type") == "ERROR"
    error_message = initdata["alerts"][0]["alertRenderer"]["text"]["simpleText"].as_s
    if error_message == "This channel does not exist."
      raise NotFoundException.new(error_message)
    else
      raise InfoException.new(error_message)
    end
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

    description_node = initdata["header"]["interactiveTabbedHeaderRenderer"]["description"]
  else
    author = initdata["metadata"]["channelMetadataRenderer"]["title"].as_s
    author_url = initdata["metadata"]["channelMetadataRenderer"]["channelUrl"].as_s
    author_thumbnail = initdata["metadata"]["channelMetadataRenderer"]["avatar"]["thumbnails"][0]["url"].as_s
    author_verified = has_verified_badge?(initdata.dig?("header", "c4TabbedHeaderRenderer", "badges"))

    ucid = initdata["metadata"]["channelMetadataRenderer"]["externalId"].as_s

    # Raises a KeyError on failure.
    banners = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["banner"]?.try &.["thumbnails"]?
    banner = banners.try &.[-1]?.try &.["url"].as_s?

    # if banner.includes? "channels/c4/default_banner"
    #  banner = nil
    # end

    description_node = initdata["metadata"]["channelMetadataRenderer"]?.try &.["description"]?
  end

  is_family_friendly = initdata["microformat"]["microformatDataRenderer"]["familySafe"].as_bool

  allowed_regions = initdata
    .dig?("microformat", "microformatDataRenderer", "availableCountries")
    .try &.as_a.map(&.as_s) || [] of String

  description = !description_node.nil? ? description_node.as_s : ""
  description_html = HTML.escape(description)

  if !description_node.nil?
    if description_node.as_h?.nil?
      description_node = text_to_parsed_content(description_node.as_s)
    end
    description_html = parse_content(description_node)
    if description_html == "" && description != ""
      description_html = HTML.escape(description)
    end
  end

  total_views = 0_i64
  joined = Time.unix(0)

  tab_names = [] of String

  if tabs_json = initdata["contents"]["twoColumnBrowseResultsRenderer"]["tabs"]?
    # Get the name of the tabs available on this channel
    tab_names = tabs_json.as_a.compact_map do |entry|
      name = entry.dig?("tabRenderer", "title").try &.as_s.downcase

      # This is a small fix to not add extra code on the HTML side
      # I.e, the URL for the "live" tab is .../streams, so use "streams"
      # everywhere for the sake of simplicity
      (name == "live") ? "streams" : name
    end

    # Get the currently active tab ("About")
    about_tab = extract_selected_tab(tabs_json)

    # Try to find the about metadata section
    channel_about_meta = about_tab.dig?(
      "content",
      "sectionListRenderer", "contents", 0,
      "itemSectionRenderer", "contents", 0,
      "channelAboutFullMetadataRenderer"
    )

    if !channel_about_meta.nil?
      total_views = channel_about_meta.dig?("viewCountText", "simpleText").try &.as_s.gsub(/\D/, "").to_i64? || 0_i64

      # The joined text is split to several sub strings. The reduce joins those strings before parsing the date.
      joined = extract_text(channel_about_meta["joinedDateText"]?)
        .try { |text| Time.parse(text, "Joined %b %-d, %Y", Time::Location.local) } || Time.unix(0)

      # Normal Auto-generated channels
      # https://support.google.com/youtube/answer/2579942
      # For auto-generated channels, channel_about_meta only has
      # ["description"]["simpleText"] and ["primaryLinks"][0]["title"]["simpleText"]
      auto_generated = (
        (channel_about_meta["primaryLinks"]?.try &.size) == 1 && \
           extract_text(channel_about_meta.dig?("primaryLinks", 0, "title")) == "Auto-generated by YouTube"
      )
    end
  end

  sub_count = initdata
    .dig?("header", "c4TabbedHeaderRenderer", "subscriberCountText", "simpleText").try &.as_s?
    .try { |text| short_text_to_number(text.split(" ")[0]).to_i32 } || 0

  AboutChannel.new(
    ucid: ucid,
    author: author,
    auto_generated: auto_generated,
    author_url: author_url,
    author_thumbnail: author_thumbnail,
    banner: banner,
    description: description,
    description_html: description_html,
    total_views: total_views,
    sub_count: sub_count,
    joined: joined,
    is_family_friendly: is_family_friendly,
    allowed_regions: allowed_regions,
    tabs: tab_names,
    verified: author_verified || false,
  )
end

def fetch_related_channels(about_channel : AboutChannel, continuation : String? = nil) : {Array(SearchChannel), String?}
  if continuation.nil?
    # params is {"2:string":"channels"} encoded
    initial_data = YoutubeAPI.browse(browse_id: about_channel.ucid, params: "EghjaGFubmVscw%3D%3D")
  else
    initial_data = YoutubeAPI.browse(continuation)
  end

  items, continuation = extract_items(initial_data)

  return items.select(SearchChannel), continuation
end
