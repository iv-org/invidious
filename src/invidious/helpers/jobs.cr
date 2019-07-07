def refresh_channels(db, logger, config)
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
              channel = fetch_channel(id, db, config.full_refresh)

              db.exec("UPDATE channels SET updated = $1, author = $2, deleted = false WHERE id = $3", Time.utc, channel.author, id)
            rescue ex
              if ex.message == "Deleted or invalid channel"
                db.exec("UPDATE channels SET updated = $1, deleted = true WHERE id = $2", Time.utc, id)
              end
              logger.puts("#{id} : #{ex.message}")
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
      Fiber.yield
    end
  end

  max_channel.send(config.channel_threads)
end

def refresh_feeds(db, logger, config)
  max_channel = Channel(Int32).new
  spawn do
    max_threads = max_channel.receive
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT email FROM users WHERE feed_needs_update = true OR feed_needs_update IS NULL") do |rs|
        rs.each do
          email = rs.read(String)
          view_name = "subscriptions_#{sha256(email)}"

          if active_threads >= max_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              # Drop outdated views
              column_array = get_column_array(db, view_name)
              ChannelVideo.to_type_tuple.each_with_index do |name, i|
                if name != column_array[i]?
                  logger.puts("DROP MATERIALIZED VIEW #{view_name}")
                  db.exec("DROP MATERIALIZED VIEW #{view_name}")
                  raise "view does not exist"
                end
              end

              if !db.query_one("SELECT pg_get_viewdef('#{view_name}')", as: String).includes? "WHERE ((cv.ucid = ANY (u.subscriptions))"
                logger.puts("Materialized view #{view_name} is out-of-date, recreating...")
                db.exec("DROP MATERIALIZED VIEW #{view_name}")
              end

              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
              db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
            rescue ex
              # Rename old views
              begin
                legacy_view_name = "subscriptions_#{sha256(email)[0..7]}"

                db.exec("SELECT * FROM #{legacy_view_name} LIMIT 0")
                logger.puts("RENAME MATERIALIZED VIEW #{legacy_view_name}")
                db.exec("ALTER MATERIALIZED VIEW #{legacy_view_name} RENAME TO #{view_name}")
              rescue ex
                begin
                  # While iterating through, we may have an email stored from a deleted account
                  if db.query_one?("SELECT true FROM users WHERE email = $1", email, as: Bool)
                    logger.puts("CREATE #{view_name}")
                    db.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(email)}")
                    db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
                  end
                rescue ex
                  logger.puts("REFRESH #{email} : #{ex.message}")
                end
              end
            end

            active_channel.send(true)
          end
        end
      end

      sleep 5.seconds
      Fiber.yield
    end
  end

  max_channel.send(config.feed_threads)
end

def subscribe_to_feeds(db, logger, key, config)
  if config.use_pubsub_feeds
    case config.use_pubsub_feeds
    when Bool
      max_threads = config.use_pubsub_feeds.as(Bool).to_unsafe
    when Int32
      max_threads = config.use_pubsub_feeds.as(Int32)
    end
    max_channel = Channel(Int32).new

    spawn do
      max_threads = max_channel.receive
      active_threads = 0
      active_channel = Channel(Bool).new

      loop do
        db.query_all("SELECT id FROM channels WHERE CURRENT_TIMESTAMP - subscribed > interval '4 days' OR subscribed IS NULL") do |rs|
          rs.each do
            ucid = rs.read(String)

            if active_threads >= max_threads.as(Int32)
              if active_channel.receive
                active_threads -= 1
              end
            end

            active_threads += 1

            spawn do
              begin
                response = subscribe_pubsub(ucid, key, config)

                if response.status_code >= 400
                  logger.puts("#{ucid} : #{response.body}")
                end
              rescue ex
              end

              active_channel.send(true)
            end
          end
        end

        sleep 1.minute
        Fiber.yield
      end
    end

    max_channel.send(max_threads.as(Int32))
  end
end

def pull_top_videos(config, db)
  loop do
    begin
      top = rank_videos(db, 40)
    rescue ex
      sleep 1.minute
      Fiber.yield

      next
    end

    if top.size == 0
      sleep 1.minute
      Fiber.yield

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

    sleep 1.minute
    Fiber.yield
  end
end

def pull_popular_videos(db)
  loop do
    videos = db.query_all("SELECT DISTINCT ON (ucid) * FROM channel_videos WHERE ucid IN \
      (SELECT channel FROM (SELECT UNNEST(subscriptions) AS channel FROM users) AS d \
      GROUP BY channel ORDER BY COUNT(channel) DESC LIMIT 40) \
      ORDER BY ucid, published DESC", as: ChannelVideo).sort_by { |video| video.published }.reverse

    yield videos

    sleep 1.minute
    Fiber.yield
  end
end

def update_decrypt_function
  loop do
    begin
      decrypt_function = fetch_decrypt_function
      yield decrypt_function
    rescue ex
      next
    end

    sleep 1.minute
    Fiber.yield
  end
end

def find_working_proxies(regions)
  loop do
    regions.each do |region|
      proxies = get_proxies(region).first(20)
      proxies = proxies.map { |proxy| {ip: proxy[:ip], port: proxy[:port]} }
      # proxies = filter_proxies(proxies)

      yield region, proxies
    end

    sleep 1.minute
    Fiber.yield
  end
end
