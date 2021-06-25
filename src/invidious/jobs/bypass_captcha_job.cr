class Invidious::Jobs::BypassCaptchaJob < Invidious::Jobs::BaseJob
  def begin
    loop do
      begin
        random_video = PG_DB.query_one?("select id, ucid from (select id, ucid from channel_videos limit 1000) as s ORDER BY RANDOM() LIMIT 1", as: {id: String, ucid: String})
        if !random_video
          random_video = {id: "zj82_v2R6ts", ucid: "UCK87Lox575O_HCHBWaBSyGA"}
        end
        {"/watch?v=#{random_video["id"]}&gl=US&hl=en&has_verified=1&bpctr=9999999999", produce_channel_videos_url(ucid: random_video["ucid"])}.each do |path|
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

            response = JSON.parse(HTTP::Client.post(CONFIG.captcha_api_url + "/createTask",
              headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {
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

              response = JSON.parse(HTTP::Client.post(CONFIG.captcha_api_url + "/getTaskResult",
                headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {
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

            response.cookies
              .select { |cookie| cookie.name != "PREF" }
              .each { |cookie| CONFIG.cookies << cookie }

            # Persist cookies between runs
            File.write("config/config.yml", CONFIG.to_yaml)
          elsif response.headers["Location"]?.try &.includes?("/sorry/index")
            location = response.headers["Location"].try { |u| URI.parse(u) }
            headers = HTTP::Headers{":authority" => location.host.not_nil!}
            response = YT_POOL.client &.get(location.request_target, headers)

            html = XML.parse_html(response.body)
            form = html.xpath_node(%(//form[@action="index"])).not_nil!
            site_key = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-sitekey"]
            s_value = form.xpath_node(%(.//div[@id="recaptcha"])).try &.["data-s"]

            inputs = {} of String => String
            form.xpath_nodes(%(.//input[@name])).map do |node|
              inputs[node["name"]] = node["value"]
            end

            captcha_client = HTTPClient.new(URI.parse(CONFIG.captcha_api_url))
            captcha_client.family = CONFIG.force_resolve || Socket::Family::INET
            response = JSON.parse(captcha_client.post("/createTask",
              headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {
              "clientKey" => CONFIG.captcha_key,
              "task"      => {
                "type"                => "NoCaptchaTaskProxyless",
                "websiteURL"          => location.to_s,
                "websiteKey"          => site_key,
                "recaptchaDataSValue" => s_value,
              },
            }.to_json).body)

            captcha_client.close

            raise response["error"].as_s if response["error"]?
            task_id = response["taskId"].as_i

            loop do
              sleep 10.seconds

              response = JSON.parse(captcha_client.post("/getTaskResult",
                headers: HTTP::Headers{"Content-Type" => "application/json"}, body: {
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
            cookies = HTTP::Cookies.from_client_headers(headers)

            cookies.each { |cookie| CONFIG.cookies << cookie }

            # Persist cookies between runs
            File.write("config/config.yml", CONFIG.to_yaml)
          end
        end
      rescue ex
        LOGGER.error("BypassCaptchaJob: #{ex.message}")
      ensure
        sleep 1.minute
        Fiber.yield
      end
    end
  end
end
