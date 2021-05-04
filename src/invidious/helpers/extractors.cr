# This file contains helper methods to parse the Youtube API json data into 
# neat little packages we can use

# Tuple of Parsers/Extractors so we can easily cycle through them.
private ITEM_CONTAINER_EXTRACTOR = {
  YoutubeTabsExtractor.new,
  SearchResultsExtractor.new,
  ContinuationExtractor.new
}

private ITEM_PARSERS = {
  VideoParser.new,
  ChannelParser.new,
  GridPlaylistParser.new,
  PlaylistParser.new,
}

private struct AuthorFallback
  property name, id

  def initialize(@name : String? = nil, @id : String? = nil)
  end
end

# The following are the parsers for parsing raw item data into neatly packaged structs.
# They're accessed through the process() method which validates the given data as applicable
# to their specific struct and then use the internal parse() method to assemble the struct
# specific to their category.
private class ItemParser
  # Base type for all item parsers.
  def process(item : JSON::Any, author_fallback : AuthorFallback)
  end

  private def parse(item_contents : JSON::Any, author_fallback : AuthorFallback)
  end
end 

private class VideoParser < ItemParser
  def process(item, author_fallback)
    if item_contents = (item["videoRenderer"]? || item["gridVideoRenderer"]?)
      return self.parse(item_contents, author_fallback)
    end
  end

  private def parse(item_contents, author_fallback)
    video_id = item_contents["videoId"].as_s
    title = item_contents["title"].try { |t| t["simpleText"]?.try &.as_s || t["runs"]?.try &.as_a.map(&.["text"].as_s).join("") } || ""

    author_info = item_contents["ownerText"]?.try &.["runs"]?.try &.as_a?.try &.[0]?
    author = author_info.try &.["text"].as_s || author_fallback.name || ""
    author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_fallback.id || ""

    published = item_contents["publishedTimeText"]?.try &.["simpleText"]?.try { |t| decode_date(t.as_s) } || Time.local
    view_count = item_contents["viewCountText"]?.try &.["simpleText"]?.try &.as_s.gsub(/\D+/, "").to_i64? || 0_i64
    description_html = item_contents["descriptionSnippet"]?.try { |t| parse_content(t) } || ""
    length_seconds = item_contents["lengthText"]?.try &.["simpleText"]?.try &.as_s.try { |t| decode_length_seconds(t) } ||
                     item_contents["thumbnailOverlays"]?.try &.as_a.find(&.["thumbnailOverlayTimeStatusRenderer"]?).try &.["thumbnailOverlayTimeStatusRenderer"]?
                       .try &.["text"]?.try &.["simpleText"]?.try &.as_s.try { |t| decode_length_seconds(t) } || 0

    live_now = false
    paid = false
    premium = false

    premiere_timestamp = item_contents["upcomingEventData"]?.try &.["startTime"]?.try { |t| Time.unix(t.as_s.to_i64) }

    item_contents["badges"]?.try &.as_a.each do |badge|
      b = badge["metadataBadgeRenderer"]
      case b["label"].as_s
      when "LIVE NOW"
        live_now = true
      when "New", "4K", "CC"
        # TODO
      when "Premium"
        paid = true

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
      paid:               paid,
      premium:            premium,
      premiere_timestamp: premiere_timestamp,
    })
  end
end

