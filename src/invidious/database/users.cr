require "./base.cr"

module Invidious::Database::Users
  extend self

  # -------------------
  #  Insert / delete
  # -------------------

  def insert(user : User, update_on_conflict : Bool = false)
    user_array = user.to_a
    user_array[4] = user_array[4].to_json # User preferences

    request = <<-SQL
      INSERT INTO users
      VALUES (#{arg_array(user_array)})
    SQL

    if update_on_conflict
      request += <<-SQL
        ON CONFLICT (email) DO UPDATE
        SET updated = $1, subscriptions = $3
      SQL
    end

    PG_DB.exec(request, args: user_array)
  end

  def delete(user : User)
    request = <<-SQL
      DELETE FROM users *
      WHERE email = $1
    SQL

    PG_DB.exec(request, user.email)
  end

  # -------------------
  #  Update (history)
  # -------------------

  def mark_watched(user : User, vid : String)
    request = <<-SQL
      UPDATE users
      SET watched = array_append(watched, $1)
      WHERE email = $2
    SQL

    PG_DB.exec(request, vid, user.email)
  end

  def mark_unwatched(user : User, vid : String)
    request = <<-SQL
      UPDATE users
      SET watched = array_remove(watched, $1)
      WHERE email = $2
    SQL

    PG_DB.exec(request, vid, user.email)
  end

  def clear_watch_history(user : User)
    request = <<-SQL
      UPDATE users
      SET watched = '{}'
      WHERE email = $1
    SQL

    PG_DB.exec(request, user.email)
  end

  # -------------------
  #  Update (channels)
  # -------------------

  def subscribe_channel(user : User, ucid : String)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true,
          subscriptions = array_append(subscriptions,$1)
      WHERE email = $2
    SQL

    PG_DB.exec(request, ucid, user.email)
  end

  def unsubscribe_channel(user : User, ucid : String)
    request = <<-SQL
      UPDATE users
      SET feed_needs_update = true,
          subscriptions = array_remove(subscriptions, $1)
      WHERE email = $2
    SQL

    PG_DB.exec(request, ucid, user.email)
  end

  # -------------------
  #  Select
  # -------------------

  def select(*, email : String) : User?
    request = <<-SQL
      SELECT * FROM users
      WHERE email = $1
    SQL

    return PG_DB.query_one?(request, email, as: User)
  end

  # Same as select, but can raise an exception
  def select!(*, email : String) : User
    request = <<-SQL
      SELECT * FROM users
      WHERE email = $1
    SQL

    return PG_DB.query_one(request, email, as: User)
  end

  def select(*, token : String) : User?
    request = <<-SQL
      SELECT * FROM users
      WHERE token = $1
    SQL

    return PG_DB.query_one?(request, token, as: User)
  end
end
