class Invidious::Jobs::StatisticsRefreshJob < Invidious::Jobs::BaseJob
  STATISTICS = {
    "version"  => "2.0",
    "software" => {
      "name"    => "invidious",
      "version" => "",
      "branch"  => "",
    },
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
  private getter config : Config

  def initialize(@db, @config, @software_config : Hash(String, String))
  end

  def begin
    load_initial_stats

    loop do
      refresh_stats
      sleep 1.minute
      Fiber.yield
    end
  end

  # should only be called once at the very beginning
  private def load_initial_stats
    STATISTICS["software"] = {
      "name"    => @software_config["name"],
      "version" => @software_config["version"],
      "branch"  => @software_config["branch"],
    }
    STATISTICS["openRegistration"] = config.registration_enabled
  end

  private def refresh_stats
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
