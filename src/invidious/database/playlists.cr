require "./base.cr"

#
# This module contains functions related to the "playlists" table.
#
module Invidious::Database::Playlists
  extend self

  # -------------------
  #  Insert / delete
  # -------------------

  def insert(playlist : InvidiousPlaylist)
    playlist_array = playlist.to_a

    request = <<-SQL
      INSERT INTO playlists
      VALUES (#{arg_array(playlist_array)})
    SQL

    PG_DB.exec(request, args: playlist_array)
  end

  # this function is a bit special: it will also remove all videos
  # related to the given playlist ID in the "playlist_videos" table,
  # in addition to deleting said ID from "playlists".
  def delete(id : String)
    request = <<-SQL
      DELETE FROM playlist_videos * WHERE plid = $1;
      DELETE FROM playlists * WHERE id = $1
    SQL

    PG_DB.exec(request, id)
  end

  # -------------------
  #  Update
  # -------------------

  def update_video_added(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE playlists
      SET index = array_append(index, $1),
          video_count = cardinality(index) + 1,
          updated = $2
      WHERE id = $3
    SQL

    PG_DB.exec(request, index, Time.utc, id)
  end

  def update_video_removed(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE playlists
      SET index = array_remove(index, $1),
          video_count = cardinality(index) - 1,
          updated = $2
      WHERE id = $3
    SQL

    PG_DB.exec(request, index, Time.utc, id)
  end
end

#
# This module contains functions related to the "playlist_videos" table.
#
module Invidious::Database::PlaylistVideos
  extend self

  # -------------------
  #  Insert / Delete
  # -------------------

  def insert(video : PlaylistVideo)
    video_array = video.to_a

    request = <<-SQL
      INSERT INTO playlist_videos
      VALUES (#{arg_array(video_array)})
    SQL

    PG_DB.exec(request, args: video_array)
  end

  def delete(index)
    request = <<-SQL
      DELETE FROM playlist_videos *
      WHERE index = $1
    SQL

    PG_DB.exec(request, index)
  end
end
