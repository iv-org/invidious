module Invidious::Routes::APIv1
  # Stats API endpoint for Invidious
  def self.stats(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    env.response.content_type = "application/json"

    if !CONFIG.statistics_enabled
      return error_json(400, "Statistics are not enabled.")
    end

    Invidious::Jobs::StatisticsRefreshJob::STATISTICS.to_json
  end
end
