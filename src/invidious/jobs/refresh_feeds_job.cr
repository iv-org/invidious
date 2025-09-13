class Invidious::Jobs::RefreshFeedsJob < Invidious::Jobs::BaseJob
  private getter db : DB::Database

  def initialize(@db)
  end

  def begin
    max_fibers = CONFIG.feed_threads
    active_fibers = 0
    active_channel = ::Channel(Bool).new

    loop do
      db.query("SELECT email FROM users WHERE feed_needs_update = true OR feed_needs_update IS NULL") do |rs|
        rs.each do
          email = rs.read(String)
          view_name = "subscriptions_#{sha256(email)}"

          if active_fibers >= max_fibers
            if active_channel.receive
              active_fibers -= 1
            end
          end

          active_fibers += 1
          spawn do
            begin
              # Drop outdated views
              column_array = Invidious::Database.get_column_array(db, view_name)
              ChannelVideo.type_array.each_with_index do |name, i|
                if name != column_array[i]?
                  Log.info { "DROP MATERIALIZED VIEW #{view_name}" }
                  db.exec("DROP MATERIALIZED VIEW #{view_name}")
                  raise "view does not exist"
                end
              end

              if !db.query_one("SELECT pg_get_viewdef('#{view_name}')", as: String).includes? "WHERE ((cv.ucid = ANY (u.subscriptions))"
                Log.info { "Materialized view #{view_name} is out-of-date, recreating..." }
                db.exec("DROP MATERIALIZED VIEW #{view_name}")
              end

              db.exec("REFRESH MATERIALIZED VIEW #{view_name}")
              db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
            rescue ex
              # Rename old views
              begin
                legacy_view_name = "subscriptions_#{sha256(email)[0..7]}"

                db.exec("SELECT * FROM #{legacy_view_name} LIMIT 0")
                Log.info { "RENAME MATERIALIZED VIEW #{legacy_view_name}" }
                db.exec("ALTER MATERIALIZED VIEW #{legacy_view_name} RENAME TO #{view_name}")
              rescue ex
                begin
                  # While iterating through, we may have an email stored from a deleted account
                  if db.query_one?("SELECT true FROM users WHERE email = $1", email, as: Bool)
                    Log.info { "CREATE #{view_name}" }
                    db.exec("CREATE MATERIALIZED VIEW #{view_name} AS #{MATERIALIZED_VIEW_SQL.call(email)}")
                    db.exec("UPDATE users SET feed_needs_update = false WHERE email = $1", email)
                  end
                rescue ex
                  Log.error { "REFRESH #{email} : #{ex.message}" }
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
