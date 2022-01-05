require "./base.cr"

module Invidious::Database::Statistics
  extend self

  # -------------------
  #  User stats
  # -------------------

  def count_users_total : Int64
    request = <<-SQL
      SELECT count(*) FROM users
    SQL

    PG_DB.query_one(request, as: Int64)
  end

  def count_users_active_1m : Int64
    request = <<-SQL
      SELECT count(*) FROM users
      WHERE CURRENT_TIMESTAMP - updated < '6 months'
    SQL

    PG_DB.query_one(request, as: Int64)
  end

  def count_users_active_6m : Int64
    request = <<-SQL
      SELECT count(*) FROM users
      WHERE CURRENT_TIMESTAMP - updated < '1 month'
    SQL

    PG_DB.query_one(request, as: Int64)
  end

  # -------------------
  #  Channel stats
  # -------------------

  def channel_last_update : Time?
    request = <<-SQL
      SELECT updated FROM channels
      ORDER BY updated DESC
      LIMIT 1
    SQL

    PG_DB.query_one?(request, as: Time)
  end
end
