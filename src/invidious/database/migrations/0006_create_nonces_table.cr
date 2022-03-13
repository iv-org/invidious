module Invidious::Database::Migrations
  class CreateNoncesTable < Migration
    version 6

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.nonces
      (
        nonce text,
        expire timestamp with time zone,
        CONSTRAINT nonces_id_key UNIQUE (nonce)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.nonces TO current_user;
      SQL

      conn.exec <<-SQL
      CREATE INDEX IF NOT EXISTS nonces_nonce_idx
        ON public.nonces
        USING btree
        (nonce COLLATE pg_catalog."default");
      SQL
    end
  end
end
