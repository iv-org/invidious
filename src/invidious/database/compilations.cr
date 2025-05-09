require "./base.cr"

#
# This module contains functions related to the "compilations" table.
#
module Invidious::Database::Compilations
  extend self

  # -------------------
  #  Insert / delete
  # -------------------

  def insert(compilation : InvidiousCompilation)
    compilation_array = compilation.to_a

    request = <<-SQL
      INSERT INTO compilations
      VALUES (#{arg_array(compilation_array)})
    SQL

    PG_DB.exec(request, args: compilation_array)
  end

  # deletes the given compilation and connected compilation videos
  def delete(id : String)
    CompilationVideos.delete_by_compilation(id)
    request = <<-SQL
      DELETE FROM compilations *
      WHERE id = $1
    SQL

    PG_DB.exec(request, id)
  end

  # -------------------
  #  Update
  # -------------------

  def update(id : String, title : String, privacy, description, updated)
    request = <<-SQL
      UPDATE compilations
      SET title = $1, privacy = $2, description = $3, updated = $4
      WHERE id = $5
    SQL

    PG_DB.exec(request, title, privacy, description, updated, id)
  end

  def update_description(id : String, description)
    request = <<-SQL
      UPDATE compilations
      SET description = $1
      WHERE id = $2
    SQL

    PG_DB.exec(request, description, id)
  end

  def update_video_added(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE compilations
      SET index = array_append(index, $1),
          video_count = cardinality(index) + 1,
          updated = now()
      WHERE id = $2
    SQL

    PG_DB.exec(request, index, id)
  end

  def update_video_removed(id : String, index : String | Int64)
    request = <<-SQL
      UPDATE compilations
      SET index = array_remove(index, $1),
          video_count = cardinality(index) - 1,
          updated = now()
      WHERE id = $2
    SQL

    PG_DB.exec(request, index, id)
  end

  def move_video_position(id : String, index : Array(Int64))
    request = <<-SQL
      UPDATE compilations
      SET index = $2
      WHERE id = $1
    SQL

    PG_DB.exec(request, id, index)
  end

  def update_first_video_params(id : String, first_video_id : String, starting_timestamp_seconds : Int32, ending_timestamp_seconds : Int32)
    request = <<-SQL
      UPDATE compilations
      SET first_video_id = $2,
          first_video_starting_timestamp_seconds = $3,
          first_video_ending_timestamp_seconds = $4
      WHERE id = $1
    SQL

    PG_DB.exec(request, id, first_video_id, starting_timestamp_seconds, ending_timestamp_seconds)
  end

  # -------------------
  #  Select
  # -------------------

  def select(*, id : String) : InvidiousCompilation?
    request = <<-SQL
      SELECT * FROM compilations
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: InvidiousCompilation)
  end

  def select_all(*, author : String) : Array(InvidiousCompilation)
    request = <<-SQL
      SELECT * FROM compilations
      WHERE author = $1
    SQL

    return PG_DB.query_all(request, author, as: InvidiousCompilation)
  end

  def select_index_array(id : String)
    request = <<-SQL
      SELECT index FROM compilations
      WHERE id = $1
      LIMIT 1
    SQL

    PG_DB.query_one?(request, id, as: Array(Int64))
  end

  # -------------------
  #  Select (filtered)
  # -------------------

  def select_like_iv(email : String) : Array(InvidiousCompilation)
    request = <<-SQL
      SELECT * FROM compilations
      WHERE author = $1 AND id LIKE 'IV%'
      ORDER BY created
    SQL

    PG_DB.query_all(request, email, as: InvidiousCompilation)
  end

  def select_not_like_iv(email : String) : Array(InvidiousCompilation)
    request = <<-SQL
      SELECT * FROM compilations
      WHERE author = $1 AND id NOT LIKE 'IV%'
      ORDER BY created
    SQL

    PG_DB.query_all(request, email, as: InvidiousCompilation)
  end

  def select_user_created_compilations(email : String) : Array({String, String})
    request = <<-SQL
      SELECT id,title FROM compilations
      WHERE author = $1 AND id LIKE 'IV%'
    SQL

    PG_DB.query_all(request, email, as: {String, String})
  end

  # -------------------
  #  Misc checks
  # -------------------

  # Check if given compilation ID exists
  def exists?(id : String) : Bool
    request = <<-SQL
      SELECT id FROM compilations
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: String).nil?
  end

  # Count how many compilations a user has created.
  def count_owned_by(author : String) : Int64
    request = <<-SQL
      SELECT count(*) FROM compilations
      WHERE author = $1
    SQL

    return PG_DB.query_one?(request, author, as: Int64) || 0_i64
  end
