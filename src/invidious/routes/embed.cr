{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Embed
  def self.redirect(env)
    locale = env.get("preferences").as(Preferences).locale
    if plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
      begin
        playlist = Invidious::Playlists::Playlists.get_playlist(plid)
        offset = env.params.query["index"]?.try &.to_i? || 0
        videos = Invidious::Playlists::Playlists.get_playlist_videos(playlist, offset: offset)
        if videos.empty?
          url = "/playlist?list=#{plid}"
          raise NotFoundException.new(I18n.translate(locale, "error_video_not_in_playlist", url))
        end

        first_playlist_video = videos[0].as(PlaylistVideo)
      rescue ex : NotFoundException
        return Errors.error_template(404, ex)
      rescue ex
        return Errors.error_template(500, ex)
      end

      url = "/embed/#{first_playlist_video.id}?#{env.params.query}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end
    else
      url = "/"
    end

    env.redirect url
  end

  def self.show(env)
    preferences = env.get("preferences").as(Preferences)
    locale = preferences.locale
    id = env.params.url["id"]

    plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    continuation = process_continuation(env.params.query, plid, id)

    if md = env.params.query["playlist"]?
         .try &.match(/[a-zA-Z0-9_-]{11}(,[a-zA-Z0-9_-]{11})*/)
      video_series = md[0].split(",")
      env.params.query.delete("playlist")
    end

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
          playlist = Invidious::Playlists::Playlists.get_playlist(plid)
          offset = env.params.query["index"]?.try &.to_i? || 0
          videos = Invidious::Playlists::Playlists.get_playlist_videos(playlist, offset: offset)
          if videos.empty?
            url = "/playlist?list=#{plid}"
            raise NotFoundException.new(I18n.translate(locale, "error_video_not_in_playlist", url))
          end

          first_playlist_video = videos[0].as(PlaylistVideo)
        rescue ex : NotFoundException
          return Errors.error_template(404, ex)
        rescue ex
          return Errors.error_template(500, ex)
        end

        url = "/embed/#{first_playlist_video.id}"
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
        return Errors.error_template(500, "Video is unavailable.")
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
    end

    params = Invidious::Videos.process_video_params(env.params.query, preferences)

    user = env.get?("user").try &.as(User)
    if user
      subscriptions = user.subscriptions
      watched = user.watched
      notifications = user.notifications
    end
    subscriptions ||= [] of String

    begin
      video = get_video(id, region: params.region)
    rescue ex : NotFoundException
      return Errors.error_template(404, ex)
    rescue ex
      return Errors.error_template(500, ex)
    end

    if preferences.annotations_subscribed &&
       subscriptions.includes?(video.ucid) &&
       (env.params.query["iv_load_policy"]? || "1") == "1"
      params.annotations = true
    end

    # if watched && !watched.includes? id
    #   PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
    # end

    # Keep the notification when no player can play the video on this instance
    playable = video.unplayable_reason.nil? && !(video.no_backend_streams? && CONFIG.disabled?("dash"))
    if CONFIG.enable_user_notifications && notifications && notifications.includes?(id) && playable
      Invidious::Database::Users.remove_notification(user.as(User), id)
      env.get("user").as(User).notifications.delete(id)
      notifications.delete(id)
    end

    fmt_stream = video.fmt_stream
    adaptive_fmts = video.adaptive_fmts

    if params.local
      fmt_stream.each { |fmt| fmt["url"] = JSON::Any.new(HttpServer::Utils.proxy_video_url(fmt["url"].as_s)) }
    end

    # Always proxy DASH streams, otherwise youtube CORS headers will prevent playback
    adaptive_fmts.each { |fmt| fmt["url"] = JSON::Any.new(HttpServer::Utils.proxy_video_url(fmt["url"].as_s)) }

    video_streams = video.video_streams
    audio_streams = video.audio_streams

    # No backend stream and SABR is disabled with DASH: nothing can play the video.
    if video.no_backend_streams? && CONFIG.disabled?("dash") && !params.raw
      return Errors.error_template(404, InfoException.new("This video can't be played on this instance: no video stream is available."))
    end

    # Without any stream from the backend (e.g. no Invidious companion), only
    # the SABR player can play the video, as it fetches the streams itself.
    # Raw requests need a backend stream, they are handled below.
    if video.no_backend_streams? && params.quality != "sabr" && !params.raw && !CONFIG.disabled?("dash")
      env.params.query.delete_all("quality")
      env.params.query["quality"] = "sabr"
      # `playlist` was consumed above: keep the rest of the series
      env.params.query["playlist"] = video_series.join(",") if video_series
      return env.redirect "/embed/#{id}?#{env.params.query}"
    end

    if audio_streams.empty? && !video.live_now && video.reason.nil?
      if params.quality == "dash"
        # Explicit quality: removing it would fall back to a saved "dash" preference
        # and redirect here again.
        env.params.query.delete_all("quality")
        # Without progressive streams either, only SABR can play (like /watch)
        env.params.query["quality"] = fmt_stream.empty? ? "sabr" : "medium"
        return env.redirect "/embed/#{id}?#{env.params.query}"
      elsif params.listen && params.quality != "sabr"
        # The SABR player fetches its own audio streams
        env.params.query.delete_all("listen")
        env.params.query["listen"] = "0"
        return env.redirect "/embed/#{id}?#{env.params.query}"
      end
    end

    captions = video.captions

    preferred_captions = captions.select do |caption|
      params.preferred_captions.includes?(caption.name) ||
        params.preferred_captions.includes?(caption.language_code.split("-")[0])
    end
    preferred_captions.sort_by! do |caption|
      (params.preferred_captions.index(caption.name) ||
        params.preferred_captions.index(caption.language_code.split("-")[0])).not_nil!
    end
    captions = captions - preferred_captions

    aspect_ratio = nil

    thumbnail = "/vi/#{video.id}/maxres.jpg"

    if params.raw
      if reason = video.reason
        return Errors.error_template(500, InfoException.new(video.subreason || reason))
      elsif fmt_stream.empty?
        return Errors.error_template(404, InfoException.new("No stream is available for this video on this instance."))
      end

      url = fmt_stream[0]["url"].as_s

      fmt_stream.each do |fmt|
        url = fmt["url"].as_s if fmt["quality"].as_s == params.quality
      end

      return env.redirect url
    end

    if CONFIG.invidious_companion.present?
      invidious_companion = CONFIG.invidious_companion.sample
    end

    # The SABR player is only rendered for playable videos (and upcoming premieres)
    if params.quality == "sabr" && video.unplayable_reason.nil?
      Invidious::Routes::BeforeAll.allow_eval_for_sabr_player(env)
    end

    rendered "embed"
  end
end
