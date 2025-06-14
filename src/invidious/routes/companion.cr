module Invidious::Routes::Companion
  # /companion
  def self.get_companion(env)
    url = env.request.path.lchop("/companion")

    begin
      COMPANION_POOL.client &.get(url, env.request.header) do |resp|
        return self.proxy_companion(env, resp)
      end
    rescue ex
    end
  end

  def self.options_companion(env)
    url = env.request.path.lchop("/companion")

    begin
      COMPANION_POOL.client &.options(url, env.request.header) do |resp|
        return self.proxy_companion(env, resp)
      end
    rescue ex
    end
  end

  private def self.proxy_companion(env, response)
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      env.response.headers[key] = value
    end

    return IO.copy response.body_io, env.response
  end
end
