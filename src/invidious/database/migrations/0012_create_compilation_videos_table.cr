module Invidious::Database::Migrations
    class CreateCompilationVideosTable < Migration
      version 12
  
      def up(conn : DB::Connection)
        conn.exec <<-SQL
        CREATE TABLE IF NOT EXISTS public.compilation_videos
        (
          title text,
          id text,
          author text,
          ucid text,
          length_seconds integer,
          starting_timestamp_seconds integer,
          ending_timestamp_seconds integer,
          published timestamptz,
          compid text references compilations(id),
          index int8,
          order_index integer,
          PRIMARY KEY (index,compid)
        );
        SQL
  
        conn.exec <<-SQL
        GRANT ALL ON TABLE public.playlist_videos TO current_user;
        SQL
      end
    end
  end
  