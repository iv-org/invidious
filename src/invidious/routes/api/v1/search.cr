module Invidious::Routes::API::V1::Search
  def self.search(env)
    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?

    env.response.content_type = "application/json"

    query = env.params.query["q"]?
    query ||= ""

    page = env.params.query["page"]?.try &.to_i?
    page ||= 1

    sort_by = env.params.query["sort_by"]?.try &.downcase
    sort_by ||= "relevance"

    date = env.params.query["date"]?.try &.downcase
    date ||= ""

    duration = env.params.query["duration"]?.try &.downcase
    duration ||= ""

    features = env.params.query["features"]?.try &.split(",").map(&.downcase)
    features ||= [] of String

    content_type = env.params.query["type"]?.try &.downcase
    content_type ||= "video"

    begin
      search_params = produce_search_params(page, sort_by, date, content_type, duration, features)
    rescue ex
      return error_json(400, ex)
    end

    search_results = search(query, search_params, region)
    JSON.build do |json|
      json.array do
        search_results.each do |item|
          item.to_json(locale, json)
        end
      end
    end
  end

  def self.search_suggestions(env)
    preferences = env.get("preferences").as(Preferences)
    region = env.params.query["region"]? || preferences.region

    env.response.content_type = "application/json"

    query = env.params.query["q"]? || ""

    begin
      client = HTTP::Client.new("suggestqueries-clients6.youtube.com")
      url = "/complete/search?client=youtube&hl=en&gl=#{region}&q=#{URI.encode_www_form(query)}&xssi=t&gs_ri=youtube&ds=yt"

      response = client.get(url).body

      body = JSON.parse(response[5..-1]).as_a
      suggestions = body[1].as_a[0..-2]

      JSON.build do |json|
        json.object do
          json.field "query", body[0].as_s
          json.field "suggestions" do
            json.array do
              suggestions.each do |suggestion|
                json.string suggestion[0].as_s
              end
            end
          end
        end
      end
    rescue ex
      return error_json(500, ex)
    end
  end
end
