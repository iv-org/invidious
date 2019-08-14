require "./spec_helper"

private class FooException < Exception
end

private def with_dummy_top_transaction
  with_dummy_connection do |cnn|
    cnn.transaction do |tx|
      yield tx.as(DummyDriver::DummyTransaction), cnn
    end
  end
end

private def with_dummy_nested_transaction
  with_dummy_connection do |cnn|
    cnn.transaction do |tx|
      tx.transaction do |nested|
        yield nested.as(DummyDriver::DummySavePointTransaction), cnn
      end
    end
  end
end

describe DB::SavePointTransaction do
  {% for context in [:with_dummy_top_transaction, :with_dummy_nested_transaction] %}
  describe "{{context.id}}" do
    it "begin/commit transaction from parent transaction" do
      {{context.id}} do |parent_tx|
        tx = parent_tx.begin_transaction
        tx.commit
      end
    end

    it "begin/rollback transaction from parent transaction" do
      {{context.id}} do |parent_tx|
        tx = parent_tx.begin_transaction
        tx.rollback
      end
    end

    it "raise if begin over existing transaction" do
      {{context.id}} do |parent_tx|
        parent_tx.begin_transaction
        expect_raises(DB::Error, "There is an existing nested transaction in this transaction") do
          parent_tx.begin_transaction
        end
      end
    end

    it "allow sequential transactions" do
      {{context.id}} do |parent_tx|
        tx = parent_tx.begin_transaction
        tx.rollback

        tx = parent_tx.begin_transaction
        tx.commit
      end
    end

    it "transaction with block from parent transaction should be committed" do
      t = uninitialized DummyDriver::DummySavePointTransaction

      with_witness do |w|
        {{context.id}} do |parent_tx|
          parent_tx.transaction do |tx|
            if tx.is_a?(DummyDriver::DummySavePointTransaction)
              t = tx
              w.check
            end
          end
        end
      end

      t.committed.should be_true
      t.rolledback.should be_false
    end
  end
  {% end %}

  it "only nested transaction with block from parent transaction should be rolledback if raise DB::Rollback" do
    top = uninitialized DummyDriver::DummyTransaction
    t = uninitialized DummyDriver::DummySavePointTransaction

    with_witness do |w|
      with_dummy_top_transaction do |parent_tx|
        top = parent_tx
        parent_tx.transaction do |tx|
          if tx.is_a?(DummyDriver::DummySavePointTransaction)
            t = tx
            w.check
          end
          raise DB::Rollback.new
        end
      end
    end

    t.rolledback.should be_true
    t.committed.should be_false

    top.rolledback.should be_false
    top.committed.should be_true
  end

  it "only nested transaction with block from parent nested transaction should be rolledback if raise DB::Rollback" do
    top = uninitialized DummyDriver::DummySavePointTransaction
    t = uninitialized DummyDriver::DummySavePointTransaction

    with_witness do |w|
      with_dummy_nested_transaction do |parent_tx|
        top = parent_tx
        parent_tx.transaction do |tx|
          if tx.is_a?(DummyDriver::DummySavePointTransaction)
            t = tx
            w.check
          end
          raise DB::Rollback.new
        end
      end
    end

    t.rolledback.should be_true
    t.committed.should be_false

    top.rolledback.should be_false
    top.committed.should be_true
  end

  it "releasing result_set from within inner transaction should not return connection to pool" do
    cnn = uninitialized DB::Connection
    with_dummy do |db|
      db.transaction do |tx|
        tx.transaction do |inner|
          cnn = inner.connection
          cnn.scalar "1"
          db.pool.is_available?(cnn).should be_false
        end
        db.pool.is_available?(cnn).should be_false
      end
      db.pool.is_available?(cnn).should be_true
    end
  end

  it "releasing result_set from within inner inner transaction should not return connection to pool" do
    cnn = uninitialized DB::Connection
    with_dummy do |db|
      db.transaction do |tx|
        tx.transaction do |inner|
          inner.transaction do |inner_inner|
            cnn = inner_inner.connection
            cnn.scalar "1"
            db.pool.is_available?(cnn).should be_false
          end
          db.pool.is_available?(cnn).should be_false
        end
        db.pool.is_available?(cnn).should be_false
      end
      db.pool.is_available?(cnn).should be_true
    end
  end
end
