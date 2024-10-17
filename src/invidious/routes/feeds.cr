{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Feeds
  def self.view_all_playlists_redirect(env)
    env.redirect "/feed/playlists"
  end

  def self.view_all_compilations_redirect(env)
    env.redirect "/feed/compilations"
  end

  def self.compilations(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)

    # TODO: make a single DB call and separate the items here?
    items_created = Invidious::Database::Compilations.select_like_iv(user.email)
    items_created.map! do |item|
      item.author = ""
      item
    end

    items_saved = Invidious::Database::Compilations.select_not_like_iv(user.email)
    items_saved.map! do |item|
      item.author = ""
      item
    end

    templated "feeds/compilations"
  end

  def self.playlists(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)

    # TODO: make a single DB call and separate the items here?
    items_created = Invidious::Database::Playlists.select_like_iv(user.email)
    items_created.map! do |item|
      item.author = ""
      item
    end

    items_saved = Invidious::Database::Playlists.select_not_like_iv(user.email)
    items_saved.map! do |item|
      item.author = ""
      item
    end

    templated "feeds/playlists"
  end

  def self.popular(env)
    locale = env.get("preferences").as(Preferences).locale

    if CONFIG.popular_enabled
      templated "feeds/popular"
    else
      message = translate(locale, "The Popular feed has been disabled by the administrator.")
      templated "message"
    end
  end

  def self.trending(env)
    locale = env.get("preferences").as(Preferences).locale

    trending_type = env.params.query["type"]?
    trending_type ||= "Default"

    region = env.params.query["region"]?
    region ||= env.get("preferences").as(Preferences).region

    begin
      trending, plid = fetch_trending(trending_type, region, locale)
    rescue ex
      return error_template(500, ex)
    end

    templated "feeds/trending"
  end

  def self.subscriptions(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)
    token = user.token

    if user.preferences.unseen_only
      env.set "show_watched", true
    end

    # Refresh account
    headers = HTTP::Headers.new
    headers["Cookie"] = env.request.headers["Cookie"]

    max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
    max_results ||= user.preferences.max_results
    max_results ||= CONFIG.default_user_preferences.max_results

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    videos, notifications = get_subscription_feed(user, max_results, page)

    if CONFIG.enable_user_notifications
      # "updated" here is used for delivering new notifications, so if
      # we know a user has looked at their feed e.g. in the past 10 minutes,
      # they've already seen a video posted 20 minutes ago, and don't need
      # to be notified.
      Invidious::Database::Users.clear_notifications(user)
      user.notifications = [] of String
    end
    env.set "user", user

    # Used for pagination links
    base_url = "/feed/subscriptions"
    base_url += "?max_results=#{max_results}" if env.params.query.has_key?("max_results")

    templated "feeds/subscriptions"
  end

  def self.history(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env)

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    if !user
      return env.redirect referer
    end

    user = user.as(User)

    max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
    max_results ||= user.preferences.max_results
    max_results ||= CONFIG.default_user_preferences.max_results

    if user.watched[(page - 1) * max_results]?
      watched = user.watched.reverse[(page - 1) * max_results, max_results]
    end
    watched ||= [] of String

    # Used for pagination links
    base_url = "/feed/history"
    base_url += "?max_results=#{max_results}" if env.params.query.has_key?("max_results")

    templated "feeds/history"
  end

  # RSS feeds

  def self.rss_channel(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.headers["Content-Type"] = "application/atom+xml"
    env.response.content_type = "application/atom+xml"

    ucid = env.params.url["ucid"]

    params = HTTP::Params.parse(env.params.query["params"]? || "")

    begin
      channel = get_about_info(ucid, locale)
    rescue ex : ChannelRedirect
      return env.redirect env.request.resource.gsub(ucid, ex.channel_id)
    rescue ex : NotFoundException
      return error_atom(404, ex)
    rescue ex
      return error_atom(500, ex)
    end

    namespaces = {
      "yt"      => "http://www.youtube.com/xml/schemas/2015",
      "media"   => "http://search.yahoo.com/mrss/",
      "default" => "http://www.w3.org/2005/Atom",
    }

    response = YT_POOL.client &.get("/feeds/videos.xml?channel_id=#{channel.ucid}")
    rss = XML.parse(response.body)

    videos = rss.xpath_nodes("//default:feed/default:entry", namespaces).map do |entry|
      video_id = entry.xpath_node("yt:videoId", namespaces).not_nil!.content
      title = entry.xpath_node("default:title", namespaces).not_nil!.content

      published = Time.parse_rfc3339(entry.xpath_node("default:published", namespaces).not_nil!.content)
      updated = Time.parse_rfc3339(entry.xpath_node("default:updated", namespaces).not_nil!.content)

      author = entry.xpath_node("default:author/default:name", namespaces).not_nil!.content
      ucid = entry.xpath_node("yt:channelId", namespaces).not_nil!.content
      description_html = entry.xpath_node("media:group/media:description", namespaces).not_nil!.to_s
      views = entry.xpath_node("media:group/media:community/media:statistics", namespaces).not_nil!.["views"].to_i64

      SearchVideo.new({
        title:              title,
        id:                 video_id,
        author:             author,
        ucid:               ucid,
        published:          published,
        views:              views,
        description_html:   description_html,
        length_seconds:     0,
        premiere_timestamp: nil,
        author_verified:    false,
        badges:             VideoBadges::None,
      })
    end

    XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
        "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
        "xml:lang": "en-US") do
        xml.element("link", rel: "self", href: "#{HOST_URL}#{env.request.resource}")
        xml.element("id") { xml.text "yt:channel:#{channel.ucid}" }
        xml.element("yt:channelId") { xml.text channel.ucid }
        xml.element("icon") { xml.text channel.author_thumbnail }
        xml.element("title") { xml.text channel.author }
        xml.element("link", rel: "alternate", href: "#{HOST_URL}/channel/#{channel.ucid}")

        xml.element("author") do
          xml.element("name") { xml.text channel.author }
          xml.element("uri") { xml.text "#{HOST_URL}/channel/#{channel.ucid}" }
        end

        xml.element("image") do
          xml.element("url") { xml.text channel.author_thumbnail }
          xml.element("title") { xml.text channel.author }
          xml.element("link", rel: "self", href: "#{HOST_URL}#{env.request.resource}")
        end

        videos.each do |video|
          video.to_xml(channel.auto_generated, params, xml)
        end
      end
    end
  end

  def self.rss_private(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.headers["Content-Type"] = "application/atom+xml"
    env.response.content_type = "application/atom+xml"

    token = env.params.query["token"]?

    if !token
      haltf env, status_code: 403
    end

    user = Invidious::Database::Users.select(token: token.strip)
    if !user
      haltf env, status_code: 403
    end

    max_results = env.params.query["max_results"]?.try &.to_i?.try &.clamp(0, MAX_ITEMS_PER_PAGE)
    max_results ||= user.preferences.max_results
    max_results ||= CONFIG.default_user_preferences.max_results

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    params = HTTP::Params.parse(env.params.query["params"]? || "")

    videos, notifications = get_subscription_feed(user, max_results, page)

    XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
        "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
        "xml:lang": "en-US") do
        xml.element("link", "type": "text/html", rel: "alternate", href: "#{HOST_URL}/feed/subscriptions")
        xml.element("link", "type": "application/atom+xml", rel: "self",
          href: "#{HOST_URL}#{env.request.resource}")
        xml.element("title") { xml.text translate(locale, "Invidious Private Feed for `x`", user.email) }

        (notifications + videos).each do |video|
          video.to_xml(locale, params, xml)
        end
      end
    end
  end

  def self.rss_playlist(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.headers["Content-Type"] = "application/atom+xml"
    env.response.content_type = "application/atom+xml"

    plid = env.params.url["plid"]

    params = HTTP::Params.parse(env.params.query["params"]? || "")
    path = env.request.path

    if plid.starts_with? "IV"
      if playlist = Invidious::Database::Playlists.select(id: plid)
        videos = get_playlist_videos(playlist, offset: 0)

        return XML.build(indent: "  ", encoding: "UTF-8") do |xml|
          xml.element("feed", "xmlns:yt": "http://www.youtube.com/xml/schemas/2015",
            "xmlns:media": "http://search.yahoo.com/mrss/", xmlns: "http://www.w3.org/2005/Atom",
            "xml:lang": "en-US") do
            xml.element("link", rel: "self", href: "#{HOST_URL}#{env.request.resource}")
            xml.element("id") { xml.text "iv:playlist:#{plid}" }
            xml.element("iv:playlistId") { xml.text plid }
            xml.element("title") { xml.text playlist.title }
            xml.element("link", rel: "alternate", href: "#{HOST_URL}/playlist?list=#{plid}")

            xml.element("author") do
              xml.element("name") { xml.text playlist.author }
            end

            videos.each &.to_xml(xml)
          end
        end
      else
        haltf env, status_code: 404
      end
    end

    response = YT_POOL.client &.get("/feeds/videos.xml?playlist_id=#{plid}")
    document = XML.parse(response.body)

    document.xpath_nodes(%q(//*[@href]|//*[@url])).each do |node|
      node.attributes.each do |attribute|
        case attribute.name
        when "url", "href"
          request_target = URI.parse(node[attribute.name]).request_target
          query_string_opt = request_target.starts_with?("/watch?v=") ? "&#{params}" : ""
          node[attribute.name] = "#{HOST_URL}#{request_target}#{query_string_opt}"
        else nil # Skip
        end
      end
    end

    document = document.to_xml(options: XML::SaveOptions::NO_DECL)

    document.scan(/<uri>(?<url>[^<]+)<\/uri>/).each do |match|
      content = "#{HOST_URL}#{URI.parse(match["url"]).request_target}"
      document = document.gsub(match[0], "<uri>#{content}</uri>")
    end
    document
  end

  def self.rss_videos(env)
    if ucid = env.params.query["channel_id"]?
      env.redirect "/feed/channel/#{ucid}"
    elsif user = env.params.query["user"]?
      env.redirect "/feed/channel/#{user}"
    elsif plid = env.params.query["playlist_id"]?
      env.redirect "/feed/playlist/#{plid}"
    end
  end

  # Push notifications via PubSub

  def self.push_notifications_get(env)
    verify_token = env.params.url["token"]

    mode = env.params.query["hub.mode"]?
    topic = env.params.query["hub.topic"]?
    challenge = env.params.query["hub.challenge"]?

    if !mode || !topic || !challenge
      haltf env, status_code: 400
    else
      mode = mode.not_nil!
      topic = topic.not_nil!
      challenge = challenge.not_nil!
    end

    case verify_token
    when .starts_with? "v1"
      _, time, nonce, signature = verify_token.split(":")
      data = "#{time}:#{nonce}"
    when .starts_with? "v2"
      time, signature = verify_token.split(":")
      data = "#{time}"
    else
      haltf env, status_code: 400
    end

    # The hub will sometimes check if we're still subscribed after delivery errors,
    # so we reply with a 200 as long as the request hasn't expired
    if Time.utc.to_unix - time.to_i > 432000
      haltf env, status_code: 400
    end

    if OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, data) != signature
      haltf env, status_code: 400
    end

    if ucid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["channel_id"]?
      Invidious::Database::Channels.update_subscription_time(ucid)
    elsif plid = HTTP::Params.parse(URI.parse(topic).query.not_nil!)["playlist_id"]?
      Invidious::Database::Playlists.update_subscription_time(plid)
    else
      haltf env, status_code: 400
    end

    env.response.status_code = 200
    challenge
  end

  def self.push_notifications_post(env)
    locale = env.get("preferences").as(Preferences).locale

    token = env.params.url["token"]
    body = env.request.body.not_nil!.gets_to_end
    signature = env.request.headers["X-Hub-Signature"].lchop("sha1=")

    if signature != OpenSSL::HMAC.hexdigest(:sha1, HMAC_KEY, body)
      LOGGER.error("/feed/webhook/#{token} : Invalid signature")
      haltf env, status_code: 200
    end

    spawn do
      # TODO: unify this with the other almost identical looking parts in this and channels.cr somehow?
      namespaces = {
        "yt"      => "http://www.youtube.com/xml/schemas/2015",
        "default" => "http://www.w3.org/2005/Atom",
      }
      rss = XML.parse(body)
      rss.xpath_nodes("//default:feed/default:entry", namespaces).each do |entry|
        id = entry.xpath_node("yt:videoId", namespaces).not_nil!.content
        author = entry.xpath_node("default:author/default:name", namespaces).not_nil!.content
        published = Time.parse_rfc3339(entry.xpath_node("default:published", namespaces).not_nil!.content)
        updated = Time.parse_rfc3339(entry.xpath_node("default:updated", namespaces).not_nil!.content)

        begin
          video = get_video(id, force_refresh: true)
        rescue
          next # skip this video since it raised an exception (e.g. it is a scheduled live event)
        end

        if CONFIG.enable_user_notifications
          # Deliver notifications to `/api/v1/auth/notifications`
          payload = {
            "topic"     => video.ucid,
            "videoId"   => video.id,
            "published" => published.to_unix,
          }.to_json
          PG_DB.exec("NOTIFY notifications, E'#{payload}'")
        end

        video = ChannelVideo.new({
          id:                 id,
          title:              video.title,
          published:          published,
          updated:            updated,
          ucid:               video.ucid,
          author:             author,
          length_seconds:     video.length_seconds,
          live_now:           video.live_now,
          premiere_timestamp: video.premiere_timestamp,
          views:              video.views,
        })

        was_insert = Invidious::Database::ChannelVideos.insert(video, with_premiere_timestamp: true)
        if was_insert
          if CONFIG.enable_user_notifications
            Invidious::Database::Users.add_notification(video)
          else
            Invidious::Database::Users.feed_needs_update(video)
          end
        end
      end
    end

    env.response.status_code = 200
  end
end
