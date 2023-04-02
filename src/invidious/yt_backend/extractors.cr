require "../helpers/serialized_yt_data"

# This file contains helper methods to parse the Youtube API json data into
# neat little packages we can use

# Tuple of Parsers/Extractors so we can easily cycle through them.
private ITEM_CONTAINER_EXTRACTOR = {
  Extractors::YouTubeTabs,
  Extractors::SearchResults,
  Extractors::ContinuationContent,
}

private ITEM_PARSERS = {
  Parsers::VideoRendererParser,
  Parsers::ChannelRendererParser,
  Parsers::GridPlaylistRendererParser,
  Parsers::PlaylistRendererParser,
  Parsers::CategoryRendererParser,
  Parsers::RichItemRendererParser,
  Parsers::ReelItemRendererParser,
  Parsers::ItemSectionRendererParser,
  Parsers::ContinuationItemRendererParser,
}

private alias InitialData = Hash(String, JSON::Any)

record AuthorFallback, name : String, id : String

# Namespace for logic relating to parsing InnerTube data into various datastructs.
#
# Each of the parsers in this namespace are accessed through the #process() method
# which validates the given data as applicable to itself. If it is applicable the given
# data is passed to the private `#parse()` method which returns a datastruct of the given
# type. Otherwise, nil is returned.
private module Parsers
  # Parses a InnerTube videoRenderer into a SearchVideo. Returns nil when the given object isn't a videoRenderer
  #
  # A videoRenderer renders a video to click on within the YouTube and Invidious UI. It is **not**
  # the watchable video itself.
  #
  # See specs for example.
  #
  # `videoRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  module VideoRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = (item["videoRenderer"]? || item["gridVideoRenderer"]?)
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      video_id = item_contents["videoId"].as_s
      title = extract_text(item_contents["title"]?) || ""

      # Extract author information
      if author_info = item_contents.dig?("ownerText", "runs", 0)
        author = author_info["text"].as_s
        author_id = HelperExtractors.get_browse_id(author_info)
      elsif author_info = item_contents.dig?("shortBylineText", "runs", 0)
        author = author_info["text"].as_s
        author_id = HelperExtractors.get_browse_id(author_info)
      else
        author = author_fallback.name
        author_id = author_fallback.id
      end

      author_verified = has_verified_badge?(item_contents["ownerBadges"]?)

      # For live videos (and possibly recently premiered videos) there is no published information.
      # Instead, in its place is the amount of people currently watching. This behavior should be replicated
      # on Invidious once all features of livestreams are supported. On an unrelated note, defaulting to the current
      # time for publishing isn't a good idea.
      published = item_contents.dig?("publishedTimeText", "simpleText").try { |t| decode_date(t.as_s) } || Time.local

      # Typically views are stored under a "simpleText" in the "viewCountText". However, for
      # livestreams and premiered it is stored under a "runs" array: [{"text":123}, {"text": "watching"}]
      # When view count is disabled the "viewCountText" is not present on InnerTube data.
      # TODO change default value to nil and typical encoding type to tuple storing type (watchers, views, etc)
      # and count
      view_count = item_contents.dig?("viewCountText", "simpleText").try &.as_s.gsub(/\D+/, "").to_i64? || 0_i64
      description_html = item_contents["descriptionSnippet"]?.try { |t| parse_content(t, video_id) } || ""

      # The length information generally exist in "lengthText". However, the info can sometimes
      # be retrieved from "thumbnailOverlays" (e.g when the video is a "shorts" one).
      if length_container = item_contents["lengthText"]?
        length_seconds = decode_length_seconds(length_container["simpleText"].as_s)
      elsif length_container = item_contents["thumbnailOverlays"]?.try &.as_a.find(&.["thumbnailOverlayTimeStatusRenderer"]?)
        # This needs to only go down the `simpleText` path (if possible). If more situations came up that requires
        # a specific pathway then we should add an argument to extract_text that'll make this possible
        length_text = length_container.dig?("thumbnailOverlayTimeStatusRenderer", "text", "simpleText")

        if length_text
          length_text = length_text.as_s

          if length_text == "SHORTS"
            # Approximate length to one minute, as "shorts" generally don't exceed that length.
            # TODO: Add some sort of metadata for the type of video (normal, live, premiere, shorts)
            length_seconds = 60_i32
          else
            length_seconds = decode_length_seconds(length_text)
          end
        else
          length_seconds = 0
        end
      else
        length_seconds = 0
      end

      live_now = false
      paid = false
      premium = false

      premiere_timestamp = item_contents.dig?("upcomingEventData", "startTime").try { |t| Time.unix(t.as_s.to_i64) }

      item_contents["badges"]?.try &.as_a.each do |badge|
        b = badge["metadataBadgeRenderer"]
        case b["label"].as_s
        when "LIVE NOW"
          live_now = true
        when "New", "4K", "CC"
          # TODO
        when "Premium"
          # TODO: Potentially available as item_contents["topStandaloneBadge"]["metadataBadgeRenderer"]
          premium = true
        else nil # Ignore
        end
      end

      SearchVideo.new({
        title:              title,
        id:                 video_id,
        author:             author,
        ucid:               author_id,
        published:          published,
        views:              view_count,
        description_html:   description_html,
        length_seconds:     length_seconds,
        live_now:           live_now,
        premium:            premium,
        premiere_timestamp: premiere_timestamp,
        author_verified:    author_verified,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses a InnerTube channelRenderer into a SearchChannel. Returns nil when the given object isn't a channelRenderer
  #
  # A channelRenderer renders a channel to click on within the YouTube and Invidious UI. It is **not**
  # the channel page itself.
  #
  # See specs for example.
  #
  # `channelRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  module ChannelRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = (item["channelRenderer"]? || item["gridChannelRenderer"]?)
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      author = extract_text(item_contents["title"]) || author_fallback.name
      author_id = item_contents["channelId"]?.try &.as_s || author_fallback.id
      author_verified = has_verified_badge?(item_contents["ownerBadges"]?)
      author_thumbnail = HelperExtractors.get_thumbnails(item_contents)

      # When public subscriber count is disabled, the subscriberCountText isn't sent by InnerTube.
      # Always simpleText
      # TODO change default value to nil

      subscriber_count = item_contents.dig?("subscriberCountText", "simpleText")

      # Since youtube added channel handles, `VideoCountText` holds the number of
      # subscribers and `subscriberCountText` holds the handle, except when the
      # channel doesn't have a handle (e.g: some topic music channels).
      # See https://github.com/iv-org/invidious/issues/3394#issuecomment-1321261688
      if !subscriber_count || !subscriber_count.as_s.includes? " subscriber"
        subscriber_count = item_contents.dig?("videoCountText", "simpleText")
      end
      subscriber_count = subscriber_count
        .try { |s| short_text_to_number(s.as_s.split(" ")[0]).to_i32 } || 0

      # Auto-generated channels doesn't have videoCountText
      # Taken from: https://github.com/iv-org/invidious/pull/2228#discussion_r717620922
      auto_generated = item_contents["videoCountText"]?.nil?

      video_count = HelperExtractors.get_video_count(item_contents)
      description_html = item_contents["descriptionSnippet"]?.try { |t| parse_content(t) } || ""

      SearchChannel.new({
        author:           author,
        ucid:             author_id,
        author_thumbnail: author_thumbnail,
        subscriber_count: subscriber_count,
        video_count:      video_count,
        description_html: description_html,
        auto_generated:   auto_generated,
        author_verified:  author_verified,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses a InnerTube gridPlaylistRenderer into a SearchPlaylist. Returns nil when the given object isn't a gridPlaylistRenderer
  #
  # A gridPlaylistRenderer renders a playlist, that is located in a grid, to click on within the YouTube and Invidious UI.
  # It is **not** the playlist itself.
  #
  # See specs for example.
  #
  # `gridPlaylistRenderer`s can be found on the playlist-tabs of channels and expanded categories.
  #
  module GridPlaylistRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["gridPlaylistRenderer"]?
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      title = extract_text(item_contents["title"]) || ""
      plid = item_contents["playlistId"]?.try &.as_s || ""

      author_verified = has_verified_badge?(item_contents["ownerBadges"]?)

      video_count = HelperExtractors.get_video_count(item_contents)
      playlist_thumbnail = HelperExtractors.get_thumbnails(item_contents)

      SearchPlaylist.new({
        title:           title,
        id:              plid,
        author:          author_fallback.name,
        ucid:            author_fallback.id,
        video_count:     video_count,
        videos:          [] of SearchPlaylistVideo,
        thumbnail:       playlist_thumbnail,
        author_verified: author_verified,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses a InnerTube playlistRenderer into a SearchPlaylist. Returns nil when the given object isn't a playlistRenderer
  #
  # A playlistRenderer renders a playlist to click on within the YouTube and Invidious UI. It is **not** the playlist itself.
  #
  # See specs for example.
  #
  # `playlistRenderer`s can be found almost everywhere on YouTube. In categories, search results, recommended, etc.
  #
  module PlaylistRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["playlistRenderer"]?
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      title = item_contents["title"]["simpleText"]?.try &.as_s || ""
      plid = item_contents["playlistId"]?.try &.as_s || ""

      video_count = HelperExtractors.get_video_count(item_contents)
      playlist_thumbnail = HelperExtractors.get_thumbnails_plural(item_contents)

      author_info = item_contents.dig?("shortBylineText", "runs", 0)
      author = author_info.try &.["text"].as_s || author_fallback.name
      author_id = author_info.try { |x| HelperExtractors.get_browse_id(x) } || author_fallback.id
      author_verified = has_verified_badge?(item_contents["ownerBadges"]?)

      videos = item_contents["videos"]?.try &.as_a.map do |v|
        v = v["childVideoRenderer"]
        v_title = v.dig?("title", "simpleText").try &.as_s || ""
        v_id = v["videoId"]?.try &.as_s || ""
        v_length_seconds = v.dig?("lengthText", "simpleText").try { |t| decode_length_seconds(t.as_s) } || 0
        SearchPlaylistVideo.new({
          title:          v_title,
          id:             v_id,
          length_seconds: v_length_seconds,
        })
      end || [] of SearchPlaylistVideo

      # TODO: item_contents["publishedTimeText"]?

      SearchPlaylist.new({
        title:           title,
        id:              plid,
        author:          author,
        ucid:            author_id,
        video_count:     video_count,
        videos:          videos,
        thumbnail:       playlist_thumbnail,
        author_verified: author_verified,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses a InnerTube shelfRenderer into a Category. Returns nil when the given object isn't a shelfRenderer
  #
  # A shelfRenderer renders divided sections on YouTube. IE "People also watched" in search results and
  # the various organizational sections in the channel home page. A separate one (richShelfRenderer) is used
  # for YouTube home. A shelfRenderer can also sometimes be expanded to show more content within it.
  #
  # See specs for example.
  #
  # `shelfRenderer`s can be found almost everywhere on YouTube. In categories, search results, channels, etc.
  #
  module CategoryRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["shelfRenderer"]?
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      title = extract_text(item_contents["title"]?) || ""
      url = item_contents.dig?("endpoint", "commandMetadata", "webCommandMetadata", "url")
        .try &.as_s

      # Sometimes a category can have badges.
      badges = [] of Tuple(String, String) # (Badge style, label)
      item_contents["badges"]?.try &.as_a.each do |badge|
        badge = badge["metadataBadgeRenderer"]
        badges << {badge["style"].as_s, badge["label"].as_s}
      end

      # Category description
      description_html = item_contents["subtitle"]?.try { |desc| parse_content(desc) } || ""

      # Content parsing
      contents = [] of SearchItem

      # InnerTube recognizes some "special" categories, which are organized differently.
      if special_category_container = item_contents["content"]?
        if content_container = special_category_container["horizontalListRenderer"]?
        elsif content_container = special_category_container["expandedShelfContentsRenderer"]?
        elsif content_container = special_category_container["verticalListRenderer"]?
        else
          # Anything else, such as `horizontalMovieListRenderer` is currently unsupported.
          return
        end
      else
        # "Normal" category.
        content_container = item_contents["contents"]
      end

      content_container["items"]?.try &.as_a.each do |item|
        result = parse_item(item, author_fallback.name, author_fallback.id)
        contents << result if result.is_a?(SearchItem)
      end

      Category.new({
        title:            title,
        contents:         contents,
        description_html: description_html,
        url:              url,
        badges:           badges,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses an InnerTube itemSectionRenderer into a SearchVideo.
  # Returns nil when the given object isn't a ItemSectionRenderer
  #
  # A itemSectionRenderer seems to be a simple wrapper for a videoRenderer, used
  # by the result page for channel searches. It is located inside a continuationItems
  # container.It is very similar to RichItemRendererParser
  #
  module ItemSectionRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item.dig?("itemSectionRenderer", "contents", 0)
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      child = VideoRendererParser.process(item_contents, author_fallback)
      return child
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses an InnerTube richItemRenderer into a SearchVideo.
  # Returns nil when the given object isn't a RichItemRenderer
  #
  # A richItemRenderer seems to be a simple wrapper for a videoRenderer, used
  # by the result page for hashtags. It is located inside a continuationItems
  # container.
  #
  module RichItemRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item.dig?("richItemRenderer", "content")
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      child = VideoRendererParser.process(item_contents, author_fallback)
      child ||= ReelItemRendererParser.process(item_contents, author_fallback)
      return child
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses an InnerTube reelItemRenderer into a SearchVideo.
  # Returns nil when the given object isn't a reelItemRenderer
  #
  # reelItemRenderer items are used in the new (2022) channel layout,
  # in the "shorts" tab.
  #
  module ReelItemRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["reelItemRenderer"]?
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      video_id = item_contents["videoId"].as_s

      reel_player_overlay = item_contents.dig(
        "navigationEndpoint", "reelWatchEndpoint",
        "overlay", "reelPlayerOverlayRenderer"
      )

      if video_details_container = reel_player_overlay.dig?(
           "reelPlayerHeaderSupportedRenderers",
           "reelPlayerHeaderRenderer"
         )
        # Author infos

        author = video_details_container
          .dig?("channelTitleText", "runs", 0, "text")
          .try &.as_s || author_fallback.name

        ucid = video_details_container
          .dig?("channelNavigationEndpoint", "browseEndpoint", "browseId")
          .try &.as_s || author_fallback.id

        # Title & publication date

        title = video_details_container.dig?("reelTitleText")
          .try { |t| extract_text(t) } || ""

        published = video_details_container
          .dig?("timestampText", "simpleText")
          .try { |t| decode_date(t.as_s) } || Time.utc

        # View count
        view_count_text = video_details_container.dig?("viewCountText", "simpleText")
      else
        author = author_fallback.name
        ucid = author_fallback.id
        published = Time.utc
        title = item_contents.dig?("headline", "simpleText").try &.as_s || ""
      end
      # View count

      # View count used to be in the reelWatchEndpoint, but that changed?
      view_count_text ||= item_contents.dig?("viewCountText", "simpleText")

      view_count = short_text_to_number(view_count_text.try &.as_s || "0")

      # Duration

      a11y_data = item_contents
        .dig?("accessibility", "accessibilityData", "label")
        .try &.as_s || ""

      regex_match = /- (?<min>\d+ minutes? )?(?<sec>\d+ seconds?)+ -/.match(a11y_data)

      minutes = regex_match.try &.["min"]?.try &.to_i(strict: false) || 0
      seconds = regex_match.try &.["sec"]?.try &.to_i(strict: false) || 0

      duration = (minutes*60 + seconds)

      SearchVideo.new({
        title:              title,
        id:                 video_id,
        author:             author,
        ucid:               ucid,
        published:          published,
        views:              view_count,
        description_html:   "",
        length_seconds:     duration,
        live_now:           false,
        premium:            false,
        premiere_timestamp: Time.unix(0),
        author_verified:    false,
      })
    end

    def self.parser_name
      return {{@type.name}}
    end
  end

  # Parses an InnerTube continuationItemRenderer into a Continuation.
  # Returns nil when the given object isn't a continuationItemRenderer.
  #
  # continuationItemRenderer contains various metadata ued to load more
  # content (i.e when the user scrolls down). The interesting bit is the
  # protobuf object known as the "continutation token". Previously, those
  # were generated from sratch, but recent (as of 11/2022) Youtube changes
  # are forcing us to extract them from replies.
  #
  module ContinuationItemRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["continuationItemRenderer"]?
        return self.parse(item_contents)
      end
    end

    private def self.parse(item_contents)
      token = item_contents
        .dig?("continuationEndpoint", "continuationCommand", "token")
        .try &.as_s

      return Continuation.new(token) if token
    end

    def self.parser_name
      return {{@type.name}}
    end
  end
end

# The following are the extractors for extracting an array of items from
# the internal Youtube API's JSON response. The result is then packaged into
# a structure we can more easily use via the parsers above. Their internals are
# identical to the item parsers.

# Namespace for logic relating to extracting InnerTube's initial response to items we can parse.
#
# Each of the extractors in this namespace are accessed through the #process() method
# which validates the given data as applicable to itself. If it is applicable the given
# data is passed to the private `#extract()` method which returns an array of
# parsable items. Otherwise, nil is returned.
#
# NOTE perhaps the result from here should be abstracted into a struct in order to
# get additional metadata regarding the container of the item(s).
private module Extractors
  # Extracts items from the selected YouTube tab.
  #
  # YouTube tabs are typically stored under "twoColumnBrowseResultsRenderer"
  # and is structured like this:
  #
  # "twoColumnBrowseResultsRenderer": {
  #   {"tabs": [
  #     {"tabRenderer":  {
  #       "endpoint": {...}
  #       "title": "Playlists",
  #       "selected": true, # Is nil unless tab is selected
  #       "content": {...},
  #       ...
  #     }}
  #   ]}
  # }]
  #
  module YouTubeTabs
    def self.process(initial_data : InitialData)
      if target = initial_data["twoColumnBrowseResultsRenderer"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      raw_items = [] of JSON::Any
      content = extract_selected_tab(target["tabs"])["content"]

      if section_list_contents = content.dig?("sectionListRenderer", "contents")
        raw_items = unpack_section_list(section_list_contents)
      elsif rich_grid_contents = content.dig?("richGridRenderer", "contents")
        raw_items = rich_grid_contents.as_a
      end

      return raw_items
    end

    private def self.unpack_section_list(contents)
      raw_items = [] of JSON::Any

      contents.as_a.each do |renderer_container|
        renderer_container_contents = renderer_container["itemSectionRenderer"]["contents"][0]

        # Category extraction
        if items_container = renderer_container_contents["shelfRenderer"]?
          raw_items << renderer_container_contents
          next
        elsif items_container = renderer_container_contents["gridRenderer"]?
        else
          items_container = renderer_container_contents
        end

        items_container["items"]?.try &.as_a.each do |item|
          raw_items << item
        end
      end

      return raw_items
    end

    def self.extractor_name
      return {{@type.name}}
    end
  end

  # Extracts items from the InnerTube response for search results
  #
  # Search results are typically stored under "twoColumnSearchResultsRenderer"
  # and is structured like this:
  #
  # "twoColumnSearchResultsRenderer": {
  #   {"primaryContents": {
  #     {"sectionListRenderer": {
  #       "contents": [...],
  #       ...,
  #       "subMenu": {...},
  #       "hideBottomSeparator": true,
  #       "targetId": "search-feed"
  #     }}
  #   }}
  # }
  #
  module SearchResults
    def self.process(initial_data : InitialData)
      if target = initial_data["twoColumnSearchResultsRenderer"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      raw_items = [] of Array(JSON::Any)

      target.dig("primaryContents", "sectionListRenderer", "contents").as_a.each do |node|
        if node = node["itemSectionRenderer"]?
          raw_items << node["contents"].as_a
        end
      end

      return raw_items.flatten
    end

    def self.extractor_name
      return {{@type.name}}
    end
  end

  # Extracts continuation items from a InnerTube response
  #
  # Continuation items (on YouTube) are items which are appended to the
  # end of the page for continuous scrolling. As such, in many cases,
  # the items are lacking information such as author or category title,
  # since the original results has already rendered them on the top of the page.
  #
  # The way they are structured is too varied to be accurately written down here.
  # However, they all eventually lead to an array of parsable items after traversing
  # through the JSON structure.
  module ContinuationContent
    def self.process(initial_data : InitialData)
      if target = initial_data["continuationContents"]?
        self.extract(target)
      elsif target = initial_data["appendContinuationItemsAction"]?
        self.extract(target)
      elsif target = initial_data["reloadContinuationItemsCommand"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      content = target["continuationItems"]?
      content ||= target.dig?("gridContinuation", "items")
      content ||= target.dig?("richGridContinuation", "contents")

      return content.nil? ? [] of JSON::Any : content.as_a
    end

    def self.extractor_name
      return {{@type.name}}
    end
  end
end

# Helper methods to aid in the parsing of InnerTube to data structs.
#
# Mostly used to extract out repeated structures to deal with code
# repetition.
module HelperExtractors
  # Retrieves the amount of videos present within the given InnerTube data.
  #
  # Returns a 0 when it's unable to do so
  def self.get_video_count(container : JSON::Any) : Int32
    if box = container["videoCountText"]?
      if (extracted_text = extract_text(box)) && !extracted_text.includes? " subscriber"
        return extracted_text.gsub(/\D/, "").to_i
      else
        return 0
      end
    elsif box = container["videoCount"]?
      return box.as_s.to_i
    else
      return 0
    end
  end

  # Retrieves the amount of views/viewers a video has.
  # Seems to be used on related videos only
  #
  # Returns "0" when unable to parse
  def self.get_short_view_count(container : JSON::Any) : String
    box = container["shortViewCountText"]?
    return "0" if !box

    # Simpletext: "4M views"
    # runs: {"text": "1.1K"},{"text":" watching"}
    return box["simpleText"]?.try &.as_s.sub(" views", "") ||
      box.dig?("runs", 0, "text").try &.as_s || "0"
  end

  # Retrieve lowest quality thumbnail from InnerTube data
  #
  # TODO allow configuration of image quality (-1 is highest)
  #
  # Raises when it's unable to parse from the given JSON data.
  def self.get_thumbnails(container : JSON::Any) : String
    return container.dig("thumbnail", "thumbnails", 0, "url").as_s
  end

  # ditto
  #
  # YouTube sometimes sends the thumbnail as:
  # {"thumbnails": [{"thumbnails": [{"url": "example.com"}, ...]}]}
  def self.get_thumbnails_plural(container : JSON::Any) : String
    return container.dig("thumbnails", 0, "thumbnails", 0, "url").as_s
  end

  # Retrieves the ID required for querying the InnerTube browse endpoint.
  # Raises when it's unable to do so
  def self.get_browse_id(container)
    return container.dig("navigationEndpoint", "browseEndpoint", "browseId").as_s
  end
end

# Parses an item from Youtube's JSON response into a more usable structure.
# The end result can either be a SearchVideo, SearchPlaylist or SearchChannel.
def parse_item(item : JSON::Any, author_fallback : String? = "", author_id_fallback : String? = "")
  # We "allow" nil values but secretly use empty strings instead. This is to save us the
  # hassle of modifying every author_fallback and author_id_fallback arg usage
  # which is more often than not nil.
  author_fallback = AuthorFallback.new(author_fallback || "", author_id_fallback || "")

  # Cycles through all of the item parsers and attempt to parse the raw YT JSON data.
  # Each parser automatically validates the data given to see if the data is
  # applicable to itself. If not nil is returned and the next parser is attempted.
  ITEM_PARSERS.each do |parser|
    LOGGER.trace("parse_item: Attempting to parse item using \"#{parser.parser_name}\" (cycling...)")

    if result = parser.process(item, author_fallback)
      LOGGER.debug("parse_item: Successfully parsed via #{parser.parser_name}")
      return result
    else
      LOGGER.trace("parse_item: Parser \"#{parser.parser_name}\" does not apply. Cycling to the next one...")
    end
  end
end

# Parses multiple items from YouTube's initial JSON response into a more usable structure.
# The end result is an array of SearchItem.
#
# This function yields the container so that items can be parsed separately.
#
def extract_items(initial_data : InitialData, &block)
  if unpackaged_data = initial_data["contents"]?.try &.as_h
  elsif unpackaged_data = initial_data["response"]?.try &.as_h
  elsif unpackaged_data = initial_data.dig?("onResponseReceivedActions", 1).try &.as_h
  elsif unpackaged_data = initial_data.dig?("onResponseReceivedActions", 0).try &.as_h
  else
    unpackaged_data = initial_data
  end

  # This is identical to the parser cycling of parse_item().
  ITEM_CONTAINER_EXTRACTOR.each do |extractor|
    LOGGER.trace("extract_items: Attempting to extract item container using \"#{extractor.extractor_name}\" (cycling...)")

    if container = extractor.process(unpackaged_data)
      LOGGER.debug("extract_items: Successfully unpacked container with \"#{extractor.extractor_name}\"")
      # Extract items in container
      container.each { |item| yield item }
    else
      LOGGER.trace("extract_items: Extractor \"#{extractor.extractor_name}\" does not apply. Cycling to the next one...")
    end
  end
end

# Wrapper using the block function above
def extract_items(
  initial_data : InitialData,
  author_fallback : String? = nil,
  author_id_fallback : String? = nil
) : {Array(SearchItem), String?}
  items = [] of SearchItem
  continuation = nil

  extract_items(initial_data) do |item|
    parsed = parse_item(item, author_fallback, author_id_fallback)

    case parsed
    when .is_a?(Continuation) then continuation = parsed.token
    when .is_a?(SearchItem)   then items << parsed
    end
  end

  return items, continuation
end
