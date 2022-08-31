class Invidious::Jobs::ClearExpiredItemsJob < Invidious::Jobs::BaseJob
  # Remove items (videos, nonces, etc..) whose cache is outdated every hour.
  # Removes the need for a cron job.
  def begin
    loop do
      failed = false

      begin
        Invidious::Database::Videos.delete_expired
        Invidious::Database::Nonces.delete_expired
      rescue DB::Error
        failed = true
      end

      # Retry earlier than scheduled on DB error
      if failed
        sleep 10.minutes
      else
        sleep 1.hour
      end
    end
  end
end
