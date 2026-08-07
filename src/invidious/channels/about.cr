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
  pronouns : String?,
  allowed_regions : Array(String),
  tabs : Array(String),
  tags : Array(String),
  verified : Bool,
  is_age_gated : Bool

# Topic channels keep the channel details inside one of the carousel entries.
# The position of that entry varies between channels, so it is looked up by key
# rather than by index.
# ex: https://www.youtube.com/channel/UCEgdi0XIXXZ-qJOFPf4JSKw
def extract_topic_channel_details(initdata : Hash(String, JSON::Any)) : JSON::Any?
  contents = initdata.dig?("header", "carouselHeaderRenderer", "contents")
  return nil if contents.nil?

  contents.as_a
    .find { |content| !content.dig?("topicChannelDetailsRenderer").nil? }
    .try &.dig?("topicChannelDetailsRenderer")
end

# Auto-generated channels come with one of three header shapes. This is only
# reached when the payload has no `metadata` object, i.e. when the regular
# `channelMetadataRenderer` path is not available.
def extract_auto_generated_channel_header(initdata : Hash(String, JSON::Any), ucid : String)
  banner = nil
  description_node = nil
  tags = [] of String

  if header = initdata.dig?("header", "interactiveTabbedHeaderRenderer")
    author = header.dig("title", "simpleText").as_s
    author_url = initdata.dig("microformat", "microformatDataRenderer", "urlCanonical").as_s
    author_thumbnail = header.dig("boxArt", "thumbnails", 0, "url").as_s

    banner = header.dig?("banner", "thumbnails").try &.[-1]?.try &.["url"].as_s?

    description_base_node = header["description"]
    # some channels have the description in a simpleText
    # ex: https://www.youtube.com/channel/UCQvWX73GQygcwXOTSf_VDVg/
    description_node = description_base_node.dig?("simpleText") || description_base_node

    tags = header.dig?("badges")
      .try &.as_a.map(&.["metadataBadgeRenderer"]["label"].as_s) || [] of String
  elsif header = initdata.dig?("header", "pageHeaderRenderer")
    # ex: https://www.youtube.com/channel/UCOpNcN46UbXVtpKMrmU4Abg
    view_model = header.dig?("content", "pageHeaderViewModel")

    author = view_model.try &.dig?("title", "dynamicTextViewModel", "text", "content").try &.as_s
    author ||= header.dig?("pageTitle").try &.as_s
    author ||= ucid

    author_url = "https://www.youtube.com/channel/#{ucid}"

    author_thumbnail = view_model.try &.dig?("image", "decoratedAvatarViewModel", "avatar", "avatarViewModel", "image", "sources", 0, "url").try &.as_s
    author_thumbnail ||= view_model.try &.dig?("animatedImage", "contentPreviewImageViewModel", "image", "sources", 0, "url").try &.as_s
    author_thumbnail ||= ""

    banner = view_model.try &.dig?("banner", "imageBannerViewModel", "image", "sources")
      .try &.[-1]?.try &.["url"].as_s?
  elsif initdata.dig?("header", "carouselHeaderRenderer")
    # ex: https://www.youtube.com/channel/UCEgdi0XIXXZ-qJOFPf4JSKw
    # This shape carries neither a banner nor a description.
    details = extract_topic_channel_details(initdata)

    unless details
      raise InfoException.new("Could not extract the carousel header of channel #{ucid}")
    end

    author = details.dig?("title", "simpleText").try &.as_s
    author ||= raise InfoException.new("Could not extract the carousel title of channel #{ucid}")
    author_url = "https://www.youtube.com/channel/#{ucid}"

    # A missing avatar is not worth failing the whole page over, and the
    # `pageHeaderRenderer` branch above falls back to an empty string too.
    author_thumbnail = details.dig?("avatar", "thumbnails", 0, "url").try &.as_s || ""
  else
    raise InfoException.new("Could not extract the header of channel #{ucid}")
  end

  # `microformat` is absent from these payloads, so a missing flag defaults to
  # safe. An explicit `false` is still preserved.
  family_safe = initdata.dig?("microformat", "microformatDataRenderer", "familySafe").try(&.as_bool)

  {
    author:             author,
    author_url:         author_url,
    author_thumbnail:   author_thumbnail,
    banner:             banner,
    description_node:   description_node,
    tags:               tags,
    is_family_friendly: family_safe.nil? ? true : family_safe,
  }