private class ChannelParser < ItemParser
  def process(item, author_fallback)
    if item_contents = item["channelRenderer"]?
      return self.parse(item_contents, author_fallback)
    end
  end

  private def parse(item_contents, author_fallback)
    author = item_contents["title"]["simpleText"]?.try &.as_s || author_fallback.name || ""
    author_id = item_contents["channelId"]?.try &.as_s || author_fallback.id || ""

    author_thumbnail = item_contents["thumbnail"]["thumbnails"]?.try &.as_a[0]?.try &.["url"]?.try &.as_s || ""
    subscriber_count = item_contents["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s.try { |s| short_text_to_number(s.split(" ")[0]) } || 0

    auto_generated = false
    auto_generated = true if !item_contents["videoCountText"]?
    video_count = item_contents["videoCountText"]?.try &.["runs"].as_a[0]?.try &.["text"].as_s.gsub(/\D/, "").to_i || 0
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

private class GridPlaylistParser < ItemParser
  def process(item, author_fallback)
    if item_contents = item["gridPlaylistRenderer"]?
      return self.parse(item_contents, author_fallback)
    end
  end

  private def parse(item_contents, author_fallback)
    title = item_contents["title"]["runs"].as_a[0]?.try &.["text"].as_s || ""
    plid = item_contents["playlistId"]?.try &.as_s || ""

    video_count = item_contents["videoCountText"]["runs"].as_a[0]?.try &.["text"].as_s.gsub(/\D/, "").to_i || 0
    playlist_thumbnail = item_contents["thumbnail"]["thumbnails"][0]?.try &.["url"]?.try &.as_s || ""

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

private class PlaylistParser < ItemParser
  def process(item, author_fallback)
    if item_contents = item["playlistRenderer"]?
      return self.parse(item_contents, author_fallback)
    end
  end

  def parse(item_contents, author_fallback)
    title = item_contents["title"]["simpleText"]?.try &.as_s || ""
    plid = item_contents["playlistId"]?.try &.as_s || ""

    video_count = item_contents["videoCount"]?.try &.as_s.to_i || 0
    playlist_thumbnail = item_contents["thumbnails"].as_a[0]?.try &.["thumbnails"]?.try &.as_a[0]?.try &.["url"].as_s || ""

    author_info = item_contents["shortBylineText"]?.try &.["runs"]?.try &.as_a?.try &.[0]?
    author = author_info.try &.["text"].as_s || author_fallback.name || ""
    author_id = author_info.try &.["navigationEndpoint"]?.try &.["browseEndpoint"]["browseId"].as_s || author_fallback.id || ""

    videos = item_contents["videos"]?.try &.as_a.map do |v|
      v = v["childVideoRenderer"]
      v_title = v["title"]["simpleText"]?.try &.as_s || ""
      v_id = v["videoId"]?.try &.as_s || ""
      v_length_seconds = v["lengthText"]?.try &.["simpleText"]?.try { |t| decode_length_seconds(t.as_s) } || 0
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

# The following are the extractors for extracting an array of items from 
# the internal Youtube API's JSON response. The result is then packaged into
# a structure we can more easily use via the parsers above. Their internals are
# identical to the item parsers.

private class ItemsContainerExtractor
  def process(item : Hash(String, JSON::Any))
  end

  private def extract(target : JSON::Any)
  end
end

private class YoutubeTabsExtractor < ItemsContainerExtractor
  def process(initial_data)
    if target = initial_data["twoColumnBrowseResultsRenderer"]?
      self.extract(target)
    end
  end

  private def extract(target)
    raw_items = [] of JSON::Any
    selected_tab = extract_selected_tab(target["tabs"])
    content = selected_tab["tabRenderer"]["content"]

    content["sectionListRenderer"]["contents"].as_a.each do | renderer_container |
      renderer_container = renderer_container["itemSectionRenderer"]
      renderer_container_contents = renderer_container["contents"].as_a[0]

      # Shelf renderer usually refer to a category and would need special handling once
      # An extractor for categories are added. But for now it is just used to 
      # extract items for the trending page
      if items_container = renderer_container_contents["shelfRenderer"]?
        if items_container["content"]["expandedShelfContentsRenderer"]?
           items_container = items_container["content"]["expandedShelfContentsRenderer"]
        end
      elsif items_container = renderer_container_contents["gridRenderer"]? 
      else
        items_container = renderer_container_contents
      end

      items_container["items"].as_a.each do | item |
        raw_items << item
      end
    end

    return raw_items
  end
end

private class SearchResultsExtractor < ItemsContainerExtractor
  def process(initial_data)
    if target = initial_data["twoColumnSearchResultsRenderer"]?
      self.extract(target)
    end
  end

  private def extract(target)
    raw_items = [] of JSON::Any
    content = target["primaryContents"]
    renderer = content["sectionListRenderer"]["contents"].as_a[0]["itemSectionRenderer"]
    raw_items = renderer["contents"].as_a

    return raw_items
  end
end

private class ContinuationExtractor < ItemsContainerExtractor
  def process(initial_data)
    if target = initial_data["continuationContents"]?
      self.extract(target)
    end
  end

  private def extract(target)
    raw_items = [] of JSON::Any
    if content = target["gridContinuation"]?
      raw_items = content["items"].as_a
    end

    return raw_items
  end
end

def extract_item(item : JSON::Any, author_fallback : String? = nil, author_id_fallback : String? = nil)
  # Parses an item from Youtube's JSON response into a more usable structure.
  # The end result can either be a SearchVideo, SearchPlaylist or SearchChannel.
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

def extract_items(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  items = [] of SearchItem
  initial_data = initial_data["contents"]?.try &.as_h  || initial_data["response"]?.try &.as_h || initial_data

  # This is identicial to the parser cyling of extract_item().
  ITEM_CONTAINER_EXTRACTOR.each do | extractor |
    results = extractor.process(initial_data)
    if !results.nil?
      results.each do | item |
        parsed_result = extract_item(item, author_fallback, author_id_fallback)

        if !parsed_result.nil?
          items << parsed_result
        end
      end
    end
  end

  return items
end