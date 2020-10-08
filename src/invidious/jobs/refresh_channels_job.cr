class Invidious::Jobs::RefreshChannelsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database
  private getter logger : Invidious::LogHandler
  private getter config : Config

  def initialize(@db, @logger, @config)
  end

  def begin
    max_threads = config.channel_threads
    lim_threads = max_threads
    active_threads = 0
    active_channel = Channel(Bool).new
    backoff = 1.seconds

    loop do
      db.query("SELECT id FROM channels ORDER BY updated") do |rs|
        rs.each do
          id = rs.read(String)

          if active_threads >= lim_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              channel = fetch_channel(id, db, config.full_refresh)

              lim_threads = max_threads
              db.exec("UPDATE channels SET updated = $1, author = $2, deleted = false WHERE id = $3", Time.utc, channel.author, id)
            rescue ex
              logger.puts("#{id} : #{ex.message}")
              if ex.message == "Deleted or invalid channel"
                db.exec("UPDATE channels SET updated = $1, deleted = true WHERE id = $2", Time.utc, id)
              else
                lim_threads = 1
                logger.puts("#{id} : backing off for #{backoff}s")
                sleep backoff
                if backoff < 1.days
                  backoff += backoff
                else
                  backoff = 1.days
                end
              end
            end

            active_channel.send(true)
          end
        end
      end

      sleep 1.minute
      Fiber.yield
    end
  end
end
