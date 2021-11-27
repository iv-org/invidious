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

    if !user.password
      channel_req = {} of String => String

      channel_req["receive_all_updates"] = env.params.query["receive_all_updates"]? || "true"
      channel_req["receive_no_updates"] = env.params.query["receive_no_updates"]? || ""
      channel_req["receive_post_updates"] = env.params.query["receive_post_updates"]? || "true"

      channel_req.reject! { |k, v| v != "true" && v != "false" }

      headers = HTTP::Headers.new
      headers["Cookie"] = env.request.headers["Cookie"]

      html = YT_POOL.client &.get("/subscription_manager?disable_polymer=1", headers)

      cookies = HTTP::Cookies.from_client_headers(headers)
      html.cookies.each do |cookie|
        if {"VISITOR_INFO1_LIVE", "YSC", "SIDCC"}.includes? cookie.name
          if cookies[cookie.name]?
            cookies[cookie.name] = cookie
          else
            cookies << cookie
          end
        end
      end
      headers = cookies.add_request_headers(headers)

      if match = html.body.match(/'XSRF_TOKEN': "(?<session_token>[^"]+)"/)
        session_token = match["session_token"]
      else
        return env.redirect referer
      end

      headers["content-type"] = "application/x-www-form-urlencoded"
      channel_req["session_token"] = session_token

      subs = XML.parse_html(html.body)
      subs.xpath_nodes(%q(//a[@class="subscription-title yt-uix-sessionlink"]/@href)).each do |channel|
        channel_id = channel.content.lstrip("/channel/").not_nil!
        channel_req["channel_id"] = channel_id

        YT_POOL.client &.post("/subscription_ajax?action_update_subscription_preferences=1", headers, form: channel_req)
      end
    end

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end
end
