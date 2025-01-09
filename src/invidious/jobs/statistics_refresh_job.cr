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

    #
    #    "totalRequests" => 0_i64,
    #    "successfulRequests" => 0_i64
    #    "ratio"   => 0_i64
    #
    "playback" => {} of String => Int64 | Float64,
  }

  STATISTICS_PROMETHEUS = {
    "invidious_updated_at"                => Time.utc.to_unix,
    "invidious_last_channel_refreshed_at" => 0_i64,
  }

  private getter db : DB::Database

  def initialize(@db, @software_config : Hash(String, String))
  end

  def begin
    load_initial_stats

    loop do
      refresh_stats
      sleep 10.minute
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
    STATISTICS["openRegistrations"] = CONFIG.registration_enabled
  end

  private def refresh_stats
    users = STATISTICS.dig("usage", "users").as(Hash(String, Int64))

    users["total"] = Invidious::Database::Statistics.count_users_total
    users["activeHalfyear"] = Invidious::Database::Statistics.count_users_active_6m
    users["activeMonth"] = Invidious::Database::Statistics.count_users_active_1m

    STATISTICS_PROMETHEUS["invidious_updated_at"] = Time.utc.to_unix
    STATISTICS_PROMETHEUS["invidious_last_channel_refreshed_at"] = Invidious::Database::Statistics.channel_last_update.try &.to_unix || 0_i64

    STATISTICS["metadata"] = {
      "updatedAt"              => Time.utc.to_unix,
      "lastChannelRefreshedAt" => Invidious::Database::Statistics.channel_last_update.try &.to_unix || 0_i64,
    }

    # Reset playback requests tracker
    STATISTICS["playback"] = {} of String => Int64 | Float64
  end
end
