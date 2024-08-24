{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Search
  def self.opensearch(env)
    locale = env.get("preferences").as(Preferences).locale
    env.response.content_type = "application/opensearchdescription+xml"

    XML.build(indent: "  ", encoding: "UTF-8") do |xml|
      xml.element("OpenSearchDescription", xmlns: "http://a9.com/-/spec/opensearch/1.1/") do
        xml.element("ShortName") { xml.text "Invidious" }
        xml.element("LongName") { xml.text "Invidious Search" }
        xml.element("Description") { xml.text "Search for videos, channels, and playlists on Invidious" }
        xml.element("InputEncoding") { xml.text "UTF-8" }
        xml.element("Image", width: 48, height: 48, type: "image/x-icon") { xml.text "#{HOST_URL}/favicon.ico" }
        xml.element("Url", type: "text/html", method: "get", template: "#{HOST_URL}/search?q={searchTerms}")
      end
    end
  end

  def self.results(env)
    locale = env.get("preferences").as(Preferences).locale

    query = env.params.query["search_query"]?
    query ||= env.params.query["q"]?

    page = env.params.query["page"]?

    if query && !query.empty?
      if page && !page.empty?
        env.redirect "/search?q=" + URI.encode_www_form(query) + "&page=" + page
      else
        env.redirect "/search?q=" + URI.encode_www_form(query)
      end
    else
      env.redirect "/search"
    end
  end

  def self.search(env)
    prefs = env.get("preferences").as(Preferences)
    locale = prefs.locale

    region = env.params.query["region"]? || prefs.region

    query = Invidious::Search::Query.new(env.params.query, :regular, region)

    if query.empty?
      # Display the full page search box implemented in #1977
      env.set "search", ""
      templated "search_homepage", navbar_search: false
    else
      user = env.get? "user"

      # An URL was copy/pasted in the search box.
      # Redirect the user to the appropriate page.
      if query.url?
        return env.redirect UrlSanitizer.process(query.text).to_s
      end

      begin
        items = query.process
      rescue ex : ChannelSearchException
        return error_template(404, "Unable to find channel with id of '#{HTML.escape(ex.channel)}'. Are you sure that's an actual channel id? It should look like 'UC4QobU6STFB0P71PMvOGN5A'.")
      rescue ex
        return error_template(500, ex)
      end

      redirect_url = Invidious::Frontend::Misc.redirect_url(env)

      # Pagination
      page_nav_html = Frontend::Pagination.nav_numeric(locale,
        base_url: "/search?#{query.to_http_params}",
        current_page: query.page,
        show_next: (items.size >= 20)
      )

      if query.type == Invidious::Search::Query::Type::Channel
        env.set "search", "channel:#{query.channel} #{query.text}"
      else
        env.set "search", query.text
      end

      templated "search"
    end
  end

  def self.hashtag(env : HTTP::Server::Context)
    locale = env.get("preferences").as(Preferences).locale

    hashtag = env.params.url["hashtag"]?
    if hashtag.nil? || hashtag.empty?
      return error_template(400, "Invalid request")
    end

    page = env.params.query["page"]?
    if page.nil?
      page = 1
    else
      page = Math.max(1, page.to_i)
      env.params.query.delete_all("page")
    end

    begin
      hashtag_page = Invidious::Hashtag.fetch(hashtag, page)
      items = hashtag_page.videos
    rescue ex
      return error_template(500, ex)
    end

    # Pagination
    hashtag_encoded = URI.encode_www_form(hashtag, space_to_plus: false)
    page_nav_html = Frontend::Pagination.nav_numeric(locale,
      base_url: "/hashtag/#{hashtag_encoded}",
      current_page: page,
      show_next: hashtag_page.has_next_continuation
    )

    templated "hashtag"
  end
end
