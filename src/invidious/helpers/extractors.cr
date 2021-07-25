# This file contains helper methods to parse the Youtube API json data into
# neat little packages we can use

# Tuple of Parsers/Extractors so we can easily cycle through them.
private ITEM_CONTAINER_EXTRACTOR = {
  Extractors::YouTubeTabs,
  Extractors::SearchResults,
  Extractors::Continuation,
}

private ITEM_PARSERS = {
  Parsers::VideoRendererParser,
  Parsers::ChannelRendererParser,
  Parsers::GridPlaylistRendererParser,
  Parsers::PlaylistRendererParser,
  Parsers::CategoryRendererParser,
  Parsers::BackstagePostThreadRendererParser,
}

record AuthorFallback, name : String, id : String

# Namespace for logic relating to parsing InnerTube data into various datastructs.
#
# Each of the parsers in this namespace are accessed through the #process() method
# which validates the given data as applicable to itself. If it is applicable the given
# data is passed to the private `#parse()` method which returns a datastruct of the given
# type. Otherwise, nil is returned.
private module Parsers
  # Parses a InnerTube videoRenderer into a YouTubeStructs::VideoRenderer. Returns nil when the given object isn't a videoRenderer
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
      title = extract_text(item_contents["title"]) || ""

      # Extract author information
      if author_info = item_contents.dig?("ownerText", "runs", 0)
        author = author_info["text"].as_s
        author_id = HelperExtractors.get_browse_id(author_info)
      else
        author = author_fallback.name
        author_id = author_fallback.id
      end

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

      # TODO YouTube seems to have removed the description_html snippet and replaced it with "snippetText"
      # inside the detailedMetadataSnippets attribute
      description_html = item_contents["descriptionSnippet"]?.try { |t| parse_content(t) } || ""

      # The length information *should* only always exist in "lengthText". However, the legacy Invidious code
      # extracts from "thumbnailOverlays" when it doesn't. More testing is needed to see if this is
      # actually needed
      if length_container = item_contents["lengthText"]?
        length_seconds = decode_length_seconds(length_container["simpleText"].as_s)
      elsif length_container = item_contents["thumbnailOverlays"]?.try &.as_a.find(&.["thumbnailOverlayTimeStatusRenderer"]?)
        length_seconds = extract_text(length_container["thumbnailOverlayTimeStatusRenderer"]["text"]).try { |t| decode_length_seconds(t) } || 0
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

      YouTubeStructs::VideoRenderer.new({
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
      })
    end
  end

  # Parses a InnerTube channelRenderer into a YouTubeStructs::ChannelRenderer. Returns nil when the given object isn't a channelRenderer
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

      author_thumbnail = HelperExtractors.get_thumbnails(item_contents)
      # When public subscriber count is disabled, the subscriberCountText isn't sent by InnerTube.
      # Always simpleText
      # TODO change default value to nil
      subscriber_count = item_contents.dig?("subscriberCountText", "simpleText")
        .try { |s| short_text_to_number(s.as_s.split(" ")[0]) } || 0

      # Auto-generated channels doesn't have videoCountText
      # Taken from: https://github.com/iv-org/invidious/pull/2228#discussion_r717620922
      auto_generated = item_contents["videoCountText"]?.nil?

      video_count = HelperExtractors.get_video_count(item_contents)
      description_html = item_contents["descriptionSnippet"]?.try { |t| parse_content(t) } || ""

      YouTubeStructs::ChannelRenderer.new({
        author:           author,
        ucid:             author_id,
        author_thumbnail: author_thumbnail,
        subscriber_count: subscriber_count,
        video_count:      video_count,
        description_html: description_html,
        auto_generated:   auto_generated,
      })
    end
  end

  # Parses a InnerTube gridPlaylistRenderer into a YouTubeStructs::PlaylistRenderer. Returns nil when the given object isn't a gridPlaylistRenderer
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

      video_count = HelperExtractors.get_video_count(item_contents)
      playlist_thumbnail = HelperExtractors.get_thumbnails(item_contents)

      YouTubeStructs::PlaylistRenderer.new({
        title:       title,
        id:          plid,
        author:      author_fallback.name,
        ucid:        author_fallback.id,
        video_count: video_count,
        videos:      [] of YouTubeStructs::PlaylistVideoRenderer,
        thumbnail:   playlist_thumbnail,
      })
    end
  end

  # Parses a InnerTube playlistRenderer into a YouTubeStructs::PlaylistRenderer. Returns nil when the given object isn't a playlistRenderer
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
        return self.parse(item_contents)
      end
    end

    private def self.parse(item_contents)
      title = item_contents["title"]["simpleText"]?.try &.as_s || ""
      plid = item_contents["playlistId"]?.try &.as_s || ""

      video_count = HelperExtractors.get_video_count(item_contents)
      playlist_thumbnail = HelperExtractors.get_thumbnails_plural(item_contents)

      author_info = item_contents.dig("shortBylineText", "runs", 0)
      author = author_info["text"].as_s
      author_id = HelperExtractors.get_browse_id(author_info)

      videos = item_contents["videos"]?.try &.as_a.map do |v|
        v = v["childVideoRenderer"]
        v_title = v.dig?("title", "simpleText").try &.as_s || ""
        v_id = v["videoId"]?.try &.as_s || ""
        v_length_seconds = v.dig?("lengthText", "simpleText").try { |t| decode_length_seconds(t.as_s) } || 0
        YouTubeStructs::PlaylistVideoRenderer.new(
          title: v_title,
          id: v_id,
          length_seconds: v_length_seconds,
        )
      end || [] of YouTubeStructs::PlaylistVideoRenderer

      # TODO: item_contents["publishedTimeText"]?

      YouTubeStructs::PlaylistRenderer.new({
        title:       title,
        id:          plid,
        author:      author,
        ucid:        author_id,
        video_count: video_count,
        videos:      videos,
        thumbnail:   playlist_thumbnail,
      })
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
      contents = [] of YouTubeStructs::Renderer

      # Content could be in three locations.
      if content_container = item_contents["content"]["horizontalListRenderer"]?
      elsif content_container = item_contents["content"]["expandedShelfContentsRenderer"]?
      elsif content_container = item_contents["content"]["verticalListRenderer"]?
      else
        content_container = item_contents["contents"]
      end

      raw_contents = content_container["items"].as_a
      raw_contents.each do |item|
        result = extract_item(item)
        if !result.nil?
          contents << result
        end
      end

      YouTubeStructs::Category.new({
        title:            title,
        contents:         contents,
        description_html: description_html,
        url:              url,
        badges:           badges,
      })
    end
  end

  # Parses a InnerTube backstagePostThreadRenderer into a CommunityPost.
  # Returns nil when the given object isn't a backstagePostThreadRenderer
  #
  # A backstagePostThreadRenderer represents a community post, including all of it's attachments, metadata, contents,
  # etc.
  #
  # See spec for example
  #
  # `backstagePostThreadRenderer` can only be found in a channel's community or discussion tab.
  module BackstagePostThreadRendererParser
    def self.process(item, author_fallback)
      if item_contents = item["backstagePostThreadRenderer"]?
        return self.parse(item_contents["post"]["backstagePostRenderer"])
      end
    end

    def self.parse(item_contents)
      post_id = item_contents["postId"].as_s

      author_name = item_contents.dig("authorText", "runs", 0, "text").as_s
      author_id = item_contents.dig("authorEndpoint", "browseEndpoint", "browseId").as_s
      author_thumbnail = item_contents.dig("authorThumbnail", "thumbnails", -1, "url").as_s # last item is highest quality

      contents = String.build do |content_text|
        item_contents["contentText"]["runs"].as_a.each { |t| content_text << t["text"] }
      end

      attachment_container = item_contents["backstageAttachment"]?

      case attachment_container
      when nil
        attachment = nil
      when .[]?("backstageImageRenderer")
        attachment = attachment_container.dig("backstageImageRenderer", "image", "thumbnails", -1, "url").as_s
      when .[]?("pollRenderer")
        container = attachment_container.dig("pollRenderer")

        choices = container["choices"].as_a.map { |i| i["text"]["runs"][0]["text"].as_s }
        votes = short_text_to_number(container["totalVotes"]["simpleText"].as_s.split(" ")[0])
        attachment = YouTubeStructs::CommunityPoll.new({choices: choices, total_votes: votes})
      else
        attachment = extract_item(attachment_container)
        raise "Unreachable" if !attachment.is_a?(YouTubeStructs::VideoRenderer | YouTubeStructs::PlaylistRenderer)
      end

      likes = short_text_to_number(item_contents["voteCount"]["simpleText"].as_s.split(" ")[0]) # Youtube doesn't provide dislikes...
      published = item_contents["publishedTimeText"]?.try &.["simpleText"]?.try { |t| decode_date(t.as_s) } || Time.local

      YouTubeStructs::CommunityPost.new({
        author:           author_name,
        author_id:        author_id,
        author_thumbnail: author_thumbnail,

        post_id:    post_id,
        contents:   contents,
        attachment: attachment,
        likes:      likes,
        published:  published,
      })
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
  #       "selected": true,
  #       "content": {...},
  #       ...
  #     }}
  #   ]}
  # }]
  #
  module YouTubeTabs
    def self.process(initial_data : Hash(String, JSON::Any))
      if target = initial_data["twoColumnBrowseResultsRenderer"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      raw_items = [] of JSON::Any
      selected_tab = extract_selected_tab(target["tabs"])
      content = selected_tab["content"]

      content["sectionListRenderer"]["contents"].as_a.each do |renderer_container|
        renderer_container = renderer_container["itemSectionRenderer"]

        # For some odd reason every YT tab request *except* community tabs
        # has only one item (the renderer contents array) in the contents array of
        # `renderer_container`. For community tabs, this `renderer_container` is the
        #  just the array of contents. Strange.
        if selected_tab["title"] == "Community"
          return renderer_container["contents"].as_a
        end

        renderer_container_contents = renderer_container["contents"].as_a[0]
        # Category extraction
        if items_container = renderer_container_contents["shelfRenderer"]?
          raw_items << renderer_container_contents
          next
        elsif items_container = renderer_container_contents["gridRenderer"]?
        else
          items_container = renderer_container_contents
        end

        items_container["items"].as_a.each do |item|
          raw_items << item
        end
      end

      return raw_items
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
    def self.process(initial_data : Hash(String, JSON::Any))
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
  module Continuation
    def self.process(initial_data : Hash(String, JSON::Any))
      if target = initial_data["continuationContents"]?
        self.extract(target)
      elsif target = initial_data["appendContinuationItemsAction"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      raw_items = [] of JSON::Any
      if content = target["gridContinuation"]?
        raw_items = content["items"].as_a
      elsif content = target["continuationItems"]?
        raw_items = content.as_a
      end

      return raw_items
    end
  end
end

# Helper methods to aid in the parsing of InnerTube to data structs.
#
# Mostly used to extract out repeated structures to deal with code
# repetition.
private module HelperExtractors
  # Retrieves the amount of videos present within the given InnerTube data.
  #
  # Returns a 0 when it's unable to do so
  def self.get_video_count(container : JSON::Any) : Int32
    if box = container["videoCountText"]?
      return extract_text(box).try &.gsub(/\D/, "").to_i || 0
    elsif box = container["videoCount"]?
      return box.as_s.to_i
    else
      return 0
    end
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

# Extracts text from InnerTube response
#
# InnerTube can package text in three different formats
# "runs": [
# {"text": "something"},
# {"text": "cont"},
# ...
# ]
#
# "SimpleText": "something"
#
# Or sometimes just none at all as with the data returned from
# category continuations.
#
# In order to facilitate calling this function with `#[]?`:
# A nil will be accepted. Of course, since nil cannot be parsed,
# another nil will be returned.
def extract_text(item : JSON::Any?) : String?
  if item.nil?
    return nil
  end

  if text_container = item["simpleText"]?
    return text_container.as_s
  elsif text_container = item["runs"]?
    return text_container.as_a.map(&.["text"].as_s).join("")
  else
    nil
  end
end

# Parses an item from Youtube's JSON response into a more usable structure.
# The end result can either be a SearchVideo, SearchPlaylist or SearchChannel.
def extract_item(item : JSON::Any, author_fallback : String? = "",
                 author_id_fallback : String? = "")
  # We "allow" nil values but secretly use empty strings instead. This is to save us the
  # hassle of modifying every author_fallback and author_id_fallback arg usage
  # which is more often than not nil.
  author_fallback = AuthorFallback.new(author_fallback || "", author_id_fallback || "")

  # Cycles through all of the item parsers and attempt to parse the raw YT JSON data.
  # Each parser automatically validates the data given to see if the data is
  # applicable to itself. If not nil is returned and the next parser is attemped.
  ITEM_PARSERS.each do |parser|
    if result = parser.process(item, author_fallback)
      return result
    end
  end
end

# Parses multiple items from YouTube's initial JSON response into a more usable structure.
# The end result is an array of YouTubeStructs::Renderer.
def extract_items(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil,
                  author_id_fallback : String? = nil) : Array(YouTubeStructs::Renderer)
  items = [] of YouTubeStructs::Renderer

  if unpackaged_data = initial_data["contents"]?.try &.as_h
  elsif unpackaged_data = initial_data["response"]?.try &.as_h
  elsif unpackaged_data = initial_data.dig?("onResponseReceivedActions", 0).try &.as_h
  else
    unpackaged_data = initial_data
  end

  # This is identical to the parser cycling of extract_item().
  ITEM_CONTAINER_EXTRACTOR.each do |extractor|
    if container = extractor.process(unpackaged_data)
      # Extract items in container
      container.each do |item|
        if parsed_result = extract_item(item, author_fallback, author_id_fallback)
          items << parsed_result
        end
      end

      break
    end
  end

  return items
end

# Extracts videos (videoRenderer) from initial InnerTube response.
def extract_videos(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  extracted = extract_items(initial_data, author_fallback, author_id_fallback)

  target = [] of YouTubeStructs::Renderer
  extracted.each do |i|
    if i.is_a?(YouTubeStructs::Category)
      target += i.extract_renderers
    else
      target << i
    end
  end

  return target.select(&.is_a?(YouTubeStructs::VideoRenderer)).map(&.as(YouTubeStructs::VideoRenderer))
end

# Extract the selected tab from the array of tabs YouTube returns
def extract_selected_tab(tabs)
  return selected_target = tabs.as_a.select(&.["tabRenderer"]?.try &.["selected"].as_bool)[0]["tabRenderer"]
end
