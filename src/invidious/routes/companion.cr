module Invidious::Routes::Companion
  extend self

  # GET /companion
  def get_companion(env)
    url = make_url(env)
    proxy_companion(env, "GET", url)
  end

  # POST /companion
  def post_companion(env)
    url = make_url(env)
    proxy_companion(env, "POST", url)
  end

  # OPTIONS /companion
  def options_companion(env)
    url = make_url(env)
    proxy_companion(env, "OPTIONS", url)
  end

  private def make_url(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end
    url
  end

  private def proxy_companion(env, method, url)
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
