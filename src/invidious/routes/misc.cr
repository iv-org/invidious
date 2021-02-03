class Invidious::Routes::Misc < Invidious::Routes::BaseRoute
  def home(env)
    preferences = env.get("preferences").as(Preferences)
    locale = LOCALES[preferences.locale]?
    user = env.get? "user"

    case preferences.default_home
    when "Popular"
      env.redirect "/feed/popular"
    when "Trending"
      env.redirect "/feed/trending"
    when "Subscriptions"
      if user
        env.redirect "/feed/subscriptions"
      else
        env.redirect "/feed/popular"
      end
    when "Playlists"
      if user
        env.redirect "/view_all_playlists"
      else
        env.redirect "/feed/popular"
      end
    else
      templated "empty"
    end
  end

  def privacy(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    templated "privacy"
  end

  def licenses(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    rendered "licenses"
  end
end
