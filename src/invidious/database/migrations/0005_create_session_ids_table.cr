module Invidious::Database::Migrations
  class CreateSessionIdsTable < Migration
    version 5

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.session_ids
      (
        id text NOT NULL,
        email text,
        issued timestamp with time zone,
        CONSTRAINT session_ids_pkey PRIMARY KEY (id)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.session_ids TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS session_ids_id_idx
        ON public.session_ids
        USING btree
        (id COLLATE pg_catalog."default");
      SQL
    end
  end
end
