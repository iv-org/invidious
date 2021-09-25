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

def extract_videos(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil)
  extracted = extract_items(initial_data, author_fallback, author_id_fallback)

  target = [] of SearchItem
  extracted.each do |i|
    if i.is_a?(Category)
      i.contents.each { |cate_i| target << cate_i if !cate_i.is_a? Video }
    else
      target << i
    end
  end
  return target.select(SearchVideo).map(&.as(SearchVideo))
end

def extract_selected_tab(tabs)
  # Extract the selected tab from the array of tabs Youtube returns
  return selected_target = tabs.as_a.select(&.["tabRenderer"]?.try &.["selected"].as_bool)[0]["tabRenderer"]
end

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
