require "./spec_helper"

module GenericResultSet
  @index = 0

  def move_next : Bool
    @index = 0
    true
  end

  def column_count : Int32
    @row.size
  end

  def column_name(index : Int32) : String
    index.to_s
  end

  def read
    @index += 1
    @row[@index - 1]
  end
end

class FooValue
  def initialize(@value : Int32)
  end

  def value
    @value
  end
end

class FooDriver < DB::Driver
  alias Any = DB::Any | FooValue
  @@row = [] of Any

  def self.fake_row=(row : Array(Any))
    @@row = row
  end

  def self.fake_row
    @@row
  end

  def build_connection(context : DB::ConnectionContext) : DB::Connection
    FooConnection.new(context)
  end

  class FooConnection < DB::Connection
    def build_prepared_statement(query) : DB::Statement
      FooStatement.new(self)
    end

    def build_unprepared_statement(query) : DB::Statement
      raise "not implemented"
    end
  end

  class FooStatement < DB::Statement
    protected def perform_query(args : Enumerable) : DB::ResultSet
      args.each { |arg| process_arg arg }
      FooResultSet.new(self, FooDriver.fake_row)
    end

    protected def perform_exec(args : Enumerable) : DB::ExecResult
      args.each { |arg| process_arg arg }
      DB::ExecResult.new 0i64, 0i64
    end

    private def process_arg(value : FooDriver::Any)
    end

    private def process_arg(value)
      raise "#{self.class} does not support #{value.class} params"
    end
  end

  class FooResultSet < DB::ResultSet
    include GenericResultSet

    def initialize(statement, @row : Array(FooDriver::Any))
      super(statement)
    end
  end
end

DB.register_driver "foo", FooDriver

class BarValue
  getter value

  def initialize(@value : Int32)
  end
end

class BarDriver < DB::Driver
  alias Any = DB::Any | BarValue
  @@row = [] of Any

  def self.fake_row=(row : Array(Any))
    @@row = row
  end

  def self.fake_row
    @@row
  end

  def build_connection(context : DB::ConnectionContext) : DB::Connection
    BarConnection.new(context)
  end

  class BarConnection < DB::Connection
    def build_prepared_statement(query) : DB::Statement
      BarStatement.new(self)
    end

    def build_unprepared_statement(query) : DB::Statement
      raise "not implemented"
    end
  end

  class BarStatement < DB::Statement
    protected def perform_query(args : Enumerable) : DB::ResultSet
      args.each { |arg| process_arg arg }
      BarResultSet.new(self, BarDriver.fake_row)
    end

    protected def perform_exec(args : Enumerable) : DB::ExecResult
      args.each { |arg| process_arg arg }
      DB::ExecResult.new 0i64, 0i64
    end

    private def process_arg(value : BarDriver::Any)
    end

    private def process_arg(value)
      raise "#{self.class} does not support #{value.class} params"
    end
  end

  class BarResultSet < DB::ResultSet
    include GenericResultSet

    def initialize(statement, @row : Array(BarDriver::Any))
      super(statement)
    end
  end
end

DB.register_driver "bar", BarDriver

