module Invidious::Routes::Companion
  # GET /companion
  def self.get_companion(env)
    url = self.make_url
    self.proxy_companion(env, "GET", url)
  end

  # POST /companion
  def self.post_companion(env)
    url = self.make_url
    self.proxy_companion(env, "POST", url)
  end

  # OPTIONS /companion
  def self.options_companion(env)
    url = self.make_url
    self.proxy_companion(env, "OPTIONS", url)
  end

  private def make_url(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end
  end

  private def self.proxy_companion(env, method, url)
    begin
      COMPANION_POOL.client do |wrapper|
        wrapper.client.exec(method, url, env.request.headers, (env.request.body if method == "POST")) do |resp|
          env.response.status_code = resp.status_code
          resp.headers.each do |key, value|
            env.response.headers[key] = value
          end
          env.response.headers["Via"] = "1.1 Invidious"
          return IO.copy resp.body_io, env.response
        end
      end
    rescue ex
      return error_json(502, "Couldn't proxy request to Invidious Companion.")
    end
  end
end
