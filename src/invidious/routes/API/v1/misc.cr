class Invidious::Routes::V1Api < Invidious::Routes::BaseRoute
  # Stats API endpoint for Invidious
  def stats(env)
    locale = LOCALES[env.get("preferences").as(Preferences).locale]?
    env.response.content_type = "application/json"

    if !CONFIG.statistics_enabled
      return error_json(400, "Statistics are not enabled.")
    end

    Invidious::Jobs::StatisticsRefreshJob::STATISTICS.to_json
  end
end
