module Invidious::Routes::ErrorRoutes
  def self.error_404(env)
    # Workaround for #3117
    if HOST_URL.empty? && env.request.path.starts_with?("/v1/storyboards/sb")
      return env.redirect "#{env.request.path[15..]}?#{env.params.query}"
    end

    if match = env.request.path.match(/^\/(?<id>[a-zA-Z0-9_-]{11})$/)
      # NOTE: we assume that a 11 chars long path is a video ID
      # to spare a call to 'resolve_url' and improve response time.
      id = match["id"]
      url = HttpServer::Utils.add_params_to_url("/watch?v=#{id}", env.params.query)
      return env.redirect url.to_s
      #
    elsif match = env.request.path.match(/^\/(?<name>\w+)$/)
      # Check if item is branding URL e.g. https://youtube.com/gaming
      begin
        response = YoutubeAPI.resolve_url("https://youtube.com/#{env.request.path}")
        endpoint = response["endpoint"]

        if ucid = endpoint.dig?("browseEndpoint", "browseId")
          url = HttpServer::Utils.add_params_to_url("/channel/#{ucid}", env.params.query)
          return env.redirect url.to_s
        end
      rescue ex
      end
    end

    # TODO: create a proper 404 page
    haltf env, status_code: 404
  end
end
