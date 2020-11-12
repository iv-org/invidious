class Invidious::Jobs::BypassCaptchaJob < Invidious::Jobs::BaseJob
  private getter logger : Invidious::LogHandler
  private getter config : Config

  def initialize(@logger, @config)
  end

  def begin
    loop do
      begin
        {"/watch?v=jNQXAC9IVRw&gl=US&hl=en&has_verified=1&bpctr=9999999999", produce_channel_videos_url(ucid: "UC4QobU6STFB0P71PMvOGN5A")}.each do |path|
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
              "clientKey" => config.captcha_key,
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
                "clientKey" => config.captcha_key,
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
              .each { |cookie| config.cookies << cookie }

            # Persist cookies between runs
            File.write("config/config.yml", config.to_yaml)
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
            captcha_client.family = config.force_resolve || Socket::Family::INET
            response = JSON.parse(captcha_client.post("/createTask", body: {
              "clientKey" => config.captcha_key,
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
                "clientKey" => config.captcha_key,
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

            cookies.each { |cookie| config.cookies << cookie }

            # Persist cookies between runs
            File.write("config/config.yml", config.to_yaml)
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
end
