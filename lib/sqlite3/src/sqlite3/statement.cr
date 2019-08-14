class SQLite3::Statement < DB::Statement
  def initialize(connection, sql)
    super(connection)
    check LibSQLite3.prepare_v2(sqlite3_connection, sql, sql.bytesize + 1, out @stmt, nil)
  end

  protected def perform_query(args : Enumerable) : DB::ResultSet
    LibSQLite3.reset(self)
    args.each_with_index(1) do |arg, index|
      bind_arg(index, arg)
    end
    ResultSet.new(self)
  end

  protected def perform_exec(args : Enumerable) : DB::ExecResult
    LibSQLite3.reset(self.to_unsafe)
    args.each_with_index(1) do |arg, index|
      bind_arg(index, arg)
    end

    # exec
    step = uninitialized LibSQLite3::Code
    loop do
      step = LibSQLite3::Code.new LibSQLite3.step(self)
      break unless step == LibSQLite3::Code::ROW
    end
    raise Exception.new(sqlite3_connection) unless step == LibSQLite3::Code::DONE

    rows_affected = LibSQLite3.changes(sqlite3_connection).to_i64
    last_id = LibSQLite3.last_insert_rowid(sqlite3_connection)

    DB::ExecResult.new rows_affected, last_id
  end

  protected def do_close
    super
    check LibSQLite3.finalize(self)
  end

  private def bind_arg(index, value : Nil)
    check LibSQLite3.bind_null(self, index)
  end

  private def bind_arg(index, value : Bool)
    check LibSQLite3.bind_int(self, index, value ? 1 : 0)
  end

  private def bind_arg(index, value : Int32)
    check LibSQLite3.bind_int(self, index, value)
  end

  private def bind_arg(index, value : Int64)
    check LibSQLite3.bind_int64(self, index, value)
  end

  private def bind_arg(index, value : Float32)
    check LibSQLite3.bind_double(self, index, value.to_f64)
  end

  private def bind_arg(index, value : Float64)
    check LibSQLite3.bind_double(self, index, value)
  end

  private def bind_arg(index, value : String)
    check LibSQLite3.bind_text(self, index, value, value.bytesize, nil)
  end

  private def bind_arg(index, value : Bytes)
    check LibSQLite3.bind_blob(self, index, value, value.size, nil)
  end

  private def bind_arg(index, value : Time)
    bind_arg(index, value.in(SQLite3::TIME_ZONE).to_s(SQLite3::DATE_FORMAT))
  end

  private def bind_arg(index, value)
    raise "#{self.class} does not support #{value.class} params"
  end

  private def check(code)
    raise Exception.new(sqlite3_connection) unless code == 0
  end

  protected def sqlite3_connection
    @connection.as(Connection)
  end

  def to_unsafe
    @stmt
  end
end
