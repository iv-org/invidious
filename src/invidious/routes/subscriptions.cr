module Invidious::Routes::Subscriptions
  def self.toggle_subscription(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env, "/")

    redirect = env.params.query["redirect"]?
    redirect ||= "true"
    redirect = redirect == "true"

    if !user
      if redirect
        return env.redirect referer
      else
        return error_json(403, "No such user")
      end
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      if redirect
        return error_template(400, ex)
      else
        return error_json(400, ex)
      end
    end

    if env.params.query["action_create_subscription_to_channel"]?.try &.to_i?.try &.== 1
      action = "action_create_subscription_to_channel"
    elsif env.params.query["action_remove_subscriptions"]?.try &.to_i?.try &.== 1
      action = "action_remove_subscriptions"
    else
      return env.redirect referer
    end

    channel_id = env.params.query["c"]?
    channel_id ||= ""

    if !user.password
      # Sync subscriptions with YouTube
      subscribe_ajax(channel_id, action, env.request.headers)
    end

    case action
    when "action_create_subscription_to_channel"
      if !user.subscriptions.includes? channel_id
        get_channel(channel_id)
        Invidious::Database::Users.subscribe_channel(user, channel_id)
      end
    when "action_remove_subscriptions"
      Invidious::Database::Users.unsubscribe_channel(user, channel_id)
    else
      return error_json(400, "Unsupported action #{action}")
    end

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end

  def self.subscription_manager(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    if !user
      return env.redirect referer
    end

    user = user.as(User)
    sid = sid.as(String)

    if !user.password
      # Refresh account
      headers = HTTP::Headers.new
      headers["Cookie"] = env.request.headers["Cookie"]

      user, sid = get_user(sid, headers)
    end

    action_takeout = env.params.query["action_takeout"]?.try &.to_i?
    action_takeout ||= 0
    action_takeout = action_takeout == 1

    format = env.params.query["format"]?
    format ||= "rss"

    subscriptions = Invidious::Database::Channels.select(user.subscriptions)
    subscriptions.sort_by!(&.author.downcase)

    if action_takeout
      if format == "json"
        env.response.content_type = "application/json"
        env.response.headers["content-disposition"] = "attachment"

        return Invidious::User::Export.to_invidious(user)
      else
        env.response.content_type = "application/xml"
        env.response.headers["content-disposition"] = "attachment"
        export = XML.build do |xml|
          xml.element("opml", version: "1.1") do
            xml.element("body") do
              if format == "newpipe"
                title = "YouTube Subscriptions"
              else
                title = "Invidious Subscriptions"
              end

              xml.element("outline", text: title, title: title) do
                subscriptions.each do |channel|
                  if format == "newpipe"
                    xml_url = "https://www.youtube.com/feeds/videos.xml?channel_id=#{channel.id}"
                  else
                    xml_url = "#{HOST_URL}/feed/channel/#{channel.id}"
                  end

                  xml.element("outline", text: channel.author, title: channel.author,
                    "type": "rss", xmlUrl: xml_url)
                end
              end
            end
          end
        end

        return export.gsub(%(<?xml version="1.0"?>\n), "")
      end
    end

    templated "user/subscription_manager"
  end
end
