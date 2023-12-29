module Invidious::Database::Migrations
  class CreateCompilationsTable < Migration
    version 11

    def up(conn : DB::Connection)
      if !compilation_privacy_type_exists?(conn)
        conn.exec <<-SQL
        CREATE TYPE public.compilation_privacy AS ENUM
        (
          'Unlisted',
          'Private'
        );
        SQL
      end

      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.compilations
      (
        title text,
        id text primary key,
        author text,
        description text,
        video_count integer,
        created timestamptz,
        updated timestamptz,
        privacy compilation_privacy,
        index int8[],
        first_video_id text,
        first_video_starting_timestamp_seconds integer,
        first_video_ending_timestamp_seconds integer
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON public.compilations TO current_user;
      SQL
    end

    private def compilation_privacy_type_exists?(conn : DB::Connection) : Bool
      request = <<-SQL
        SELECT 1 AS one
        FROM pg_type
        INNER JOIN pg_namespace ON pg_namespace.oid = pg_type.typnamespace
        WHERE pg_namespace.nspname = 'public'
          AND pg_type.typname = 'compilation_privacy'
        LIMIT 1;
      SQL

      !conn.query_one?(request, as: Int32).nil?
    end
  end
end
