require "./base.cr"

module Invidious::Database::Annotations
  extend self

  def insert(id : String, annotations : String)
    request = <<-SQL
      INSERT INTO annotations
      VALUES ($1, $2)
      ON CONFLICT DO NOTHING
    SQL

    PG_DB.exec(request, id, annotations)
  end

  def select(id : String) : Annotation?
    request = <<-SQL
      SELECT * FROM annotations
      WHERE id = $1
    SQL

    return PG_DB.query_one?(request, id, as: Annotation)
  end
end
