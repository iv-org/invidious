class Invidious::Jobs::SubscribeToFeedsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database
  private getter logger : Invidious::LogHandler
  private getter hmac_key : String
  private getter config : Config

  def initialize(@db, @logger, @config, @hmac_key)
  end

  def begin
    max_threads = 1
    if config.use_pubsub_feeds.is_a?(Int32)
      max_threads = config.use_pubsub_feeds.as(Int32)
    end

    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query_all("SELECT id FROM channels WHERE CURRENT_TIMESTAMP - subscribed > interval '4 days' OR subscribed IS NULL") do |rs|
        rs.each do
          ucid = rs.read(String)

          if active_threads >= max_threads.as(Int32)
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1

          spawn do
            begin
              response = subscribe_pubsub(ucid, hmac_key, config)

              if response.status_code >= 400
                logger.puts("#{ucid} : #{response.body}")
              end
            rescue ex
              logger.puts("#{ucid} : #{ex.message}")
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
