module Invidious::Database::Migrations
  class AddThumbnailIdToPlaylists < Migration
    version 11

    def up(conn : DB::Connection)
      conn.exec <<-SQL
        ALTER TABLE public.playlists
          ADD COLUMN IF NOT EXISTS thumbnail_id TEXT;
      SQL
    end
  end
end
