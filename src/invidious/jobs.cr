def crawl_videos(db)
  ids = Deque(String).new
  random = Random.new

  search(random.base64(3)).each do |video|
    ids << video.id
  end

  loop do
    if ids.empty?
      search(random.base64(3)).each do |video|
        ids << video.id
      end
    end

    begin
      id = ids[0]
      video = get_video(id, db)
    rescue ex
      STDOUT << id << " : " << ex.message << "\n"
      next
    ensure
      ids.delete(id)
    end

    rvs = [] of Hash(String, String)
    if video.info.has_key?("rvs")
      video.info["rvs"].split(",").each do |rv|
        rvs << HTTP::Params.parse(rv).to_h
      end
    end

    rvs.each do |rv|
      if rv.has_key?("id") && !db.query_one?("SELECT EXISTS (SELECT true FROM videos WHERE id = $1)", rv["id"], as: Bool)
        ids.delete(id)
        ids << rv["id"]
        if ids.size == 150
          ids.shift
        end
      end
    end

    Fiber.yield
  end
end

def refresh_channels(db)
  loop do
    db.query("SELECT id FROM channels ORDER BY updated") do |rs|
      rs.each do
        client = make_client(YT_URL)

        begin
          id = rs.read(String)
          channel = fetch_channel(id, client, db, false)
          db.exec("UPDATE channels SET updated = $1 WHERE id = $2", Time.now, id)
        rescue ex
          STDOUT << id << " : " << ex.message << "\n"
          next
        end
      end
    end

    Fiber.yield
  end
end

def refresh_videos(db)
  loop do
    db.query("SELECT id FROM videos ORDER BY updated") do |rs|
      rs.each do
        begin
          id = rs.read(String)
          video = get_video(id, db)
        rescue ex
          STDOUT << id << " : " << ex.message << "\n"
          next
        end
      end
    end

    Fiber.yield
  end
end

def pull_top_videos(config, db)
  if config.dl_api_key
    DetectLanguage.configure do |dl_config|
      dl_config.api_key = config.dl_api_key.not_nil!
    end
    filter = true
  end

  filter ||= false

  loop do
    begin
      top = rank_videos(db, 40, filter, YT_URL)
    rescue ex
      next
    end

    if top.size > 0
      args = arg_array(top)
    else
      next
    end

    videos = [] of Video

    top.each do |id|
      begin
        videos << get_video(id, db)
      rescue ex
        next
      end
    end

    yield videos
    Fiber.yield
  end
end

def update_decrypt_function
  loop do
    begin
      client = make_client(YT_URL)
      decrypt_function = fetch_decrypt_function(client)
    rescue ex
      next
    end

    yield decrypt_function
    Fiber.yield
  end
end
