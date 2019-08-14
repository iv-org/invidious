class PG::ResultSet < ::DB::ResultSet
  getter rows_affected

  def initialize(statement, @fields : Array(PQ::Field)?)
    super(statement)
    @column_index = -1 # The current column
    @end = false       # Did we read all the rows?
    @rows_affected = 0_i64
  end

  protected def conn
    statement.as(Statement).conn
  end

  def move_next : Bool
    return false if @end

    fields = @fields

    # `move_next` might be called before consuming all rows,
    # in that case we need to skip columns
    if fields && @column_index > -1 && @column_index < fields.size
      while @column_index < fields.size
        skip
      end
    end

    unless fields
      @end = true
      frame = conn.expect_frame PQ::Frame::CommandComplete | PQ::Frame::EmptyQueryResponse
      if frame.is_a?(PQ::Frame::CommandComplete)
        @rows_affected = frame.rows_affected
      end

      conn.expect_frame PQ::Frame::ReadyForQuery
      return false
    end

    if conn.read_next_row_start
      # We ignore these (redundant information)
      conn.read_i32 # size
      conn.read_i16 # ncols
      @column_index = 0
      true
    else
      conn.expect_frame PQ::Frame::ReadyForQuery
      @end = true
      false
    end
  rescue IO::Error
    raise DB::ConnectionLost.new(statement.connection)
  rescue ex
    @end = true
    raise ex
  end

  def column_count : Int32
    @fields.try(&.size) || 0
  end

  def column_name(index : Int32) : String
    field(index).name
  end

  def column_type(index : Int32)
    decoder(index).type
  end

  def read
    col_bytesize = conn.read_i32
    if col_bytesize == -1
      @column_index += 1
      return nil
    end

    safe_read(col_bytesize) do |io|
      decoder.decode(io, col_bytesize, oid)
    end
  rescue IO::Error
    raise DB::ConnectionLost.new(statement.connection)
  end

  def read(t : Array(T).class) : Array(T) forall T
    read_array(Array(T)) do
      raise PG::RuntimeError.new("unexpected NULL, expecting to read #{t}")
    end
  end

  def read(t : Array(T)?.class) : Array(T)? forall T
    read_array(Array(T)) do
      return nil
    end
  end

  private def read_array(t : T.class) : T forall T
    col_bytesize = conn.read_i32
    if col_bytesize == -1
      @column_index += 1
      yield
    end

    safe_read(col_bytesize) do |io|
      Decoders.decode_array(io, col_bytesize, T)
    end
  rescue IO::Error
    raise DB::ConnectionLost.new(statement.connection)
  end

  private def safe_read(col_bytesize)
    sized_io = IO::Sized.new(conn.soc, col_bytesize)

    begin
      yield sized_io
    ensure
      # An exception might happen while decoding the value:
      # 1. Make sure to skip the column bytes
      # 2. Make sure to increment the column index
      conn.soc.skip(sized_io.read_remaining) if sized_io.read_remaining > 0
      @column_index += 1
    end
  end

  private def field(index = @column_index)
    @fields.not_nil![index]
  end

  private def decoder(index = @column_index)
    Decoders.from_oid(oid(index))
  end

  private def oid(index = @column_index)
    field(index).type_oid
  end

  private def skip
    col_size = conn.read_i32
    conn.skip_bytes(col_size) if col_size != -1
    @column_index += 1
  rescue IO::Error
    raise DB::ConnectionLost.new(statement.connection)
  end

  protected def do_close
    super

    # Nothing to do if all the rows were consumed
    return if @end

    # Check if we didn't advance to the first row
    if @column_index == -1
      return unless move_next
    end

    fields = @fields

    loop do
      # Skip remaining columns
      while fields && @column_index < fields.size
        skip
      end

      break unless move_next
    end
  rescue DB::ConnectionLost
    # if the connection is lost there is nothing to be
    # done since the result set is no longer needed
  end
end
