require "../../spec_helper"

describe PG::Decoders do
  test_decode "array", "'{}'::integer[]", [] of Int32
  test_decode "array", "ARRAY[9]", [9]
  test_decode "array", "ARRAY[8,9]", [8, 9]
  test_decode "array", "'{{9,8},{7,6},{5,4}}'::integer[]",
    [[9, 8], [7, 6], [5, 4]]
  test_decode "array", "'{ {9,8,7}, {6,5,4} }'::integer[] ",
    [[9, 8, 7], [6, 5, 4]]
  test_decode "array", "'{{{1,2},{3,4}},{{9,8},{7,6}}}'::integer[]",
    [[[1, 2], [3, 4]], [[9, 8], [7, 6]]]
  test_decode "array", "ARRAY[1, null, 2] ", [1, nil, 2]
  test_decode "array", "('[3:5]={1,2,3}'::integer[])", [nil, nil, 1, 2, 3]

  it "allows special-case casting on simple arrays" do
    value = PG_DB.query_one("select '{}'::integer[]", &.read(Array(Int32)))
    typeof(value).should eq(Array(Int32))
    value.empty?.should be_true

    value = PG_DB.query_one("select '{1,2,3}'::integer[]", &.read(Array(Int32)))
    typeof(value).should eq(Array(Int32))
    value.should eq([1, 2, 3])

    value = PG_DB.query_one("select '{1,2,3,null}'::integer[]", &.read(Array(Int32?)))
    typeof(value).should eq(Array(Int32?))
    value.should eq([1, 2, 3, nil])

    value = PG_DB.query_one("select '{{1,2,3},{4,5,6}}'::integer[]", &.read(Array(Array(Int32))))
    typeof(value).should eq(Array(Array(Int32)))
    value.should eq([[1, 2, 3], [4, 5, 6]])
  end

  it "reads array as nilable" do
    value = PG_DB.query_one("select '{1,2,3}'::integer[]", &.read(Array(Int32)?))
    typeof(value).should eq(Array(Int32)?)
    value.should eq([1, 2, 3])

    value = PG_DB.query_one("select null", &.read(Array(Int32)?))
    typeof(value).should eq(Array(Int32)?)
    value.should be_nil
  end

  it "reads arrray of numeric" do
    value = PG_DB.query_one("select '{1,2,3}'::numeric[]", &.read(Array(PG::Numeric)))
    typeof(value).should eq(Array(PG::Numeric))
    value.map(&.to_f).should eq([1, 2, 3])
  end

  it "reads arrray of nilable numeric" do
    value = PG_DB.query_one("select '{1,null,3}'::numeric[]", &.read(Array(PG::Numeric?)))
    typeof(value).should eq(Array(PG::Numeric?))
    value.map(&.try &.to_f).should eq([1, nil, 3])
  end

  it "raises when reading null in non-null array" do
    expect_raises(PG::RuntimeError) do
      PG_DB.query_one("select '{1,2,3,null}'::integer[]", &.read(Array(Int32)))
    end
  end

  it "reads array of time" do
    values = PG_DB.query_one("select array[to_date('20170103', 'YYYYMMDD')::timestamp]", &.read(Array(Time)))
    typeof(values).should eq(Array(Time))

    values.size.should eq(1)
    values[0].should eq(Time.utc(2017, 1, 3))
  end

  it "reads array of date" do
    values = PG_DB.query_one("select array[to_date('20170103', 'YYYYMMDD')]", &.read(Array(Time)))
    typeof(values).should eq(Array(Time))

    values.size.should eq(1)
    values[0].should eq(Time.utc(2017, 1, 3))
  end

  it "raises when reading incorrect array type" do
    expect_raises(PG::RuntimeError) do
      PG_DB.query_one("select '{1,2,3}'::numeric[]", &.read(Array(Float64)))
    end
  end

  it "errors on negative lower bounds" do
    expect_raises(PG::RuntimeError) do
      PG_DB.query_one("select '[-2:-0]={1,2,3}'::integer[]", &.read)
    end
  end

  test_decode "bool array", "$${t,f,t}$$::bool[]", [true, false, true]
  test_decode "char array", "$${a, b}$$::\"char\"[]", ['a', 'b']
  test_decode "int2 array", "$${1,2}$$::int2[]", [1, 2]
  test_decode "text array", "$${hello, world}$$::text[]", ["hello", "world"]
  test_decode "int8 array", "$${1,2}$$::int8[]", [1, 2]
  test_decode "float4 array", "$${1.1,2.2}$$::float4[]", [1.1_f32, 2.2_f32]
  test_decode "float8 array", "$${1.1,2.2}$$::float8[]", [1.1_f64, 2.2_f64]
  test_decode "date array", "array[to_date('20170103', 'YYYYMMDD')]", [Time.utc(2017, 1, 3)]
  test_decode "numeric array", "array[1::numeric]", [PG::Numeric.new(ndigits: 1, weight: 0, sign: PG::Numeric::Sign::Pos.value, dscale: 0, digits: [1] of Int16)]
  test_decode "time array", "array[to_date('20170103', 'YYYYMMDD')::timestamp]", [Time.utc(2017, 1, 3)]

  it "errors when expecting array returns null" do
    expect_raises(PG::RuntimeError, "unexpected NULL, expecting to read Array(String)") do
      PG_DB.query_one("SELECT NULL", as: Array(String))
    end
  end
end
