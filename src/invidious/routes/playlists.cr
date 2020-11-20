class Invidious::Routes::Playlists < Invidious::Routes::BaseRoute
  def index(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)

    items_created = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1 AND id LIKE 'IV%' ORDER BY created", user.email, as: InvidiousPlaylist)
    items_created.map! do |item|
      item.author = ""
      item
    end

    items_saved = PG_DB.query_all("SELECT * FROM playlists WHERE author = $1 AND id NOT LIKE 'IV%' ORDER BY created", user.email, as: InvidiousPlaylist)
    items_saved.map! do |item|
      item.author = ""
      item
    end

    templated "view_all_playlists"
  end

  def new(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":create_playlist"}, HMAC_KEY, PG_DB)

    templated "create_playlist"
  end

  def create(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      return templated "error"
    end

    title = env.params.body["title"]?.try &.as(String)
    if !title || title.empty?
      error_message = "Title cannot be empty."
      return templated "error"
    end

    privacy = PlaylistPrivacy.parse?(env.params.body["privacy"]?.try &.as(String) || "")
    if !privacy
      error_message = "Invalid privacy setting."
      return templated "error"
    end

    if PG_DB.query_one("SELECT count(*) FROM playlists WHERE author = $1", user.email, as: Int64) >= 100
      error_message = "User cannot have more than 100 playlists."
      return templated "error"
    end

    playlist = create_playlist(PG_DB, title, privacy, user)

    env.redirect "/playlist?list=#{playlist.id}"
  end

  def subscribe(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)

    playlist_id = env.params.query["list"]
    playlist = get_playlist(PG_DB, playlist_id, locale)
    subscribe_playlist(PG_DB, user, playlist)

    env.redirect "/playlist?list=#{playlist.id}"
  end

  def delete_page(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    plid = env.params.query["list"]?
    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      return env.redirect referer
    end

    csrf_token = generate_response(sid, {":delete_playlist"}, HMAC_KEY, PG_DB)

    templated "delete_playlist"
  end

  def delete(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    plid = env.params.query["list"]?
    return env.redirect referer if plid.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      return templated "error"
    end

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      return env.redirect referer
    end

    PG_DB.exec("DELETE FROM playlist_videos * WHERE plid = $1", plid)
    PG_DB.exec("DELETE FROM playlists * WHERE id = $1", plid)

    env.redirect "/view_all_playlists"
  end

  def edit(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    plid = env.params.query["list"]?
    if !plid || !plid.starts_with?("IV")
      return env.redirect referer
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    begin
      playlist = PG_DB.query_one("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
      if !playlist || playlist.author != user.email
        return env.redirect referer
      end
    rescue ex
      return env.redirect referer
    end

    begin
      videos = get_playlist_videos(PG_DB, playlist, offset: (page - 1) * 100, locale: locale)
    rescue ex
      videos = [] of PlaylistVideo
    end

    csrf_token = generate_response(sid, {":edit_playlist"}, HMAC_KEY, PG_DB)

    templated "edit_playlist"
  end

  def update(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    plid = env.params.query["list"]?
    return env.redirect referer if plid.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 400
      return templated "error"
    end

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      return env.redirect referer
    end

    title = env.params.body["title"]?.try &.delete("<>") || ""
    privacy = PlaylistPrivacy.parse(env.params.body["privacy"]? || "Public")
    description = env.params.body["description"]?.try &.delete("\r") || ""

    if title != playlist.title ||
       privacy != playlist.privacy ||
       description != playlist.description
      updated = Time.utc
    else
      updated = playlist.updated
    end

    PG_DB.exec("UPDATE playlists SET title = $1, privacy = $2, description = $3, updated = $4 WHERE id = $5", title, privacy, description, updated, plid)

    env.redirect "/playlist?list=#{plid}"
  end

  def add_playlist_items_page(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    plid = env.params.query["list"]?
    if !plid || !plid.starts_with?("IV")
      return env.redirect referer
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    begin
      playlist = PG_DB.query_one("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
      if !playlist || playlist.author != user.email
        return env.redirect referer
      end
    rescue ex
      return env.redirect referer
    end

    query = env.params.query["q"]?
    if query
      begin
        search_query, count, items = process_search_query(query, page, user, region: nil)
        videos = items.select { |item| item.is_a? SearchVideo }.map { |item| item.as(SearchVideo) }
      rescue ex
        videos = [] of SearchVideo
        count = 0
      end
    else
      videos = [] of SearchVideo
      count = 0
    end

    env.set "add_playlist_items", plid
    templated "add_playlist_items"
  end

  def playlist_ajax(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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
        error_message = {"error" => "No such user"}.to_json
        env.response.status_code = 403
        return error_message
      end
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      if redirect
        error_message = ex.message
        env.response.status_code = 400
        return templated "error"
      else
        error_message = {"error" => ex.message}.to_json
        env.response.status_code = 400
        return error_message
      end
    end

    if env.params.query["action_create_playlist"]?
      action = "action_create_playlist"
    elsif env.params.query["action_delete_playlist"]?
      action = "action_delete_playlist"
    elsif env.params.query["action_edit_playlist"]?
      action = "action_edit_playlist"
    elsif env.params.query["action_add_video"]?
      action = "action_add_video"
      video_id = env.params.query["video_id"]
    elsif env.params.query["action_remove_video"]?
      action = "action_remove_video"
    elsif env.params.query["action_move_video_before"]?
      action = "action_move_video_before"
    else
      return env.redirect referer
    end

    begin
      playlist_id = env.params.query["playlist_id"]
      playlist = get_playlist(PG_DB, playlist_id, locale).as(InvidiousPlaylist)
      raise "Invalid user" if playlist.author != user.email
    rescue ex
      if redirect
        error_message = ex.message
        env.response.status_code = 400
        return templated "error"
      else
        error_message = {"error" => ex.message}.to_json
        env.response.status_code = 400
        return error_message
      end
    end

    if !user.password
      # TODO: Playlist stub, sync with YouTube for Google accounts
      # playlist_ajax(playlist_id, action, env.request.headers)
    end
    email = user.email

    case action
    when "action_edit_playlist"
      # TODO: Playlist stub
    when "action_add_video"
      if playlist.index.size >= 500
        env.response.status_code = 400
        if redirect
          error_message = "Playlist cannot have more than 500 videos"
          return templated "error"
        else
          error_message = {"error" => "Playlist cannot have more than 500 videos"}.to_json
          return error_message
        end
      end

      video_id = env.params.query["video_id"]

      begin
        video = get_video(video_id, PG_DB)
      rescue ex
        env.response.status_code = 500
        if redirect
          error_message = ex.message
          return templated "error"
        else
          error_message = {"error" => ex.message}.to_json
          return error_message
        end
      end

      playlist_video = PlaylistVideo.new({
        title:          video.title,
        id:             video.id,
        author:         video.author,
        ucid:           video.ucid,
        length_seconds: video.length_seconds,
        published:      video.published,
        plid:           playlist_id,
        live_now:       video.live_now,
        index:          Random::Secure.rand(0_i64..Int64::MAX),
      })

      video_array = playlist_video.to_a
      args = arg_array(video_array)

      PG_DB.exec("INSERT INTO playlist_videos VALUES (#{args})", args: video_array)
      PG_DB.exec("UPDATE playlists SET index = array_append(index, $1), video_count = cardinality(index) + 1, updated = $2 WHERE id = $3", playlist_video.index, Time.utc, playlist_id)
    when "action_remove_video"
      index = env.params.query["set_video_id"]
      PG_DB.exec("DELETE FROM playlist_videos * WHERE index = $1", index)
      PG_DB.exec("UPDATE playlists SET index = array_remove(index, $1), video_count = cardinality(index) - 1, updated = $2 WHERE id = $3", index, Time.utc, playlist_id)
    when "action_move_video_before"
      # TODO: Playlist stub
    else
      error_message = {"error" => "Unsupported action #{action}"}.to_json
      env.response.status_code = 400
      return error_message
    end

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end

  def show(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    user = env.get?("user").try &.as(User)
    referer = get_referer(env)

    plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    if !plid
      return env.redirect "/"
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    if plid.starts_with? "RD"
      return env.redirect "/mix?list=#{plid}"
    end

    begin
      playlist = get_playlist(PG_DB, plid, locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 500
      return templated "error"
    end

    if playlist.privacy == PlaylistPrivacy::Private && playlist.author != user.try &.email
      error_message = "This playlist is private."
      env.response.status_code = 403
      return templated "error"
    end

    begin
      videos = get_playlist_videos(PG_DB, playlist, offset: (page - 1) * 100, locale: locale)
    rescue ex
      videos = [] of PlaylistVideo
    end

    if playlist.author == user.try &.email
      env.set "remove_playlist_items", plid
    end

    templated "playlist"
  end

  def mix(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    rdid = env.params.query["list"]?
    if !rdid
      return env.redirect "/"
    end

    continuation = env.params.query["continuation"]?
    continuation ||= rdid.lchop("RD")

    begin
      mix = fetch_mix(rdid, continuation, locale: locale)
    rescue ex
      error_message = ex.message
      env.response.status_code = 500
      return templated "error"
    end

    templated "mix"
  end
end
