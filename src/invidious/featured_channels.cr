struct FeaturedChannel
  include DB::Serializable

  property author : String
  property ucid : String
  property author_thumbnail : String
  property subscriber_count : Int32
  property video_count : Int32
  property description_html : String?

  def to_json(locale, json : JSON::Builder)
    json.object do
      json.field "author", self.author
      json.field "authorId", self.ucid
      json.field "authorUrl", "/channel/#{self.ucid}"
      json.field "authorThumbnails" do
        json.array do
          qualities = {32, 48, 76, 100, 176, 512}

          qualities.each do |quality|
            json.object do
              json.field "url", self.author_thumbnail.gsub(/=\d+/, "=s#{quality}")
              json.field "width", quality
              json.field "height", quality
            end
          end
        end
      end

      json.field "description", html_to_content(self.description_html)
      json.field "descriptionHtml", self.description_html
      json.field "subCount", self.subscriber_count
      json.field "videoCount", self.video_count
      json.field "badges", self.badges
    end
  end

  def to_json(locale, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, json)
    else
      JSON.build do |json|
        to_json(locale, json)
      end
    end
  end
end

struct Category
  include DB::Serializable

  property title : String
  property contents : Array(FeaturedChannel) | FeaturedChannel
  property browse_endpoint_param : String?
  property continuation_token : String?

  def to_json(locale, json : JSON::Builder)
    json.object do
      json.field "title", self.title
      json.field "contents", self.contents
    end
  end

  def to_json(locale, json : JSON::Builder | Nil = nil)
    if json
      to_json(locale, json)
    else
      JSON.build do |json|
        to_json(locale, json)
      end
    end
  end
end

def _extract_channel_data(channel)
  ucid = channel["channelId"].as_s
  author = channel["title"]["simpleText"].as_s
  author_thumbnail = channel["thumbnail"]["thumbnails"].as_a[0]["url"].as_s
  subscriber_count = channel["subscriberCountText"]?.try &.["simpleText"]?.try &.as_s?
    .try { |text| short_text_to_number(text.split(" ")[0]) } || 0

  video_count = channel["videoCountText"]?.try &.["runs"][0]["text"].as_s.gsub(/\D/, "").to_i || 0

  if channel["descriptionSnippet"]?
    description = channel["descriptionSnippet"]["runs"][0]["text"].as_s
    description_html = HTML.escape(description).gsub("\n", "")
  else
    description_html = nil
  end

  FeaturedChannel.new({
    author: author,
    ucid: ucid,
    author_thumbnail: author_thumbnail,
    subscriber_count: subscriber_count,
    video_count: video_count,
    description_html: description_html
  })
end

def process_featured_channels(data, submenu_data, title=nil, continuation_items=false)
  all_categories = [] of Category

  if submenu_data.is_a?(Bool)
    return all_categories
  end

  # Extraction process differs when there's more than one category
  if data.size > 1
    data.each do |raw_category|
      raw_category = raw_category["itemSectionRenderer"]["contents"].as_a[0]["shelfRenderer"]

      category_title = raw_category["title"]["runs"][0]["text"].as_s
      browse_endpoint_param = raw_category["endpoint"]["browseEndpoint"]["params"].as_s

      # Category has multiple channels
      if raw_category["content"].as_h.has_key?("horizontalListRenderer")
        contents = [] of FeaturedChannel
        raw_category["content"]["horizontalListRenderer"]["items"].as_a.each do |channel|
          contents << _extract_channel_data(channel["gridChannelRenderer"])
        end
      # Single channel
      else
        channel = raw_category["content"]["expandedShelfContentsRenderer"]["items"][0]["channelRenderer"]
        contents = _extract_channel_data(channel)
      end

      all_categories << Category.new({
        title: category_title,
        contents: contents,
        browse_endpoint_param: browse_endpoint_param,
        continuation_token: nil
      })
    end
  else
    if !continuation_items
      raw_category_contents = data[0]["itemSectionRenderer"]["contents"].as_a[0]["gridRenderer"]["items"].as_a
    else
      raw_category_contents = data[0].as_a
    end

    category_title = submenu_data.try &.[0]["title"].as_s || title || ""

    browse_endpoint_param = nil # Not needed
    continuation_token = nil

    # If a continuation token is needed it'll always be after at least twelve channels
    if raw_category_contents.size > 12
      continuation_token = raw_category_contents[-1]["continuationItemRenderer"]?.try &.["continuationEndpoint"]["continuationCommand"]["token"].as_s || nil

      if !continuation_token.nil?
        raw_category_contents = raw_category_contents[0..-2]
      end
    end

    contents = [] of FeaturedChannel
    raw_category_contents.each do |channel|
      contents << _extract_channel_data(channel["gridChannelRenderer"])
    end

    all_categories << Category.new({
      title: category_title,
      contents: contents,
      browse_endpoint_param: browse_endpoint_param,
      continuation_token: continuation_token
    })
  end

  return all_categories
end
