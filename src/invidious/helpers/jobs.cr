def refresh_channels(db, logger, max_threads = 1, full_refresh = false)
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
              channel = fetch_channel(id, db, full_refresh)

              db.exec("UPDATE channels SET updated = $1, author = $2, deleted = false WHERE id = $3", Time.now, channel.author, id)
            rescue ex
              if ex.message == "Deleted or invalid channel"
                db.exec("UPDATE channels SET updated = $1, deleted = true WHERE id = $2", Time.now, id)
              end
              logger.write("#{id} : #{ex.message}\n")
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
    end
  end

  max_channel.send(max_threads)
end

def refresh_feeds(db, logger, max_threads = 1, use_feed_events = false)
  max_channel = Channel(Int32).new

  # Spawn thread to handle feed events
  if use_feed_events
    spawn do
      queue = Deque(String).new(30)

      spawn do
        loop do
          if event = queue.shift?
            feed = JSON.parse(event)
            email = feed["email"].as_s
            action = feed["action"].as_s

            view_name = "subscriptions_#{sha256(email)}"

            case action
            when "refresh"
              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
            end

            # Delete any future events that we just processed
            queue.delete(event)
          else
            sleep 1.second
          end

          Fiber.yield
        end
      end

      PG.connect_listen(PG_URL, "feeds") do |event|
        queue << event.payload
      end
    end
  end

  spawn do
    max_threads = max_channel.receive
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT email FROM users") do |rs|
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
                  logger.write("DROP MATERIALIZED VIEW #{view_name}\n")
                  db.exec("DROP MATERIALIZED VIEW #{view_name}")
                  raise "view does not exist"
                end
              end

              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
            rescue ex
              # Rename old views
              begin
                legacy_view_name = "subscriptions_#{sha256(email)[0..7]}"

                db.exec("SELECT * FROM #{legacy_view_name} LIMIT 0")
                logger.write("RENAME MATERIALIZED VIEW #{legacy_view_name}\n")
                db.exec("ALTER MATERIALIZED VIEW #{legacy_view_name} RENAME TO #{view_name}")
              rescue ex
                begin
                  # While iterating through, we may have an email stored from a deleted account
                  if db.query_one?("SELECT true FROM users WHERE email = $1", email, as: Bool)
                    logger.write("CREATE #{view_name}\n")
                    db.exec("CREATE MATERIALIZED VIEW #{view_name} AS \
                    SELECT * FROM channel_videos WHERE \
                    ucid = ANY ((SELECT subscriptions FROM users WHERE email = E'#{email.gsub("'", "\\'")}')::text[]) \
                    ORDER BY published DESC;")
                  end
                rescue ex
                  logger.write("REFRESH #{email} : #{ex.message}\n")
                end
              end
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
    end
  end

  max_channel.send(max_threads)
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
                  logger.write("#{ucid} : #{response.body}\n")
                end
              rescue ex
              end

              active_channel.send(true)
            end
          end
        end

        sleep 1.minute
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
    sleep 1.minute
  end
end

def pull_popular_videos(db)
  loop do
    subscriptions = db.query_all("SELECT channel FROM \
      (SELECT UNNEST(subscriptions) AS channel FROM users) AS d \
    GROUP BY channel ORDER BY COUNT(channel) DESC LIMIT 40", as: String)

    videos = db.query_all("SELECT DISTINCT ON (ucid) * FROM \
      channel_videos WHERE ucid IN (#{arg_array(subscriptions)}) \
    ORDER BY ucid, published DESC", subscriptions, as: ChannelVideo).sort_by { |video| video.published }.reverse

    yield videos
    sleep 1.minute
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
    sleep 1.minute
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
  end
end
