class Invidious::Routes::Home < Invidious::Routes::BaseRoute
  def handle(env)
    preferences = env.get("preferences").as(Preferences)
    locale = LOCALES[preferences.locale]?
    user = env.get? "user"

    case preferences.default_home
    when ""
      templated "empty"
    when "Popular"
      templated "popular"
    when "Trending"
      env.redirect "/feed/trending"
    when "Subscriptions"
      if user
        env.redirect "/feed/subscriptions"
      else
        templated "popular"
      end
    when "Playlists"
      if user
        env.redirect "/view_all_playlists"
      else
        templated "popular"
      end
    else
      templated "empty"
    end
  end

  private def popular_videos
    Jobs::PullPopularVideosJob::POPULAR_VIDEOS.get
  end
end
