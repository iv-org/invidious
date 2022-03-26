class ChannelSearchException < InfoException
  getter channel : String

  def initialize(@channel)
  end
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
  # Parse legacy query
  filters, channel, search_query, subscriptions = Invidious::Search::Filters.from_legacy_filters(query)

  if !channel.nil? && !channel.empty?
    items = Invidious::Search::Processors.channel(search_query, page, channel)
  elsif subscriptions
    if user
      user = user.as(Invidious::User)
      items = Invidious::Search::Processors.subscriptions(query, page, user)
    else
      items = [] of ChannelVideo
    end
  else
    search_params = filters.to_yt_params(page: page)
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

  {search_query, items_without_category, filters}
end
