module Invidious::Database::Migrations
  class CreatePlaylistVideosTable < Migration
    version 9

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      CREATE TABLE IF NOT EXISTS public.playlist_videos
      (
        title text,
        id text,
        author text,
        ucid text,
        length_seconds integer,
        published timestamptz,
        plid text references playlists(id),
        index int8,
        live_now boolean,
        PRIMARY KEY (index,plid)
      );
      SQL

      conn.exec <<-SQL
      GRANT ALL ON TABLE public.playlist_videos TO current_user;
      SQL
    end
  end
end
