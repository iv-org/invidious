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
}

record AuthorFallback, name : String? = nil, id : String? = nil

# The following are the parsers for parsing raw item data into neatly packaged structs.
# They're accessed through the process() method which validates the given data as applicable
# to their specific struct and then use the internal parse() method to assemble the struct
# specific to their category.
private module Parsers
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
      author_info = item_contents["ownerText"]?.try &.["runs"]?.try &.as_a?.try &.[0]?
      if author_info = item_contents.dig?("ownerText", "runs")
        author_info = author_info[0]
        author = author_info["text"].as_s
        author_id = HelperExtractors.get_browse_endpoint(author_info)
      else
        author = author_fallback.name || ""
        author_id = author_fallback.id || ""
      end

      # For live videos (and possibly recently premiered videos) there is no published information.
      # Instead, in its place is the amount of people currently watching. This behavior should be replicated
      # on Invidious once all features of livestreams are supported. On an unrelated note, defaulting to the current
      # time for publishing isn't a good idea.
      published = item_contents["publishedTimeText"]?.try &.["simpleText"].try { |t| decode_date(t.as_s) } || Time.local

      # Typically views are stored under a "simpleText" in the "viewCountText". However, for
      # livestreams and premiered it is stored under a "runs" array: [{"text":123}, {"text": "watching"}]
      # When view count is disabled the "viewCountText" is not present on InnerTube data.
      # TODO change default value to nil and typical encoding type to tuple storing type (watchers, views, etc)
      # and count
      view_count = item_contents.dig?("viewCountText", "simpleText").try &.as_s.gsub(/\D+/, "").to_i64? || 0_i64
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
      })
    end
  end

  module ChannelRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = (item["channelRenderer"]? || item["gridChannelRenderer"]?)
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      author = extract_text(item_contents["title"]) || author_fallback.name || ""
      author_id = item_contents["channelId"]?.try &.as_s || author_fallback.id || ""

      author_thumbnail = HelperExtractors.get_thumbnails(item_contents)
      # When public subscriber count is disabled, the subscriberCountText isn't sent by InnerTube.
      # TODO change default value to nil
      subscriber_count = item_contents.dig?("subscriberCountText").try &.["simpleText"].try { |s| short_text_to_number(s.as_s.split(" ")[0]) } || 0

      auto_generated = !item_contents["videoCountText"]? ? true : false

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
      })
    end
  end

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

      SearchPlaylist.new({
        title:       title,
        id:          plid,
        author:      author_fallback.name || "",
        ucid:        author_fallback.id || "",
        video_count: video_count,
        videos:      [] of SearchPlaylistVideo,
        thumbnail:   playlist_thumbnail,
      })
    end
  end

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
      author_id = HelperExtractors.get_browse_endpoint(author_info)

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

  module CategoryRendererParser
    def self.process(item : JSON::Any, author_fallback : AuthorFallback)
      if item_contents = item["shelfRenderer"]?
        return self.parse(item_contents, author_fallback)
      end
    end

    private def self.parse(item_contents, author_fallback)
      title = extract_text(item_contents["title"]?) || ""
      url = item_contents["endpoint"]?.try &.dig("commandMetadata", "webCommandMetadata", "url").as_s

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

      Category.new({
        title:            title,
        contents:         contents,
        description_html: description_html,
        url:              url,
        badges:           badges,
      })
    end
  end
end

# The following are the extractors for extracting an array of items from
# the internal Youtube API's JSON response. The result is then packaged into
# a structure we can more easily use via the parsers above. Their internals are
# identical to the item parsers.
private module Extractors
  module YouTubeTabs
    def self.process(initial_data : Hash(String, JSON::Any))
      if target = initial_data["twoColumnBrowseResultsRenderer"]?
        self.extract(target)
      end
    end

    private def self.extract(target)
      raw_items = [] of JSON::Any
      content = extract_selected_tab(target["tabs"])["content"]

      content["sectionListRenderer"]["contents"].as_a.each do |renderer_container|
        renderer_container_contents = renderer_container["itemSectionRenderer"]["contents"].as_a[0]

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

# Helper methods to extract out certain stuff from InnerTube
private module HelperExtractors
  # Retrieves the amount of videos present within the given InnerTube data.
  #
  # Returns a 0 when it's unable to do so
  def self.get_video_count(container : JSON::Any) : Int32
    if box = container["videoCountText"]?
      return extract_text(container["videoCountText"]?).try &.gsub(/\D/, "").to_i || 0
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
  # YouTube sometimes sends the thumbnail as:
  # {"thumbnails": [{"thumbnails": [{"url": "example.com"}, ...]}]}
  def self.get_thumbnails_plural(container : JSON::Any) : String
    return container.dig("thumbnails", 0, "thumbnails", 0, "url").as_s
  end

  # Retrieves the ID required for querying the InnerTube browse endpoint
  #
  # Raises when it's unable to do so
  def self.get_browse_endpoint(container)
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
def extract_item(item : JSON::Any, author_fallback : String? = nil,
                 author_id_fallback : String? = nil)
  author_fallback = AuthorFallback.new(author_fallback, author_id_fallback)

  # Cycles through all of the item parsers and attempt to parse the raw YT JSON data.
  # Each parser automatically validates the data given to see if the data is
  # applicable to itself. If not nil is returned and the next parser is attemped.
  ITEM_PARSERS.each do |parser|
    result = parser.process(item, author_fallback)
    if !result.nil?
      return result
    end
  end
  # TODO radioRenderer, showRenderer, shelfRenderer, horizontalCardListRenderer, searchPyvRenderer
end

# Parses multiple items from Youtube's initial JSON response into a more usable structure.
# The end result is an array of SearchItem.
def extract_items(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil,
                  author_id_fallback : String? = nil) : Array(SearchItem)
  items = [] of SearchItem

  if unpackaged_data = initial_data["contents"]?.try &.as_h
  elsif unpackaged_data = initial_data["response"]?.try &.as_h
  elsif unpackaged_data = initial_data["onResponseReceivedActions"]?.try &.as_a.[0].as_h
  else
    unpackaged_data = initial_data
  end

  # This is identicial to the parser cyling of extract_item().
  ITEM_CONTAINER_EXTRACTOR.each do |extractor|
    results = extractor.process(unpackaged_data)
    if !results.nil?
      results.each do |item|
        parsed_result = extract_item(item, author_fallback, author_id_fallback)

        if !parsed_result.nil?
          items << parsed_result
        end
      end
      return items
    end
  end

  return items
end
