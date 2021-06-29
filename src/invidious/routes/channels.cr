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

    templated "channel"
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

    templated "playlists"
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

    if !channel.tabs.includes? "community"
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

    templated "community"
  end

  def about(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    env.redirect "/channel/#{ucid}"
  end

  # Redirects brand url channels to a normal /channel/:ucid route
  def brand_redirect(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    begin
      resolved_url = YoutubeAPI.resolve_url("https://youtube.com#{env.request.path}#{env.params.query.size > 0 ? "?#{env.params.query}" : ""}")
    rescue ex : InfoException
      raise InfoException.new("This channel does not exist.")
    end

    ucid = resolved_url["endpoint"]["browseEndpoint"]["browseId"]

    selected_tab = env.request.path.split("/")[-1]
    if ["home", "videos", "playlists", "community", "channels", "about"].includes? selected_tab
      url = "/channel/#{ucid}/#{selected_tab}"
    else
      url = "/channel/#{ucid}"
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
