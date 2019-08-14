module DB
  # Transactions should be started from `DB#transaction`, `Connection#transaction`
  # or `Connection#begin_transaction`.
  #
  # Use `Transaction#connection` to submit statements to the database.
  #
  # Use `Transaction#commit` or `Transaction#rollback` to close the ongoing transaction
  # explicitly. Or refer to `BeginTransaction#transaction` for documentation on how to
  # use `#transaction(&block)` methods in `DB` and `Connection`.
  #
  # Nested transactions are supported by using sql `SAVEPOINT`. To start a nested
  # transaction use `Transaction#transaction` or `Transaction#begin_transaction`.
  #
  abstract class Transaction
    include Disposable
    include BeginTransaction

    abstract def connection : Connection

    # commits the current transaction
    def commit
      close!
    end

    # rollbacks the current transaction
    def rollback
      close!
    end

    private def close!
      raise DB::Error.new("Transaction already closed") if closed?
      close
    end

    abstract def release_from_nested_transaction
  end

  class TopLevelTransaction < Transaction
    getter connection : Connection
    # :nodoc:
    property savepoint_name : String? = nil

    def initialize(@connection : Connection)
      @nested_transaction = false
      @connection.perform_begin_transaction
    end

    def commit
      @connection.perform_commit_transaction
      super
    end

    def rollback
      @connection.perform_rollback_transaction
      super
    end

    protected def do_close
      connection.release_from_transaction
    end

    def begin_transaction : Transaction
      raise DB::Error.new("There is an existing nested transaction in this transaction") if @nested_transaction
      @nested_transaction = true
      create_save_point_transaction(self)
    end

    # :nodoc:
    def create_save_point_transaction(parent : Transaction) : SavePointTransaction
      # TODO should we wrap this in a mutex?
      previous_savepoint = @savepoint_name
      savepoint_name = if previous_savepoint
                         previous_savepoint.succ
                       else
                         # random prefix to avoid determinism
                         "cr_#{@connection.object_id}_#{Random.rand(10_000)}_00001"
                       end

      @savepoint_name = savepoint_name

      create_save_point_transaction(parent, savepoint_name)
    end

    protected def create_save_point_transaction(parent : Transaction, savepoint_name : String) : SavePointTransaction
      SavePointTransaction.new(parent, savepoint_name)
    end

    # :nodoc:
    def release_from_nested_transaction
      @nested_transaction = false
    end
  end

  class SavePointTransaction < Transaction
    getter connection : Connection

    def initialize(@parent : Transaction, @savepoint_name : String)
      @nested_transaction = false
      @connection = @parent.connection
      @connection.perform_create_savepoint(@savepoint_name)
    end

    def commit
      @connection.perform_release_savepoint(@savepoint_name)
      super
    end

    def rollback
      @connection.perform_rollback_savepoint(@savepoint_name)
      super
    end

    protected def do_close
      @parent.release_from_nested_transaction
    end

    def begin_transaction : Transaction
      raise DB::Error.new("There is an existing nested transaction in this transaction") if @nested_transaction
      @nested_transaction = true
      create_save_point_transaction(self)
    end

    def create_save_point_transaction(parent : Transaction)
      @parent.create_save_point_transaction(parent)
    end

    def release_from_nested_transaction
      @nested_transaction = false
    end
  end
end
