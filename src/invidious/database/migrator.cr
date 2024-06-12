class Invidious::Database::Migrator
  MIGRATIONS_TABLE    = "public.invidious_migrations"
  MIGRATE_INSTRUCTION = "Run `invidious --migrate` to apply the migration(s)."

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

  def check_pending_migrations
    versions = load_versions

    pending_migrations = load_migrations.sort_by(&.version)
      .select { |migration| !versions.includes?(migration.version) }

    return if pending_migrations.empty?

    if pending_migrations.any?(&.required?)
      LOGGER.error("There are pending migrations and the application is unable to continue. #{MIGRATE_INSTRUCTION}")
      exit 1
    else
      LOGGER.warn("There are pending migrations. #{MIGRATE_INSTRUCTION}")
    end
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
