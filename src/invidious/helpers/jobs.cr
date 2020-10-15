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
              ChannelVideo.type_array.each_with_index do |name, i|
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

def update_decrypt_function
  loop do
    begin
      decrypt_function = fetch_decrypt_function
      yield decrypt_function
    rescue ex
      # TODO: Log error
      next
    ensure
      sleep 1.minute
      Fiber.yield
    end
  end
end

def bypass_captcha(captcha_key, logger)
  loop do
    begin
      {"/watch?v=CvFH_6DNRCY&gl=US&hl=en&has_verified=1&bpctr=9999999999", produce_channel_videos_url(ucid: "UCXuqSBlHAE6Xw-yeJA0Tunw")}.each do |path|
        response = YT_POOL.client &.get(path)
        if response.body.includes?("To continue with your YouTube experience, please fill out the form below.")
          html = XML.parse_html(response.body)
          form = html.xpath_node(%(//form[@action="/das_captcha"])).not_nil!
          site_key = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-sitekey"]
          s_value = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-s"]

          inputs = {} of String => String
          form.xpath_nodes(%(.//input[@name])).map do |node|
            inputs[node["name"]] = node["value"]
          end

          headers = response.cookies.add_request_headers(HTTP::Headers.new)

          response = JSON.parse(HTTP::Client.post("https://api.anti-captcha.com/createTask", body: {
            "clientKey" => CONFIG.captcha_key,
            "task"      => {
              "type"                => "NoCaptchaTaskProxyless",
              "websiteURL"          => "https://www.youtube.com#{path}",
              "websiteKey"          => site_key,
              "recaptchaDataSValue" => s_value,
            },
          }.to_json).body)

          raise response["error"].as_s if response["error"]?
          task_id = response["taskId"].as_i

          loop do
            sleep 10.seconds

            response = JSON.parse(HTTP::Client.post("https://api.anti-captcha.com/getTaskResult", body: {
              "clientKey" => CONFIG.captcha_key,
              "taskId"    => task_id,
            }.to_json).body)

            if response["status"]?.try &.== "ready"
              break
            elsif response["errorId"]?.try &.as_i != 0
              raise response["errorDescription"].as_s
            end
          end

          inputs["g-recaptcha-response"] = response["solution"]["gRecaptchaResponse"].as_s
          headers["Cookies"] = response["solution"]["cookies"].as_h?.try &.map { |k, v| "#{k}=#{v}" }.join("; ") || ""
          response = YT_POOL.client &.post("/das_captcha", headers, form: inputs)

          yield response.cookies.select { |cookie| cookie.name != "PREF" }
        elsif response.headers["Location"]?.try &.includes?("/sorry/index")
          location = response.headers["Location"].try { |u| URI.parse(u) }
          headers = HTTP::Headers{":authority" => location.host.not_nil!}
          response = YT_POOL.client &.get(location.full_path, headers)

          html = XML.parse_html(response.body)
          form = html.xpath_node(%(//form[@action="index"])).not_nil!
          site_key = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-sitekey"]
          s_value = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-s"]

          inputs = {} of String => String
          form.xpath_nodes(%(.//input[@name])).map do |node|
            inputs[node["name"]] = node["value"]
          end

          captcha_client = HTTPClient.new(URI.parse("https://api.anti-captcha.com"))
          captcha_client.family = CONFIG.force_resolve || Socket::Family::INET
          response = JSON.parse(captcha_client.post("/createTask", body: {
            "clientKey" => CONFIG.captcha_key,
            "task"      => {
              "type"                => "NoCaptchaTaskProxyless",
              "websiteURL"          => location.to_s,
              "websiteKey"          => site_key,
              "recaptchaDataSValue" => s_value,
            },
          }.to_json).body)

          raise response["error"].as_s if response["error"]?
          task_id = response["taskId"].as_i

          loop do
            sleep 10.seconds

            response = JSON.parse(captcha_client.post("/getTaskResult", body: {
              "clientKey" => CONFIG.captcha_key,
              "taskId"    => task_id,
            }.to_json).body)

            if response["status"]?.try &.== "ready"
              break
            elsif response["errorId"]?.try &.as_i != 0
              raise response["errorDescription"].as_s
            end
          end

          inputs["g-recaptcha-response"] = response["solution"]["gRecaptchaResponse"].as_s
          headers["Cookies"] = response["solution"]["cookies"].as_h?.try &.map { |k, v| "#{k}=#{v}" }.join("; ") || ""
          response = YT_POOL.client &.post("/sorry/index", headers: headers, form: inputs)
          headers = HTTP::Headers{
            "Cookie" => URI.parse(response.headers["location"]).query_params["google_abuse"].split(";")[0],
          }
          cookies = HTTP::Cookies.from_headers(headers)

          yield cookies
        end
      end
    rescue ex
      logger.puts("Exception: #{ex.message}")
    ensure
      sleep 1.minute
      Fiber.yield
    end
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
