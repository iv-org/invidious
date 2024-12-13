module Invidious::Database::Migrations
  class MakeVideosUnlogged < Migration
    version 10

    def up(conn : DB::Connection)
      conn.exec <<-SQL
      ALTER TABLE public.videos SET UNLOGGED;
      SQL
    end
  end
end
