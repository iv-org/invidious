def crawl_videos(db)
  ids = Deque(String).new
  random = Random.new

  search(random.base64(3)).as(Tuple)[1].each do |video|
    if video.is_a?(SearchVideo)
      ids << video.id
    end
  end

  loop do
    if ids.empty?
      search(random.base64(3)).as(Tuple)[1].each do |video|
        if video.is_a?(SearchVideo)
          ids << video.id
        end
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
    video.info["rvs"]?.try &.split(",").each do |rv|
      rvs << HTTP::Params.parse(rv).to_h
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

def refresh_channels(db, max_threads = 1, full_refresh = false)
  max_channel = Channel(Int32).new

  spawn do
    max_threads = max_channel.receive
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT id FROM channels ORDER BY updated") do |rs|
        rs.each do
          id = rs.read(String)

          if active_threads >= max_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              client = make_client(YT_URL)
              channel = fetch_channel(id, client, db, full_refresh)

              db.exec("UPDATE channels SET updated = $1 WHERE id = $2", Time.now, id)
            rescue ex
              STDOUT << id << " : " << ex.message << "\n"
            end

            active_channel.send(true)
          end
        end
      end
    end
  end

  max_channel.send(max_threads)
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
      decrypt_function = fetch_decrypt_function
    rescue ex
      next
    end

    yield decrypt_function
    Fiber.yield
  end
end

def find_working_proxies(regions)
  proxy_channel = Channel({String, Array({ip: String, port: Int32})}).new

  regions.each do |region|
    spawn do
      loop do
        begin
          proxies = get_proxies(region).first(20)
        rescue ex
          next proxy_channel.send({region, Array({ip: String, port: Int32}).new})
        end

        proxies.select! do |proxy|
          begin
            client = HTTPClient.new(YT_URL)
            client.read_timeout = 10.seconds
            client.connect_timeout = 10.seconds

            proxy = HTTPProxy.new(proxy_host: proxy[:ip], proxy_port: proxy[:port])
            client.set_proxy(proxy)

            client.get("/").status_code == 200
          rescue ex
            false
          end
        end
        proxies = proxies.map { |proxy| {ip: proxy[:ip], port: proxy[:port]} }

        proxy_channel.send({region, proxies})
      end
    end
  end

  loop do
    yield proxy_channel.receive
  end
end
