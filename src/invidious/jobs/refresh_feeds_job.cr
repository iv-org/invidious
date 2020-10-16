class Invidious::Jobs::RefreshFeedsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database
  private getter logger : Invidious::LogHandler
  private getter config : Config

  def initialize(@db, @logger, @config)
  end

  def begin
    max_threads = config.feed_threads
    active_threads = 0
    active_channel = Channel(Bool).new

    loop do
      db.query("SELECT email FROM users WHERE feed_needs_update = true OR feed_needs_update IS NULL") do |rs|
        rs.each do
          email = rs.read(String)
          view_name = "subscriptions_#{sha256(email)}"

          if active_threads >= max_threads
            if active_channel.receive
              active_threads -= 1
            end
          end

          active_threads += 1
          spawn do
            begin
              # Drop outdated views
              column_array = get_column_array(db, view_name)
              ChannelVideo.type_array.each_with_index do |name, i|
                if name != column_array[i]?
                  logger.puts("DROP MATERIALIZED VIEW #{view_name}")
                  db.exec("DROP MATERIALIZED VIEW #{view_name}")
                  raise "view does not exist"
                end
              end

              if !db.query_one("SELECT pg_get_viewdef('#{view_name}')", as: String).includes? "WHERE ((cv.ucid = ANY (u.subscriptions))"
                logger.puts("Materialized view #{view_name} is out-of-date, recreating...")
                db.exec("DROP MATERIALIZED VIEW #{view_name}")
              end

              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
              db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
            rescue ex
              # Rename old views
              begin
                legacy_view_name = "subscriptions_#{sha256(email)[0..7]}"

                db.exec("SELECT * FROM #{legacy_view_name} LIMIT 0")
                logger.puts("RENAME MATERIALIZED VIEW #{legacy_view_name}")
                db.exec("ALTER MATERIALIZED VIEW #{legacy_view_name} RENAME TO #{view_name}")
              rescue ex
                begin
                  # While iterating through, we may have an email stored from a deleted account
                  if db.query_one?("SELECT true FROM users WHERE email = $1", email, as: Bool)
                    logger.puts("CREATE #{view_name}")
                    db.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(email)}")
                    db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
                  end
                rescue ex
                  logger.puts("REFRESH #{email} : #{ex.message}")
                end
              end
            end

            active_channel.send(true)
          end
        end
      end

      sleep 5.seconds
      Fiber.yield
    end
  end
end
