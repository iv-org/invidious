require "../spec_helper"

def assert_single_read(rs, value_type, value)
  rs.move_next.should be_true
  rs.read(value_type).should eq(value)
  rs.move_next.should be_false
end

class NotSupportedType
end

struct StructWithMapping
  DB.mapping(a: Int32, b: Int32)
end

describe PG::Driver do
  it "should register postgres name" do
    DB.driver_class("postgres").should eq(PG::Driver)
  end

  it "exectes and selects value" do
    PG_DB.query "select 123::int4" do |rs|
      assert_single_read rs, Int32, 123
    end
  end

  it "gets column count" do
    PG_DB.query "select 1::int4, 1::int4" do |rs|
      rs.column_count.should eq(2)
    end
  end

  it "gets column names" do
    PG_DB.query "select 1::int4 as foo, 1::int4 as bar" do |rs|
      rs.column_name(0).should eq("foo")
      rs.column_name(1).should eq("bar")
    end
  end

  it "should raise an exception if unique constraint is violated" do
    expect_raises(PQ::PQError) do
      PG_DB.exec "drop table if exists contacts"
      PG_DB.exec "create table contacts (name varchar(256), CONSTRAINT key_name UNIQUE(name))"

      result = PG_DB.query "insert into contacts values ($1)", "Foo"
      result = PG_DB.query "insert into contacts values ($1)", "Foo" do |rs|
        rs.move_next
      end
    end
  end

  it "executes insert" do
    PG_DB.exec "drop table if exists contacts"
    PG_DB.exec "create table contacts (name varchar(256), age int4)"

    result = PG_DB.exec "insert into contacts values ($1, $2)", "Foo", 10

    result.last_insert_id.should eq(0) # postgres doesn't support this
    result.rows_affected.should eq(1)
  end

  it "executes insert via query" do
    PG_DB.query("drop table if exists contacts") do |rs|
      rs.move_next.should be_false
    end
  end

  it "executes update" do
    PG_DB.exec "drop table if exists contacts"
    PG_DB.exec "create table contacts (name varchar(256), age int4)"

    PG_DB.exec "insert into contacts values ($1, $2)", "Foo", 10
    PG_DB.exec "insert into contacts values ($1, $2)", "Baz", 10
    PG_DB.exec "insert into contacts values ($1, $2)", "Baz", 20

    result = PG_DB.exec "update contacts set age = 30 where age = 10"

    result.last_insert_id.should eq(0) # postgres doesn't support this
    result.rows_affected.should eq(2)
  end

  it "traverses result set" do
    PG_DB.exec "drop table if exists contacts"
    PG_DB.exec "create table contacts (name varchar(256), age int4)"

    PG_DB.exec "insert into contacts values ($1, $2)", "Foo", 10
    PG_DB.exec "insert into contacts values ($1, $2)", "Bar", 20

    PG_DB.query "select name, age from contacts order by age" do |rs|
      rs.move_next.should be_true
      rs.read(String).should eq("Foo")
      rs.move_next.should be_true
      rs.read(String).should eq("Bar")
      rs.move_next.should be_false
    end
  end

  describe "transactions" do
    it "can read inside transaction and rollback after" do
      with_db do |db|
        db.exec "drop table if exists person"
        db.exec "create table person (name varchar(25))"
        db.transaction do |tx|
          tx.connection.scalar("select count(*) from person").should eq(0)
          tx.connection.exec "insert into person (name) values ($1)", "John Doe"
          tx.connection.scalar("select count(*) from person").should eq(1)
          tx.rollback
        end
        db.scalar("select count(*) from person").should eq(0)
      end
    end

    it "can read inside transaction or after commit" do
      with_db do |db|
        db.exec "drop table if exists person"
        db.exec "create table person (name varchar(25))"
        db.transaction do |tx|
          tx.connection.scalar("select count(*) from person").should eq(0)
          tx.connection.exec "insert into person (name) values ($1)", "John Doe"
          tx.connection.scalar("select count(*) from person").should eq(1)
          # using other connection
          db.scalar("select count(*) from person").should eq(0)
        end
        db.scalar("select count(*) from person").should eq(1)
      end
    end
  end

  describe "nested transactions" do
    it "can read inside transaction and rollback after" do
      with_db do |db|
        db.exec "drop table if exists person"
        db.exec "create table person (name varchar(25))"
        db.transaction do |tx_0|
          tx_0.connection.scalar("select count(*) from person").should eq(0)
          tx_0.connection.exec "insert into person (name) values ($1)", "John Doe"
          tx_0.transaction do |tx_1|
            tx_1.connection.exec "insert into person (name) values ($1)", "Sarah"
            tx_1.connection.scalar("select count(*) from person").should eq(2)
            tx_1.transaction do |tx_2|
              tx_2.connection.exec "insert into person (name) values ($1)", "Jimmy"
              tx_2.connection.scalar("select count(*) from person").should eq(3)
              tx_2.rollback
            end
          end
          tx_0.connection.scalar("select count(*) from person").should eq(2)
          tx_0.rollback
        end
        db.scalar("select count(*) from person").should eq(0)
      end
    end
  end

  describe "move_next" do
    it "properly skips null columns" do
      no_nulls = StructWithMapping.from_rs(PG_DB.query("select 1 as a, 1 as b")).first
      {no_nulls.a, no_nulls.b}.should eq({1, 1})

      message = "PG::ResultSet#read returned a Nil. A Int32 was expected."
      expect_raises(Exception, message) do
        StructWithMapping.from_rs(PG_DB.query("select 2 as a, null as b"))
      end

      expect_raises(Exception, message) do # importantly not an IndexError: Index out of bounds
        StructWithMapping.from_rs(PG_DB.query("select null as a, null as b"))
      end
    end
  end
end
