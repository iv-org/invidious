module Invidious::Database::Connection
  extend self
  alias Driver = DBConfig::Driver

  def connect : DB::Database
    url = CONFIG.database_url

    if url.to_s.empty?
      raise "Config: Either database_url or db.* is required"
    end

    scheme = url.scheme.try(&.downcase)

    case scheme
    when Driver::Postgres.to_s.downcase
      Databases::Postgres.connect
    when Driver::Sqlite.to_s.downcase
      Databases::Sqlite.connect
    else
      raise "Config: Unsupported database URL scheme '#{scheme}' (expected 'postgres' or 'sqlite3')"
    end
  end

  module Databases
    module Postgres
      extend self

      def connect : DB::Database
        DB.open(CONFIG.database_url)
      rescue ex
        raise "Failed to connect to PostgreSQL database: #{ex.message}\n" \
              "Check your 'config.yml' database settings or PostgreSQL settings."
      end
    end

    module Sqlite
      extend self

      def connect : DB::Database
        DB.open(CONFIG.database_url)
      rescue ex
        raise "Failed to connect to SQLite database: #{ex.message}\n" \
              "Check your 'config.yml' database settings."
      end
    end
  end
end
