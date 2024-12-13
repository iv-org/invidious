module Invidious::Routes::Images
  # Avatars, banners and other large image assets.
  def self.ggpht(env)
    url = env.request.path.lchop("/ggpht")

    headers = HTTP::Headers.new

    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    begin
      GGPHT_POOL.client &.get(url, headers) do |resp|
        return self.proxy_image(env, resp)
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

    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    begin
      get_ytimg_pool(authority).client &.get(url, headers) do |resp|
        env.response.headers["Connection"] = "close"
        return self.proxy_image(env, resp)
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

    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    begin
      get_ytimg_pool("i9").client &.get(url, headers) do |resp|
        return self.proxy_image(env, resp)
      end
    rescue ex
    end
  end

  def self.yts_image(env)
    headers = HTTP::Headers.new
    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    begin
      YT_POOL.client &.get(env.request.resource, headers) do |response|
        env.response.status_code = response.status_code
        response.headers.each do |key, value|
          if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
            env.response.headers[key] = value
          end
        end

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

    if name == "maxres.jpg"
      build_thumbnails(id).each do |thumb|
        thumbnail_resource_path = "/vi/#{id}/#{thumb[:url]}.jpg"
        if get_ytimg_pool("i9").client &.head(thumbnail_resource_path, headers).status_code == 200
          name = thumb[:url] + ".jpg"
          break
        end
      end
    end

    url = "/vi/#{id}/#{name}"

    REQUEST_HEADERS_WHITELIST.each do |header|
      if env.request.headers[header]?
        headers[header] = env.request.headers[header]
      end
    end

    begin
      get_ytimg_pool("i").client &.get(url, headers) do |resp|
        return self.proxy_image(env, resp)
      end
    rescue ex
    end
  end

  private def self.proxy_image(env, response)
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      if !RESPONSE_HEADERS_BLACKLIST.includes?(key.downcase)
        env.response.headers[key] = value
      end
    end

    env.response.headers["Access-Control-Allow-Origin"] = "*"

    if response.status_code >= 300
      return env.response.headers.delete("Transfer-Encoding")
    end

    return proxy_file(response, env)
  end
end
