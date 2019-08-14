require "./spec_helper"

class DummyException < Exception
end

describe DB::ResultSet do
  it "should enumerate records using each" do
    nums = [] of Int32

    with_dummy do |db|
      db.query "3,4 1,2" do |rs|
        rs.each do
          nums << rs.read(Int32)
          nums << rs.read(Int32)
        end
      end
    end

    nums.should eq([3, 4, 1, 2])
  end

  it "should close ResultSet after query" do
    with_dummy do |db|
      the_rs = uninitialized DB::ResultSet
      db.query "3,4 1,2" do |rs|
        the_rs = rs
      end
      the_rs.closed?.should be_true
    end
  end

  it "should close ResultSet after query even with exception" do
    with_dummy do |db|
      the_rs = uninitialized DB::ResultSet
      begin
        db.query "3,4 1,2" do |rs|
          the_rs = rs
          raise DummyException.new
        end
      rescue DummyException
      end
      the_rs.closed?.should be_true
    end
  end

  it "should enumerate columns" do
    cols = [] of String

    with_dummy do |db|
      db.query "3,4 1,2" do |rs|
        rs.each_column do |col|
          cols << col
        end
      end
    end

    cols.should eq(["c0", "c1"])
  end

  it "gets all column names" do
    with_dummy do |db|
      db.query "1,2" do |rs|
        rs.column_names.should eq(%w(c0 c1))
      end
    end
  end
end
