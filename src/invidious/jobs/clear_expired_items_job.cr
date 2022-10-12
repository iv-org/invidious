class Invidious::Jobs::ClearExpiredItemsJob < Invidious::Jobs::BaseJob
  # Remove items (videos, nonces, etc..) whose cache is outdated every hour.
  # Removes the need for a cron job.
  def begin
    loop do
      failed = false

      LOGGER.info("jobs: running ClearExpiredItems job")

      begin
        Invidious::Database::Videos.delete_expired
        Invidious::Database::Nonces.delete_expired
      rescue DB::Error
        failed = true
      end

      # Retry earlier than scheduled on DB error
      if failed
        LOGGER.info("jobs: ClearExpiredItems failed. Retrying in 10 minutes.")
        sleep 10.minutes
      else
        LOGGER.info("jobs: ClearExpiredItems done.")
        sleep 1.hour
      end
    end
  end
end