end

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

  tags = [] of String
  tab_names = [] of String
  total_views = 0_i64
  joined = Time.unix(0)

  if age_gate_renderer = initdata.dig?("contents", "twoColumnBrowseResultsRenderer", "tabs", 0, "tabRenderer", "content", "sectionListRenderer", "contents", 0, "channelAgeGateRenderer")
    description_node = nil
    author = age_gate_renderer["channelTitle"].as_s
    ucid = initdata.dig("responseContext", "serviceTrackingParams", 0, "params", 0, "value").as_s
    author_url = "https://www.youtube.com/channel/#{ucid}"
    author_thumbnail = age_gate_renderer.dig("avatar", "thumbnails", 0, "url").as_s
    banner = nil
    is_family_friendly = false
    is_age_gated = true
    tab_names = ["videos", "shorts", "streams"]
    auto_generated = false
  else
    if auto_generated
      channel_header = extract_auto_generated_channel_header(initdata, ucid)
      author = channel_header[:author]
      author_url = channel_header[:author_url]
      author_thumbnail = channel_header[:author_thumbnail]
      banner = channel_header[:banner]
      description_node = channel_header[:description_node]
      tags = channel_header[:tags]
      is_family_friendly = channel_header[:is_family_friendly]
    else
      author = initdata["metadata"]["channelMetadataRenderer"]["title"].as_s
      author_url = initdata["metadata"]["channelMetadataRenderer"]["channelUrl"].as_s
      author_thumbnail = initdata["metadata"]["channelMetadataRenderer"]["avatar"]["thumbnails"][0]["url"].as_s
      author_badge = initdata.dig?("header", "pageHeaderRenderer", "content", "pageHeaderViewModel", "title", "dynamicTextViewModel", "text", "attachmentRuns", 0, "element", "type", "imageType", "image", "sources", 0, "clientResource", "imageName")
        .try &.as_s
      # CHECK_CIRCLE_FILLED is used for normal channels and AUDIO_BADGE if used For
      # music/artist channels
      # TODO: Maybe separate verified author from verified artist?
      author_verified = author_badge.try { |badge| badge == "CHECK_CIRCLE_FILLED" || badge == "AUDIO_BADGE" } || false
      ucid = initdata["metadata"]["channelMetadataRenderer"]["externalId"].as_s

      # Raises a KeyError on failure.
      # TODO: Check if `c4TabbedHeaderRenderer` still exists on some channels.
      banners = initdata["header"]["c4TabbedHeaderRenderer"]?.try &.["banner"]?.try &.["thumbnails"]?
      banners ||= initdata.dig?("header", "pageHeaderRenderer", "content", "pageHeaderViewModel", "banner", "imageBannerViewModel", "image", "sources")
      banner = banners.try &.[-1]?.try &.["url"].as_s?

      # if banner.includes? "channels/c4/default_banner"
      #  banner = nil
      # end

      description_node = initdata["metadata"]["channelMetadataRenderer"]?.try &.["description"]?
      tags = initdata.dig?("microformat", "microformatDataRenderer", "tags").try &.as_a.map(&.as_s) || [] of String
      is_family_friendly = initdata["microformat"]["microformatDataRenderer"]["familySafe"].as_bool
    end

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
             extract_text(channel_about_meta.dig?("primaryLinks", 0, "title")) == "Auto-generated by YouTube" ||
          channel_about_meta.dig?("links", 0, "channelExternalLinkViewModel", "title", "content").try &.as_s == "Auto-generated by YouTube"
        )
      end
    end
  end

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

  sub_count = 0
  pronouns = nil

  if (metadata_rows = initdata.dig?("header", "pageHeaderRenderer", "content", "pageHeaderViewModel", "metadata", "contentMetadataViewModel", "metadataRows").try &.as_a)
    metadata_rows.each do |row|
      subscribe_metadata_part = row.dig?("metadataParts").try &.as_a.find { |i| i.dig?("text", "content").try &.as_s.includes?("subscribers") }
      if !subscribe_metadata_part.nil?
        sub_count = short_text_to_number(subscribe_metadata_part.dig("text", "content").as_s.split(" ")[0]).to_i32
      end

      pronoun_metadata_part = row.dig?("metadataParts").try &.as_a.find { |i| i.dig?("tooltip").try &.as_s.includes?("Pronouns") }
      if !pronoun_metadata_part.nil?
        pronouns = pronoun_metadata_part.dig("text", "content").as_s
      end

      break if sub_count != 0 && !pronouns.nil?
    end
  elsif (topic_details = extract_topic_channel_details(initdata))
    # Topic channels carry the subscriber count as free text in the subtitle,
    # ex: "74.3M subscribers". `subscriberCountText` is part of the same
    # renderer but comes back null, so it is only used as a first choice.
    sub_text = topic_details.dig?("subscriberCountText", "simpleText").try &.as_s
    sub_text ||= topic_details.dig?("subtitle", "simpleText").try &.as_s

    if sub_text && sub_text.includes?("subscriber")
      sub_count = short_text_to_number(sub_text.split(" ")[0]).to_i32
    end
  end

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
    pronouns: pronouns,
    allowed_regions: allowed_regions,
    tabs: tab_names,
    tags: tags,
    verified: author_verified || false,
    is_age_gated: is_age_gated || false,
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
