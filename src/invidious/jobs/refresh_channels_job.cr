class Invidious::Jobs::RefreshChannelsJob < Invidious::Jobs::BaseJob
  Log = ::Log.for(self)

  private getter db : DB::Database

  def initialize(@db)
  end

  def begin
    max_fibers = CONFIG.channel_threads
    lim_fibers = max_fibers
    active_fibers = 0
    active_channel = ::Channel(Bool).new
    backoff = 2.minutes

    loop do
      Log.debug { "Refreshing all channels" }
      PG_DB.query("SELECT id FROM channels ORDER BY updated") do |rs|
        rs.each do
          id = rs.read(String)

          if active_fibers >= lim_fibers
            Log.trace { "Fiber limit reached, waiting..." }
            if active_channel.receive
              Log.trace { "Fiber limit ok, continuing" }
              active_fibers -= 1
            end
          end

          Log.debug { "#{id} : Spawning fiber" }
          active_fibers += 1
          spawn do
            begin
              Log.trace { "#{id} fiber : Fetching channel" }
              channel = fetch_channel(id, pull_all_videos: CONFIG.full_refresh)

              lim_fibers = max_fibers

              Log.trace { "#{id} fiber : Updating DB" }
              Invidious::Database::Channels.update_author(id, channel.author)
            rescue ex
              Log.error { "#{id} : #{ex.message}" }
              if ex.message == "Deleted or invalid channel"
                Invidious::Database::Channels.update_mark_deleted(id)
              else
                lim_fibers = 1
                Log.error { "#{id} fiber : backing off for #{backoff}s" }
                sleep backoff
                if backoff < 1.days
                  backoff += backoff
                else
                  backoff = 1.days
                end
              end
            ensure
              Log.debug { "#{id} fiber : Done" }
              active_channel.send(true)
            end
          end
        end
      end

      Log.debug { "Done, sleeping for #{CONFIG.channel_refresh_interval}" }
      sleep CONFIG.channel_refresh_interval
      Fiber.yield
    end
  end
end
