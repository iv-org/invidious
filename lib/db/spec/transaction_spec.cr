require "./spec_helper"

private class FooException < Exception
end

describe DB::Transaction do
  it "begin/commit transaction from connection" do
    with_dummy_connection do |cnn|
      tx = cnn.begin_transaction
      tx.commit
    end
  end

  it "begin/rollback transaction from connection" do
    with_dummy_connection do |cnn|
      tx = cnn.begin_transaction
      tx.rollback
    end
  end

  it "raise if begin over existing transaction" do
    with_dummy_connection do |cnn|
      cnn.begin_transaction
      expect_raises(DB::Error, "There is an existing transaction in this connection") do
        cnn.begin_transaction
      end
    end
  end

  it "allow sequential transactions" do
    with_dummy_connection do |cnn|
      tx = cnn.begin_transaction
      tx.rollback

      tx = cnn.begin_transaction
      tx.commit
    end
  end

  it "transaction with block from connection should be committed" do
    t = uninitialized DummyDriver::DummyTransaction

    with_witness do |w|
      with_dummy_connection do |cnn|
        cnn.transaction do |tx|
          if tx.is_a?(DummyDriver::DummyTransaction)
            t = tx
            w.check
          end
        end
      end
    end

    t.committed.should be_true
    t.rolledback.should be_false
  end

  it "transaction with block from connection should be rolledback if raise DB::Rollback" do
    t = uninitialized DummyDriver::DummyTransaction

    with_witness do |w|
      with_dummy_connection do |cnn|
        cnn.transaction do |tx|
          if tx.is_a?(DummyDriver::DummyTransaction)
            t = tx
            w.check
          end
          raise DB::Rollback.new
        end
      end
    end

    t.rolledback.should be_true
    t.committed.should be_false
  end

  it "transaction with block from connection should be rolledback if raise" do
    t = uninitialized DummyDriver::DummyTransaction

    with_witness do |w|
      with_dummy_connection do |cnn|
        expect_raises(FooException) do
          cnn.transaction do |tx|
            if tx.is_a?(DummyDriver::DummyTransaction)
              t = tx
              w.check
            end
            raise FooException.new
          end
        end
      end
    end

    t.rolledback.should be_true
    t.committed.should be_false
  end

  it "transaction can be committed within block" do
    with_dummy_connection do |cnn|
      cnn.transaction do |tx|
        tx.commit
      end
    end
  end

  it "transaction can be rolledback within block" do
    with_dummy_connection do |cnn|
      cnn.transaction do |tx|
        tx.rollback
      end
    end
  end

  it "transaction can be rolledback within block and later raise" do
    with_dummy_connection do |cnn|
      expect_raises(FooException) do
        cnn.transaction do |tx|
          tx.rollback
          raise FooException.new
        end
      end
    end
  end

  it "transaction can be rolledback within block and later raise DB::Rollback without forwarding it" do
    with_dummy_connection do |cnn|
      cnn.transaction do |tx|
        tx.rollback
        raise DB::Rollback.new
      end
    end
  end

  it "transaction can't be committed twice" do
    with_dummy_connection do |cnn|
      cnn.transaction do |tx|
        tx.commit
        expect_raises(DB::Error, "Transaction already closed") do
          tx.commit
        end
      end
    end
  end

  it "transaction can't be rolledback twice" do
    with_dummy_connection do |cnn|
      cnn.transaction do |tx|
        tx.rollback
        expect_raises(DB::Error, "Transaction already closed") do
          tx.rollback
        end
      end
    end
  end

  it "return connection to pool after transaction block in db" do
    DummyDriver::DummyConnection.clear_connections

    with_dummy do |db|
      db.transaction do |tx|
        db.pool.is_available?(DummyDriver::DummyConnection.connections.first).should be_false
      end
      db.pool.is_available?(DummyDriver::DummyConnection.connections.first).should be_true
    end
  end

  it "releasing result_set from within transaction should not return connection to pool" do
    cnn = uninitialized DB::Connection
    with_dummy do |db|
      db.transaction do |tx|
        cnn = tx.connection
        cnn.scalar "1"
        db.pool.is_available?(cnn).should be_false
      end
      db.pool.is_available?(cnn).should be_true
    end
  end
end
