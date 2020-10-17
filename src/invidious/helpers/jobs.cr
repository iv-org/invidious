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
                logger.puts("#{ucid} : #{ex.message}")
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
