require "spec"
require "../src/db"

class DummyDriver < DB::Driver
  def build_connection(context : DB::ConnectionContext) : DB::Connection
    DummyConnection.new(context)
  end

  class DummyConnection < DB::Connection
    def initialize(context)
      super(context)
      @connected = true
      @@connections ||= [] of DummyConnection
      @@connections.not_nil! << self
    end

    def self.connections
      @@connections.not_nil!
    end

    def self.clear_connections
      @@connections.try &.clear
    end

    def build_prepared_statement(query) : DB::Statement
      DummyStatement.new(self, query, true)
    end

    def build_unprepared_statement(query) : DB::Statement
      DummyStatement.new(self, query, false)
    end

    def last_insert_id : Int64
      0
    end

    def check
      raise DB::ConnectionLost.new(self) unless @connected
    end

    def disconnect!
      @connected = false
    end

    def create_transaction
      DummyTransaction.new(self)
    end

    protected def do_close
      super
    end
  end

  class DummyTransaction < DB::TopLevelTransaction
    getter committed = false
    getter rolledback = false

    def initialize(connection)
      super(connection)
    end

    def commit
      super
      @committed = true
    end

    def rollback
      super
      @rolledback = true
    end

    protected def create_save_point_transaction(parent, savepoint_name : String)
      DummySavePointTransaction.new(parent, savepoint_name)
    end
  end

  class DummySavePointTransaction < DB::SavePointTransaction
    getter committed = false
    getter rolledback = false

    def initialize(parent, savepoint_name)
      super(parent, savepoint_name)
    end

    def commit
      super
      @committed = true
    end

    def rollback
      super
      @rolledback = true
    end
  end

  class DummyStatement < DB::Statement
    property params

    def initialize(connection, @query : String, @prepared : Bool)
      @params = Hash(Int32 | String, DB::Any).new
      super(connection)
      raise DB::Error.new(query) if query == "syntax error"
    end

    protected def perform_query(args : Enumerable) : DB::ResultSet
      @connection.as(DummyConnection).check
      set_params args
      DummyResultSet.new self, @query
    end

    protected def perform_exec(args : Enumerable) : DB::ExecResult
      @connection.as(DummyConnection).check
      set_params args
      raise DB::Error.new("forced exception due to query") if @query == "raise"
      DB::ExecResult.new 0i64, 0_i64
    end

    private def set_params(args)
      @params.clear
      args.each_with_index do |arg, index|
        set_param(index, arg)
      end
    end

    private def set_param(index, value : DB::Any)
      @params[index] = value
    end

    private def set_param(index, value)
      raise "not implemented for #{value.class}"
    end

    def prepared?
      @prepared
    end

    protected def do_close
      super
    end
  end

  class DummyResultSet < DB::ResultSet
    @top_values : Array(Array(String))
    @values : Array(String)?

    @@last_result_set : self?

    def initialize(statement, query)
      super(statement)
      @top_values = query.split.map { |r| r.split(',') }.to_a
      @column_count = @top_values.size > 0 ? @top_values[0].size : 2

      @@last_result_set = self
    end

    protected def do_close
      super
    end

    def self.last_result_set
      @@last_result_set.not_nil!
    end

    def move_next : Bool
      @values = @top_values.shift?
      !!@values
    end

    def column_count : Int32
      @column_count
    end

    def column_name(index) : String
      "c#{index}"
    end

    def read
      n = @values.not_nil!.shift?
      raise "end of row" if n.is_a?(Nil)
      return nil if n == "NULL"

      if n == "?"
        return (@statement.as(DummyStatement)).params[0]
      end

      return n
    end

    def read(t : String.class)
      read.to_s
    end

    def read(t : String?.class)
      read.try &.to_s
    end

    def read(t : Int32.class)
      read(String).to_i32
    end

    def read(t : Int32?.class)
      read(String?).try &.to_i32
    end

    def read(t : Int64.class)
      read(String).to_i64
    end

    def read(t : Int64?.class)
      read(String?).try &.to_i64
    end

    def read(t : Float32.class)
      read(String).to_f32
    end

    def read(t : Float64.class)
      read(String).to_f64
    end

    def read(t : Bytes.class)
      case value = read
      when String
        ary = value.bytes
        Slice.new(ary.to_unsafe, ary.size)
      when Bytes
        value
      else
        raise "#{value} is not convertible to Bytes"
      end
    end
  end
end

DB.register_driver "dummy", DummyDriver

class Witness
  getter count

  def initialize(@count = 1)
  end

  def check
    @count -= 1
  end
end

def with_witness(count = 1)
  w = Witness.new(count)
  yield w
  w.count.should eq(0), "The expected coverage was unmet"
end

def with_dummy(uri : String = "dummy://host?checkout_timeout=0.5")
  DummyDriver::DummyConnection.clear_connections

  DB.open uri do |db|
    yield db
  end
end

def with_dummy_connection(options = "")
  with_dummy("dummy://host?checkout_timeout=0.5&#{options}") do |db|
    db.using_connection do |cnn|
      yield cnn.as(DummyDriver::DummyConnection)
    end
  end
end
