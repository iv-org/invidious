require "uri"

# The DB module is a unified interface for database access.
# Individual database systems are supported by specific database driver shards.
#
# Available drivers include:
# * [crystal-lang/crystal-sqlite3](https://github.com/crystal-lang/crystal-sqlite3) for SQLite
# * [crystal-lang/crystal-mysql](https://github.com/crystal-lang/crystal-mysql) for MySQL and MariaDB
# * [will/crystal-pg](https://github.com/will/crystal-pg) for PostgreSQL
# * [kaukas/crystal-cassandra](https://github.com/kaukas/crystal-cassandra) for Cassandra
#
# For basic instructions on implementing a new database driver, check `Driver` and the existing drivers.
#
# DB manages a connection pool. The connection pool can be configured by query parameters to the
# connection `URI` as described in `Database`.
#
# ### Usage
#
# Assuming `crystal-sqlite3` is included a SQLite3 database can be opened with `#open`.
#
# ```
# db = DB.open "sqlite3:./path/to/db/file.db"
# db.close
# ```
#
# If a block is given to `#open` the database is closed automatically
#
# ```
# DB.open "sqlite3:./file.db" do |db|
#   # work with db
# end # db is closed
# ```
#
# In the code above `db` is a `Database`. Methods available for querying it are described in `QueryMethods`.
#
# Three kind of statements can be performed:
# 1. `Database#exec` waits no response from the database.
# 2. `Database#scalar` reads a single value of the response.
# 3. `Database#query` returns a ResultSet that allows iteration over the rows in the response and column information.
#
# All of the above methods allows parametrised query. Either positional or named arguments.
#
# Check a full working version:
#
# The following example uses SQLite where `?` indicates the arguments. If PostgreSQL is used `$1`, `$2`, etc. should be used. `crystal-db` does not interpret the statements.
#
# ```
# require "db"
# require "sqlite3"
#
# DB.open "sqlite3:./file.db" do |db|
#   # When using the pg driver, use $1, $2, etc. instead of ?
#   db.exec "create table contacts (name text, age integer)"
#   db.exec "insert into contacts values (?, ?)", "John Doe", 30
#
#   args = [] of DB::Any
#   args << "Sarah"
#   args << 33
#   db.exec "insert into contacts values (?, ?)", args
#
#   puts "max age:"
#   puts db.scalar "select max(age) from contacts" # => 33
#
#   puts "contacts:"
#   db.query "select name, age from contacts order by age desc" do |rs|
#     puts "#{rs.column_name(0)} (#{rs.column_name(1)})"
#     # => name (age)
#     rs.each do
#       puts "#{rs.read(String)} (#{rs.read(Int32)})"
#       # => Sarah (33)
#       # => John Doe (30)
#     end
#   end
# end
# ```
#
module DB
  # Types supported to interface with database driver.
  # These can be used in any `ResultSet#read` or any `Database#query` related
  # method to be used as query parameters
  TYPES = [Nil, String, Bool, Int32, Int64, Float32, Float64, Time, Bytes]

  # See `DB::TYPES` in `DB`. `Any` is a union of all types in `DB::TYPES`
  {% begin %}
    alias Any = Union({{*TYPES}})
  {% end %}

  # Result of a `#exec` statement.
  record ExecResult, rows_affected : Int64, last_insert_id : Int64

  # :nodoc:
  def self.driver_class(driver_name) : Driver.class
    drivers[driver_name]? ||
      raise(ArgumentError.new(%(no driver was registered for the schema "#{driver_name}", did you maybe forget to require the database driver?)))
  end

  # Registers a driver class for a given *driver_name*.
  # Should be called by drivers implementors only.
  def self.register_driver(driver_name, driver_class : Driver.class)
    drivers[driver_name] = driver_class
  end

  private def self.drivers
    @@drivers ||= {} of String => Driver.class
  end

  # Creates a `Database` pool and opens initial connection(s) as specified in the connection *uri*.
  # Use `DB#connect` to open a single connection.
  #
  # The scheme of the *uri* determines the driver to use.
  # Connection parameters such as hostname, user, database name, etc. are specified according
  # to each database driver's specific format.
  #
  # The returned database must be closed by `Database#close`.
  def self.open(uri : URI | String)
    build_database(uri)
  end

  # Same as `#open` but the database is yielded and closed automatically at the end of the block.
  def self.open(uri : URI | String, &block)
    db = build_database(uri)
    begin
      yield db
    ensure
      db.close
    end
  end

  # Opens a connection using the specified *uri*.
  # The scheme of the *uri* determines the driver to use.
  # Returned connection must be closed by `Connection#close`.
  # If a block is used the connection is yielded and closed automatically.
  def self.connect(uri : URI | String)
    build_connection(uri)
  end

  # ditto
  def self.connect(uri : URI | String, &block)
    cnn = build_connection(uri)
    begin
      yield cnn
    ensure
      cnn.close
    end
  end

  private def self.build_database(connection_string : String)
    build_database(URI.parse(connection_string))
  end

  private def self.build_database(uri : URI)
    Database.new(build_driver(uri), uri)
  end

  private def self.build_connection(connection_string : String)
    build_connection(URI.parse(connection_string))
  end

  private def self.build_connection(uri : URI)
    build_driver(uri).build_connection(SingleConnectionContext.new(uri)).as(Connection)
  end

  private def self.build_driver(uri : URI)
    driver_class(uri.scheme).new
  end

  # :nodoc:
  def self.fetch_bool(params : HTTP::Params, name, default : Bool)
    case (value = params[name]?).try &.downcase
    when nil
      default
    when "true"
      true
    when "false"
      false
    else
      raise ArgumentError.new(%(invalid "#{value}" value for option "#{name}"))
    end
  end
end

require "./db/pool"
require "./db/string_key_cache"
require "./db/query_methods"
require "./db/session_methods"
require "./db/disposable"
require "./db/driver"
require "./db/statement"
require "./db/begin_transaction"
require "./db/connection_context"
require "./db/connection"
require "./db/transaction"
require "./db/statement"
require "./db/pool_statement"
require "./db/database"
require "./db/pool_prepared_statement"
require "./db/pool_unprepared_statement"
require "./db/result_set"
require "./db/error"
require "./db/mapping"
