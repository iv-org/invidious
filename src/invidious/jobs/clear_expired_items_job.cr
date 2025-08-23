class Invidious::Jobs::ClearExpiredItemsJob < Invidious::Jobs::BaseJob
  # Remove items (videos, nonces, etc..) whose cache is outdated every hour.
  # Removes the need for a cron job.
  def begin
    loop do
      failed = false

      Log.info { "running ClearExpiredItemsJob job" }

      begin
        Invidious::Database::Videos.delete_expired
        Invidious::Database::Nonces.delete_expired
      rescue DB::Error
        failed = true
      end

      # Retry earlier than scheduled on DB error
      if failed
        Log.info { "ClearExpiredItems failed. Retrying in 10 minutes." }
        sleep 10.minutes
      else
        Log.info { "ClearExpiredItems done." }
        sleep 1.hour
      end
    end
  end
end
