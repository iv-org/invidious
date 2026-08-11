module Invidious::Routes::Companion
  # GET /companion
  def self.get_companion(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end

    begin
      COMPANION_POOL.client do |wrapper|
        wrapper.client.get(url, env.request.headers) do |resp|
          return self.proxy_companion(env, resp)
        end
      end
    rescue ex
      LOGGER.warn("Companion GET upstream request failed: #{ex.class}")
      env.response.status_code = 502
      return env.response.print("502 Bad Gateway")
    end
  end

  # POST /companion
  def self.post_companion(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end

    begin
      COMPANION_POOL.client do |wrapper|
        wrapper.client.post(url, env.request.headers, env.request.body) do |resp|
          return self.proxy_companion(env, resp)
        end
      end
    rescue ex
      LOGGER.warn("Companion POST upstream request failed: #{ex.class}")
      env.response.status_code = 502
      return env.response.print("502 Bad Gateway")
    end
  end

  def self.options_companion(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end

    begin
      COMPANION_POOL.client do |wrapper|
        wrapper.client.options(url, env.request.headers) do |resp|
          return self.proxy_companion(env, resp)
        end
      end
    rescue ex
      LOGGER.warn("Companion OPTIONS upstream request failed: #{ex.class}")
      env.response.status_code = 502
      return env.response.print("502 Bad Gateway")
    end
  end

  private def self.proxy_companion(env, response)
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      env.response.headers[key] = value
    end

    begin
      return IO.copy response.body_io, env.response
    rescue ex
      LOGGER.warn("Companion response stream failed: #{ex.class}")
      env.response.close unless env.response.closed?
      return
    end
  end
end
