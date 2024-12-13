module Invidious::Database::Migrations
  class CreateUsersTable < Migration
    version 4

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.users
      (
        updated timestamp with time zone,
        notifications text[],
        subscriptions text[],
        email text NOT NULL,
        preferences text,
        password text,
        token text,
        watched text[],
        feed_needs_update boolean,
        CONSTRAINT users_email_key UNIQUE (email)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.users TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS email_unique_idx
        ON public.users
        USING btree
        (lower(email) COLLATE pg_catalog."default");
      SQL
    end
  end
end
