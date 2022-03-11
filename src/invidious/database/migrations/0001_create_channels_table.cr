module Invidious::Database::Migrations
  class CreateChannelsTable < Migration
    version 1

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.channels
      (
        id text NOT NULL,
        author text,
        updated timestamp with time zone,
        deleted boolean,
        subscribed timestamp with time zone,
        CONSTRAINT channels_id_key UNIQUE (id)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.channels TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS channels_id_idx
        ON public.channels
        USING btree
        (id COLLATE pg_catalog."default");
      SQL
    end
  end
end
