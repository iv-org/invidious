require "./base.cr"

module Invidious::Database::Videos
  extend self

  def insert(video : Video)
    request = <<-SQL
      INSERT INTO videos
      VALUES ($1, $2, $3)
      ON CONFLICT (id) DO NOTHING
    SQL

    PG_DB.exec(request, video.id, video.info.to_json, video.updated)
  end

  def delete(id)
    request = <<-SQL
      DELETE FROM videos *
      WHERE id = $1
    SQL

    PG_DB.exec(request, id)
  end

  def update(video : Video)
    request = <<-SQL
      UPDATE videos
      SET (id, info, updated) = ($1, $2, $3)
      WHERE id = $1
    SQL

    PG_DB.exec(request, video.id, video.info.to_json, video.updated)
  end

  def select(id : String) : Video?
    request = <<-SQL
      SELECT * FROM videos
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: Video)
  end
end
