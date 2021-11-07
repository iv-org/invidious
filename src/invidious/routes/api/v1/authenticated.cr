module Invidious::Routes::API::V1::Authenticated
  # The notification APIs cannot be extracted yet!
  # They require the *local* notifications constant defined in invidious.cr
  #
  # def self.notifications(env)
  #   env.response.content_type = "text/event-stream"

  #   topics = env.params.body["topics"]?.try &.split(",").uniq.first(1000)
  #   topics ||= [] of String

  #   create_notification_stream(env, topics, connection_channel)
  # end

  def self.get_preferences(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)
    user.preferences.to_json
  end

  def self.set_preferences(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    begin
      preferences = Preferences.from_json(env.request.body || "{}")
    rescue
      preferences = user.preferences
    end

    PG_DB.exec("UPDATE users SET preferences = $1 WHERE email = $2", preferences.to_json, user.email)

    env.response.status_code = 204
  end

  def self.feed(env)
    env.response.content_type = "application/json"

    user = env.get("user").as(User)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    max_results = env.params.query["max_results"]?.try &.to_i?
    max_results ||= user.preferences.max_results
    max_results ||= CONFIG.default_user_preferences.max_results

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    videos, notifications = get_subscription_feed(PG_DB, user, max_results, page)

    JSON.build do |json|
      json.object do
        json.field "notifications" do
          json.array do
            notifications.each do |video|
              video.to_json(locale, json)
            end
          end
        end

        json.field "videos" do
          json.array do
            videos.each do |video|
              video.to_json(locale, json)
            end
          end
        end
      end
    end
  end

  def self.get_subscriptions(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    if user.subscriptions.empty?
      values = "'{}'"
    else
      values = "VALUES #{user.subscriptions.map { |id| %(('#{id}')) }.join(",")}"
    end

    subscriptions = PG_DB.query_all("SELECT * FROM channels WHERE id = ANY(#{values})", as: InvidiousChannel)

    JSON.build do |json|
      json.array do
        subscriptions.each do |subscription|
          json.object do
            json.field "author", subscription.author
            json.field "authorId", subscription.id
          end
        end
      end
    end
  end

  def self.subscribe_channel(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    ucid = env.params.url["ucid"]

    if !user.subscriptions.includes? ucid
      get_channel(ucid, PG_DB, false, false)
      PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_append(subscriptions,$1) WHERE email = $2", ucid, user.email)
    end

    # For Google accounts, access tokens don't have enough information to
    # make a request on the user's behalf, which is why we don't sync with
    # YouTube.

    env.response.status_code = 204
  end

  def self.unsubscribe_channel(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    ucid = env.params.url["ucid"]

    PG_DB.exec("UPDATE users SET feed_needs_update = true, subscriptions = array_remove(subscriptions, $1) WHERE email = $2", ucid, user.email)

    env.response.status_code = 204
  end

  def self.list_playlists(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    playlists = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1", user.email, as: InvidiousPlaylist)

    JSON.build do |json|
      json.array do
        playlists.each do |playlist|
          playlist.to_json(0, locale, json)
        end
      end
    end
  end

  def self.create_playlist(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    title = env.params.json["title"]?.try &.as(String).delete("<>").byte_slice(0, 150)
    if !title
      return error_json(400, "Invalid title.")
    end

    privacy = env.params.json["privacy"]?.try { |privacy| PlaylistPrivacy.parse(privacy.as(String).downcase) }
    if !privacy
      return error_json(400, "Invalid privacy setting.")
    end

    if PG_DB.query_one("SELECT count(*) FROM playlists WHERE author = $1", user.email, as: Int64) >= 100
      return error_json(400, "User cannot have more than 100 playlists.")
    end

    playlist = create_playlist(PG_DB, title, privacy, user)
    env.response.headers["Location"] = "#{HOST_URL}/api/v1/auth/playlists/#{playlist.id}"
    env.response.status_code = 201
    {
      "title"      => title,
      "playlistId" => playlist.id,
    }.to_json
  end

  def self.update_playlist_attribute(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    plid = env.params.url["plid"]

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email && playlist.privacy.private?
      return error_json(404, "Playlist does not exist.")
    end

    if playlist.author != user.email
      return error_json(403, "Invalid user")
    end

    title = env.params.json["title"].try &.as(String).delete("<>").byte_slice(0, 150) || playlist.title
    privacy = env.params.json["privacy"]?.try { |privacy| PlaylistPrivacy.parse(privacy.as(String).downcase) } || playlist.privacy
    description = env.params.json["description"]?.try &.as(String).delete("\r") || playlist.description

    if title != playlist.title ||
       privacy != playlist.privacy ||
       description != playlist.description
      updated = Time.utc
    else
      updated = playlist.updated
    end

    PG_DB.exec("UPDATE playlists SET title = $1, privacy = $2, description = $3, updated = $4 WHERE id = $5", title, privacy, description, updated, plid)
    env.response.status_code = 204
  end

  def self.delete_playlist(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    plid = env.params.url["plid"]

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email && playlist.privacy.private?
      return error_json(404, "Playlist does not exist.")
    end

    if playlist.author != user.email
      return error_json(403, "Invalid user")
    end

    PG_DB.exec("DELETE FROM playlist_videos * WHERE plid = $1", plid)
    PG_DB.exec("DELETE FROM playlists * WHERE id = $1", plid)

    env.response.status_code = 204
  end

  def self.insert_video_into_playlist(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    plid = env.params.url["plid"]

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email && playlist.privacy.private?
      return error_json(404, "Playlist does not exist.")
    end

    if playlist.author != user.email
      return error_json(403, "Invalid user")
    end

    if playlist.index.size >= 500
      return error_json(400, "Playlist cannot have more than 500 videos")
    end

    video_id = env.params.json["videoId"].try &.as(String)
    if !video_id
      return error_json(403, "Invalid videoId")
    end

    begin
      video = get_video(video_id, PG_DB)
    rescue ex
      return error_json(500, ex)
    end

    playlist_video = PlaylistVideo.new({
      title:          video.title,
      id:             video.id,
      author:         video.author,
      ucid:           video.ucid,
      length_seconds: video.length_seconds,
      published:      video.published,
      plid:           plid,
      live_now:       video.live_now,
      index:          Random::Secure.rand(0_i64..Int64::MAX),
    })

    video_array = playlist_video.to_a
    args = arg_array(video_array)

    PG_DB.exec("INSERT INTO playlist_videos VALUES (#{args})", args: video_array)
    PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = cardinality(index) + 1, updated = $2 WHERE id = $3", playlist_video.index, Time.utc, plid)

    env.response.headers["Location"] = "#{HOST_URL}/api/v1/auth/playlists/#{plid}/videos/#{playlist_video.index.to_u64.to_s(16).upcase}"
    env.response.status_code = 201

    JSON.build do |json|
      playlist_video.to_json(json, index: playlist.index.size)
    end
  end

  def self.delete_video_in_playlist(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    env.response.content_type = "application/json"
    user = env.get("user").as(User)

    plid = env.params.url["plid"]
    index = env.params.url["index"].to_i64(16)

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email && playlist.privacy.private?
      return error_json(404, "Playlist does not exist.")
    end

    if playlist.author != user.email
      return error_json(403, "Invalid user")
    end

    if !playlist.index.includes? index
      return error_json(404, "Playlist does not contain index")
    end

    PG_DB.exec("DELETE FROM playlist_videos * WHERE index = $1", index)
    PG_DB.exec("UPDATE playlists SET index = array_remove(index, $1), video_count = cardinality(index) - 1, updated = $2 WHERE id = $3", index, Time.utc, plid)

    env.response.status_code = 204
  end

  # Invidious::Routing.patch "/api/v1/auth/playlists/:plid/videos/:index"
  # def modify_playlist_at(env)
  # TODO
  # end

  def self.get_tokens(env)
    env.response.content_type = "application/json"
    user = env.get("user").as(User)
    scopes = env.get("scopes").as(Array(String))

    tokens = PG_DB.query_all("SELECT id, issued FROM session_ids WHERE email = $1", user.email, as: {session: String, issued: Time})

    JSON.build do |json|
      json.array do
        tokens.each do |token|
          json.object do
            json.field "session", token[:session]
            json.field "issued", token[:issued].to_unix
          end
        end
      end
    end
  end

  def self.register_token(env)
    user = env.get("user").as(User)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    case env.request.headers["Content-Type"]?
    when "application/x-www-form-urlencoded"
      scopes = env.params.body.select { |k, _| k.match(/^scopes\[\d+\]$/) }.map { |_, v| v }
      callback_url = env.params.body["callbackUrl"]?
      expire = env.params.body["expire"]?.try &.to_i?
    when "application/json"
      scopes = env.params.json["scopes"].as(Array).map(&.as_s)
      callback_url = env.params.json["callbackUrl"]?.try &.as(String)
      expire = env.params.json["expire"]?.try &.as(Int64)
    else
      return error_json(400, "Invalid or missing header 'Content-Type'")
    end

    if callback_url && callback_url.empty?
      callback_url = nil
    end

    if callback_url
      callback_url = URI.parse(callback_url)
    end

    if sid = env.get?("sid").try &.as(String)
      env.response.content_type = "text/html"

      csrf_token = generate_response(sid, {":authorize_token"}, HMAC_KEY, PG_DB, use_nonce: true)
      return templated "authorize_token"
    else
      env.response.content_type = "application/json"

      superset_scopes = env.get("scopes").as(Array(String))

      authorized_scopes = [] of String
      scopes.each do |scope|
        if scopes_include_scope(superset_scopes, scope)
          authorized_scopes << scope
        end
      end

      access_token = generate_token(user.email, authorized_scopes, expire, HMAC_KEY, PG_DB)

      if callback_url
        access_token = URI.encode_www_form(access_token)

        if query = callback_url.query
          query = HTTP::Params.parse(query.not_nil!)
        else
          query = HTTP::Params.new
        end

        query["token"] = access_token
        callback_url.query = query.to_s

        env.redirect callback_url.to_s
      else
        access_token
      end
    end
  end

  def self.unregister_token(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    env.response.content_type = "application/json"
    user = env.get("user").as(User)
    scopes = env.get("scopes").as(Array(String))

    session = env.params.json["session"]?.try &.as(String)
    session ||= env.get("session").as(String)

    # Allow tokens to revoke other tokens with correct scope
    if session == env.get("session").as(String)
      PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", session)
    elsif scopes_include_scope(scopes, "GET:tokens")
      PG_DB.exec("DELETE FROM session_ids * WHERE id = $1", session)
    else
      return error_json(400, "Cannot revoke session #{session}")
    end

    env.response.status_code = 204
  end
end
