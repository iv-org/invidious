class Invidious::Jobs::SubscribeToFeedsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database
  private getter hmac_key : String

  def initialize(@db, @hmac_key)
  end

  def begin
    max_fibers = 1
    if CONFIG.use_pubsub_feeds.is_a?(Int32)
      max_fibers = CONFIG.use_pubsub_feeds.as(Int32)
    end

    active_fibers = 0
    active_channel = Channel(Bool).new

    loop do
      db.query_all("SELECT id FROM channels WHERE CURRENT_TIMESTAMP - subscribed > interval '4 days' OR subscribed IS NULL") do |rs|
        rs.each do
          ucid = rs.read(String)

          if active_fibers >= max_fibers.as(Int32)
            if active_channel.receive
              active_fibers -= 1
            end
          end

          active_fibers += 1

          spawn do
            begin
              response = subscribe_pubsub(ucid, hmac_key)

              if response.status_code >= 400
                LOGGER.error("SubscribeToFeedsJob: #{ucid} : #{response.body}")
              end
            rescue ex
              LOGGER.error("SubscribeToFeedsJob: #{ucid} : #{ex.message}")
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
