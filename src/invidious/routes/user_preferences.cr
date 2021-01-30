class Invidious::Routes::UserPreferences < Invidious::Routes::BaseRoute
  def show(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    referer = get_referer(env)

    preferences = env.get("preferences").as(Preferences)

    templated "preferences"
  end

  def update(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    referer = get_referer(env)

    video_loop = env.params.body["video_loop"]?.try &.as(String)
    video_loop ||= "off"
    video_loop = video_loop == "on"

    annotations = env.params.body["annotations"]?.try &.as(String)
    annotations ||= "off"
    annotations = annotations == "on"

    annotations_subscribed = env.params.body["annotations_subscribed"]?.try &.as(String)
    annotations_subscribed ||= "off"
    annotations_subscribed = annotations_subscribed == "on"

    autoplay = env.params.body["autoplay"]?.try &.as(String)
    autoplay ||= "off"
    autoplay = autoplay == "on"

    continue = env.params.body["continue"]?.try &.as(String)
    continue ||= "off"
    continue = continue == "on"

    continue_autoplay = env.params.body["continue_autoplay"]?.try &.as(String)
    continue_autoplay ||= "off"
    continue_autoplay = continue_autoplay == "on"

    listen = env.params.body["listen"]?.try &.as(String)
    listen ||= "off"
    listen = listen == "on"

    local = env.params.body["local"]?.try &.as(String)
    local ||= "off"
    local = local == "on"

    speed = env.params.body["speed"]?.try &.as(String).to_f32?
    speed ||= CONFIG.default_user_preferences.speed

    player_style = env.params.body["player_style"]?.try &.as(String)
    player_style ||= CONFIG.default_user_preferences.player_style

    quality = env.params.body["quality"]?.try &.as(String)
    quality ||= CONFIG.default_user_preferences.quality

    quality_dash = env.params.body["quality_dash"]?.try &.as(String)
    quality_dash ||= CONFIG.default_user_preferences.quality_dash

    volume = env.params.body["volume"]?.try &.as(String).to_i?
    volume ||= CONFIG.default_user_preferences.volume

    comments = [] of String
    2.times do |i|
      comments << (env.params.body["comments[#{i}]"]?.try &.as(String) || CONFIG.default_user_preferences.comments[i])
    end

    captions = [] of String
    3.times do |i|
      captions << (env.params.body["captions[#{i}]"]?.try &.as(String) || CONFIG.default_user_preferences.captions[i])
    end

    related_videos = env.params.body["related_videos"]?.try &.as(String)
    related_videos ||= "off"
    related_videos = related_videos == "on"

    default_home = env.params.body["default_home"]?.try &.as(String) || CONFIG.default_user_preferences.default_home

    feed_menu = [] of String
    4.times do |index|
      option = env.params.body["feed_menu[#{index}]"]?.try &.as(String) || ""
      if !option.empty?
        feed_menu << option
      end
    end

    locale = env.params.body["locale"]?.try &.as(String)
    locale ||= CONFIG.default_user_preferences.locale

    dark_mode = env.params.body["dark_mode"]?.try &.as(String)
    dark_mode ||= CONFIG.default_user_preferences.dark_mode

    thin_mode = env.params.body["thin_mode"]?.try &.as(String)
    thin_mode ||= "off"
    thin_mode = thin_mode == "on"

    max_results = env.params.body["max_results"]?.try &.as(String).to_i?
    max_results ||= CONFIG.default_user_preferences.max_results

    sort = env.params.body["sort"]?.try &.as(String)
    sort ||= CONFIG.default_user_preferences.sort

    latest_only = env.params.body["latest_only"]?.try &.as(String)
    latest_only ||= "off"
    latest_only = latest_only == "on"

    unseen_only = env.params.body["unseen_only"]?.try &.as(String)
    unseen_only ||= "off"
    unseen_only = unseen_only == "on"

    notifications_only = env.params.body["notifications_only"]?.try &.as(String)
    notifications_only ||= "off"
    notifications_only = notifications_only == "on"

    # Convert to JSON and back again to take advantage of converters used for compatability
    preferences = Preferences.from_json({
      annotations:            annotations,
      annotations_subscribed: annotations_subscribed,
      autoplay:               autoplay,
      captions:               captions,
      comments:               comments,
      continue:               continue,
      continue_autoplay:      continue_autoplay,
      dark_mode:              dark_mode,
      latest_only:            latest_only,
      listen:                 listen,
      local:                  local,
      locale:                 locale,
      max_results:            max_results,
      notifications_only:     notifications_only,
      player_style:           player_style,
      quality:                quality,
      quality_dash:           quality_dash,
      default_home:           default_home,
      feed_menu:              feed_menu,
      related_videos:         related_videos,
      sort:                   sort,
      speed:                  speed,
      thin_mode:              thin_mode,
      unseen_only:            unseen_only,
      video_loop:             video_loop,
      volume:                 volume,
    }.to_json).to_json

    if user = env.get? "user"
      user = user.as(User)
      PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)

      if CONFIG.admins.includes? user.email
        CONFIG.default_user_preferences.default_home = env.params.body["admin_default_home"]?.try &.as(String) || CONFIG.default_user_preferences.default_home

        admin_feed_menu = [] of String
        4.times do |index|
          option = env.params.body["admin_feed_menu[#{index}]"]?.try &.as(String) || ""
          if !option.empty?
            admin_feed_menu << option
          end
        end
        CONFIG.default_user_preferences.feed_menu = admin_feed_menu

        popular_enabled = env.params.body["popular_enabled"]?.try &.as(String)
        popular_enabled ||= "off"
        CONFIG.popular_enabled = popular_enabled == "on"

        captcha_enabled = env.params.body["captcha_enabled"]?.try &.as(String)
        captcha_enabled ||= "off"
        CONFIG.captcha_enabled = captcha_enabled == "on"

        login_enabled = env.params.body["login_enabled"]?.try &.as(String)
        login_enabled ||= "off"
        CONFIG.login_enabled = login_enabled == "on"

        registration_enabled = env.params.body["registration_enabled"]?.try &.as(String)
        registration_enabled ||= "off"
        CONFIG.registration_enabled = registration_enabled == "on"

        statistics_enabled = env.params.body["statistics_enabled"]?.try &.as(String)
        statistics_enabled ||= "off"
        CONFIG.statistics_enabled = statistics_enabled == "on"

        File.write("config/config.yml", CONFIG.to_yaml)
      end
    else
      if Kemal.config.ssl || CONFIG.https_only
        secure = true
      else
        secure = false
      end

      if CONFIG.domain
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{CONFIG.domain}", value: preferences, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      end
    end

    env.redirect referer
  end

  def toggle_theme(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    referer = get_referer(env, unroll: false)

    redirect = env.params.query["redirect"]?
    redirect ||= "true"
    redirect = redirect == "true"

    if user = env.get? "user"
      user = user.as(User)
      preferences = user.preferences

      case preferences.dark_mode
      when "dark"
        preferences.dark_mode = "light"
      else
        preferences.dark_mode = "dark"
      end

      preferences = preferences.to_json

      PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences, user.email)
    else
      preferences = env.get("preferences").as(Preferences)

      case preferences.dark_mode
      when "dark"
        preferences.dark_mode = "light"
      else
        preferences.dark_mode = "dark"
      end

      preferences = preferences.to_json

      if Kemal.config.ssl || CONFIG.https_only
        secure = true
      else
        secure = false
      end

      if CONFIG.domain
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{CONFIG.domain}", value: preferences, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: preferences, expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      end
    end

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end
end
