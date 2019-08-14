require "./spec_helper"

private def connections
  DummyDriver::DummyConnection.connections
end

describe DB do
  it "should get driver class by name" do
    DB.driver_class("dummy").should eq(DummyDriver)
  end

  it "should instantiate driver with connection uri" do
    db = DB.open "dummy://localhost:1027"
    db.driver.should be_a(DummyDriver)
    db.uri.scheme.should eq("dummy")
    db.uri.host.should eq("localhost")
    db.uri.port.should eq(1027)
  end

  it "should create a connection and close it" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost" do |db|
    end
    connections.size.should eq(1)
    connections.first.closed?.should be_true
  end

  it "should create a connection and close it" do
    DummyDriver::DummyConnection.clear_connections
    DB.connect "dummy://localhost" do |cnn|
      cnn.should be_a(DummyDriver::DummyConnection)
    end
    connections.size.should eq(1)
    connections.first.closed?.should be_true
  end

  it "should create a connection and wait for explicit closing" do
    DummyDriver::DummyConnection.clear_connections
    cnn = DB.connect "dummy://localhost"
    cnn.should be_a(DummyDriver::DummyConnection)
    connections.size.should eq(1)
    connections.first.closed?.should be_false
    cnn.close
    connections.first.closed?.should be_true
  end

  it "query should close result_set" do
    with_witness do |w|
      with_dummy do |db|
        db.query "1,2" do
          break
        end

        w.check
        DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
      end
    end
  end

  it "scalar should close statement" do
    with_dummy do |db|
      db.scalar "1"
      DummyDriver::DummyResultSet.last_result_set.closed?.should be_true
    end
  end

  it "initially a single connection should be created" do
    with_dummy do |db|
      connections.size.should eq(1)
    end
  end

  it "the connection should be closed after db usage" do
    with_dummy do |db|
      connections.first.closed?.should be_false
    end
    connections.first.closed?.should be_true
  end

  it "should raise if the sole connection is been used" do
    with_dummy "dummy://host?max_pool_size=1&checkout_timeout=0.5" do |db|
      db.query "1" do |rs|
        expect_raises DB::PoolTimeout do
          db.scalar "2"
        end
      end
    end
  end

  it "should use 'unlimited' connections by default" do
    with_dummy "dummy://host?checkout_timeout=0.5" do |db|
      rs = [] of DB::ResultSet
      500.times do
        rs << db.query "1"
      end
      DummyDriver::DummyConnection.connections.size.should eq(500)
    end
  end

  it "exec should return to pool" do
    with_dummy do |db|
      db.exec "foo"
      db.exec "bar"
    end
  end

  it "scalar should return to pool" do
    with_dummy do |db|
      db.scalar "foo"
      db.scalar "bar"
    end
  end

  it "gives nice error message when no driver is registered for schema (#21)" do
    expect_raises(ArgumentError, %(no driver was registered for the schema "foobar", did you maybe forget to require the database driver?)) do
      DB.open "foobar://baz"
    end
  end

  it "should parse boolean query string params" do
    DB.fetch_bool(HTTP::Params.parse("foo=true"), "foo", false).should be_true
    DB.fetch_bool(HTTP::Params.parse("foo=True"), "foo", false).should be_true

    DB.fetch_bool(HTTP::Params.parse("foo=false"), "foo", true).should be_false
    DB.fetch_bool(HTTP::Params.parse("foo=False"), "foo", true).should be_false

    DB.fetch_bool(HTTP::Params.parse("bar=true"), "foo", false).should be_false
    DB.fetch_bool(HTTP::Params.parse("bar=true"), "foo", true).should be_true

    expect_raises(ArgumentError, %(invalid "other" value for option "foo")) do
      DB.fetch_bool(HTTP::Params.parse("foo=other"), "foo", true)
    end
  end
end
