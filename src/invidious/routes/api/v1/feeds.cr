module Invidious::Routes::API::V1::Feeds
  def self.trending(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    if !CONFIG.page_enabled?("trending")
      error_message = {"error" => "Administrator has disabled this endpoint."}.to_json
      haltf env, 403, error_message
    end

    region = env.params.query["region"]?
    trending_type = env.params.query["type"]?

    begin
      trending, plid = fetch_trending(trending_type, region, locale)
    rescue ex
      return error_json(500, ex)
    end

    videos = JSON.build do |json|
      json.array do
        trending.each do |video|
          video.to_json(locale, json)
        end
      end
    end

    videos
  end

  def self.popular(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    if !CONFIG.page_enabled?("popular")
      error_message = {"error" => "Administrator has disabled this endpoint."}.to_json
      haltf env, 403, error_message
    end

    JSON.build do |json|
      json.array do
        popular_videos.each do |video|
          video.to_json(locale, json)
        end
      end
    end
  end
end
