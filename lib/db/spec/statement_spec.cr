require "./spec_helper"

describe DB::Statement do
  it "should build prepared statements" do
    with_dummy_connection do |cnn|
      prepared = cnn.prepared("the query")
      prepared.should be_a(DB::Statement)
      prepared.as(DummyDriver::DummyStatement).prepared?.should be_true
    end
  end

  it "should build unprepared statements" do
    with_dummy_connection("prepared_statements=false") do |cnn|
      prepared = cnn.unprepared("the query")
      prepared.should be_a(DB::Statement)
      prepared.as(DummyDriver::DummyStatement).prepared?.should be_false
    end
  end

  describe "prepared_statements flag" do
    it "should build prepared statements if true" do
      with_dummy_connection("prepared_statements=true") do |cnn|
        stmt = cnn.query("the query").statement
        stmt.as(DummyDriver::DummyStatement).prepared?.should be_true
      end
    end

    it "should build unprepared statements if false" do
      with_dummy_connection("prepared_statements=false") do |cnn|
        stmt = cnn.query("the query").statement
        stmt.as(DummyDriver::DummyStatement).prepared?.should be_false
      end
    end
  end

  it "should initialize positional params in query" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared("the query").as(DummyDriver::DummyStatement)
      stmt.query "a", 1, nil
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in query with array" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared("the query").as(DummyDriver::DummyStatement)
      stmt.query ["a", 1, nil]
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in exec" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared("the query").as(DummyDriver::DummyStatement)
      stmt.exec "a", 1, nil
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in exec with array" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared("the query").as(DummyDriver::DummyStatement)
      stmt.exec ["a", 1, nil]
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "should initialize positional params in scalar" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared("the query").as(DummyDriver::DummyStatement)
      stmt.scalar "a", 1, nil
      stmt.params[0].should eq("a")
      stmt.params[1].should eq(1)
      stmt.params[2].should eq(nil)
    end
  end

  it "query with block should not close statement" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.query
      stmt.closed?.should be_false
    end
  end

  it "closing connection should close statement" do
    stmt = uninitialized DB::Statement
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.query
    end
    stmt.closed?.should be_true
  end

  it "query with block should not close statement" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_false
    end
  end

  it "query should not close statement" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.query do |rs|
      end
      stmt.closed?.should be_false
    end
  end

  it "scalar should not close statement" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.scalar
      stmt.closed?.should be_false
    end
  end

  it "exec should not close statement" do
    with_dummy_connection do |cnn|
      stmt = cnn.prepared "3,4 1,2"
      stmt.exec
      stmt.closed?.should be_false
    end
  end

  it "connection should cache statements by query" do
    with_dummy_connection do |cnn|
      rs = cnn.prepared.query "1, ?", 2
      stmt = rs.statement
      rs.close

      rs = cnn.prepared.query "1, ?", 4
      rs.statement.should be(stmt)
    end
  end

  it "connection should be released if error occurs during exec" do
    with_dummy do |db|
      expect_raises DB::Error do
        db.exec "raise"
      end
      DummyDriver::DummyConnection.connections.size.should eq(1)
      db.pool.is_available?(DummyDriver::DummyConnection.connections.first)
    end
  end
end
