require "spec"
require "../src/sqlite3"

include SQLite3

DB_FILENAME = "./test.db"

def with_db(&block : DB::Database ->)
  File.delete(DB_FILENAME) rescue nil
  DB.open "sqlite3:#{DB_FILENAME}", &block
ensure
  File.delete(DB_FILENAME)
end

def with_cnn(&block : DB::Connection ->)
  File.delete(DB_FILENAME) rescue nil
  DB.connect "sqlite3:#{DB_FILENAME}", &block
ensure
  File.delete(DB_FILENAME)
end

def with_db(config, &block : DB::Database ->)
  uri = "sqlite3:#{config}"
  filename = SQLite3::Connection.filename(URI.parse(uri))
  File.delete(filename) rescue nil
  DB.open uri, &block
ensure
  File.delete(filename) if filename
end

def with_mem_db(&block : DB::Database ->)
  DB.open "sqlite3://%3Amemory%3A", &block
end
