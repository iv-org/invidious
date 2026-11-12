class Invidious::Database::Migrator
  TABLE_NAME = "invidious_migrations"
  MIGRATIONS_TABLE    = "public.#{TABLE_NAME}"
  MIGRATE_INSTRUCTION = "Run `invidious --migrate` to apply the migration(s)."

  class_getter migrations = [] of Invidious::Database::Migration.class

  def initialize(@db : DB::Database)
  end

  def migrate
    create_migrations_table
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
    # for a check, we don't need to create the migrations table if it doesn't exist yet
    # only create the migrations table on a migrate command
    versions = migrations_table_exists? ? load_versions : [] of Int64

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
    @db.query_all("SELECT version FROM #{MIGRATIONS_TABLE}", as: Int64)
  end

  private def migrations_table_exists? : Bool
    sql = <<-SQL
      SELECT 1 
      FROM information_schema.tables 
      WHERE table_schema = 'public' 
        AND table_type = 'BASE TABLE'
        AND table_name = '#{TABLE_NAME}';
    SQL
    result = @db.query_one?(sql, as: Int64)
    !result.nil?
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
