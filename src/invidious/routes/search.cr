{% skip_file if flag?(:api_only) %}

module Invidious::Routes::Search
  def self.opensearch(env)
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

  def self.results(env)
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

  def self.search(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    region = env.params.query["region"]?

    query = env.params.query["search_query"]?
    query ||= env.params.query["q"]?

    if !query || query.empty?
      # Display the full page search box implemented in #1977
      env.set "search", ""
      templated "search_homepage", navbar_search: false
    else
      page = env.params.query["page"]?.try &.to_i?
      page ||= 1

      user = env.get? "user"

      begin
        search_query, count, videos, operators = process_search_query(query, page, user, region: region)
      rescue ex
        return error_template(500, ex)
      end

      operator_hash = {} of String => String
      operators.each do |operator|
        key, value = operator.downcase.split(":")
        operator_hash[key] = value
      end

      env.set "search", query
      templated "search"
    end
  end
end
