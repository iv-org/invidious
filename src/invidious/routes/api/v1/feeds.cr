module Invidious::Routes::API::V1::Feeds
  def self.popular(env)
    locale = env.get("preferences").as(Preferences).locale

    env.response.content_type = "application/json"

    if !CONFIG.popular_enabled
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
