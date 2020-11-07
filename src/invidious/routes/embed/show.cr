class Invidious::Routes::Embed::Show < Invidious::Routes::BaseRoute
  def handle(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    id = env.params.url["id"]

    plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    continuation = process_continuation(PG_DB, env.params.query, plid, id)

    if md = env.params.query["playlist"]?
         .try &.match(/[a-zA-Z0-9_-]{11}(,[a-zA-Z0-9_-]{11})*/)
      video_series = md[0].split(",")
      env.params.query.delete("playlist")
    end

    preferences = env.get("preferences").as(Preferences)

    if id.includes?("%20") || id.includes?("+") || env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
      id = env.params.url["id"].gsub("%20", "").delete("+")

      url = "/embed/#{id}"

      if env.params.query.size > 0
        url += "?#{env.params.query.to_s.gsub("%20", "").delete("+")}"
      end

      return env.redirect url
    end

    # YouTube embed supports `videoseries` with either `list=PLID`
    # or `playlist=VIDEO_ID,VIDEO_ID`
    case id
    when "videoseries"
      url = ""

      if plid
        begin
          playlist = get_playlist(PG_DB, plid, locale: locale)
          offset = env.params.query["index"]?.try &.to_i? || 0
          videos = get_playlist_videos(PG_DB, playlist, offset: offset, locale: locale)
        rescue ex
          error_message = ex.message
          env.response.status_code = 500
          return templated "error"
        end

        url = "/embed/#{videos[0].id}"
      elsif video_series
        url = "/embed/#{video_series.shift}"
        env.params.query["playlist"] = video_series.join(",")
      else
        return env.redirect "/"
      end

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    when "live_stream"
      response = YT_POOL.client &.get("/embed/live_stream?channel=#{env.params.query["channel"]? || ""}")
      video_id = response.body.match(/"video_id":"(?<video_id>[a-zA-Z0-9_-]{11})"/).try &.["video_id"]

      env.params.query.delete_all("channel")

      if !video_id || video_id == "live_stream"
        error_message = "Video is unavailable."
        return templated "error"
      end

      url = "/embed/#{video_id}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    when id.size > 11
      url = "/embed/#{id[0, 11]}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end

      return env.redirect url
    else nil # Continue
    end

    params = process_video_params(env.params.query, preferences)

    user = env.get?("user").try &.as(User)
    if user
      subscriptions = user.subscriptions
      watched = user.watched
      notifications = user.notifications
    end
    subscriptions ||= [] of String

    begin
      video = get_video(id, PG_DB, region: params.region)
    rescue ex : VideoRedirect
      return env.redirect env.request.resource.gsub(id, ex.video_id)
    rescue ex
      error_message = ex.message
      env.response.status_code = 500
      return templated "error"
    end

    if preferences.annotations_subscribed &&
       subscriptions.includes?(video.ucid) &&
       (env.params.query["iv_load_policy"]? || "1") == "1"
      params.annotations = true
    end

    # if watched && !watched.includes? id
    #   PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
    # end

    if notifications && notifications.includes? id
      PG_DB.exec("UPDATE users SET notifications = array_remove(notifications, $1) WHERE email = $2", id, user.as(User).email)
      env.get("user").as(User).notifications.delete(id)
      notifications.delete(id)
    end

    fmt_stream = video.fmt_stream
    adaptive_fmts = video.adaptive_fmts

    if params.local
      fmt_stream.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
      adaptive_fmts.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).full_path) }
    end

    video_streams = video.video_streams
    audio_streams = video.audio_streams

    if audio_streams.empty? && !video.live_now
      if params.quality == "dash"
        env.params.query.delete_all("quality")
        return env.redirect "/embed/#{id}?#{env.params.query}"
      elsif params.listen
        env.params.query.delete_all("listen")
        env.params.query["listen"] = "0"
        return env.redirect "/embed/#{id}?#{env.params.query}"
      end
    end

    captions = video.captions

    preferred_captions = captions.select { |caption|
      params.preferred_captions.includes?(caption.name.simpleText) ||
        params.preferred_captions.includes?(caption.languageCode.split("-")[0])
    }
    preferred_captions.sort_by! { |caption|
      (params.preferred_captions.index(caption.name.simpleText) ||
        params.preferred_captions.index(caption.languageCode.split("-")[0])).not_nil!
    }
    captions = captions - preferred_captions

    aspect_ratio = nil

    thumbnail = "/vi/#{video.id}/maxres.jpg"

    if params.raw
      url = fmt_stream[0]["url"].as_s

      fmt_stream.each do |fmt|
        url = fmt["url"].as_s if fmt["quality"].as_s == params.quality
      end

      return env.redirect url
    end

    rendered "embed"
  end
end
