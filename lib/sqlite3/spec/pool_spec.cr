require "./spec_helper"

describe DB::Pool do
  it "should write from multiple connections" do
    channel = Channel(Nil).new
    fibers = 5
    max_n = 50
    with_db "#{DB_FILENAME}?max_pool_size=#{fibers}" do |db|
      db.exec "create table numbers (n integer, fiber integer)"

      fibers.times do |f|
        spawn do
          (1..max_n).each do |n|
            db.exec "insert into numbers (n, fiber) values (?, ?)", n, f
            sleep 0.01
          end
          channel.send nil
        end
      end

      fibers.times { channel.receive }

      # all numbers were inserted
      s = fibers * max_n * (max_n + 1) // 2
      db.scalar("select sum(n) from numbers").should eq(s)

      # numbers were not inserted one fiber at a time
      rows = db.query_all "select n, fiber from numbers", as: {Int32, Int32}
      rows.map(&.[1]).should_not eq(rows.map(&.[1]).sort)
    end
  end
end
