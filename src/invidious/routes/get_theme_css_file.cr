# No need to initialize yet another namespace
#
# :nodoc:
module Invidious::Routes::Misc
  private CSS_THEME_LIGHT    = File.read("assets/css/light.css")
  private CSS_THEME_UA_LIGHT = CSS_THEME_LIGHT.gsub(".light-theme", ".no-theme")

  private CSS_THEME_DARK    = File.read("assets/css/dark.css")
  private CSS_THEME_UA_DARK = CSS_THEME_DARK.gsub(".dark-theme", ".no-theme")

  private THEME_LAST_MODIFIED = {
    File.info("assets/css/light.css").modification_time,
    File.info("assets/css/dark.css").modification_time,
  }.min

  def self.theme_css(env)
    env.response.headers["Content-Type"] = "text/css; charset=utf-8"

    # Replicate cache header behavior of static file handler
    env.response.headers["Etag"] = %{W/"#{THEME_LAST_MODIFIED.to_unix}"}
    env.response.headers["Last-Modified"] = HTTP.format_time(THEME_LAST_MODIFIED)

    if cache_request?(env, THEME_LAST_MODIFIED)
      env.response.status = HTTP::Status::NOT_MODIFIED
      return
    end

    # Usually added in `send_file` when static_headers proc is called
    env.response.headers["Cache-Control"] = "max-age=2629800"

    rendered "theme.css"
  end

  # Taken from https://github.com/crystal-lang/crystal/blob/1.16.3/src/http/server/handlers/static_file_handler.cr#L236
  private def self.cache_request?(context : HTTP::Server::Context, last_modified : Time) : Bool
    # According to RFC 7232:
    # A recipient must ignore If-Modified-Since if the request contains an If-None-Match header field
    if if_none_match = context.request.if_none_match
      match = {"*", context.response.headers["Etag"]}
      if_none_match.any? { |etag| match.includes?(etag) }
    elsif if_modified_since = context.request.headers["If-Modified-Since"]?
      header_time = HTTP.parse_time(if_modified_since)
      # File mtime probably has a higher resolution than the header value.
      # An exact comparison might be slightly off, so we add 1s padding.
      # Static files should generally not be modified in subsecond intervals, so this is perfectly safe.
      # This might be replaced by a more sophisticated time comparison when it becomes available.
      !!(header_time && last_modified <= header_time + 1.second)
    else
      false
    end
  end
end
