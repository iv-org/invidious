class Invidious::Routes::Channels < Invidious::Routes::BaseRoute
  def home(env)
    self.videos(env)
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

    templated "channel/channel"
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

    if !channel.tabs.has_key?("community")
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

    if !channel.tabs.has_key?("channels")
      return env.redirect "/channel/#{channel.ucid}"
    end

    if continuation
      offset = env.params.query["offset"]?
      if offset
        offset = offset.to_i
      else
        offset = 0
      end

      # Previous continuation
      previous_continuation = env.params.query["previous"]?
      # Category title is not returned when using a continuation token.
      title = env.params.query["title"]?

      featured_channel_categories = fetch_channel_featured_channels(ucid, channel.tabs["channels"], nil, continuation, title).not_nil!
    else
      previous_continuation = nil
      category_param = nil
      offset = 0
      title = nil

      featured_channel_categories = fetch_channel_featured_channels(ucid, channel.tabs["channels"], nil, nil).not_nil!
    end

    templated "channel/featured_channels", buffer_footer: true
  end

  def featured_channel_category(env)
    # Used to check when the initial page is reached and redirect to /channel/:ucid/channels/:param when zero
    offset = env.params.query["offset"]?
    category_param = env.params.url["param"]
    if offset
      offset = offset.to_i
    else
      offset = 0
    end

    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    # Previous continuation
    previous_continuation = env.params.query["previous"]?
    # Category title is not returned when using a continuation token.
    title = env.params.query["title"]?

    featured_channel_categories = fetch_channel_featured_channels(ucid, channel.tabs["channels"], category_param, continuation, title).not_nil!
    templated "channel/featured_channels"
  end

  def about(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    templated "channel/about", buffer_footer: true
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
