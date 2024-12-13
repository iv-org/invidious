require "uri"

module UrlSanitizer
  extend self

  ALLOWED_QUERY_PARAMS = {
    channel:  ["u", "user", "lb"],
    playlist: ["list"],
    search:   ["q", "search_query", "sp"],
    watch:    [
      "v",                                  # Video ID
      "list", "index",                      # Playlist-related
      "playlist",                           # Unnamed playlist (id,id,id,...) (embed-only?)
      "t", "time_continue", "start", "end", # Timestamp
      "lc",                                 # Highlighted comment (watch page only)
    ],
  }

  # Returns whether the given string is an ASCII word. This is the same as
  # running the following regex in US-ASCII locale: /^[\w-]+$/
  private def ascii_word?(str : String) : Bool
    return false if str.bytesize != str.size

    str.each_byte do |byte|
      next if 'a'.ord <= byte <= 'z'.ord
      next if 'A'.ord <= byte <= 'Z'.ord
      next if '0'.ord <= byte <= '9'.ord
      next if byte == '-'.ord || byte == '_'.ord

      return false
    end

    return true
  end

  # Return which kind of parameters are allowed based on the
  # first path component (breadcrumb 0).
  private def determine_allowed(path_root : String)
    case path_root
    when "watch", "w", "v", "embed", "e", "shorts", "clip"
      return :watch
    when .starts_with?("@"), "c", "channel", "user", "profile", "attribution_link"
      return :channel
    when "playlist", "mix"
      return :playlist
    when "results", "search"
      return :search
    else # hashtag, post, trending, brand URLs, etc..
      return nil
    end
  end

  # Create a new URI::Param containing only the allowed parameters
  private def copy_params(unsafe_params : URI::Params, allowed_type) : URI::Params
    new_params = URI::Params.new

    ALLOWED_QUERY_PARAMS[allowed_type].each do |name|
      if unsafe_params[name]?
        # Only copy the last parameter, in case there is more than one
        new_params[name] = unsafe_params.fetch_all(name)[-1]
      end
    end

    return new_params
  end

  # Transform any user-supplied youtube URL into something we can trust
  # and use across the code.
  def process(str : String) : URI
    # Because URI follows RFC3986 specifications, URL without a scheme
    # will be parsed as a relative path. So we have to add a scheme ourselves.
    str = "https://#{str}" if !str.starts_with?(/https?:\/\//)

    unsafe_uri = URI.parse(str)
    unsafe_host = unsafe_uri.host
    unsafe_path = unsafe_uri.path

    new_uri = URI.new(path: "/")

    # Redirect to homepage for bogus URLs
    return new_uri if (unsafe_host.nil? || unsafe_path.nil?)

    breadcrumbs = unsafe_path
      .split('/', remove_empty: true)
      .compact_map do |bc|
        # Exclude attempts at path trasversal
        next if bc == "." || bc == ".."

        # Non-alnum characters are unlikely in a genuine URL
        next if !ascii_word?(bc)

        bc
      end

    # If nothing remains, it's either a legit URL to the homepage
    # (who does that!?) or because we filtered some junk earlier.
    return new_uri if breadcrumbs.empty?

    # Replace the original query parameters with the sanitized ones
    case unsafe_host
    when .ends_with?("youtube.com")
      # Use our sanitized path (not forgetting the leading '/')
      new_uri.path = "/#{breadcrumbs.join('/')}"

      # Then determine which params are allowed, and copy them over
      if allowed = determine_allowed(breadcrumbs[0])
        new_uri.query_params = copy_params(unsafe_uri.query_params, allowed)
      end
    when "youtu.be"
      # Always redirect to the watch page
      new_uri.path = "/watch"

      new_params = copy_params(unsafe_uri.query_params, :watch)
      new_params["v"] = breadcrumbs[0]

      new_uri.query_params = new_params
    end

    return new_uri
  end
end
