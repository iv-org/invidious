module Invidious::Routes::Misc
  def self.home(env)
    preferences = env.get("preferences").as(Preferences)
    locale = LOCALES[preferences.locale]?
    user = env.get? "user"

    case preferences.default_home
    when Settings::HomePages::Popular ; env.redirect "/feed/popular"
    when Settings::HomePages::Trending; env.redirect "/feed/trending"
    when Settings::UserHomePages::Subscriptions
      if user
        env.redirect "/feed/subscriptions"
      else
        env.redirect "/feed/popular"
      end
    when Settings::UserHomePages::Playlists
      if user
        env.redirect "/feed/playlists"
      else
        env.redirect "/feed/popular"
      end
    else # Settings::HomePages::Search
      env.redirect "/search"
    end
  end

  def self.privacy(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    templated "privacy"
  end

  def self.licenses(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    rendered "licenses"
  end

  def self.cross_instance_redirect(env)
    referer = get_referer(env)

    if !env.get("preferences").as(Preferences).automatic_instance_redirect
      return env.redirect("https://redirect.invidious.io#{referer}")
    end

    instance_url = fetch_random_instance
    env.redirect "https://#{instance_url}#{referer}"
  end
end
