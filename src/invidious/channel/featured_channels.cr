def fetch_channel_featured_channels(ucid, params, view = nil, shelf_id = nil, continuation = nil, query_title = nil) : {Array(Category), (String | Nil)}
  if continuation.is_a?(String)
    initial_data = request_youtube_api_browse(continuation)
    items = extract_items(initial_data)
    continuation_token = fetch_continuation_token(initial_data)

    return [Category.new({
      title:            query_title.not_nil!, # If continuation contents is requested then the query_title has to be passed along.
      contents:         items,
      description_html: "",
      url:              nil,
      badges:           nil,
    })], continuation_token
  else
    url = nil
    if view && shelf_id
      url = "/channel/#{ucid}/channels?view=#{view}&shelf_id=#{shelf_id}"

      params = produce_featured_channel_browse_param(view.to_i64, shelf_id.to_i64)
      initial_data = request_youtube_api_browse(ucid, params)
      continuation_token = fetch_continuation_token(initial_data)
    else
      initial_data = request_youtube_api_browse(ucid, params)
      continuation_token = nil
    end

    channels_tab = extract_selected_tab(initial_data["contents"]["twoColumnBrowseResultsRenderer"]["tabs"])
    submenu = channels_tab["content"]["sectionListRenderer"]["subMenu"]?

    # There's no submenu data if the channel doesn't feature any channels.
    if !submenu
      return {[] of Category, continuation_token}
    end

    submenu_data = submenu["channelSubMenuRenderer"]["contentTypeSubMenuItems"]

    items = extract_items(initial_data)
    fallback_title = submenu_data.as_a.select(&.["selected"].as_bool)[0]["title"].as_s

    # Although extract_items parsed everything into the right structs, we still have
    # to fill in the title (if missing) attribute since Youtube doesn't return it when requesting
    # a full category

    category_array = [] of Category
    items.each do |category|
      # Tell compiler that the result from extract_items has to be an array of Categories
      if !category.is_a?(Category)
        next
      end

      category_array << Category.new({
        title:            category.title.empty? ? fallback_title : category.title,
        contents:         category.contents,
        description_html: category.description_html,
        url:              category.url,
        badges:           nil,
      })
    end

    # If no categories has been parsed then it means that we're currently requesting a single one and not in
    # the initial preview anymore. The frontend still needs a Category however, so we'll create one.
    if category_array.empty?
      category_array << Category.new({
        title:            fallback_title,
        contents:         items,
        description_html: "",
        url:              url,
        badges:           nil,
      })
    end

    return category_array, continuation_token
  end
end

def produce_featured_channel_browse_param(view : Int64, shelf_id : Int64)
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
