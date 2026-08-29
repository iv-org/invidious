module Invidious::Routes::Companion
  SUBTITLE_CACHE = Invidious::SubtitleCache.new

  # GET /companion
  def self.get_companion(env)
    url = env.request.path
    if env.request.query
      url += "?#{env.request.query}"
    end

    path = env.request.path.rstrip('/')
    if match = path.match(Invidious::SubtitleCache::CAPTION_PATH_REGEX)
      video_id = match[1]
      return self.handle_caption_request(env, url, video_id)
    end

    begin
      COMPANION_POOL.client do |wrapper|
        wrapper.client.get(url, env.request.headers) do |resp|
          return self.proxy_companion(env, resp)
        end
      end
    rescue ex
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
    end
  end

  private def self.handle_caption_request(env, url, video_id)
    label = env.params.query["label"]? || ""
    lang = env.params.query["lang"]? || ""
    tlang = env.params.query["tlang"]? || ""
    check = env.params.query["check"]? || ""

    # Verify check token before accessing cache
    valid_check = invidious_companion_verify_check(check, video_id)

    unless valid_check
      # Bypass cache if token is invalid or expired
      begin
        COMPANION_POOL.client do |wrapper|
          wrapper.client.get(url, env.request.headers) do |resp|
            env.response.headers["X-Invidious-Subtitle-Cache"] = "bypass"
            return self.proxy_companion(env, resp)
          end
        end
      rescue ex
      end
      return
    end

    cache_key = "video:#{video_id}|label:#{label}|lang:#{lang}|tlang:#{tlang}"

    result = SUBTITLE_CACHE.get_or_fetch(cache_key) do
      fetch_from_companion(url, env.request.headers)
    end

    if entry = result.entry
      env.response.status_code = 200
      env.response.headers["Access-Control-Allow-Origin"] = "*"
      env.response.headers["Content-Type"] = entry.content_type
      env.response.headers["Cache-Control"] = "private, max-age=21600"
      env.response.headers["X-Invidious-Subtitle-Cache"] = result.cache_status
      env.response.print entry.body
      return
    elsif response = result.response
      env.response.status_code = response.status_code
      response.headers.each do |key, value|
        env.response.headers[key] = value
      end
      env.response.headers["X-Invidious-Subtitle-Cache"] = result.cache_status
      env.response.print response.body
    end
  end

  private def self.fetch_from_companion(url : String, headers : HTTP::Headers) : Invidious::SubtitleCache::Response?
    COMPANION_POOL.client do |wrapper|
      wrapper.client.get(url, headers) do |resp|
        limited_body = Invidious::SubtitleCache.read_limited_body(resp.body_io)
        if limited_body.oversized
          resp.body_io.close
          return oversized_caption_response
        end

        body = limited_body.body
        return nil unless body
        response_headers = HTTP::Headers.new
        resp.headers.each do |key, value|
          response_headers[key] = value
        end
        return Invidious::SubtitleCache::Response.new(resp.status_code, response_headers, body)
      end
    end
  rescue ex
    nil
  end

  private def self.oversized_caption_response
    headers = HTTP::Headers.new
    headers["Access-Control-Allow-Origin"] = "*"
    headers["Cache-Control"] = "no-store"
    headers["Content-Type"] = "text/plain; charset=utf-8"
    Invidious::SubtitleCache::Response.new(413, headers, "Caption response exceeds size limit\n")
  end

  private def self.proxy_companion(env, response)
    env.response.status_code = response.status_code
    response.headers.each do |key, value|
      env.response.headers[key] = value
    end

    return IO.copy response.body_io, env.response
  end
end
