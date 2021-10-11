def fetch_continuation_token(items : Array(JSON::Any))
  # Fetches the continuation token from an array of items
  return items.last["continuationItemRenderer"]?
    .try &.["continuationEndpoint"]["continuationCommand"]["token"].as_s
end

def fetch_continuation_token(initial_data : Hash(String, JSON::Any))
  # Fetches the continuation token from initial data
  if initial_data["onResponseReceivedActions"]?
    continuation_items = initial_data["onResponseReceivedActions"][0]["appendContinuationItemsAction"]["continuationItems"]
  else
    tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])
    continuation_items = tab["content"]["sectionListRenderer"]["contents"][0]["itemSectionRenderer"]["contents"][0]["gridRenderer"]["items"]
  end

  return fetch_continuation_token(continuation_items.as_a)
end
