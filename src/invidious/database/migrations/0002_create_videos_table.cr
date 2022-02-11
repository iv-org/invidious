module Invidious::Database::Migrations
  class CreateVideosTable < Migration
    version 2

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE UNLOGGED TABLE IF NOT EXISTS public.videos
      (
        id text NOT NULL,
        info text,
        updated timestamp with time zone,
        CONSTRAINT videos_pkey PRIMARY KEY (id)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.videos TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE UNIQUE INDEX IF NOT EXISTS id_idx
        ON public.videos
        USING btree
        (id COLLATE pg_catalog."default");
      SQL
    end
  end
end
