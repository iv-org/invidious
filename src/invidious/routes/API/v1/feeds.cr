class Invidious::Routes::V1Api < Invidious::Routes::BaseRoute
  def comments(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    region = env.params.query["region"]?

    env.response.content_type = "application/json"

    id = env.params.url["id"]

    source = env.params.query["source"]?
    source ||= "youtube"

    thin_mode = env.params.query["thin_mode"]?
    thin_mode = thin_mode == "true"

    format = env.params.query["format"]?
    format ||= "json"

    action = env.params.query["action"]?
    action ||= "action_get_comments"

    continuation = env.params.query["continuation"]?
    sort_by = env.params.query["sort_by"]?.try &.downcase

    if source == "youtube"
      sort_by ||= "top"

      begin
        comments = fetch_youtube_comments(id, PG_DB, continuation, format, locale, thin_mode, region, sort_by: sort_by, action: action)
      rescue ex
        return error_json(500, ex)
      end

      return comments
    elsif source == "reddit"
      sort_by ||= "confidence"

      begin
        comments, reddit_thread = fetch_reddit_comments(id, sort_by: sort_by)
        content_html = template_reddit_comments(comments, locale)

        content_html = fill_links(content_html, "https", "www.reddit.com")
        content_html = replace_links(content_html)
      rescue ex
        comments = nil
        reddit_thread = nil
        content_html = ""
      end

      if !reddit_thread || !comments
        env.response.status_code = 404
        return
      end

      if format == "json"
        reddit_thread = JSON.parse(reddit_thread.to_json).as_h
        reddit_thread["comments"] = JSON.parse(comments.to_json)

        return reddit_thread.to_json
      else
        response = {
          "title"       => reddit_thread.title,
          "permalink"   => reddit_thread.permalink,
          "contentHtml" => content_html,
        }

        return response.to_json
      end
    end
  end

  def trending(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    region = env.params.query["region"]?
    trending_type = env.params.query["type"]?

    begin
      trending, plid = fetch_trending(trending_type, region, locale)
    rescue ex
      return error_json(500, ex)
    end

    videos = JSON.build do |json|
      json.array do
        trending.each do |video|
          video.to_json(locale, json)
        end
      end
    end

    videos
  end

  def popular(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"

    if !CONFIG.popular_enabled
      error_message = {"error" => "Administrator has disabled this endpoint."}.to_json
      env.response.status_code = 400
      return error_message
    end

    JSON.build do |json|
      json.array do
        popular_videos.each do |video|
          video.to_json(locale, json)
        end
      end
    end
  end
end
