{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Watch
  def self.handle(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    region = env.params.query["region"]?

    if env.params.query.to_s.includes?("%20") || env.params.query.to_s.includes?("+")
      url = "/watch?" + env.params.query.to_s.gsub("%20", "").delete("+")
      return env.redirect url
    end

    if env.params.query["v"]?
      id = env.params.query["v"]

      if env.params.query["v"].empty?
        return error_template(400, "Invalid parameters.")
      end

      if id.size > 11
        url = "/watch?v=#{id[0, 11]}"
        env.params.query.delete_all("v")
        if env.params.query.size > 0
          url += "&#{env.params.query}"
        end

        return env.redirect url
      end
    else
      return env.redirect "/"
    end

    embed_link = "/embed/#{id}"
    if env.params.query.size > 1
      embed_params = HTTP::Params.parse(env.params.query.to_s)
      embed_params.delete_all("v")
      embed_link += "?"
      embed_link += embed_params.to_s
    end

    plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    continuation = process_continuation(PG_DB, env.params.query, plid, id)

    nojs = env.params.query["nojs"]?

    nojs ||= "0"
    nojs = nojs == "1"

    preferences = env.get("preferences").as(Preferences)

    user = env.get?("user").try &.as(User)
    if user
      subscriptions = user.subscriptions
      watched = user.watched
      notifications = user.notifications
    end
    subscriptions ||= [] of String

    params = process_video_params(env.params.query, preferences)
    env.params.query.delete_all("listen")

    begin
      video = get_video(id, PG_DB, region: params.region)
    rescue ex : VideoRedirect
      return env.redirect env.request.resource.gsub(id, ex.video_id)
    rescue ex
      LOGGER.error("get_video: #{id} : #{ex.message}")
      return error_template(500, ex)
    end

    if preferences.annotations_subscribed &&
       subscriptions.includes?(video.ucid) &&
       (env.params.query["iv_load_policy"]? || "1") == "1"
      params.annotations = true
    end
    env.params.query.delete_all("iv_load_policy")

    if watched && !watched.includes? id
      PG_DB.exec("UPDATE users SET watched = array_append(watched, $1) WHERE email = $2", id, user.as(User).email)
    end

    if notifications && notifications.includes? id
      PG_DB.exec("UPDATE users SET notifications = array_remove(notifications, $1) WHERE email = $2", id, user.as(User).email)
      env.get("user").as(User).notifications.delete(id)
      notifications.delete(id)
    end

    if nojs
      if preferences
        source = preferences.comments[0]
        if source.empty?
          source = preferences.comments[1]
        end

        if source == "youtube"
          begin
            comment_html = JSON.parse(fetch_youtube_comments(id, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
          rescue ex
            if preferences.comments[1] == "reddit"
              comments, reddit_thread = fetch_reddit_comments(id)
              comment_html = template_reddit_comments(comments, locale)

              comment_html = fill_links(comment_html, "https", "www.reddit.com")
              comment_html = replace_links(comment_html)
            end
          end
        elsif source == "reddit"
          begin
            comments, reddit_thread = fetch_reddit_comments(id)
            comment_html = template_reddit_comments(comments, locale)

            comment_html = fill_links(comment_html, "https", "www.reddit.com")
            comment_html = replace_links(comment_html)
          rescue ex
            if preferences.comments[1] == "youtube"
              comment_html = JSON.parse(fetch_youtube_comments(id, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
            end
          end
        end
      else
        comment_html = JSON.parse(fetch_youtube_comments(id, nil, "html", locale, preferences.thin_mode, region))["contentHtml"]
      end

      comment_html ||= ""
    end

    fmt_stream = video.fmt_stream
    adaptive_fmts = video.adaptive_fmts

    if params.local
      fmt_stream.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).request_target) }
      adaptive_fmts.each { |fmt| fmt["url"] = JSON::Any.new(URI.parse(fmt["url"].as_s).request_target) }
    end

    video_streams = video.video_streams
    audio_streams = video.audio_streams

    # Older videos may not have audio sources available.
    # We redirect here so they're not unplayable
    if audio_streams.empty? && !video.live_now
      if params.quality == "dash"
        env.params.query.delete_all("quality")
        env.params.query["quality"] = "medium"
        return env.redirect "/watch?#{env.params.query}"
      elsif params.listen
        env.params.query.delete_all("listen")
        env.params.query["listen"] = "0"
        return env.redirect "/watch?#{env.params.query}"
      end
    end

    captions = video.captions

    preferred_captions = captions.select { |caption|
      params.preferred_captions.includes?(caption.name) ||
        params.preferred_captions.includes?(caption.language_code.split("-")[0])
    }
    preferred_captions.sort_by! { |caption|
      (params.preferred_captions.index(caption.name) ||
        params.preferred_captions.index(caption.language_code.split("-")[0])).not_nil!
    }
    captions = captions - preferred_captions

    aspect_ratio = "16:9"

    thumbnail = "/vi/#{video.id}/maxres.jpg"

    if params.raw
      if params.listen
        url = audio_streams[0]["url"].as_s

        if params.quality.ends_with? "k"
          audio_streams.each do |fmt|
            if fmt["bitrate"].as_i == params.quality.rchop("k").to_i
              url = fmt["url"].as_s
            end
          end
        end
      else
        url = fmt_stream[0]["url"].as_s

        fmt_stream.each do |fmt|
          if fmt["quality"].as_s == params.quality
            url = fmt["url"].as_s
          end
        end
      end

      return env.redirect url
    end

    templated "watch"
  end

  def self.redirect(env)
    url = "/watch?v=#{env.params.url["id"]}"
    if env.params.query.size > 0
      url += "&#{env.params.query}"
    end

    return env.redirect url
  end
end
