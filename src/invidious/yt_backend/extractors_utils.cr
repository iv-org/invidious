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

# Check if an "ownerBadges" or a "badges" element contains a verified badge.
# There is currently two known types of verified badges:
#
# "ownerBadges": [{
#   "metadataBadgeRenderer": {
#     "icon": { "iconType": "CHECK_CIRCLE_THICK" },
#     "style": "BADGE_STYLE_TYPE_VERIFIED",
#     "tooltip": "Verified",
#     "accessibilityData": { "label": "Verified" }
#    }
# }],
#
# "ownerBadges": [{
#   "metadataBadgeRenderer": {
#     "icon": { "iconType": "OFFICIAL_ARTIST_BADGE" },
#     "style": "BADGE_STYLE_TYPE_VERIFIED_ARTIST",
#     "tooltip": "Official Artist Channel",
#     "accessibilityData": { "label": "Official Artist Channel" }
#   }
# }],
#
def has_verified_badge?(badges : JSON::Any?)
  return false if badges.nil?

  badges.as_a.each do |badge|
    style = badge.dig("metadataBadgeRenderer", "style").as_s

    return true if style == "BADGE_STYLE_TYPE_VERIFIED"
    return true if style == "BADGE_STYLE_TYPE_VERIFIED_ARTIST"
  end

  return false
rescue ex
  LOGGER.debug("Unable to parse owner badges. Got exception: #{ex.message}")
  LOGGER.trace("Owner badges data: #{badges.to_json}")

  return false
end

def extract_videos(initial_data : Hash(String, JSON::Any), author_fallback : String? = nil, author_id_fallback : String? = nil) : Array(SearchVideo)
  extracted, _ = extract_items(initial_data, author_fallback, author_id_fallback)

  target = [] of (SearchItem | Continuation)
  extracted.each do |i|
    if i.is_a?(Category)
      i.contents.each { |cate_i| target << cate_i if !cate_i.is_a? Video }
    else
      target << i
    end
  end

  return target.select(SearchVideo)
end

def extract_selected_tab(tabs)
  # Extract the selected tab from the array of tabs Youtube returns
  return selected_target = tabs.as_a.select(&.["tabRenderer"]?.try &.["selected"]?.try &.as_bool)[0]["tabRenderer"]
end
