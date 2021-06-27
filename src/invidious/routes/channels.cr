class Invidious::Routes::Channels < Invidious::Routes::BaseRoute
  def channel(env)
    if !env.get("preferences").as(Preferences).view_channel_homepage_by_default
      env.redirect "/channel/#{env.params.url["ucid"]}/videos"
    else
      env.redirect "/channel/#{env.params.url["ucid"]}/home"
    end
  end

  def home(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data
    items = fetch_channel_home(ucid, channel)

    has_trailer = false
    if !items.empty? && items[0].is_a? Video
      has_trailer = true
    end

    templated "channel/home"
  end

  def videos(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    sort_by = env.params.query["sort_by"]?.try &.downcase

    if channel.auto_generated
      sort_options = {"last", "oldest", "newest"}
      sort_by ||= "last"

      items, continuation = fetch_channel_playlists(channel.ucid, channel.author, continuation, sort_by)
      items.uniq! do |item|
        if item.responds_to?(:title)
          item.title
        elsif item.responds_to?(:author)
          item.author
        end
      end
      items = items.select(&.is_a?(SearchPlaylist)).map(&.as(SearchPlaylist))
      items.each { |item| item.author = "" }
    else
      sort_options = {"newest", "oldest", "popular"}
      sort_by ||= "newest"

      count, items = get_60_videos(channel.ucid, channel.author, page, channel.auto_generated, sort_by)
      items.reject! &.paid
    end

    templated "channel/videos"
  end

  def playlists(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    sort_options = {"last", "oldest", "newest"}
    sort_by = env.params.query["sort_by"]?.try &.downcase
    sort_by ||= "last"

    if channel.auto_generated
      return env.redirect "/channel/#{channel.ucid}"
    end

    items, continuation = fetch_channel_playlists(channel.ucid, channel.author, continuation, sort_by)
    items = items.select { |item| item.is_a?(SearchPlaylist) }.map { |item| item.as(SearchPlaylist) }
    items.each { |item| item.author = "" }

    templated "channel/playlists", buffer_footer: true
  end

  def community(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    thin_mode = env.params.query["thin_mode"]? || env.get("preferences").as(Preferences).thin_mode
    thin_mode = thin_mode == "true"

    continuation = env.params.query["continuation"]?
    # sort_by = env.params.query["sort_by"]?.try &.downcase

    if !channel.tabs.includes?("community")
      return env.redirect "/channel/#{channel.ucid}"
    end

    begin
      items = JSON.parse(fetch_channel_community(ucid, continuation, locale, "json", thin_mode))
    rescue ex : InfoException
      env.response.status_code = 500
      error_message = ex.message
    rescue ex
      return error_template(500, ex)
    end

    templated "channel/community"
  end

  def channels(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    if !channel.tabs.includes?("channels")
      return env.redirect "/channel/#{channel.ucid}"
    end

    view = env.params.query["view"]?
    shelf_id = env.params.query["shelf_id"]?

    # The offset is mainly to check if we're at the first page or not and in turn whether we should have a "previous page" button or not.
    offset = env.params.query["offset"]?
    if offset
      offset = offset.to_i
    else
      offset = 0
    end

    # Category title isn't returned when requesting a specific category or continuation data
    # so we have it in through a url param
    current_category_title = env.params.query["title"]?

    previous_continuation = env.params.query["previous"]?

    if continuation
      featured_channel_categories, continuation_token = fetch_channel_featured_channels_category_continuation(continuation, current_category_title)
    elsif view && shelf_id
      featured_channel_categories, continuation_token = fetch_selected_channel_featuring_category(ucid, view, shelf_id)
    else
      continuation_token = nil
      featured_channel_categories = fetch_channel_featured_channels(ucid)
    end

    # If we only got a single category we'll go ahead and wrap it within an array for easier processing in the template.
    if featured_channel_categories.is_a? Category
      featured_channel_categories = [featured_channel_categories]
    end

    templated "channel/featured_channels", buffer_footer: true
  end

  def about(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    templated "channel/about", buffer_footer: true
  end

  def brand_redirect(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.params.url["user"]

    response = YT_POOL.client &.get("/c/#{user}")
    html = XML.parse_html(response.body)

    ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]
    if !ucid
      env.response.status_code = 404
      return
    end

    url = "/channel/#{ucid}"

    location = env.request.path.lchop?("/c/#{user}/")
    if location
      url += "/#{location}"
    end

    if env.params.query.size > 0
      url += "?#{env.params.query}"
    end

    env.redirect url
  end

  private def fetch_basic_information(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    if user
      user = user.as(User)
      subscriptions = user.subscriptions
    end
    subscriptions ||= [] of String

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?

    begin
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      return env.redirect env.request.resource.gsub(ucid, ex.channel_id)
    rescue ex
      return error_template(500, ex)
    end

    return {locale, user, subscriptions, continuation, ucid, channel}
  end
end
