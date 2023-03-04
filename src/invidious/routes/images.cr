module Invidious::Routes::Images
  # Avatars, banners and other large image assets.
  def self.ggpht(env)
    url = env.request.path.lchop("/ggpht")

    headers = HTTP::Headers.new
    headers[":authority"] = "yt3.ggpht.com" if CONFIG.use_quic

    MediaProxy.copy_request_headers(from: env.request.headers, to: headers)

    # We're encapsulating this into a proc in order to easily reuse this
    # portion of the code for each request block below.
    request_proc = ->(response : HTTP::Client::Response) {
      env.response.status_code = response.status_code

      MediaProxy.copy_response_headers(from: response.headers, to: env.response.headers)
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300
        env.response.headers.delete("Transfer-Encoding")
        return
      end

      proxy_file(response, env)
    }

    begin
      if CONFIG.use_quic
        YT_POOL.client &.get(url, headers) do |resp|
          return request_proc.call(resp)
        end
      else
        # This can likely be optimized into a (small) pool sometime in the future.
        HTTP::Client.get("https://yt3.ggpht.com#{url}") do |resp|
          return request_proc.call(resp)
        end
      end
    rescue ex
    end
  end

  def self.options_storyboard(env)
    env.response.headers["Access-Control-Allow-Origin"] = "*"
    env.response.headers["Access-Control-Allow-Methods"] = "GET, OPTIONS"
    env.response.headers["Access-Control-Allow-Headers"] = "Content-Type, Range"
  end

  def self.get_storyboard(env)
    authority = env.params.url["authority"]
    id = env.params.url["id"]
    storyboard = env.params.url["storyboard"]
    index = env.params.url["index"]

    url = "/sb/#{id}/#{storyboard}/#{index}?#{env.params.query}"

    headers = HTTP::Headers.new
    headers[":authority"] = "#{authority}.ytimg.com" if CONFIG.use_quic

    MediaProxy.copy_request_headers(from: env.request.headers, to: headers)

    request_proc = ->(response : HTTP::Client::Response) {
      env.response.status_code = response.status_code

      MediaProxy.copy_response_headers(from: response.headers, to: env.response.headers)
      env.response.headers["Connection"] = "close"
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300
        return env.response.headers.delete("Transfer-Encoding")
      end

      proxy_file(response, env)
    }

    begin
      if CONFIG.use_quic
        YT_POOL.client &.get(url, headers) do |resp|
          return request_proc.call(resp)
        end
      else
        # This can likely be optimized into a (small) pool sometime in the future.
        HTTP::Client.get("https://#{authority}.ytimg.com#{url}") do |resp|
          return request_proc.call(resp)
        end
      end
    rescue ex
    end
  end

  # ??? maybe also for storyboards?
  def self.s_p_image(env)
    id = env.params.url["id"]
    name = env.params.url["name"]
    url = env.request.resource

    headers = HTTP::Headers.new
    headers[":authority"] = "i9.ytimg.com" if CONFIG.use_quic

    MediaProxy.copy_request_headers(from: env.request.headers, to: headers)

    request_proc = ->(response : HTTP::Client::Response) {
      env.response.status_code = response.status_code

      MediaProxy.copy_response_headers(from: response.headers, to: env.response.headers)
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300 && response.status_code != 404
        return env.response.headers.delete("Transfer-Encoding")
      end

      proxy_file(response, env)
    }

    begin
      if CONFIG.use_quic
        YT_POOL.client &.get(url, headers) do |resp|
          return request_proc.call(resp)
        end
      else
        # This can likely be optimized into a (small) pool sometime in the future.
        HTTP::Client.get("https://i9.ytimg.com#{url}") do |resp|
          return request_proc.call(resp)
        end
      end
    rescue ex
    end
  end

  def self.yts_image(env)
    headers = HTTP::Headers.new
    MediaProxy.copy_request_headers(from: env.request.headers, to: headers)

    begin
      YT_POOL.client &.get(env.request.resource, headers) do |response|
        env.response.status_code = response.status_code

        MediaProxy.copy_response_headers(from: response.headers, to: env.response.headers)
        env.response.headers["Access-Control-Allow-Origin"] = "*"

        if response.status_code >= 300 && response.status_code != 404
          env.response.headers.delete("Transfer-Encoding")
          break
        end

        proxy_file(response, env)
      end
    rescue ex
    end
  end

  def self.thumbnails(env)
    id = env.params.url["id"]
    name = env.params.url["name"]

    headers = HTTP::Headers.new
    headers[":authority"] = "i.ytimg.com" if CONFIG.use_quic

    if name == "maxres.jpg"
      build_thumbnails(id).each do |thumb|
        thumbnail_resource_path = "/vi/#{id}/#{thumb[:url]}.jpg"

        # Logic here is short enough that manually typing them out should be fine.
        if CONFIG.use_quic
          if YT_POOL.client &.head(thumbnail_resource_path, headers).status_code == 200
            name = thumb[:url] + ".jpg"
            break
          end
        else
          # This can likely be optimized into a (small) pool sometime in the future.
          if HTTP::Client.head("https://i.ytimg.com#{thumbnail_resource_path}").status_code == 200
            name = thumb[:url] + ".jpg"
            break
          end
        end
      end
    end

    url = "/vi/#{id}/#{name}"

    MediaProxy.copy_request_headers(from: env.request.headers, to: headers)

    request_proc = ->(response : HTTP::Client::Response) {
      env.response.status_code = response.status_code

      MediaProxy.copy_response_headers(from: response.headers, to: env.response.headers)
      env.response.headers["Access-Control-Allow-Origin"] = "*"

      if response.status_code >= 300 && response.status_code != 404
        return env.response.headers.delete("Transfer-Encoding")
      end

      proxy_file(response, env)
    }

    begin
      if CONFIG.use_quic
        YT_POOL.client &.get(url, headers) do |resp|
          return request_proc.call(resp)
        end
      else
        # This can likely be optimized into a (small) pool sometime in the future.
        HTTP::Client.get("https://i.ytimg.com#{url}") do |resp|
          return request_proc.call(resp)
        end
      end
    rescue ex
    end
  end
end
