class Invidious::Routes::Search < Invidious::Routes::BaseRoute
  def opensearch(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
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

  def results(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?

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

  def search(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    region = env.params.query["region"]?

    query = env.params.query["search_query"]?
    query ||= env.params.query["q"]?
    query ||= env.params.query["query"]?

    if !query || query.empty?
      # Display the full page search box implemented in #1977
      env.set "search", ""
      templated "search_homepage", navbar_search: false
    else
      page = env.params.query["page"]?.try &.to_i?
      page ||= 1

      user = env.get? "user"

      begin
        search_query, count, items, operators = process_search_query(env.params.query, query, page, user, region: nil)
      rescue ex
        return error_template(500, ex)
      end

      if operators.fetch("channel", false) && count > 0
        channel = get_about_info(operators.fetch("channel", "Placeholder. This will never get reached!"), locale).not_nil!
        if user
          user = user.as(User)
          subscriptions = user.subscriptions
        end
        subscriptions ||= [] of String
      end

      env.set "search", query
      templated "search"
    end
  end
end
