require "./base.cr"

module Invidious::Database::SessionIDs
  extend self

  # -------------------
  #  Insert
  # -------------------

  def insert(sid : String, email : String, handle_conflicts : Bool = false, *, conn : DB::Database | DB::Connection | DB::Transaction = PG_DB)
    request = <<-SQL
      INSERT INTO session_ids
      VALUES ($1, $2, now())
    SQL

    request += " ON CONFLICT (id) DO NOTHING" if handle_conflicts

    conn.exec(request, sid, email)
  end

  # -------------------
  #  Delete
  # -------------------

  def delete(*, sid : String, conn : DB::Database | DB::Connection | DB::Transaction = PG_DB)
    request = <<-SQL
      DELETE FROM session_ids *
      WHERE id = $1
    SQL

    conn.exec(request, sid)
  end

  def delete(*, email : String, conn : DB::Database | DB::Connection | DB::Transaction = PG_DB)
    request = <<-SQL
      DELETE FROM session_ids *
      WHERE email = $1
    SQL

    conn.exec(request, email)
  end

  def delete(*, sid : String, email : String, conn : DB::Database | DB::Connection | DB::Transaction = PG_DB)
    request = <<-SQL
      DELETE FROM session_ids *
      WHERE id = $1 AND email = $2
    SQL

    conn.exec(request, sid, email)
  end

  # -------------------
  #  Select
  # -------------------

  def select_email(sid : String) : String?
    request = <<-SQL
      SELECT email FROM session_ids
      WHERE id = $1
    SQL

    PG_DB.query_one?(request, sid, as: String)
  end

  def select_all(email : String) : Array({session: String, issued: Time})
    request = <<-SQL
      SELECT id, issued FROM session_ids
      WHERE email = $1
      ORDER BY issued DESC
    SQL

    PG_DB.query_all(request, email, as: {session: String, issued: Time})
  end
end
