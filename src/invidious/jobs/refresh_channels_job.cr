class Invidious::Jobs::RefreshChannelsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database

  def initialize(@db)
  end

  def begin
    max_fibers = CONFIG.channel_threads
    lim_fibers = max_fibers
    active_fibers = 0
    active_channel = Channel(Bool).new
    backoff = 2.minutes

    loop do
      LOGGER.debug("RefreshChannelsJob: Refreshing all channels")
      db.query("SELECT id FROM channels ORDER BY updated") do |rs|
        rs.each do
          id = rs.read(String)

          if active_fibers >= lim_fibers
            LOGGER.trace("RefreshChannelsJob: Fiber limit reached, waiting...")
            if active_channel.receive
              LOGGER.trace("RefreshChannelsJob: Fiber limit ok, continuing")
              active_fibers -= 1
            end
          end

          LOGGER.debug("RefreshChannelsJob: #{id} : Spawning fiber")
          active_fibers += 1
          spawn do
            begin
              LOGGER.trace("RefreshChannelsJob: #{id} fiber : Fetching channel")
              channel = fetch_channel(id, db, CONFIG.full_refresh)

              lim_fibers = max_fibers

              LOGGER.trace("RefreshChannelsJob: #{id} fiber : Updating DB")
              db.exec("UPDATE channels SET updated = $1, author = $2, deleted = false WHERE id = $3", Time.utc, channel.author, id)
            rescue ex
              LOGGER.error("RefreshChannelsJob: #{id} : #{ex.message}")
              if ex.message == "Deleted or invalid channel"
                db.exec("UPDATE channels SET updated = $1, deleted = true WHERE id = $2", Time.utc, id)
              else
                lim_fibers = 1
                LOGGER.error("RefreshChannelsJob: #{id} fiber : backing off for #{backoff}s")
                sleep backoff
                if backoff < 1.days
                  backoff += backoff
                else
                  backoff = 1.days
                end
              end
            ensure
              LOGGER.debug("RefreshChannelsJob: #{id} fiber : Done")
              active_channel.send(true)
            end
          end
        end
      end

      # TODO: make this configurable
      LOGGER.debug("RefreshChannelsJob: Done, sleeping for thirty minutes")
      sleep 30.minutes
      Fiber.yield
    end
  end
end
