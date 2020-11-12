class Invidious::Routes::Embed::Index < Invidious::Routes::BaseRoute
  def handle(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

    if plid = env.params.query["list"]?.try &.gsub(/[^a-zA-Z0-9_-]/, "")
      begin
        playlist = get_playlist(PG_DB, plid, locale: locale)
        offset = env.params.query["index"]?.try &.to_i? || 0
        videos = get_playlist_videos(PG_DB, playlist, offset: offset, locale: locale)
      rescue ex
        error_message = ex.message
        env.response.status_code = 500
        return templated "error"
      end

      url = "/embed/#{videos[0].id}?#{env.params.query}"

      if env.params.query.size > 0
        url += "?#{env.params.query}"
      end
    else
      url = "/"
    end

    env.redirect url
  end
end
