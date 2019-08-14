# Exception thrown on invalid SQLite3 operations.
class SQLite3::Exception < ::Exception
  # The internal code associated with the failure.
  getter code

  def initialize(db)
    super(String.new(LibSQLite3.errmsg(db)))
    @code = LibSQLite3.errcode(db)
  end
end
