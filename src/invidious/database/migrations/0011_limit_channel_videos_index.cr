module Invidious::Database::Migrations
  class LimitChannelVideosIndex < Migration
    version 11
    required false

    def up(conn : DB::Connection)
      conn.exec <<-SQL
        CREATE INDEX IF NOT EXISTS channel_videos_ucid_published_idx
            ON public.channel_videos
            USING btree
            (ucid COLLATE pg_catalog."default", published);
      SQL

      conn.exec <<-SQL
        DROP INDEX IF EXISTS channel_videos_ucid_idx;
      SQL
    end
  end
end
