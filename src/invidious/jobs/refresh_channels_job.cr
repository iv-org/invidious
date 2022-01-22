class Invidious::Jobs::RefreshChannelsJob < Invidious::Jobs::BaseJob
  def begin
    max_fibers = CONFIG.channel_threads
    lim_fibers = max_fibers
    active_fibers = 0
    active_channel = Channel(Bool).new
    backoff = 2.minutes

    loop do
      LOGGER.debug("RefreshChannelsJob: Refreshing all channels")
      Invidious::Database::Channels.select_all.each do |channel|
        if active_fibers >= lim_fibers
          LOGGER.trace("RefreshChannelsJob: Fiber limit reached, waiting...")
          if active_channel.receive
            LOGGER.trace("RefreshChannelsJob: Fiber limit ok, continuing")
            active_fibers -= 1
          end
        end

        LOGGER.debug("RefreshChannelsJob: #{channel.id} : Spawning fiber")
        active_fibers += 1
        spawn do
          if refresh_channel(channel)
            lim_fibers = max_fibers
          else
            lim_fibers = 1
            LOGGER.error("RefreshChannelsJob: #{channel.id} fiber : backing off for #{backoff}s")
            sleep backoff
            if backoff < 1.days
              backoff += backoff
            else
              backoff = 1.days
            end
          end

          LOGGER.debug("RefreshChannelsJob: #{channel.id} fiber : Done")
          active_channel.send(true)
        end
      end

      # TODO: make this configurable
      LOGGER.debug("RefreshChannelsJob: Done, sleeping for thirty minutes")
      sleep 30.minutes
      Fiber.yield
    end
  end

  private def refresh_channel(channel : InvidiousChannel) : Bool
    id = channel.id

    LOGGER.trace("RefreshChannelsJob: #{id} fiber : Fetching channel")
    channel = fetch_channel(id, CONFIG.full_refresh)

    LOGGER.trace("RefreshChannelsJob: #{id} fiber : Updating DB")
    Invidious::Database::Channels.update_author(id, channel.author)
    return true
  rescue ex
    LOGGER.error("RefreshChannelsJob: #{id} : #{ex.message}")
    if ex.message == "Deleted or invalid channel"
      Invidious::Database::Channels.update_mark_deleted(id) if id
      return true
    else
      return false
    end
  end
end
