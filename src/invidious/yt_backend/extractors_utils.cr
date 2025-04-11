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

def has_unlisted_badge?(badges : JSON::Any?)
  return false if badges.nil?

  badges.as_a.each do |badge|
    icon_type = badge.dig("metadataBadgeRenderer", "icon", "iconType").as_s

    return true if icon_type == "PRIVACY_UNLISTED"
  end

  return false
rescue ex
  LOGGER.debug("Unable to parse owner badges. Got exception: #{ex.message}")
  LOGGER.trace("Owner badges data: #{badges.to_json}")

  return false
end

# This function extracts SearchVideo items from a Category.
# Categories are commonly returned in search results and trending pages.
def extract_category(category : Category) : Array(SearchVideo)
  return category.contents.select(SearchVideo)
end

# :ditto:
def extract_category(category : Category, &)
  category.contents.select(SearchVideo).each do |item|
    yield item
  end
end

def extract_selected_tab(tabs)
  # Extract the selected tab from the array of tabs Youtube returns
  return tabs.as_a.select(&.["tabRenderer"]?.try &.["selected"]?.try &.as_bool)[0]["tabRenderer"]
end
