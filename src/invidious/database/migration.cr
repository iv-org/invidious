abstract class Invidious::Database::Migration
  macro inherited
    Migrator.migrations << self
  end

  @@version : Int64?

  def self.version(version : Int32 | Int64)
    @@version = version.to_i64
  end

  getter? completed = false

  def initialize(@db : DB::Database)
  end

  abstract def up(conn : DB::Connection)

  def migrate
    # migrator already ignores completed migrations
    # but this is an extra check to make sure a migration doesn't run twice
    return if completed?

    @db.transaction do |txn|
      up(txn.connection)
      track(txn.connection)
      @completed = true
    end
  end

  def version : Int64
    @@version.not_nil!
  end

  private def track(conn : DB::Connection)
    conn.exec("INSERT INTO #{Migrator::MIGRATIONS_TABLE} (version) VALUES ($1)", version)
  end
end
