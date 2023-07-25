module Invidious::Database::Migrations
  class AddTotpSecretToUsersTable < Migration
    version 11

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      ALTER TABLE users ADD COLUMN totp_secret VARCHAR(128)
      SQL
    end
  end
end
