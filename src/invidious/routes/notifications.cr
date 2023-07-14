module Invidious::Routes::Notifications
  # /modify_notifications
  # will "ding" all subscriptions.
  # /modify_notifications?receive_all_updates=false&receive_no_updates=false
  # will "unding" all subscriptions.
  def self.modify(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, "/")

    redirect = env.params.query["redirect"]?
    redirect ||= "false"
    redirect = redirect == "true"

    if !user
      if redirect
        return env.redirect referer
      else
        return error_json(403, "No such user")
      end
    end

    user = user.as(User)

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end
end