describe DB do
  it "should be able to register multiple drivers" do
    DB.open("foo://host").driver.should be_a(FooDriver)
    DB.open("bar://host").driver.should be_a(BarDriver)
  end

  it "Foo and Bar drivers should return fake_row" do
    with_witness do |w|
      DB.open("foo://host") do |db|
        FooDriver.fake_row = [1, "string", FooValue.new(3)] of FooDriver::Any
        db.query "query" do |rs|
          w.check
          rs.move_next
          rs.read(Int32).should eq(1)
          rs.read(String).should eq("string")
          rs.read(FooValue).value.should eq(3)
        end
      end
    end

    with_witness do |w|
      DB.open("bar://host") do |db|
        BarDriver.fake_row = [BarValue.new(4), "lorem", 1.0] of BarDriver::Any
        db.query "query" do |rs|
          w.check
          rs.move_next
          rs.read(BarValue).value.should eq(4)
          rs.read(String).should eq("lorem")
          rs.read(Float64).should eq(1.0)
        end
      end
    end
  end

  it "drivers should return custom values as scalar" do
    DB.open("foo://host") do |db|
      FooDriver.fake_row = [FooValue.new(3)] of FooDriver::Any
      db.scalar("query").as(FooValue).value.should eq(3)
    end
  end

  it "Foo and Bar drivers should not implement each other read" do
    with_witness do |w|
      DB.open("foo://host") do |db|
        FooDriver.fake_row = [1] of FooDriver::Any
        db.query "query" do |rs|
          rs.move_next
          expect_raises(Exception, "FooResultSet#read returned a Int32. A BarValue was expected.") do
            w.check
            rs.read(BarValue)
          end
        end
      end
    end

    with_witness do |w|
      DB.open("bar://host") do |db|
        BarDriver.fake_row = [1] of BarDriver::Any
        db.query "query" do |rs|
          rs.move_next
          expect_raises(Exception, "BarResultSet#read returned a Int32. A FooValue was expected.") do
            w.check
            rs.read(FooValue)
          end
        end
      end
    end
  end

  it "allow custom types to be used as arguments for query" do
    DB.open("foo://host") do |db|
      FooDriver.fake_row = [1, "string"] of FooDriver::Any
      db.query "query" { }
      db.query "query", 1 { }
      db.query "query", 1, "string" { }
      db.query("query", Bytes.new(4)) { }
      db.query("query", 1, "string", FooValue.new(5)) { }
      db.query "query", [1, "string", FooValue.new(5)] { }

      db.query("query").close
      db.query("query", 1).close
      db.query("query", 1, "string").close
      db.query("query", Bytes.new(4)).close
      db.query("query", 1, "string", FooValue.new(5)).close
      db.query("query", [1, "string", FooValue.new(5)]).close
    end

    DB.open("bar://host") do |db|
      BarDriver.fake_row = [1, "string"] of BarDriver::Any
      db.query "query" { }
      db.query "query", 1 { }
      db.query "query", 1, "string" { }
      db.query("query", Bytes.new(4)) { }
      db.query("query", 1, "string", BarValue.new(5)) { }
      db.query "query", [1, "string", BarValue.new(5)] { }

      db.query("query").close
      db.query("query", 1).close
      db.query("query", 1, "string").close
      db.query("query", Bytes.new(4)).close
      db.query("query", 1, "string", BarValue.new(5)).close
      db.query("query", [1, "string", BarValue.new(5)]).close
    end
  end

  it "allow custom types to be used as arguments for exec" do
    DB.open("foo://host") do |db|
      FooDriver.fake_row = [1, "string"] of FooDriver::Any
      db.exec("query")
      db.exec("query", 1)
      db.exec("query", 1, "string")
      db.exec("query", Bytes.new(4))
      db.exec("query", 1, "string", FooValue.new(5))
      db.exec("query", [1, "string", FooValue.new(5)])
    end

    DB.open("bar://host") do |db|
      BarDriver.fake_row = [1, "string"] of BarDriver::Any
      db.exec("query")
      db.exec("query", 1)
      db.exec("query", 1, "string")
      db.exec("query", Bytes.new(4))
      db.exec("query", 1, "string", BarValue.new(5))
      db.exec("query", [1, "string", BarValue.new(5)])
    end
  end

  it "Foo and Bar drivers should not implement each other params" do
    DB.open("foo://host") do |db|
      expect_raises Exception, "FooDriver::FooStatement does not support BarValue params" do
        db.exec("query", [BarValue.new(5)])
      end
    end

    DB.open("bar://host") do |db|
      expect_raises Exception, "BarDriver::BarStatement does not support FooValue params" do
        db.exec("query", [FooValue.new(5)])
      end
    end
  end
end
