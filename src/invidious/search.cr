class ChannelSearchException < InfoException
  getter channel : String

  def initialize(@channel)
  end
end

def search(query, search_params = produce_search_params(content_type: "all"), region = nil) : Array(SearchItem)
  return [] of SearchItem if query.empty?

  client_config = YoutubeAPI::ClientConfig.new(region: region)
  initial_data = YoutubeAPI.search(query, search_params, client_config: client_config)

  return extract_items(initial_data)
end

def produce_search_params(page = 1, sort : String = "relevance", date : String = "", content_type : String = "",
                          duration : String = "", features : Array(String) = [] of String)
  object = {
    "1:varint"   => 0_i64,
    "2:embedded" => {} of String => Int64,
    "9:varint"   => ((page - 1) * 20).to_i64,
  }

  case sort
  when "relevance"
    object["1:varint"] = 0_i64
  when "rating"
    object["1:varint"] = 1_i64
  when "upload_date", "date"
    object["1:varint"] = 2_i64
  when "view_count", "views"
    object["1:varint"] = 3_i64
  else
    raise "No sort #{sort}"
  end

  case date
  when "hour"
    object["2:embedded"].as(Hash)["1:varint"] = 1_i64
  when "today"
    object["2:embedded"].as(Hash)["1:varint"] = 2_i64
  when "week"
    object["2:embedded"].as(Hash)["1:varint"] = 3_i64
  when "month"
    object["2:embedded"].as(Hash)["1:varint"] = 4_i64
  when "year"
    object["2:embedded"].as(Hash)["1:varint"] = 5_i64
  else nil # Ignore
  end

  case content_type
  when "video"
    object["2:embedded"].as(Hash)["2:varint"] = 1_i64
  when "channel"
    object["2:embedded"].as(Hash)["2:varint"] = 2_i64
  when "playlist"
    object["2:embedded"].as(Hash)["2:varint"] = 3_i64
  when "movie"
    object["2:embedded"].as(Hash)["2:varint"] = 4_i64
  when "show"
    object["2:embedded"].as(Hash)["2:varint"] = 5_i64
  when "all"
    #
  else
    object["2:embedded"].as(Hash)["2:varint"] = 1_i64
  end

  case duration
  when "short"
    object["2:embedded"].as(Hash)["3:varint"] = 1_i64
  when "long"
    object["2:embedded"].as(Hash)["3:varint"] = 2_i64
  else nil # Ignore
  end

  features.each do |feature|
    case feature
    when "hd"
      object["2:embedded"].as(Hash)["4:varint"] = 1_i64
    when "subtitles"
      object["2:embedded"].as(Hash)["5:varint"] = 1_i64
    when "creative_commons", "cc"
      object["2:embedded"].as(Hash)["6:varint"] = 1_i64
    when "3d"
      object["2:embedded"].as(Hash)["7:varint"] = 1_i64
    when "live", "livestream"
      object["2:embedded"].as(Hash)["8:varint"] = 1_i64
    when "purchased"
      object["2:embedded"].as(Hash)["9:varint"] = 1_i64
    when "4k"
      object["2:embedded"].as(Hash)["14:varint"] = 1_i64
    when "360"
      object["2:embedded"].as(Hash)["15:varint"] = 1_i64
    when "location"
      object["2:embedded"].as(Hash)["23:varint"] = 1_i64
    when "hdr"
      object["2:embedded"].as(Hash)["25:varint"] = 1_i64
    else nil # Ignore
    end
  end

  if object["2:embedded"].as(Hash).empty?
    object.delete("2:embedded")
  end

  params = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return params
end

def produce_channel_search_continuation(ucid, query, page)
  if page <= 1
    idx = 0_i64
  else
    idx = 30_i64 * (page - 1)
  end

  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "search",
        "6:varint"  => 1_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "15:base64" => {
          "3:varint" => idx,
        },
        "23:varint" => 0_i64,
      },
      "11:string" => query,
      "35:string" => "browse-feed#{ucid}search",
    },
  }

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return continuation
end

def process_search_query(query, page, user, region)
  channel = nil
  content_type = "all"
  date = ""
  duration = ""
  features = [] of String
  sort = "relevance"
  subscriptions = nil

  operators = query.split(" ").select(&.match(/\w+:[\w,]+/))
  operators.each do |operator|
    key, value = operator.downcase.split(":")

    case key
    when "channel", "user"
      channel = operator.split(":")[-1]
    when "content_type", "type"
      content_type = value
    when "date"
      date = value
    when "duration"
      duration = value
    when "feature", "features"
      features = value.split(",")
    when "sort"
      sort = value
    when "subscriptions"
      subscriptions = value == "true"
    else
      operators.delete(operator)
    end
  end

  search_query = (query.split(" ") - operators).join(" ")

  if channel
    items = Invidious::Search::Processors.channel(search_query, page, channel)
  elsif subscriptions
    if user
      user = user.as(Invidious::User)
      items = Invidious::Search::Processors.subscriptions(query, page, user)
    else
      items = [] of ChannelVideo
    end
  else
    search_params = produce_search_params(page: page, sort: sort, date: date, content_type: content_type,
      duration: duration, features: features)

    items = search(search_query, search_params, region)
  end

  # Light processing to flatten search results out of Categories.
  # They should ideally be supported in the future.
  items_without_category = [] of SearchItem | ChannelVideo
  items.each do |i|
    if i.is_a? Category
      i.contents.each do |nest_i|
        if !nest_i.is_a? Video
          items_without_category << nest_i
        end
      end
    else
      items_without_category << i
    end
  end

  {search_query, items_without_category, operators}
end
