# Fetches the featured channel categories of a channel
#
# Returned as an array of Category objects containing different channels.
def fetch_channel_featured_channels(ucid) : Array(Category)
  initial_data = YoutubeAPI.browse(ucid, params: "EghjaGFubmVscw%3D%3D")

  channels_tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])

  # The submenu is the content type menu, and is used to select which categories to view fully.
  # As a result, it contains the category title which we'll use as a fallback, since Innertube doesn't
  # return the title when the channel only has one featured channel category.
  submenu = channels_tab["content"]["sectionListRenderer"]["subMenu"]?

  # If the featured channel tabs lacks categories then that means the channel doesn't feature any other channels.
  if !submenu
    return [] of Category
  end

  # Fetches the fallback title.
  submenu_data = submenu["channelSubMenuRenderer"]["contentTypeSubMenuItems"]
  fallback_title = submenu_data.as_a.select(&.["selected"].as_bool)[0]["title"].as_s

  items = extract_items(initial_data)

  category_array = [] of Category
  items.each do |category|
    # The items can either be an Array of Categories or an Array of channels.
    if !category.is_a?(Category)
      break
    end

    # category.title = category.title.empty? ? fallback_title : category.title
    category_array << category
  end

  # If the returned data is only an array of channels then it means that the featured channel tab only has one category.
  # This is due to the fact that InnerTube uses a "gridRenderer" (an array of items) when only one category is present.
  # However, as the InnerTube result is a "gridRenderer" and not an "shelfRenderer", an object representing an
  # category or section on youtube, we'll lack the category title. But, the good news is that the title of the category is still stored within the submenu
  # which we fetched above. We can then use all of these values together to produce a Category object.
  if category_array.empty?
    category_array << Category.new({
      title:            fallback_title,
      contents:         items,
      description_html: "",
      url:              nil,
      badges:           nil,
    })
  end

  return category_array
end

# Produces the InnerTube parameter for requesting the contents of a specific channel featuring category
private def produce_featured_channel_browse_param(view : Int64, shelf_id : Int64)
  object = {
    "2:string"  => "channels",
    "4:varint"  => view,
    "14:varint" => shelf_id,
  }

  browse_params = object.try { |i| Protodec::Any.cast_json(object) }
    .try { |i| Protodec::Any.from_json(i) }
    .try { |i| Base64.urlsafe_encode(i) }
    .try { |i| URI.encode_www_form(i) }

  return browse_params
end

# Fetches the first set of channels from a selected channel featuring category
def fetch_selected_channel_featuring_category(ucid, view, shelf_id) : Tuple(Category, String | Nil)
  category_url = "/channel/#{ucid}/channels?view=#{view}&shelf_id=#{shelf_id}"

  params = produce_featured_channel_browse_param(view.to_i64, shelf_id.to_i64)
  initial_data = YoutubeAPI.browse(ucid, params: params)
  channels_tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])
  continuation_token = fetch_continuation_token(initial_data)

  # Fetches the fallback title
  submenu = channels_tab["content"]["sectionListRenderer"]["subMenu"]
  submenu_data = submenu["channelSubMenuRenderer"]["contentTypeSubMenuItems"]
  fallback_title = submenu_data.as_a.select(&.["selected"].as_bool)[0]["title"].as_s

  items = extract_items(initial_data)

  # Since the returned items from InnerTube is an array of channels, (See explanation at the end of the fetch_channel_featured_channels function)
  # we lack the category title attribute. However, it is still stored as a submenu data which we fetched above. We can then use all of these
  # values together to produce a Category object.
  return Category.new({
    title:            fallback_title,
    contents:         items,
    description_html: "",
    url:              category_url,
    badges:           nil,
  }), continuation_token
end

# Fetches the next set of channels within the selected channel featuring category.
# Requires the continuation token and the query_title.
#
# TODO: The query_title here is really only used for frontend rendering.
#  And since it's a URL parameter we should be able to just request it directly within the template files.
def fetch_channel_featured_channels_category_continuation(continuation, query_title) : Tuple(Category, String | Nil)
  initial_data = YoutubeAPI.browse(continuation)
  items = extract_items(initial_data)
  continuation_token = fetch_continuation_token(initial_data)

  return Category.new({
    title:            query_title.not_nil!, # If continuation contents is requested then the query_title has to be passed along.
    contents:         items,
    description_html: "",
    url:              nil,
    badges:           nil,
  }), continuation_token
end
