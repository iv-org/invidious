def fetch_channel_playlists(ucid, author, continuation, sort_by)
  if continuation
    response_json = request_youtube_api_browse(continuation)
    continuationItems = response_json["onResponseReceivedActions"]?
      .try &.[0]["appendContinuationItemsAction"]["continuationItems"]

    return [] of SearchItem, nil if !continuationItems

    items = [] of SearchItem
    continuationItems.as_a.select(&.as_h.has_key?("gridPlaylistRenderer")).each { |item|
      extract_item(item, author, ucid).try { |t| items << t }
    }

    continuation = continuationItems.as_a.last["continuationItemRenderer"]?
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
