class Invidious::Migrator
  MIGRATIONS_TABLE = "invidious_migrations"

  class_getter migrations = [] of Invidious::Migration.class

  def initialize(@db : DB::Database)
  end

  def migrate
    run_migrations = load_run_migrations
    migrations = load_migrations.sort_by(&.version)
    migrations_to_run = migrations.reject { |migration| run_migrations.includes?(migration.version) }
    if migrations.empty?
      puts "No migrations to run."
      return
    end

    migrations_to_run.each do |migration|
      puts "Running migration: #{migration.class.name}"
      migration.migrate
    end
  end

  private def load_migrations : Array(Invidious::Migration)
    self.class.migrations.map(&.new(@db))
  end

  private def load_run_migrations : Array(Int64)
    create_migrations_table
    @db.query_all("SELECT version FROM #{MIGRATIONS_TABLE}", as: Int64)
  end

  private def create_migrations_table
    @db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS #{MIGRATIONS_TABLE} (
        id bigserial PRIMARY KEY,
        version bigint NOT NULL
      )
    SQL
  end
end
