require "./type"

@[Link("sqlite3")]
lib LibSQLite3
  type SQLite3 = Void*
  type Statement = Void*
  type SQLite3Backup = Void*

  enum Code
    # Successful result
    OKAY = 0
    # Generic error
    ERROR = 1
    # Internal logic error in SQLite
    INTERNAL = 2
    # Access permission denied
    PERM = 3
    # Callback routine requested an abort
    ABORT = 4
    # The database file is locked
    BUSY = 5
    # A table in the database is locked
    LOCKED = 6
    # A malloc() failed
    NOMEM = 7
    # Attempt to write a readonly database
    READONLY = 8
    # Operation terminated by sqlite3_interrupt()
    INTERRUPT = 9
    # Some kind of disk I/O error occurred
    IOERR = 10
    # The database disk image is malformed
    CORRUPT = 11
    # Unknown opcode in sqlite3_file_control()
    NOTFOUND = 12
    # Insertion failed because database is full
    FULL = 13
    # Unable to open the database file
    CANTOPEN = 14
    # Database lock protocol error
    PROTOCOL = 15
    # Internal use only
    EMPTY = 16
    # The database schema changed
    SCHEMA = 17
    # String or BLOB exceeds size limit
    TOOBIG = 18
    # Abort due to constraint violation
    CONSTRAINT = 19
    # Data type mismatch
    MISMATCH = 20
    # Library used incorrectly
    MISUSE = 21
    # Uses OS features not supported on host
    NOLFS = 22
    # Authorization denied
    AUTH = 23
    # Not used
    FORMAT = 24
    # 2nd parameter to sqlite3_bind out of range
    RANGE = 25
    # File opened that is not a database file
    NOTADB = 26
    # Notifications from sqlite3_log()
    NOTICE = 27
    # Warnings from sqlite3_log()
    WARNING = 28
    # sqlite3_step() has another row ready
    ROW = 100
    # sqlite3_step() has finished executing
    DONE = 101
  end

  alias Callback = (Void*, Int32, UInt8**, UInt8**) -> Int32

  fun open_v2 = sqlite3_open_v2(filename : UInt8*, db : SQLite3*, flags : ::SQLite3::Flag, zVfs : UInt8*) : Int32

  fun errcode = sqlite3_errcode(SQLite3) : Int32
  fun errmsg = sqlite3_errmsg(SQLite3) : UInt8*

  fun backup_init = sqlite3_backup_init(SQLite3, UInt8*, SQLite3, UInt8*) : SQLite3Backup
  fun backup_step = sqlite3_backup_step(SQLite3Backup, Int32) : Code
  fun backup_finish = sqlite3_backup_finish(SQLite3Backup) : Code

  fun prepare_v2 = sqlite3_prepare_v2(db : SQLite3, zSql : UInt8*, nByte : Int32, ppStmt : Statement*, pzTail : UInt8**) : Int32
  fun step = sqlite3_step(stmt : Statement) : Int32
  fun column_count = sqlite3_column_count(stmt : Statement) : Int32
  fun column_type = sqlite3_column_type(stmt : Statement, iCol : Int32) : ::SQLite3::Type
  fun column_int64 = sqlite3_column_int64(stmt : Statement, iCol : Int32) : Int64
  fun column_double = sqlite3_column_double(stmt : Statement, iCol : Int32) : Float64
  fun column_text = sqlite3_column_text(stmt : Statement, iCol : Int32) : UInt8*
  fun column_bytes = sqlite3_column_bytes(stmt : Statement, iCol : Int32) : Int32
  fun column_blob = sqlite3_column_blob(stmt : Statement, iCol : Int32) : UInt8*

  fun bind_int = sqlite3_bind_int(stmt : Statement, idx : Int32, value : Int32) : Int32
  fun bind_int64 = sqlite3_bind_int64(stmt : Statement, idx : Int32, value : Int64) : Int32
  fun bind_text = sqlite3_bind_text(stmt : Statement, idx : Int32, value : UInt8*, bytes : Int32, destructor : Void* ->) : Int32
  fun bind_blob = sqlite3_bind_blob(stmt : Statement, idx : Int32, value : UInt8*, bytes : Int32, destructor : Void* ->) : Int32
  fun bind_null = sqlite3_bind_null(stmt : Statement, idx : Int32) : Int32
  fun bind_double = sqlite3_bind_double(stmt : Statement, idx : Int32, value : Float64) : Int32

  fun bind_parameter_index = sqlite3_bind_parameter_index(stmt : Statement, name : UInt8*) : Int32
  fun reset = sqlite3_reset(stmt : Statement) : Int32
  fun column_name = sqlite3_column_name(stmt : Statement, idx : Int32) : UInt8*
  fun last_insert_rowid = sqlite3_last_insert_rowid(db : SQLite3) : Int64
  fun changes = sqlite3_changes(db : SQLite3) : Int32

  fun finalize = sqlite3_finalize(stmt : Statement) : Int32
  fun close_v2 = sqlite3_close_v2(SQLite3) : Int32
  fun close = sqlite3_close(SQLite3) : Int32
end
