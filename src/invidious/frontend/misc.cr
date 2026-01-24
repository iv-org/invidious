module Invidious::Frontend::Misc
  extend self

  def redirect_url(env : HTTP::Server::Context)
    preferences = env.get("preferences").as(Preferences)

    if preferences.automatic_instance_redirect
      current_page = env.get?("current_page").as(String)
      "/redirect?referer=#{current_page}"
    else
      "https://redirect.invidious.io#{env.request.resource}"
    end
  end
end
