class Invidious::Database::Migrator
  MIGRATIONS_TABLE = "public.invidious_migrations"

  class_getter migrations = [] of Invidious::Database::Migration.class

  def initialize(@db : DB::Database)
  end

  def migrate
    versions = load_versions

    ran_migration = false
    load_migrations.sort_by(&.version)
      .each do |migration|
        next if versions.includes?(migration.version)

        puts "Running migration: #{migration.class.name}"
        migration.migrate
        ran_migration = true
      end

    puts "No migrations to run." unless ran_migration
  end

  def pending_migrations? : Bool
    versions = load_versions

    load_migrations.sort_by(&.version)
      .any? { |migration| !versions.includes?(migration.version) }
  end

  private def load_migrations : Array(Invidious::Database::Migration)
    self.class.migrations.map(&.new(@db))
  end

  private def load_versions : Array(Int64)
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
