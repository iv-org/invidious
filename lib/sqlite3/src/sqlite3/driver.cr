class SQLite3::Driver < DB::Driver
  def build_connection(context : DB::ConnectionContext) : SQLite3::Connection
    SQLite3::Connection.new(context)
  end
end

DB.register_driver "sqlite3", SQLite3::Driver
