{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Channels
  def self.home(env)
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

  def self.videos(env)
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
    end

    templated "channel/videos"
  end

  def self.playlists(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

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

  def self.community(env)
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

  def self.channels(env)
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

  def self.featured_channel_category(env)
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

  def self.about(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    ucid = env.params.url["ucid"]
    continuation = env.params.query["continuation"]?

    begin
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      next env.redirect env.request.resource.gsub(ucid, ex.channel_id)
    rescue ex
      next error_template(500, ex)
    end

    templated "channel/about", buffer_footer: true
  end

  # Redirects brand url channels to a normal /channel/:ucid route

  def self.brand_redirect(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    # /attribution_link endpoint needs both the `a` and `u` parameter
    # and in order to avoid detection from YouTube we should only send the required ones
    # without any of the additional url parameters that only Invidious uses.
    yt_url_params = URI::Params.encode(env.params.query.to_h.select(["a", "u", "user"]))

    # Retrieves URL params that only Invidious uses
    invidious_url_params = URI::Params.encode(env.params.query.to_h.select!(["a", "u", "user"]))

    begin
      resolved_url = YoutubeAPI.resolve_url("https://youtube.com#{env.request.path}#{yt_url_params.size > 0 ? "?#{yt_url_params}" : ""}")
      ucid = resolved_url["endpoint"]["browseEndpoint"]["browseId"]
    rescue ex : InfoException | KeyError
      raise InfoException.new(translate(locale, "This channel does not exist."))
    end

    selected_tab = env.request.path.split("/")[-1]
    if ["home", "videos", "playlists", "community", "channels", "about"].includes? selected_tab
      url = "/channel/#{ucid}/#{selected_tab}"
    else
      url = "/channel/#{ucid}"
    end

    env.redirect url
  end

  # Handles redirects for the /profile endpoint
  def self.profile(env)
    # The /profile endpoint is special. If passed into the resolve_url
    # endpoint YouTube would return a sign in page instead of an /channel/:ucid
    # thus we'll add an edge case and handle it here.

    uri_params = env.params.query.size > 0 ? "?#{env.params.query}" : ""

    user = env.params.query["user"]?
    if !user
      raise InfoException.new("This channel does not exist.")
    else
      env.redirect "/user/#{user}#{uri_params}"
    end
  end

  private def search(env)
    return env.redirect "/search?#{env.params.query}&channel=#{env.params.url["ucid"]}"
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
