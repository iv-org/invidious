def fetch_channel_playlists(ucid, author, continuation, sort_by)
  if continuation
    response_json = YoutubeAPI.browse(continuation)
    continuation_items = response_json["onResponseReceivedActions"]?
      .try &.[0]["appendContinuationItemsAction"]["continuationItems"]

    return [] of SearchItem, nil if !continuation_items

    items = [] of SearchItem
    continuation_items.as_a.select(&.as_h.has_key?("gridPlaylistRenderer")).each { |item|
      extract_item(item, author, ucid).try { |t| items << t }
    }

    continuation = continuation_items.as_a.last["continuationItemRenderer"]?
      .try &.["continuationEndpoint"]["continuationCommand"]["token"].as_s
  else
    url = "/channel/#{ucid}/playlists?flow=list&view=1"

    case sort_by
    when "last", "last_added"
      #
    when "oldest", "oldest_created"
      url += "&sort=da"
    when "newest", "newest_created"
      url += "&sort=dd"
    else nil # Ignore
    end

    response = YT_POOL.client &.get(url)
    initial_data = extract_initial_data(response.body)
    return [] of SearchItem, nil if !initial_data

    items = extract_items(initial_data, author, ucid)
    continuation = response.body.match(/"token":"(?<continuation>[^"]+)"/).try &.["continuation"]?
  end

  return items, continuation
end

# ## NOTE: DEPRECATED
# Reason -> Unstable
# The Protobuf object must be provided with an id of the last playlist from the current "page"
# in order to fetch the next one accurately
# (if the id isn't included, entries shift around erratically between pages,
# leading to repetitions and skip overs)
#
# Since it's impossible to produce the appropriate Protobuf without an id being provided by the user,
# it's better to stick to continuation tokens provided by the first request and onward
def produce_channel_playlists_url(ucid, cursor, sort = "newest", auto_generated = false)
  object = {
    "80226972:embedded" => {
      "2:string" => ucid,
      "3:base64" => {
        "2:string"  => "playlists",
        "6:varint"  => 2_i64,
        "7:varint"  => 1_i64,
        "12:varint" => 1_i64,
        "13:string" => "",
        "23:varint" => 0_i64,
      },
    },
  }

  if cursor
    cursor = Base64.urlsafe_encode(cursor, false) if !auto_generated
    object["80226972:embedded"]["3:base64"].as(Hash)["15:string"] = cursor
  end

  if auto_generated
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 0x32_i64
  else
    object["80226972:embedded"]["3:base64"].as(Hash)["4:varint"] = 1_i64
    case sort
    when "oldest", "oldest_created"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 2_i64
    when "newest", "newest_created"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 3_i64
    when "last", "last_added"
      object["80226972:embedded"]["3:base64"].as(Hash)["3:varint"] = 4_i64
    else nil # Ignore
    end
  end

  object["80226972:embedded"]["3:string"] = Base64.urlsafe_encode(Protodec::Any.from_json(Protodec::Any.cast_json(object["80226972:embedded"]["3:base64"])))
  object["80226972:embedded"].delete("3:base64")

  continuation = object.try { |i| Protodec::Any.cast_json(i) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return "/browse_ajax?continuation=#{continuation}&gl=US&hl=en"
end
