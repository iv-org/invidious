module Invidious::Routes::API::V1::Search
  def self.search(env)
    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?

    env.response.content_type = "application/json"

    query = Invidious::Search::Query.new(env.params.query, :regular, region)

    begin
      search_results = query.process
    rescue ex
      return error_json(400, ex)
    end

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

  def self.hashtag(env)
    hashtag = env.params.url["hashtag"]

    page = env.params.query["page"]?.try &.to_i? || 1

    locale = env.get("preferences").as(Preferences).locale
    region = env.params.query["region"]?
    env.response.content_type = "application/json"

    begin
      results = Invidious::Hashtag.fetch(hashtag, page, region)
    rescue ex
      return error_json(400, ex)
    end

    JSON.build do |json|
      json.object do
        json.field "results" do
          json.array do
            results.each do |item|
              item.to_json(locale, json)
            end
          end
        end
      end
    end
  end
end
