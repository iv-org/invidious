class Invidious::Database::Migrator
  MIGRATIONS_TABLE = "public.invidious_migrations"

  class_getter migrations = [] of Invidious::Database::Migration.class

  def initialize(@db : DB::Database)
  end

  def migrate
    versions = load_versions

    ran_migration = false
    backed_up = false
    load_migrations.sort_by(&.version)
      .each do |migration|
        next if versions.includes?(migration.version)

        if !backed_up
          puts "New migration(s) found: creating database backup"
          back_up_database
          backed_up = true
        end

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

  private def back_up_database
    table_names_request = <<-SQL
      SELECT tablename FROM pg_catalog.pg_tables
      WHERE schemaname = 'public'
    SQL

    table_names = @db.query_all(table_names_request, as: String)

    table_names.try &.each do |name|
      copy_table(name)
    end
  end

  private def copy_table(table_name : String)
    puts "Creating a table backup.#{table_name}. Most recent version"
    @db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS backup.#{table_name} (
        id bigserial PRIMARY KEY
      )
    SQL

    puts "Creating a table backup.#{table_name}. Second most recent version"
    @db.exec <<-SQL
      CREATE TABLE IF NOT EXISTS backup.#{table_name}_second_most_recent (
        id bigserial PRIMARY KEY
      )
    SQL

    puts "Populating table backup.#{table_name}. Second most recent version"
    @db.exec <<-SQL
      SELECT * INTO backup.#{table_name}_second_most_recent
      FROM backup.#{table_name}
    SQL

    puts "Populating table backup.#{table_name}. Most recent version"
    @db.exec <<-SQL
      SELECT * INTO backup.#{table_name}
      FROM public.#{table_name}
    SQL

    puts "Deleting table backup.#{table_name}. Second most recent version"
    @db.exec("DROP TABLE backup.#{table_name}_second_most_recent")
  end
end
