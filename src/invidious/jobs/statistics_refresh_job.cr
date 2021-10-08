class Invidious::Jobs::StatisticsRefreshJob < Invidious::Jobs::BaseJob
  STATISTICS = {
    "version"           => "3.0",
    "software"          => SOFTWARE,
    "statisticsEnabled" => true,
    "openRegistrations" => true,
    "usage"             => {
      "users" => {
        "total"          => 0_i64,
        "activeHalfyear" => 0_i64,
        "activeMonth"    => 0_i64,
      },
    },
    "metadata" => {
      "updatedAt"              => Time.utc.to_unix,
      "lastChannelRefreshedAt" => 0_i64,
    },
  }

  private getter db : DB::Database

  def initialize(@db)
  end

  def begin
    loop do
      refresh_stats
      sleep 1.minute
      Fiber.yield
    end
  end

  private def refresh_stats
    STATISTICS["openRegistrations"] = CONFIG.registration_enabled
    users = STATISTICS.dig("usage", "users").as(Hash(String, Int64))
    users["total"] = db.query_one("SELECT count(*) FROM users", as: Int64)
    users["activeHalfyear"] = db.query_one("SELECT count(*) FROM users WHERE CURRENT_TIMESTAMP - updated < '6 months'", as: Int64)
    users["activeMonth"] = db.query_one("SELECT count(*) FROM users WHERE CURRENT_TIMESTAMP - updated < '1 month'", as: Int64)
    STATISTICS["metadata"] = {
      "updatedAt"              => Time.utc.to_unix,
      "lastChannelRefreshedAt" => db.query_one?("SELECT updated FROM channels ORDER BY updated DESC LIMIT 1", as: Time).try &.to_unix || 0_i64,
    }
  end
end
