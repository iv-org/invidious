module Invidious::Routes::ErrorRoutes
  def self.error_404(env)
    # Workaround for #3117 on versions prior to 1.16.0
    #
    # Crystal 1.16.0 fixed the parsing of some weird-looking paths
    # meaning that `//api/v1/storyboards/sb/i/...` will no longer
    # get parsed into a request target of `/v1/storyboards/sb/i/...`
    #
    # This also means that we won't be able to handle the logic here
    # because status code error handles are disabled for the API routes

    # We only need to include this workaround on versions prior to 1.16.0
    {% if compare_versions(Crystal::VERSION, "1.16.0") < 0 %}
      if HOST_URL.empty? && env.request.path.starts_with?("/v1/storyboards/sb")
        return env.redirect "#{env.request.path[15..]}?#{env.params.query}"
      end
    {% end %}

    if md = env.request.path.match(/^\/(?<id>([a-zA-Z0-9_-]{11})|(\w+))$/)
      item = md["id"]

      # Check if item is branding URL e.g. https://youtube.com/gaming
      response = YT_POOL.client &.get("/#{item}")

      if response.status_code == 301
        response = YT_POOL.client &.get(URI.parse(response.headers["Location"]).request_target)
      end

      if response.body.empty?
        env.response.headers["Location"] = "/"
        haltf env, status_code: 302
      end

      html = XML.parse_html(response.body)
      ucid = html.xpath_node(%q(//link[@rel="canonical"])).try &.["href"].split("/")[-1]

      if ucid
        env.response.headers["Location"] = "/channel/#{ucid}"
        haltf env, status_code: 302
      end

      params = [] of String
      env.params.query.each do |k, v|
        params << "#{k}=#{v}"
      end
      params = params.join("&")

      url = "/watch?v=#{item}"
      if !params.empty?
        url += "&#{params}"
      end

      # Check if item is video ID
      if item.match(/^[a-zA-Z0-9_-]{11}$/) && YT_POOL.client &.head("/watch?v=#{item}").status_code != 404
        env.response.headers["Location"] = url
        haltf env, status_code: 302
      end
    end

    env.response.headers["Location"] = "/"
    haltf env, status_code: 302
  end
end
