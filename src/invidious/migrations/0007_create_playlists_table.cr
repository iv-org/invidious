module Invidious::Migrations
  class CreatePlaylistsTable < Migration
    version 7

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      DO
      $$
      BEGIN
        IF NOT EXISTS (SELECT *
                        FROM pg_type typ
                        INNER JOIN pg_namespace nsp ON nsp.oid = typ.typnamespace
                        WHERE nsp.nspname = 'public'
                              AND typ.typname = 'privacy') THEN
          CREATE TYPE public.privacy AS ENUM
            (
                'Public',
                'Unlisted',
                'Private'
            );
        END IF;
      END;
      $$
      LANGUAGE plpgsql;
      SQL

      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.playlists
      (
          title text,
          id text primary key,
          author text,
          description text,
          video_count integer,
          created timestamptz,
          updated timestamptz,
          privacy privacy,
          index int8[]
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON public.playlists TO current_user;
      SQL
    end
  end
end
