{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Compilations
  def self.new(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)
    csrf_token = generate_response(sid, {":create_compilation"}, HMAC_KEY)

    templated "create_compilation"
  end

  def self.create(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    title = env.params.body["title"]?.try &.as(String)
    if !title || title.empty?
      return error_template(400, "Title cannot be empty.")
    end

    privacy = CompilationPrivacy.parse?(env.params.body["privacy"]?.try &.as(String) || "")
    if !privacy
      return error_template(400, "Invalid privacy setting.")
    end

    if Invidious::Database::Compilations.count_owned_by(user.email) >= 100
      return error_template(400, "User cannot have more than 100 compilations.")
    end

    compilation = create_compilation(title, privacy, user)

    env.redirect "/compilation?comp=#{compilation.id}"
  end

  def self.delete_page(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    compid = env.params.query["comp"]?
    if !compid || compid.empty?
      return error_template(400, "A compilation ID is required")
    end

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email
      return env.redirect referer
    end

    csrf_token = generate_response(sid, {":delete_compilation"}, HMAC_KEY)

    templated "delete_compilation"
  end

  def self.delete(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    compid = env.params.query["comp"]?
    return env.redirect referer if compid.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email
      return env.redirect referer
    end

    Invidious::Database::Compilations.delete(compid)

    env.redirect "/feed/compilations"
  end

  def self.edit(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    compid = env.params.query["comp"]?
    if !compid || !compid.starts_with?("IVCMP")
      return env.redirect referer
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email
      return env.redirect referer
    end

    begin
      videos = get_compilation_videos(compilation, offset: (page - 1) * 100)
    rescue ex
      videos = [] of CompilationVideo
    end

    csrf_token = generate_response(sid, {":edit_compilation"}, HMAC_KEY)

    templated "edit_compilation"
  end

  def self.update(env)
    locale = env.get("preferences").as(Preferences).locale

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    compid = env.params.query["comp"]?
    return env.redirect referer if compid.nil?

    user = user.as(User)
    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email
      return env.redirect referer
    end

    title = env.params.body["title"]?.try &.delete("<>") || ""
    privacy = CompilationPrivacy.parse(env.params.body["privacy"]? || "Unlisted")
    description = env.params.body["description"]?.try &.delete("\r") || ""

    if title != compilation.title ||
       compilation != compilation.privacy ||
       description != compilation.description
      updated = Time.utc
    else
      updated = compilation.updated
    end

    Invidious::Database::Compilations.update(compid, title, privacy, description, updated)

    env.redirect "/compilation?comp=#{compid}"
  end

  def self.adjust_timestamps(env)
    locale = env.get("preferences").as(Preferences).locale
    env.response.content_type = "application/json"
    user = env.get("user")
    sid = env.get? "sid"

    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    compid = env.params.query["comp"]?
    return env.redirect referer if compid.nil?

    user = user.as(User)

    sid = sid.as(String)
    token = env.params.body["csrf_token"]?

    begin
      validate_request(token, sid, env.request, HMAC_KEY, locale)
    rescue ex
      return error_template(400, ex)
    end

    if !compid || compid.empty?
      return error_json(400, "A compilation ID is required")
    end

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email && compilation.privacy.private?
      return error_json(404, "Compilation does not exist.")
    end

    if compilation.author != user.email
      return error_json(403, "Invalid user")
    end

    title = env.params.body["title"]?.try &.delete("<>") || ""
    privacy = CompilationPrivacy.parse(env.params.body["privacy"]? || "Private")

    Invidious::Database::Compilations.update(compid, title, privacy, "", compilation.updated)

    (0..compilation.index.size - 1).each do |index|
      compilation_video_index = compilation.index[index]
      compilation_video = Invidious::Database::CompilationVideos.select_video(compid, compilation.index, compilation_video_index, 0, 1)
      json_timestamp_query_start = compilation_video_index.to_s + "_start_timestamp"
      start_timestamp = env.params.body[json_timestamp_query_start]?.try &.as(String).byte_slice(0, 8)
      if !start_timestamp.nil? && !compilation_video[0].id.nil?
        start_timestamp_seconds = decode_length_seconds(start_timestamp)
        if !start_timestamp_seconds.nil?
          if start_timestamp_seconds >= 0 && start_timestamp_seconds <= compilation_video[0].length_seconds
            Invidious::Database::CompilationVideos.update_start_timestamp(compilation_video[0].id, start_timestamp_seconds.to_i)
          end
        end
      end
      compilation_video = Invidious::Database::CompilationVideos.select_video(compid, compilation.index, compilation_video_index, 0, 1)
      json_timestamp_query_end = compilation_video_index.to_s + "_end_timestamp"
      end_timestamp = env.params.body[json_timestamp_query_end]?.try &.as(String).byte_slice(0, 8)
      if !end_timestamp.nil? && !compilation_video[0].id.nil?
        end_timestamp_seconds = decode_length_seconds(end_timestamp)
        if !end_timestamp_seconds.nil?
          if end_timestamp_seconds >= 0 && end_timestamp_seconds <= compilation_video[0].length_seconds && end_timestamp_seconds > compilation_video[0].starting_timestamp_seconds
            Invidious::Database::CompilationVideos.update_end_timestamp(compilation_video[0].id, end_timestamp_seconds.to_i)
          end
        end
      end
    end

    update_first_video_params(compid)

    env.redirect "/compilation?comp=#{compid}"
  end

  def self.add_compilation_items_page(env)
    prefs = env.get("preferences").as(Preferences)
    locale = prefs.locale

    region = env.params.query["region"]? || prefs.region

    user = env.get? "user"
    sid = env.get? "sid"
    referer = get_referer(env)

    return env.redirect "/" if user.nil?

    user = user.as(User)
    sid = sid.as(String)

    compid = env.params.query["comp"]?
    if !compid || !compid.starts_with?("IVCMP")
      return env.redirect referer
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    compilation = Invidious::Database::Compilations.select(id: compid)
    if !compilation || compilation.author != user.email
      return env.redirect referer
    end

    begin
      query = Invidious::Search::Query.new(env.params.query, :compilation, region)
      items = query.process.select(SearchVideo).map(&.as(SearchVideo))
    rescue ex
      items = [] of SearchVideo
    end

    query_encoded = URI.encode_www_form(query.try &.text || "", space_to_plus: true)
    page_nav_html = Frontend::Pagination.nav_numeric(locale,
      base_url: "/add_compilation_items?comp=#{compilation.id}&q=#{query_encoded}",
      current_page: page,
      show_next: (items.size >= 20)
    )

    env.set "add_compilation_items", compid
    templated "add_compilation_items"
  end

  def self.compilation_ajax(env)
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

    if env.params.query["action_create_compilation"]?
      action = "action_create_compilation"
    elsif env.params.query["action_delete_compilation"]?
      action = "action_delete_compilation"
    elsif env.params.query["action_edit_compilation"]?
      action = "action_edit_compilation"
    elsif env.params.query["action_add_video"]?
      action = "action_add_video"
      video_id = env.params.query["video_id"]
    elsif env.params.query["action_remove_video"]?
      action = "action_remove_video"
    elsif env.params.query["action_move_video_before"]?
      action = "action_move_video_before"
    elsif env.params.query["action_move_video_after"]?
      action = "action_move_video_after"
    else
      return env.redirect referer
    end

    begin
      compilation_id = env.params.query["compilation_id"]
      compilation = get_compilation(compilation_id).as(InvidiousCompilation)
      raise "Invalid user" if compilation.author != user.email
    rescue ex : NotFoundException
      return error_json(404, ex)
    rescue ex
      if redirect
        return error_template(400, ex)
      else
        return error_json(400, ex)
      end
    end

    email = user.email

    case action
    when "action_edit_compilation"
      # TODO: Compilation stub

    when "action_add_video"
      if compilation.index.size >= CONFIG.compilation_length_limit
        if redirect
          return error_template(400, "Compilation cannot have more than #{CONFIG.compilation_length_limit} videos")
        else
          return error_json(400, "Compilation cannot have more than #{CONFIG.compilation_length_limit} videos")
        end
      end

      video_id = env.params.query["video_id"]

      begin
        video = get_video(video_id)
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        if redirect
          return error_template(500, ex)
        else
          return error_json(500, ex)
        end
      end

      compilation_video = CompilationVideo.new({
        title:                      video.title,
        id:                         video.id,
        author:                     video.author,
        ucid:                       video.ucid,
        length_seconds:             video.length_seconds,
        starting_timestamp_seconds: 0,
        ending_timestamp_seconds:   video.length_seconds,
        published:                  video.published,
        compid:                     compilation_id,
        live_now:                   video.live_now,
        index:                      Random::Secure.rand(0_i64..Int64::MAX),
        order_index:                compilation.index.size,
      })

      Invidious::Database::CompilationVideos.insert(compilation_video)
      Invidious::Database::Compilations.update_video_added(compilation_id, compilation_video.index)
      update_first_video_params(compilation_id)
    when "action_remove_video"
      index = env.params.query["set_video_id"]
      Invidious::Database::CompilationVideos.delete(index)
      Invidious::Database::Compilations.update_video_removed(compilation_id, index)
      update_first_video_params(compilation_id)
    when "action_move_video_before"
      # TODO: Compilation stub
      video_index = env.params.query["video_index"]
      begin
        compilation_video = Invidious::Database::CompilationVideos.select_video(compilation_id, compilation.index, video_index, 0, 1)
        compilation_index_array = compilation.index
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        if redirect
          return error_template(500, ex)
        else
          return error_json(500, ex)
        end
      end
      compilation_index_array_position = compilation_index_array.index(compilation_video[0].index)
      if !compilation_index_array_position.nil?
        compilation_index_array.delete_at(compilation_index_array_position)
        compilation_index_array.insert(compilation_index_array_position - 1, compilation_video[0].index)
        Invidious::Database::Compilations.move_video_position(compilation_id, compilation_index_array)
      end
      update_first_video_params(compilation_id)
    when "action_move_video_after"
      # TODO: Compilation stub
      video_index = env.params.query["video_index"]
      begin
        compilation_video = Invidious::Database::CompilationVideos.select_video(compilation_id, compilation.index, video_index, 0, 1)
        compilation_index_array = compilation.index
      rescue ex : NotFoundException
        return error_json(404, ex)
      rescue ex
        if redirect
          return error_template(500, ex)
        else
          return error_json(500, ex)
        end
      end
      compilation_index_array_position = compilation_index_array.index(compilation_video[0].index)
      if !compilation_index_array_position.nil?
        compilation_index_array.delete_at(compilation_index_array_position)
        if (compilation_index_array_position == compilation_index_array.size)
          compilation_index_array.insert(compilation_index_array_position, compilation_video[0].index)
        else
          compilation_index_array.insert(compilation_index_array_position + 1, compilation_video[0].index)
        end
        Invidious::Database::Compilations.move_video_position(compilation_id, compilation_index_array)
      end
      update_first_video_params(compilation_id)
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
    locale = env.get("preferences").as(Preferences).locale

    user = env.get?("user").try &.as(User)
    referer = get_referer(env)

    compid = env.params.query["comp"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
    if !compid
      return env.redirect "/"
    end

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    begin
      compilation = get_compilation(compid)
    rescue ex : NotFoundException
      return error_template(404, ex)
    rescue ex
      return error_template(500, ex)
    end

    page_count = (compilation.video_count / 200).to_i
    page_count += 1 if (compilation.video_count % 200) > 0

    if page > page_count
      return env.redirect "/compilation?comp=#{compid}&page=#{page_count}"
    end

    if compilation.privacy == CompilationPrivacy::Private && compilation.author != user.try &.email
      return error_template(403, "This compilation is private.")
    end

    begin
      videos = get_compilation_videos(compilation, offset: (page - 1) * 200)
    rescue ex
      return error_template(500, "Error encountered while retrieving compilation videos.<br>#{ex.message}")
    end

    if compilation.author == user.try &.email
      env.set "remove_compilation_items", compid
    end

    templated "compilation"
  end
end
