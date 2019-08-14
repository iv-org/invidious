require "./spec_helper"
require "base64"

class SimpleMapping
  DB.mapping({
    c0: Int32,
    c1: String,
  })
end

class NonStrictMapping
  DB.mapping({
    c1: Int32,
    c2: String,
  }, strict: false)
end

class MappingWithDefaults
  DB.mapping({
    c0: {type: Int32, default: 10},
    c1: {type: String, default: "c"},
  })
end

class MappingWithNilables
  DB.mapping({
    c0: {type: Int32, nilable: true, default: 10},
    c1: {type: String, nilable: true},
  })
end

class MappingWithNilTypes
  DB.mapping({
    c0: {type: Int32?, default: 10},
    c1: String?,
  })
end

class MappingWithNilUnionTypes
  DB.mapping({
    c0: {type: Int32 | Nil, default: 10},
    c1: Nil | String,
  })
end

class MappingWithKeys
  DB.mapping({
    foo: {type: Int32, key: "c0"},
    bar: {type: String, key: "c1"},
  })
end

class MappingWithConverter
  module Base64Converter
    def self.from_rs(rs)
      Base64.decode(rs.read(String))
    end
  end

  DB.mapping({
    c0: {type: Slice(UInt8), converter: MappingWithConverter::Base64Converter},
    c1: {type: String},
  })
end

macro from_dummy(query, type)
  with_dummy do |db|
    rs = db.query({{ query }})
    rs.move_next
    %obj = {{ type }}.new(rs)
    rs.close
    %obj
  end
end

macro expect_mapping(query, t, values)
  %obj = from_dummy({{ query }}, {{ t }})
  %obj.should be_a({{ t }})
  {% for key, value in values %}
    %obj.{{key.id}}.should eq({{value}})
  {% end %}
end

describe "DB.mapping" do
  it "should initialize a simple mapping" do
    expect_mapping("1,a", SimpleMapping, {c0: 1, c1: "a"})
  end

  it "should fail to initialize a simple mapping if types do not match" do
    expect_raises ArgumentError do
      from_dummy("b,a", SimpleMapping)
    end
  end

  it "should fail to initialize a simple mapping if there is a missing column" do
    expect_raises DB::MappingException do
      from_dummy("1", SimpleMapping)
    end
  end

  it "should fail to initialize a simple mapping if there is an unexpected column" do
    expect_raises DB::MappingException do
      from_dummy("1,a,b", SimpleMapping)
    end
  end

  it "should initialize a non-strict mapping if there is an unexpected column" do
    expect_mapping("1,2,a,b", NonStrictMapping, {c1: 2, c2: "a"})
  end

  it "should initialize a mapping with default values" do
    expect_mapping("1,a", MappingWithDefaults, {c0: 1, c1: "a"})
  end

  it "should initialize a mapping using default values if columns are missing" do
    expect_mapping("1", MappingWithDefaults, {c0: 1, c1: "c"})
  end

  it "should initialize a mapping using default values if values are nil and types are non nilable" do
    expect_mapping("1,NULL", MappingWithDefaults, {c0: 1, c1: "c"})
  end

  it "should initialize a mapping with nilable set if columns are missing" do
    expect_mapping("1", MappingWithNilables, {c0: 1, c1: nil})
  end

  it "should initialize a mapping with nilable set ignoring default value if NULL" do
    expect_mapping("NULL,a", MappingWithNilables, {c0: nil, c1: "a"})
  end

  it "should initialize a mapping with nilable types if columns are missing" do
    expect_mapping("1", MappingWithNilTypes, {c0: 1, c1: nil})
    expect_mapping("1", MappingWithNilUnionTypes, {c0: 1, c1: nil})
  end

  it "should initialize a mapping with nilable types ignoring default value if NULL" do
    expect_mapping("NULL,a", MappingWithNilTypes, {c0: nil, c1: "a"})
    expect_mapping("NULL,a", MappingWithNilUnionTypes, {c0: nil, c1: "a"})
  end

  it "should initialize a mapping with different keys" do
    expect_mapping("1,a", MappingWithKeys, {foo: 1, bar: "a"})
  end

  it "should initialize a mapping with a value converter" do
    expect_mapping("Zm9v,a", MappingWithConverter, {c0: "foo".to_slice, c1: "a"})
  end

  it "should initialize multiple instances from a single resultset" do
    with_dummy do |db|
      db.query("1,a 2,b") do |rs|
        objs = SimpleMapping.from_rs(rs)
        objs.size.should eq(2)
        objs[0].c0.should eq(1)
        objs[0].c1.should eq("a")
        objs[1].c0.should eq(2)
        objs[1].c1.should eq("b")
      end
    end
  end

  it "Class.from_rs should close resultset" do
    with_dummy do |db|
      rs = db.query("1,a 2,b")
      objs = SimpleMapping.from_rs(rs)
      rs.closed?.should be_true

      objs.size.should eq(2)
      objs[0].c0.should eq(1)
      objs[0].c1.should eq("a")
      objs[1].c0.should eq(2)
      objs[1].c1.should eq("b")
    end
  end

  it "should initialize from a query_one" do
    with_dummy do |db|
      obj = db.query_one "1,a", as: SimpleMapping
      obj.c0.should eq(1)
      obj.c1.should eq("a")
    end
  end

  it "should initialize from a query_all" do
    with_dummy do |db|
      objs = db.query_all "1,a 2,b", as: SimpleMapping
      objs.size.should eq(2)
      objs[0].c0.should eq(1)
      objs[0].c1.should eq("a")
      objs[1].c0.should eq(2)
      objs[1].c1.should eq("b")
    end
  end
end
