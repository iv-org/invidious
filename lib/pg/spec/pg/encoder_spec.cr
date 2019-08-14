require "../spec_helper"

private def test_insert_and_read(datatype, value, file = __FILE__, line = __LINE__)
  it "inserts #{datatype}", file, line do
    PG_DB.exec "drop table if exists test_table"
    PG_DB.exec "create table test_table (v #{datatype})"

    # Read casting the value
    PG_DB.exec "insert into test_table values ($1)", [value]
    actual_value = PG_DB.query_one "select v from test_table", as: value.class
    actual_value.should eq(value)

    # Read without casting the value
    actual_value = PG_DB.query_one "select v from test_table", &.read
    actual_value.should eq(value)
  end
end

describe PG::Driver, "encoder" do
  test_insert_and_read "int4", 123

  test_insert_and_read "float", 12.34

  test_insert_and_read "varchar", "hello world"

  test_insert_and_read "timestamp", Time.utc(2015, 2, 3, 17, 15, nanosecond: 13_000_000)
  test_insert_and_read "timestamp", Time.utc(2015, 2, 3, 17, 15, 13, nanosecond: 11_000_000)
  test_insert_and_read "timestamp", Time.utc(2015, 2, 3, 17, 15, 13, nanosecond: 123_456_000)
  test_insert_and_read "timestamptz", Time.local(2019, 8, 13, 12, 30, location: Time::Location.fixed(-14_400))

  test_insert_and_read "bool[]", [true, false, true]

  test_insert_and_read "float[]", [1.2, 3.4, 5.6]

  test_insert_and_read "integer[]", [] of Int32
  test_insert_and_read "integer[]", [1, 2, 3]
  test_insert_and_read "integer[]", [[1, 2], [3, 4]]

  test_insert_and_read "text[]", ["t", "f", "t"]
  test_insert_and_read "text[]", [%("a), %(\\b~), %(c\\"d), %(\uFF8F)]
  test_insert_and_read "text[]", ["baz, bar"]
  test_insert_and_read "text[]", ["foo}"]

  describe "geo" do
    test_insert_and_read "point", PG::Geo::Point.new(1.2, 3.4)
    if Helper.db_version_gte(9, 4)
      test_insert_and_read "line", PG::Geo::Line.new(1.2, 3.4, 5.6)
    end
    test_insert_and_read "circle", PG::Geo::Circle.new(1.2, 3.4, 5.6)
    test_insert_and_read "lseg", PG::Geo::LineSegment.new(1.2, 3.4, 5.6, 7.8)
    test_insert_and_read "box", PG::Geo::Box.new(1.2, 3.4, 5.6, 7.8)
    test_insert_and_read "path", PG::Geo::Path.new([
      PG::Geo::Point.new(1.2, 3.4),
      PG::Geo::Point.new(5.6, 7.8),
    ], closed: false)
    test_insert_and_read "path", PG::Geo::Path.new([
      PG::Geo::Point.new(1.2, 3.4),
      PG::Geo::Point.new(5.6, 7.8),
    ], closed: true)
    test_insert_and_read "polygon", PG::Geo::Polygon.new([
      PG::Geo::Point.new(1.2, 3.4),
      PG::Geo::Point.new(5.6, 7.8),
    ])
  end
end
