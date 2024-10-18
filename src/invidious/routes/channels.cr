{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Channels
  # Redirection for unsupported routes ("tabs")
  def self.redirect_home(env)
    ucid = env.params.url["ucid"]
    return env.redirect "/channel/#{URI.encode_www_form(ucid)}"
  end

  def self.home(env)
    self.videos(env)
  end

  def self.videos(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    sort_by = env.params.query["sort_by"]?.try &.downcase

    if channel.auto_generated
      sort_options = {"last", "oldest", "newest"}

      items, next_continuation = fetch_channel_playlists(
        channel.ucid, channel.author, continuation, (sort_by || "last")
      )

      items.uniq! do |item|
        if item.responds_to?(:title)
          item.title
        elsif item.responds_to?(:author)
          item.author
        end
      end
      items = items.select(SearchPlaylist)
      items.each(&.author = "")
    else
      # Fetch items and continuation token
      if channel.is_age_gated
        sort_by = ""
        sort_options = [] of String
        begin
          playlist = get_playlist(channel.ucid.sub("UC", "UULF"))
          items = get_playlist_videos(playlist, offset: 0)
        rescue ex : InfoException
          # playlist doesnt exist.
          items = [] of PlaylistVideo
        end
        next_continuation = nil
      else
        sort_options = {"newest", "oldest", "popular"}
        items, next_continuation = Channel::Tabs.get_videos(
          channel, continuation: continuation, sort_by: (sort_by || "newest")
        )
      end
    end

    selected_tab = Frontend::ChannelPage::TabsAvailable::Videos
    templated "channel"
  end

  def self.shorts(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    if !channel.tabs.includes? "shorts"
      return env.redirect "/channel/#{channel.ucid}"
    end

    if channel.is_age_gated
      sort_by = ""
      sort_options = [] of String
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UUSH"))
        items = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        items = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      # TODO: support sort option for shorts
      sort_by = ""
      sort_options = [] of String

      # Fetch items and continuation token
      items, next_continuation = Channel::Tabs.get_shorts(
        channel, continuation: continuation
      )
    end

    selected_tab = Frontend::ChannelPage::TabsAvailable::Shorts
    templated "channel"
  end

  def self.streams(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    if !channel.tabs.includes? "streams"
      return env.redirect "/channel/#{channel.ucid}"
    end

    if channel.is_age_gated
      sort_by = ""
      sort_options = [] of String
      begin
        playlist = get_playlist(channel.ucid.sub("UC", "UULV"))
        items = get_playlist_videos(playlist, offset: 0)
      rescue ex : InfoException
        # playlist doesnt exist.
        items = [] of PlaylistVideo
      end
      next_continuation = nil
    else
      sort_by = env.params.query["sort_by"]?.try &.downcase || "newest"
      sort_options = {"newest", "oldest", "popular"}

      # Fetch items and continuation token
      items, next_continuation = Channel::Tabs.get_60_livestreams(
        channel, continuation: continuation, sort_by: sort_by
      )
    end

    selected_tab = Frontend::ChannelPage::TabsAvailable::Streams
    templated "channel"
  end

  def self.playlists(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    sort_options = {"last", "oldest", "newest"}
    sort_by = env.params.query["sort_by"]?.try &.downcase

    if channel.auto_generated
      return env.redirect "/channel/#{channel.ucid}"
    end

    items, next_continuation = fetch_channel_playlists(
      channel.ucid, channel.author, continuation, (sort_by || "last")
    )

    items = items.select(SearchPlaylist)
    items.each(&.author = "")

    selected_tab = Frontend::ChannelPage::TabsAvailable::Playlists
    templated "channel"
  end

  def self.podcasts(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    sort_by = ""
    sort_options = [] of String

    items, next_continuation = fetch_channel_podcasts(
      channel.ucid, channel.author, continuation
    )

    items = items.select(SearchPlaylist)
    items.each(&.author = "")

    selected_tab = Frontend::ChannelPage::TabsAvailable::Podcasts
    templated "channel"
  end

  def self.releases(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    sort_by = ""
    sort_options = [] of String

    items, next_continuation = fetch_channel_releases(
      channel.ucid, channel.author, continuation
    )

    items = items.select(SearchPlaylist)
    items.each(&.author = "")

    selected_tab = Frontend::ChannelPage::TabsAvailable::Releases
    templated "channel"
  end

  def self.community(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    # redirect to post page
    if lb = env.params.query["lb"]?
      env.redirect "/post/#{URI.encode_www_form(lb)}?ucid=#{URI.encode_www_form(ucid)}"
    end

    thin_mode = env.params.query["thin_mode"]? || env.get("preferences").as(Preferences).thin_mode
    thin_mode = thin_mode == "true"

    continuation = env.params.query["continuation"]?

    if !channel.tabs.includes? "community"
      return env.redirect "/channel/#{channel.ucid}"
    end

    # TODO: support sort options for community posts
    sort_by = ""
    sort_options = [] of String

    begin
      items = JSON.parse(fetch_channel_community(ucid, continuation, locale, "json", thin_mode))
    rescue ex : InfoException
      env.response.status_code = 500
      error_message = ex.message
    rescue ex : NotFoundException
      env.response.status_code = 404
      error_message = ex.message
    rescue ex
      return error_template(500, ex)
    end

    templated "community"
  end

  def self.post(env)
    # /post/{postId}
    id = URI.encode_www_form(env.params.url["id"])
    ucid = env.params.query["ucid"]?

    prefs = env.get("preferences").as(Preferences)

    locale = prefs.locale

    thin_mode = env.params.query["thin_mode"]? || prefs.thin_mode
    thin_mode = thin_mode == "true"

    nojs = env.params.query["nojs"]?

    nojs ||= "0"
    nojs = nojs == "1"

    if !ucid.nil?
      ucid = URI.encode_www_form(ucid.to_s)
      post_response = fetch_channel_community_post(ucid, id, locale, "json", thin_mode)
    else
      # resolve the url to get the author's UCID
      response = YoutubeAPI.resolve_url("https://www.youtube.com/post/#{id}")
      return error_template(400, "Invalid post ID") if response["error"]?

      ucid = URI.encode_www_form(response.dig("endpoint", "browseEndpoint", "browseId").as_s)
      post_response = fetch_channel_community_post(ucid, id, locale, "json", thin_mode)
    end

    post_response = JSON.parse(post_response)

    if nojs
      comments = Comments.fetch_community_post_comments(ucid, id)
      comment_html = JSON.parse(Comments.parse_youtube(id, comments, "html", locale, thin_mode, type: "post", ucid: ucid))["contentHtml"]
    end
    templated "post"
  end

  def self.channels(env)
    data = self.fetch_basic_information(env)
    return data if !data.is_a?(Tuple)

    locale, user, subscriptions, continuation, ucid, channel = data

    if channel.auto_generated
      return env.redirect "/channel/#{channel.ucid}"
    end

    items, next_continuation = fetch_related_channels(channel, continuation)

    # Featured/related channels can't be sorted
    sort_options = [] of String
    sort_by = nil

    selected_tab = Frontend::ChannelPage::TabsAvailable::Channels
    templated "channel"
  end

  def self.about(env)
    data = self.fetch_basic_information(env)
    if !data.is_a?(Tuple)
      return data
    end
    locale, user, subscriptions, continuation, ucid, channel = data

    env.redirect "/channel/#{ucid}"
  end

  private KNOWN_TABS = {
    "home", "videos", "shorts", "streams", "podcasts",
    "releases", "playlists", "community", "channels", "about",
  }

  # Redirects brand url channels to a normal /channel/:ucid route
  def self.brand_redirect(env)
    locale = env.get("preferences").as(Preferences).locale

    # /attribution_link endpoint needs both the `a` and `u` parameter
    # and in order to avoid detection from YouTube we should only send the required ones
    # without any of the additional url parameters that only Invidious uses.
    yt_url_params = URI::Params.encode(env.params.query.to_h.select(["a", "u", "user"]))

    # Retrieves URL params that only Invidious uses
    invidious_url_params = env.params.query.dup
    invidious_url_params.delete_all("a")
    invidious_url_params.delete_all("u")
    invidious_url_params.delete_all("user")

    begin
      resolved_url = YoutubeAPI.resolve_url("https://youtube.com#{env.request.path}#{yt_url_params.size > 0 ? "?#{yt_url_params}" : ""}")
      ucid = resolved_url["endpoint"]["browseEndpoint"]["browseId"]
    rescue ex : InfoException | KeyError
      return error_template(404, translate(locale, "This channel does not exist."))
    end

    selected_tab = env.params.url["tab"]?

    if KNOWN_TABS.includes? selected_tab
      url = "/channel/#{ucid}/#{selected_tab}"
    else
      url = "/channel/#{ucid}"
    end

    url += "?#{invidious_url_params}" if !invidious_url_params.empty?

    return env.redirect url
  end

  # Handles redirects for the /profile endpoint
  def self.profile(env)
    # The /profile endpoint is special. If passed into the resolve_url
    # endpoint YouTube would return a sign in page instead of an /channel/:ucid
    # thus we'll add an edge case and handle it here.

    uri_params = env.params.query.size > 0 ? "?#{env.params.query}" : ""

    user = env.params.query["user"]?
    if !user
      return error_template(404, "This channel does not exist.")
    else
      env.redirect "/user/#{user}#{uri_params}"
    end
  end

  def self.live(env)
    locale = env.get("preferences").as(Preferences).locale

    # Appears to be a bug in routing, having several routes configured
    # as `/a/:a`, `/b/:a`, `/c/:a` results in 404
    value = env.request.resource.split("/")[2]
    body = ""
    {"channel", "user", "c"}.each do |type|
      response = YT_POOL.client &.get("/#{type}/#{value}/live?disable_polymer=1")
      if response.status_code == 200
        body = response.body
      end
    end

    video_id = body.match(/'VIDEO_ID': "(?<id>[a-zA-Z0-9_-]{11})"/).try &.["id"]?
    if video_id
      params = [] of String
      env.params.query.each do |k, v|
        params << "#{k}=#{v}"
      end
      params = params.join("&")

      url = "/watch?v=#{video_id}"
      if !params.empty?
        url += "&#{params}"
      end

      env.redirect url
    else
      env.redirect "/channel/#{value}"
    end
  end

  private def self.fetch_basic_information(env)
    locale = env.get("preferences").as(Preferences).locale

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
    rescue ex : NotFoundException
      return error_template(404, ex)
    rescue ex
      return error_template(500, ex)
    end

    env.set "search", "channel:#{ucid} "
    return {locale, user, subscriptions, continuation, ucid, channel}
  end
end
