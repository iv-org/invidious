{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Playlists
  def self.new(env)
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

  def self.create(env)
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
      return error_template(400, ex)
    end

    title = env.params.body["title"]?.try &.as(String)
    if !title || title.empty?
      return error_template(400, "Title cannot be empty.")
    end

    privacy = PlaylistPrivacy.parse?(env.params.body["privacy"]?.try &.as(String) || "")
    if !privacy
      return error_template(400, "Invalid privacy setting.")
    end

    if PG_DB.query_one("SELECT count(*) FROM playlists WHERE author = $1", user.email, as: Int64) >= 100
      return error_template(400, "User cannot have more than 100 playlists.")
    end

    playlist = create_playlist(PG_DB, title, privacy, user)

    env.redirect "/playlist?list=#{playlist.id}"
  end

  def self.subscribe(env)
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

  def self.delete_page(env)
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

  def self.delete(env)
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
      return error_template(400, ex)
    end

    playlist = PG_DB.query_one?("SELECT * FROM playlists WHERE id = $1", plid, as: InvidiousPlaylist)
    if !playlist || playlist.author != user.email
      return env.redirect referer
    end

    PG_DB.exec("DELETE FROM playlist_videos * WHERE plid = $1", plid)
    PG_DB.exec("DELETE FROM playlists * WHERE id = $1", plid)

    env.redirect "/feed/playlists"
  end

  def self.edit(env)
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

  def self.update(env)
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
      return error_template(400, ex)
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

  def self.add_playlist_items_page(env)
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
        search_query, count, items, operators = process_search_query(query, page, user, region: nil)
        videos = items.select(SearchVideo).map(&.as(SearchVideo))
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

  def self.playlist_ajax(env)
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
        return error_json(403, "No such user")
      end
    end

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, PG_DB, locale)
    rescue ex
      if redirect
        return error_template(400, ex)
      else
        return error_json(400, ex)
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
        return error_template(400, ex)
      else
        return error_json(400, ex)
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
        if redirect
          return error_template(400, "Playlist cannot have more than 500 videos")
        else
          return error_json(400, "Playlist cannot have more than 500 videos")
        end
      end

      video_id = env.params.query["video_id"]

      begin
        video = get_video(video_id, PG_DB)
      rescue ex
        if redirect
          return error_template(500, ex)
        else
          return error_json(500, ex)
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
      return error_json(400, "Unsupported action #{action}")
    end

    if redirect
      env.redirect referer
    else
      env.response.content_type = "application/json"
      "{}"
    end
  end

  def self.show(env)
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
      return error_template(500, ex)
    end

    page_count = (playlist.video_count / 100).to_i
    page_count += 1 if (playlist.video_count % 100) > 0

    if page > page_count
      return env.redirect "/playlist?list=#{plid}&page=#{page_count}"
    end

    if playlist.privacy == PlaylistPrivacy::Private && playlist.author != user.try &.email
      return error_template(403, "This playlist is private.")
    end

    begin
      videos = get_playlist_videos(PG_DB, playlist, offset: (page - 1) * 100, locale: locale)
    rescue ex
      return error_template(500, "Error encountered while retrieving playlist videos.<br>#{ex.message}")
    end

    if playlist.author == user.try &.email
      env.set "remove_playlist_items", plid
    end

    templated "playlist"
  end

  def self.mix(env)
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
      return error_template(500, ex)
    end

    templated "mix"
  end
end
