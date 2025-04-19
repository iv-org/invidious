{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Misc
  def self.home(env)
    preferences = env.get("preferences").as(Preferences)
    locale = preferences.locale
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
        env.redirect "/feed/playlists"
      else
        env.redirect "/feed/popular"
      end
    else
      templated "search_homepage", navbar_search: false
    end
  end

  def self.privacy(env)
    locale = env.get("preferences").as(Preferences).locale
    templated "privacy"
  end

  def self.licenses(env)
    locale = env.get("preferences").as(Preferences).locale
    rendered "licenses"
  end

  def self.cross_instance_redirect(env)
    referer = get_referer(env)

    instance_list = Invidious::Jobs::InstanceListRefreshJob::INSTANCES["INSTANCES"]
    # Filter out the current instance
    other_available_instances = instance_list.reject { |_, domain| domain == CONFIG.domain }

    if other_available_instances.empty?
      # If the current instance is the only one, use the redirect URL as fallback
      instance_url = "redirect.invidious.io"
    else
      # Select other random instance
      # Sample returns an array
      # Instances are packaged as {region, domain} in the instance list
      instance_url = other_available_instances.sample(1)[0][1]
    end

    env.redirect "https://#{instance_url}#{referer}"
  end
end
