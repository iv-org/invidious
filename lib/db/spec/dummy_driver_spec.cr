require "./spec_helper"

describe DummyDriver do
  it "with_dummy executes the block with a database" do
    with_witness do |w|
      with_dummy do |db|
        w.check
        db.should be_a(DB::Database)
      end
    end
  end

  describe DummyDriver::DummyStatement do
    it "should enumerate split rows by spaces" do
      with_dummy do |db|
        rs = db.query("")
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b")
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b 1,2")
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close

        rs = db.query("a,b 1,2 c,d")
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_true
        rs.move_next.should be_false
        rs.close
      end
    end

    # it "should query with block should executes always" do
    #   with_witness do |w|
    #     with_dummy do |db|
    #       db.query "a" do |rs|
    #         w.check
    #       end
    #     end
    #   end
    # end
    #
    # it "should query with block should executes always" do
    #   with_witness do |w|
    #     with_dummy do |db|
    #       db.query "lorem ipsum" do |rs|
    #         w.check
    #       end
    #     end
    #   end
    # end

    it "should enumerate string fields" do
      with_dummy do |db|
        db.query "a,b 1,2" do |rs|
          rs.move_next
          rs.read(String).should eq("a")
          rs.read(String).should eq("b")
          rs.move_next
          rs.read(String).should eq("1")
          rs.read(String).should eq("2")
        end
      end
    end

    it "should enumerate nil fields" do
      with_dummy do |db|
        db.query "a,NULL 1,NULL" do |rs|
          rs.move_next
          rs.read(String).should eq("a")
          rs.read(String | Nil).should be_nil
          rs.move_next
          rs.read(Int64).should eq(1)
          rs.read(Int64 | Nil).should be_nil
        end
      end
    end

    it "should enumerate int64 fields" do
      with_dummy do |db|
        db.query "3,4 1,2" do |rs|
          rs.move_next
          rs.read(Int64).should eq(3i64)
          rs.read(Int64).should eq(4i64)
          rs.move_next
          rs.read(Int64).should eq(1i64)
          rs.read(Int64).should eq(2i64)
        end
      end
    end

    it "should enumerate nillable int64 fields" do
      with_dummy do |db|
        db.query "3,4 1,NULL" do |rs|
          rs.move_next
          rs.read(Int64 | Nil).should eq(3i64)
          rs.read(Int64 | Nil).should eq(4i64)
          rs.move_next
          rs.read(Int64 | Nil).should eq(1i64)
          rs.read(Int64 | Nil).should be_nil
        end
      end
    end

    describe "query one" do
      it "queries" do
        with_dummy do |db|
          db.query_one("3,4", &.read(Int64, Int64)).should eq({3i64, 4i64})
        end
      end

      it "raises if more than one row" do
        with_dummy do |db|
          expect_raises(DB::Error, "more than one row") do
            db.query_one("3,4 5,6") { }
          end
        end
      end

      it "raises if no rows" do
        with_dummy do |db|
          expect_raises(DB::Error, "no rows") do
            db.query_one("") { }
          end
        end
      end

      it "with as" do
        with_dummy do |db|
          db.query_one("3,4", as: {Int64, Int64}).should eq({3i64, 4i64})
        end
      end

      it "with a named tuple" do
        with_dummy do |db|
          db.query_one("3,4", as: {a: Int64, b: Int64}).should eq({a: 3i64, b: 4i64})
        end
      end

      it "with as, just one" do
        with_dummy do |db|
          db.query_one("3", as: Int64).should eq(3i64)
        end
      end
    end

    describe "query one?" do
      it "queries" do
        with_dummy do |db|
          value = db.query_one?("3,4", &.read(Int64, Int64))
          value.should eq({3i64, 4i64})
          value.should be_a(Tuple(Int64, Int64)?)
        end
      end

      it "raises if more than one row" do
        with_dummy do |db|
          expect_raises(DB::Error, "more than one row") do
            db.query_one?("3,4 5,6") { }
          end
        end
      end

      it "returns nil if no rows" do
        with_dummy do |db|
          db.query_one?("") { fail("block shouldn't be invoked") }.should be_nil
        end
      end

      it "with as" do
        with_dummy do |db|
          value = db.query_one?("3,4", as: {Int64, Int64})
          value.should be_a(Tuple(Int64, Int64)?)
          value.should eq({3i64, 4i64})
        end
      end

      it "with as" do
        with_dummy do |db|
          value = db.query_one?("3,4", as: {a: Int64, b: Int64})
          value.should be_a(NamedTuple(a: Int64, b: Int64)?)
          value.should eq({a: 3i64, b: 4i64})
        end
      end

      it "with as, no rows" do
        with_dummy do |db|
          value = db.query_one?("", as: {a: Int64, b: Int64})
          value.should be_nil
        end
      end

      it "with as, just one" do
        with_dummy do |db|
          value = db.query_one?("3", as: Int64)
          value.should be_a(Int64?)
          value.should eq(3i64)
        end
      end
    end

    describe "query all" do
      it "queries" do
        with_dummy do |db|
          ary = db.query_all "3,4 1,2", &.read(Int64, Int64)
          ary.should eq([{3, 4}, {1, 2}])
        end
      end

      it "queries with as" do
        with_dummy do |db|
          ary = db.query_all "3,4 1,2", as: {Int64, Int64}
          ary.should eq([{3, 4}, {1, 2}])
        end
      end

      it "queries with a named tuple" do
        with_dummy do |db|
          ary = db.query_all "3,4 1,2", as: {a: Int64, b: Int64}
          ary.should eq([{a: 3, b: 4}, {a: 1, b: 2}])
        end
      end

      it "queries with as, just one" do
        with_dummy do |db|
          ary = db.query_all "3 1", as: Int64
          ary.should eq([3, 1])
        end
      end
    end

    describe "query each" do
      it "queries" do
        with_dummy do |db|
          i = 0
          db.query_each "3,4 1,2" do |rs|
            case i
            when 0
              rs.read(Int64, Int64).should eq({3i64, 4i64})
            when 1
              rs.read(Int64, Int64).should eq({1i64, 2i64})
            end
            i += 1
          end
          i.should eq(2)
        end
      end
    end

    it "reads multiple values" do
      with_dummy do |db|
        db.query "3,4 1,2" do |rs|
          rs.move_next
          rs.read(Int64, Int64).should eq({3i64, 4i64})
          rs.move_next
          rs.read(Int64, Int64).should eq({1i64, 2i64})
        end
      end
    end

    it "should enumerate blob fields" do
      with_dummy do |db|
        db.query("az,AZ") do |rs|
          rs.move_next
          ary = [97u8, 122u8]
          rs.read(Bytes).should eq(Bytes.new(ary.to_unsafe, ary.size))
          ary = [65u8, 90u8]
          rs.read(Bytes).should eq(Bytes.new(ary.to_unsafe, ary.size))
        end
      end
    end

    it "should get Nil scalars" do
      with_dummy do |db|
        db.scalar("NULL").should be_nil
      end
    end

    it "should raise executing raise query" do
      with_dummy do |db|
        expect_raises DB::Error do
          db.exec "raise"
        end
      end
    end

    {% for value in [1, 1_i64, "hello", 1.5, 1.5_f32] %}
      it "should set positional arguments for {{value.id}}" do
        with_dummy do |db|
          db.scalar("?", {{value}}).should eq({{value}})
        end
      end
    {% end %}

    it "executes and selects blob" do
      with_dummy do |db|
        ary = UInt8[0x53, 0x51, 0x4C]
        slice = Bytes.new(ary.to_unsafe, ary.size)
        (db.scalar("?", slice).as(Bytes)).to_a.should eq(ary)
      end
    end
  end
end
