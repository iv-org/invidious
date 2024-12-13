require "./base.cr"

module Invidious::Database::Nonces
  extend self

  # -------------------
  #  Insert / Delete
  # -------------------

  def insert(nonce : String, expire : Time)
    request = <<-SQL
      INSERT INTO nonces
      VALUES ($1, $2)
      ON CONFLICT DO NOTHING
    SQL

    PG_DB.exec(request, nonce, expire)
  end

  def delete_expired
    request = <<-SQL
      DELETE FROM nonces *
      WHERE expire < now()
    SQL

    PG_DB.exec(request)
  end

  # -------------------
  #  Update
  # -------------------

  def update_set_expired(nonce : String)
    request = <<-SQL
      UPDATE nonces
      SET expire = $1
      WHERE nonce = $2
    SQL

    PG_DB.exec(request, Time.utc(1990, 1, 1), nonce)
  end

  # -------------------
  #  Select
  # -------------------

  def select(nonce : String) : Tuple(String, Time)?
    request = <<-SQL
      SELECT * FROM nonces
      WHERE nonce = $1
    SQL

    return PG_DB.query_one?(request, nonce, as: {String, Time})
  end
end
