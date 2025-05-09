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

  # deletes the given playlist and connected playlist videos
  def delete(id : String)
    PlaylistVideos.delete_by_playlist(id)
    request = <<-SQL
      DELETE FROM playlists *
      WHERE id = $1
    SQL

    PG_DB.exec(request, id)
  end

  # -------------------
  #  Update
  # -------------------

  def update(id : String, title : String, privacy, description, updated)
    request = <<-SQL
      UPDATE playlists
      SET title = $1, privacy = $2, description = $3, updated = $4
      WHERE id = $5
    SQL

    PG_DB.exec(request, title, privacy, description, updated, id)
  end

  def update_description(id : String, description)
    request = <<-SQL
      UPDATE playlists
      SET description = $1
      WHERE id = $2
    SQL

    PG_DB.exec(request, description, id)
  end

  def update_subscription_time(id : String)
    request = <<-SQL
      UPDATE playlists
      SET subscribed = now()
      WHERE id = $1
    SQL

    PG_DB.exec(request, id)
  end

  def update_video_added(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE playlists
      SET index = array_append(index, $1),
          video_count = cardinality(index) + 1,
          updated = now()
      WHERE id = $2
    SQL

    PG_DB.exec(request, index, id)
  end

  def update_video_removed(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE playlists
      SET index = array_remove(index, $1),
          video_count = cardinality(index) - 1,
          updated = now()
      WHERE id = $2
    SQL

    PG_DB.exec(request, index, id)
  end

  # -------------------
  #  Select
  # -------------------

  def select(*, id : String) : InvidiousPlaylist?
    request = <<-SQL
      SELECT * FROM playlists
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: InvidiousPlaylist)
  end

  def select_all(*, author : String) : Array(InvidiousPlaylist)
    request = <<-SQL
      SELECT * FROM playlists
      WHERE author = $1
    SQL

    return PG_DB.query_all(request, author, as: InvidiousPlaylist)
  end

  # -------------------
  #  Select (filtered)
  # -------------------

  def select_like_iv(email : String) : Array(InvidiousPlaylist)
    request = <<-SQL
      SELECT * FROM playlists
      WHERE author = $1 AND id LIKE 'IV%'
      ORDER BY created
    SQL

    PG_DB.query_all(request, email, as: InvidiousPlaylist)
  end

  def select_not_like_iv(email : String) : Array(InvidiousPlaylist)
    request = <<-SQL
      SELECT * FROM playlists
      WHERE author = $1 AND id NOT LIKE 'IV%'
      ORDER BY created
    SQL

    PG_DB.query_all(request, email, as: InvidiousPlaylist)
  end

  def select_user_created_playlists(email : String) : Array({String, String})
    request = <<-SQL
      SELECT id,title FROM playlists
      WHERE author = $1 AND id LIKE 'IV%'
      ORDER BY title
    SQL

    PG_DB.query_all(request, email, as: {String, String})
  end

  # -------------------
  #  Misc checks
  # -------------------

  # Check if given playlist ID exists
  def exists?(id : String) : Bool
    request = <<-SQL
      SELECT id FROM playlists
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: String).nil?
  end

  # Count how many playlists a user has created.
  def count_owned_by(author : String) : Int64
    request = <<-SQL
      SELECT count(*) FROM playlists
      WHERE author = $1
    SQL

    return PG_DB.query_one?(request, author, as: Int64) || 0_i64
  end
end

#
# This module contains functions related to the "playlist_videos" table.
#
module Invidious::Database::PlaylistVideos
  extend self

  private alias VideoIndex = Int64 | Array(Int64)

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

  def delete_by_playlist(plid : String)
    request = <<-SQL
      DELETE FROM playlist_videos *
      WHERE plid = $1
    SQL

    PG_DB.exec(request, plid)
  end

  # -------------------
  #  Select
  # -------------------

  def select(plid : String, index : VideoIndex, offset, limit = 100) : Array(PlaylistVideo)
    request = <<-SQL
      SELECT * FROM playlist_videos
      WHERE plid = $1
      ORDER BY array_position($2, index)
      LIMIT $3
      OFFSET $4
    SQL

    return PG_DB.query_all(request, plid, index, limit, offset, as: PlaylistVideo)
  end

  def select_index(plid : String, vid : String) : Int64?
    request = <<-SQL
      SELECT index FROM playlist_videos
      WHERE plid = $1 AND id = $2
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, plid, vid, as: Int64)
  end

  def select_one_id(plid : String, index : VideoIndex) : String?
    request = <<-SQL
      SELECT id FROM playlist_videos
      WHERE plid = $1
      ORDER BY array_position($2, index)
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, plid, index, as: String)
  end

  def select_ids(plid : String, index : VideoIndex, limit = 500) : Array(String)
    request = <<-SQL
      SELECT id FROM playlist_videos
      WHERE plid = $1
      ORDER BY array_position($2, index)
      LIMIT $3
    SQL

    return PG_DB.query_all(request, plid, index, limit, as: String)
  end
end
