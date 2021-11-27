{% skip_file if flag?(:api_only) %}

module Invidious::Routes::PreferencesRoute
  def self.show(env)
    locale = env.get("preferences").as(Preferences).locale

    referer = get_referer(env)

    preferences = env.get("preferences").as(Preferences)

    templated "preferences"
  end

  def self.update(env)
    locale = env.get("preferences").as(Preferences).locale
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

    extend_desc = env.params.body["extend_desc"]?.try &.as(String)
    extend_desc ||= "off"
    extend_desc = extend_desc == "on"

    vr_mode = env.params.body["vr_mode"]?.try &.as(String)
    vr_mode ||= "off"
    vr_mode = vr_mode == "on"

    save_player_pos = env.params.body["save_player_pos"]?.try &.as(String)
    save_player_pos ||= "off"
    save_player_pos = save_player_pos == "on"

    show_nick = env.params.body["show_nick"]?.try &.as(String)
    show_nick ||= "off"
    show_nick = show_nick == "on"

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

    automatic_instance_redirect = env.params.body["automatic_instance_redirect"]?.try &.as(String)
    automatic_instance_redirect ||= "off"
    automatic_instance_redirect = automatic_instance_redirect == "on"

    region = env.params.body["region"]?.try &.as(String)

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
      annotations:                 annotations,
      annotations_subscribed:      annotations_subscribed,
      autoplay:                    autoplay,
      captions:                    captions,
      comments:                    comments,
      continue:                    continue,
      continue_autoplay:           continue_autoplay,
      dark_mode:                   dark_mode,
      latest_only:                 latest_only,
      listen:                      listen,
      local:                       local,
      locale:                      locale,
      max_results:                 max_results,
      notifications_only:          notifications_only,
      player_style:                player_style,
      quality:                     quality,
      quality_dash:                quality_dash,
      default_home:                default_home,
      feed_menu:                   feed_menu,
      automatic_instance_redirect: automatic_instance_redirect,
      region:                      region,
      related_videos:              related_videos,
      sort:                        sort,
      speed:                       speed,
      thin_mode:                   thin_mode,
      unseen_only:                 unseen_only,
      video_loop:                  video_loop,
      volume:                      volume,
      extend_desc:                 extend_desc,
      vr_mode:                     vr_mode,
      show_nick:                   show_nick,
      save_player_pos:             save_player_pos,
    }.to_json)

    if user = env.get? "user"
      user = user.as(User)
      user.preferences = preferences
      Invidious::Database::Users.update_preferences(user)

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

        CONFIG.modified_source_code_url = env.params.body["modified_source_code_url"]?.try &.as(String)

        File.write("config/config.yml", CONFIG.to_yaml)
      end
    else
      if Kemal.config.ssl || CONFIG.https_only
        secure = true
      else
        secure = false
      end

      if CONFIG.domain
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{CONFIG.domain}", value: URI.encode_www_form(preferences.to_json), expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: URI.encode_www_form(preferences.to_json), expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      end
    end

    env.redirect referer
  end

  def self.toggle_theme(env)
    locale = env.get("preferences").as(Preferences).locale
    referer = get_referer(env, unroll: false)

    redirect = env.params.query["redirect"]?
    redirect ||= "true"
    redirect = redirect == "true"

    if user = env.get? "user"
      user = user.as(User)

      case user.preferences.dark_mode
      when "dark"
        user.preferences.dark_mode = "light"
      else
        user.preferences.dark_mode = "dark"
      end

      Invidious::Database::Users.update_preferences(user)
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
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", domain: "#{CONFIG.domain}", value: URI.encode_www_form(preferences), expires: Time.utc + 2.years,
          secure: secure, http_only: true)
      else
        env.response.cookies["PREFS"] = HTTP::Cookie.new(name: "PREFS", value: URI.encode_www_form(preferences), expires: Time.utc + 2.years,
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

  def self.data_control(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)

    templated "data_control"
  end

  def self.update_data_control(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    referer = get_referer(env)

    if user
      user = user.as(User)

      # TODO: Find a way to prevent browser timeout

      HTTP::FormData.parse(env.request) do |part|
        body = part.body.gets_to_end
        type = part.headers["Content-Type"]

        return if body.empty?

        # TODO: Unify into single import based on content-type
        case part.name
        when "import_invidious"
          body = JSON.parse(body)

          if body["subscriptions"]?
            user.subscriptions += body["subscriptions"].as_a.map(&.as_s)
            user.subscriptions.uniq!

            user.subscriptions = get_batch_channels(user.subscriptions, false, false)

            Invidious::Database::Users.update_subscriptions(user)
          end

          if body["watch_history"]?
            user.watched += body["watch_history"].as_a.map(&.as_s)
            user.watched.uniq!
            Invidious::Database::Users.update_watch_history(user)
          end

          if body["preferences"]?
            user.preferences = Preferences.from_json(body["preferences"].to_json)
            Invidious::Database::Users.update_preferences(user)
          end

          if playlists = body["playlists"]?.try &.as_a?
            playlists.each do |item|
              title = item["title"]?.try &.as_s?.try &.delete("<>")
              description = item["description"]?.try &.as_s?.try &.delete("\r")
              privacy = item["privacy"]?.try &.as_s?.try { |privacy| PlaylistPrivacy.parse? privacy }

              return if !title
              return if !description
              return if !privacy

              playlist = create_playlist(title, privacy, user)
              Invidious::Database::Playlists.update_description(playlist.id, description)

              videos = item["videos"]?.try &.as_a?.try &.each_with_index do |video_id, idx|
                raise InfoException.new("Playlist cannot have more than 500 videos") if idx > 500

                video_id = video_id.try &.as_s?
                return if !video_id

                begin
                  video = get_video(video_id)
                rescue ex
                  return
                end

                playlist_video = PlaylistVideo.new({
                  title:          video.title,
                  id:             video.id,
                  author:         video.author,
                  ucid:           video.ucid,
                  length_seconds: video.length_seconds,
                  published:      video.published,
                  plid:           playlist.id,
                  live_now:       video.live_now,
                  index:          Random::Secure.rand(0_i64..Int64::MAX),
                })

                Invidious::Database::PlaylistVideos.insert(playlist_video)
                Invidious::Database::Playlists.update_video_added(playlist.id, playlist_video.index)
              end
            end
          end
        when "import_youtube"
          filename = part.filename || ""
          extension = filename.split(".").last

          if extension == "xml" || type == "application/xml" || type == "text/xml"
            subscriptions = XML.parse(body)
            user.subscriptions += subscriptions.xpath_nodes(%q(//outline[@type="rss"])).map do |channel|
              channel["xmlUrl"].match(/UC[a-zA-Z0-9_-]{22}/).not_nil![0]
            end
          elsif extension == "json" || type == "application/json"
            subscriptions = JSON.parse(body)
            user.subscriptions += subscriptions.as_a.compact_map do |entry|
              entry["snippet"]["resourceId"]["channelId"].as_s
            end
          elsif extension == "csv" || type == "text/csv"
            subscriptions = parse_subscription_export_csv(body)
            user.subscriptions += subscriptions
          else
            haltf(env, status_code: 415,
              response: error_template(415, "Invalid subscription file uploaded")
            )
          end

          user.subscriptions.uniq!
          user.subscriptions = get_batch_channels(user.subscriptions, false, false)

          Invidious::Database::Users.update_subscriptions(user)
        when "import_freetube"
          user.subscriptions += body.scan(/"channelId":"(?<channel_id>[a-zA-Z0-9_-]{24})"/).map do |md|
            md["channel_id"]
          end
          user.subscriptions.uniq!

          user.subscriptions = get_batch_channels(user.subscriptions, false, false)

          Invidious::Database::Users.update_subscriptions(user)
        when "import_newpipe_subscriptions"
          body = JSON.parse(body)
          user.subscriptions += body["subscriptions"].as_a.compact_map do |channel|
            if match = channel["url"].as_s.match(/\/channel\/(?<channel>UC[a-zA-Z0-9_-]{22})/)
              return match["channel"]
            elsif match = channel["url"].as_s.match(/\/user\/(?<user>.+)/)
              response = YT_POOL.client &.get("/user/#{match["user"]}?disable_polymer=1&hl=en&gl=US")
              html = XML.parse_html(response.body)
              ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]
              return ucid if ucid
            end

            nil
          end
          user.subscriptions.uniq!

          user.subscriptions = get_batch_channels(user.subscriptions, false, false)

          Invidious::Database::Users.update_subscriptions(user)
        when "import_newpipe"
          Compress::Zip::Reader.open(IO::Memory.new(body)) do |file|
            file.each_entry do |entry|
              if entry.filename == "newpipe.db"
                tempfile = File.tempfile(".db")
                File.write(tempfile.path, entry.io.gets_to_end)
                db = DB.open("sqlite3://" + tempfile.path)

                user.watched += db.query_all("SELECT url FROM streams", as: String).map(&.lchop("https://www.youtube.com/watch?v="))
                user.watched.uniq!

                Invidious::Database::Users.update_watch_history(user)

                user.subscriptions += db.query_all("SELECT url FROM subscriptions", as: String).map(&.lchop("https://www.youtube.com/channel/"))
                user.subscriptions.uniq!

                user.subscriptions = get_batch_channels(user.subscriptions, false, false)

                Invidious::Database::Users.update_subscriptions(user)

                db.close
                tempfile.delete
              end
            end
          end
        else nil # Ignore
        end
      end
    end

    env.redirect referer
  end
end
