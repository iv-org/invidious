class SQLite3::Connection < DB::Connection
  def initialize(database)
    super
    filename = self.class.filename(database.uri)
    # TODO maybe enable Flag::URI to parse query string in the uri as additional flags
    check LibSQLite3.open_v2(filename, out @db, (Flag::READWRITE | Flag::CREATE), nil)
  rescue
    raise DB::ConnectionRefused.new
  end

  def self.filename(uri : URI)
    {% if compare_versions(Crystal::VERSION, "0.30.0-0") >= 0 %}
      URI.decode_www_form((uri.host || "") + uri.path)
    {% else %}
      URI.unescape((uri.host || "") + uri.path)
    {% end %}
  end

  def build_prepared_statement(query) : Statement
    Statement.new(self, query)
  end

  def build_unprepared_statement(query) : Statement
    # sqlite3 does not support unprepared statement.
    # All statements once prepared should be released
    # when unneeded. Unprepared statement are not aim
    # to leave state in the connection. Mimicking them
    # with prepared statement would be wrong with
    # respect connection resources.
    raise DB::Error.new("SQLite3 driver does not support unprepared statements")
  end

  def do_close
    super
    check LibSQLite3.close(self)
  end

  # :nodoc:
  def perform_begin_transaction
    self.prepared.exec "BEGIN"
  end

  # :nodoc:
  def perform_commit_transaction
    self.prepared.exec "COMMIT"
  end

  # :nodoc:
  def perform_rollback_transaction
    self.prepared.exec "ROLLBACK"
  end

  # :nodoc:
  def perform_create_savepoint(name)
    self.prepared.exec "SAVEPOINT #{name}"
  end

  # :nodoc:
  def perform_release_savepoint(name)
    self.prepared.exec "RELEASE SAVEPOINT #{name}"
  end

  # :nodoc:
  def perform_rollback_savepoint(name)
    self.prepared.exec "ROLLBACK TO #{name}"
  end

  # Dump the database to another SQLite3 database. This can be used for backing up a SQLite3 Database
  # to disk or the opposite
  def dump(to : SQLite3::Connection)
    backup_item = LibSQLite3.backup_init(to.@db, "main", @db, "main")
    if backup_item.null?
      raise Exception.new(to.@db)
    end
    code = LibSQLite3.backup_step(backup_item, -1)

    if code != LibSQLite3::Code::DONE
      raise Exception.new(to.@db)
    end
    code = LibSQLite3.backup_finish(backup_item)
    if code != LibSQLite3::Code::OKAY
      raise Exception.new(to.@db)
    end
  end

  def to_unsafe
    @db
  end

  private def check(code)
    raise Exception.new(self) unless code == 0
  end
end
