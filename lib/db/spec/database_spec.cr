require "./spec_helper"

describe DB::Database do
  it "allows connection initialization" do
    cnn_setup = 0
    DB.open "dummy://localhost:1027?initial_pool_size=2&max_pool_size=4&max_idle_pool_size=1" do |db|
      cnn_setup.should eq(0)

      db.setup_connection do |cnn|
        cnn_setup += 1
      end

      cnn_setup.should eq(2)

      db.using_connection do
        cnn_setup.should eq(2)
        db.using_connection do
          cnn_setup.should eq(2)
          db.using_connection do
            cnn_setup.should eq(3)
            db.using_connection do
              cnn_setup.should eq(4)
            end
            # the pool didn't shrink no new initialization should be done next
            db.using_connection do
              cnn_setup.should eq(4)
            end
          end
          # the pool shrink 1. max_idle_pool_size=1
          # after the previous end there where 2.
          db.using_connection do
            cnn_setup.should eq(4)
            # so now there will be a new connection created
            db.using_connection do
              cnn_setup.should eq(5)
            end
          end
        end
      end
    end
  end

  it "should allow creation of more statements than pool connections" do
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=2" do |db|
      db.build("query1").should be_a(DB::PoolPreparedStatement)
      db.build("query2").should be_a(DB::PoolPreparedStatement)
      db.build("query3").should be_a(DB::PoolPreparedStatement)
    end
  end

  it "should return same statement in pool per query" do
    with_dummy do |db|
      stmt = db.build("query1")
      db.build("query2").should_not eq(stmt)
      db.build("query1").should eq(stmt)
    end
  end

  it "should close pool statements when closing db" do
    stmt = uninitialized DB::PoolStatement
    with_dummy do |db|
      stmt = db.build("query1")
    end
    stmt.closed?.should be_true
  end

  it "should not reconnect if connection is lost and retry_attempts=0" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=1&retry_attempts=0" do |db|
      db.exec("stmt1")
      DummyDriver::DummyConnection.connections.size.should eq(1)
      DummyDriver::DummyConnection.connections.first.disconnect!
      expect_raises DB::PoolRetryAttemptsExceeded do
        db.exec("stmt1")
      end
      DummyDriver::DummyConnection.connections.size.should eq(1)
    end
  end

  it "should reconnect if connection is lost and executing same statement" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=1&retry_attempts=1" do |db|
      db.exec("stmt1")
      DummyDriver::DummyConnection.connections.size.should eq(1)
      DummyDriver::DummyConnection.connections.first.disconnect!
      db.exec("stmt1")
      DummyDriver::DummyConnection.connections.size.should eq(2)
    end
  end

  it "should allow new connections if pool can increased and retry is not allowed" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=2&retry_attempts=0" do |db|
      db.query("stmt1")
      DummyDriver::DummyConnection.connections.size.should eq(1)
      db.query("stmt1")
      DummyDriver::DummyConnection.connections.size.should eq(2)
    end
  end

  it "should not return connection to pool if checkout explicitly" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=1&retry_attempts=0" do |db|
      the_cnn = uninitialized DB::Connection
      db.using_connection do |cnn|
        the_cnn = cnn
        db.pool.is_available?(cnn).should be_false
        3.times do
          cnn.exec("stmt1")
          db.pool.is_available?(cnn).should be_false
        end
      end
      db.pool.is_available?(the_cnn).should be_true
    end
  end

  it "should checkout different connections until they are released" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=2&retry_attempts=0" do |db|
      the_first_cnn = uninitialized DB::Connection
      the_second_cnn = uninitialized DB::Connection

      the_first_cnn = db.checkout
      the_second_cnn = db.checkout
      the_second_cnn.should_not eq(the_first_cnn)
      db.pool.is_available?(the_first_cnn).should be_false
      db.pool.is_available?(the_second_cnn).should be_false

      the_first_cnn.release
      db.pool.is_available?(the_first_cnn).should be_true
      db.pool.is_available?(the_second_cnn).should be_false

      db.checkout.should eq(the_first_cnn)
      the_first_cnn.release
      the_second_cnn.release
    end
  end

  it "should not return explicit checked out connections to the pool after query" do
    DummyDriver::DummyConnection.clear_connections
    DB.open "dummy://localhost:1027?initial_pool_size=1&max_pool_size=2&retry_attempts=0" do |db|
      cnn = db.checkout

      cnn.query_all("1", as: String)

      db.pool.is_available?(cnn).should be_false
      cnn.release
      db.pool.is_available?(cnn).should be_true
    end
  end

  it "should return connection to the pool if prepared statement is unable to be built" do
    connection = uninitialized DB::Connection
    with_dummy "dummy://localhost:1027?initial_pool_size=1" do |db|
      connection = DummyDriver::DummyConnection.connections.first
      expect_raises DB::Error do
        db.prepared.exec("syntax error")
      end
      db.pool.is_available?(connection).should be_true
    end
  end

  it "should return connection to the pool if unprepared statement is unable to be built" do
    connection = uninitialized DB::Connection
    with_dummy "dummy://localhost:1027?initial_pool_size=1" do |db|
      connection = DummyDriver::DummyConnection.connections.first
      expect_raises DB::Error do
        db.unprepared.exec("syntax error")
      end
      db.pool.is_available?(connection).should be_true
    end
  end

  describe "prepared_statements connection option" do
    it "defaults to true" do
      with_dummy "dummy://localhost:1027" do |db|
        db.prepared_statements?.should be_true
      end
    end

    it "can be set to false" do
      with_dummy "dummy://localhost:1027?prepared_statements=false" do |db|
        db.prepared_statements?.should be_false
      end
    end

    it "is copied to connections (false)" do
      with_dummy "dummy://localhost:1027?prepared_statements=false&initial_pool_size=1" do |db|
        connection = DummyDriver::DummyConnection.connections.first
        connection.prepared_statements?.should be_false
      end
    end

    it "is copied to connections (true)" do
      with_dummy "dummy://localhost:1027?prepared_statements=true&initial_pool_size=1" do |db|
        connection = DummyDriver::DummyConnection.connections.first
        connection.prepared_statements?.should be_true
      end
    end

    it "should build prepared statements if true" do
      with_dummy "dummy://localhost:1027?prepared_statements=true" do |db|
        db.build("the query").should be_a(DB::PoolPreparedStatement)
      end
    end

    it "should build unprepared statements if false" do
      with_dummy "dummy://localhost:1027?prepared_statements=false" do |db|
        db.build("the query").should be_a(DB::PoolUnpreparedStatement)
      end
    end

    it "should be overrided by dsl" do
      with_dummy "dummy://localhost:1027?prepared_statements=true" do |db|
        stmt = db.unprepared.query("the query").statement.as(DummyDriver::DummyStatement)
        stmt.prepared?.should be_false
      end

      with_dummy "dummy://localhost:1027?prepared_statements=false" do |db|
        stmt = db.prepared.query("the query").statement.as(DummyDriver::DummyStatement)
        stmt.prepared?.should be_true
      end
    end
  end

  describe "unprepared statements in pool" do
    it "creating statements should not create new connections" do
      with_dummy "dummy://localhost:1027?initial_pool_size=1" do |db|
        stmt1 = db.unprepared.build("query1")
        stmt2 = db.unprepared.build("query2")
        DummyDriver::DummyConnection.connections.size.should eq(1)
      end
    end

    it "simultaneous statements should go to different connections" do
      with_dummy "dummy://localhost:1027?initial_pool_size=1" do |db|
        rs1 = db.unprepared.query("query1")
        rs2 = db.unprepared.query("query2")
        rs1.statement.connection.should_not eq(rs2.statement.connection)
        DummyDriver::DummyConnection.connections.size.should eq(2)
      end
    end

    it "sequential statements should go to different connections" do
      with_dummy "dummy://localhost:1027?initial_pool_size=1" do |db|
        rs1 = db.unprepared.query("query1")
        rs1.close
        rs2 = db.unprepared.query("query2")
        rs2.close
        rs1.statement.connection.should eq(rs2.statement.connection)
        DummyDriver::DummyConnection.connections.size.should eq(1)
      end
    end
  end
end