end

#
# This module contains functions related to the "compilation_videos" table.
#
module Invidious::Database::CompilationVideos
  extend self

  private alias VideoIndex = Int64 | Array(Int64)

  # -------------------
  #  Insert / Delete
  # -------------------

  def insert(video : CompilationVideo)
    video_array = video.to_a

    request = <<-SQL
      INSERT INTO compilation_videos
      VALUES (#{arg_array(video_array)})
    SQL

    PG_DB.exec(request, args: video_array)
  end

  def delete(index)
    request = <<-SQL
      DELETE FROM compilation_videos *
      WHERE index = $1
    SQL

    PG_DB.exec(request, index)
  end

  def delete_by_compilation(compid : String)
    request = <<-SQL
      DELETE FROM compilation_videos *
      WHERE compid = $1
    SQL

    PG_DB.exec(request, compid)
  end

  # -------------------
  #  Select
  # -------------------

  def select(compid : String, index : VideoIndex, offset, limit = 100) : Array(CompilationVideo)
    request = <<-SQL
      SELECT * FROM compilation_videos
      WHERE compid = $1
      ORDER BY array_position($2, index)
      LIMIT $3
      OFFSET $4
    SQL

    return PG_DB.query_all(request, compid, index, limit, offset, as: CompilationVideo)
  end

  def select_video(compid : String, index : VideoIndex, video_index, offset, limit = 100) : Array(CompilationVideo)
    request = <<-SQL
      SELECT * FROM compilation_videos
      WHERE compid = $1 AND index = $3
      ORDER BY array_position($2, index)
      LIMIT $5
      OFFSET $4
    SQL

    return PG_DB.query_all(request, compid, index, video_index, offset, limit, as: CompilationVideo)
  end

  def select_timestamps(compid : String, vid : String)
    request = <<-SQL
      SELECT starting_timestamp_seconds,ending_timestamp_seconds FROM compilation_videos
      WHERE compid = $1 AND id = $2
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, compid, vid, as: {Int32, Int32})
  end

  def select_id_from_order_index(order_index : Int32)
    request = <<-SQL
      SELECT id FROM compilation_videos
      WHERE order_index = $1
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, order_index, as: String)
  end

  def select_id_from_index(index : Int64)
    request = <<-SQL
      SELECT id FROM compilation_videos
      WHERE index = $1
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, index, as: String)
  end

  def select_index_from_order_index(order_index : Int32)
    request = <<-SQL
      SELECT index FROM compilation_videos
      WHERE order_index = $1
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, order_index, as: VideoIndex)
  end

  def select_index(compid : String, vid : String) : Int64?
    request = <<-SQL
      SELECT index FROM compilation_videos
      WHERE compid = $1 AND id = $2
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, compid, vid, as: Int64)
  end

  def select_one_id(compid : String, index : VideoIndex) : String?
    request = <<-SQL
      SELECT id FROM compilation_videos
      WHERE compid = $1
      ORDER BY array_position($2, index)
      LIMIT 1
    SQL

    return PG_DB.query_one?(request, compid, index, as: String)
  end

  def select_ids(compid : String, index : VideoIndex, limit = 500) : Array(String)
    request = <<-SQL
      SELECT id FROM compilation_videos
      WHERE compid = $1
      ORDER BY array_position($2, index)
      LIMIT $3
    SQL

    return PG_DB.query_all(request, compid, index, limit, as: String)
  end

  # -------------------
  #  Update
  # -------------------

  def update_start_timestamp(id : String, starting_timestamp_seconds : Int32)
    request = <<-SQL
      UPDATE compilation_videos
      SET starting_timestamp_seconds = $2
      WHERE id = $1
    SQL

    PG_DB.exec(request, id, starting_timestamp_seconds)
  end

  def update_end_timestamp(id : String, ending_timestamp_seconds : Int32)
    request = <<-SQL
      UPDATE compilation_videos
      SET ending_timestamp_seconds = $2
      WHERE id = $1
    SQL

    PG_DB.exec(request, id, ending_timestamp_seconds)
  end
end
