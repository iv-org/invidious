require "../spec_helper"

describe PG::Connection, "#initialize" do
  it "raises on bad connections" do
    expect_raises(DB::ConnectionRefused) {
      DB.open("postgres://localhost:5433")
    }
  end
end

describe PG::Connection, "#on_notice" do
  it "sends notices to on_notice" do
    last_notice = nil
    PG_DB.using_connection do |conn|
      conn.on_notice do |notice|
        last_notice = notice
      end
    end

    PG_DB.using_connection do |conn|
      conn.exec_all <<-SQL
        SET client_min_messages TO notice;
        DO language plpgsql $$
        BEGIN
          RAISE NOTICE 'hello, world!';
        END
        $$;
      SQL
    end

    last_notice.should_not eq(nil)
    last_notice.to_s.should eq("NOTICE:  hello, world!\n")
  end
end

describe PG::Connection, "#on_notification" do
  it "does listen/notify within same connection" do
    last_note = nil
    with_db do |db|
      db.using_connection do |conn|
        conn.on_notification { |note| last_note = note }

        conn.exec("listen somechannel")
        conn.exec("notify somechannel, 'do a thing'")
      end
    end

    last_note.not_nil!.channel.should eq("somechannel")
    last_note.not_nil!.payload.should eq("do a thing")
  end
end

describe PG, "#listen" do
  it "opens a special listen only connection" do
    got = false
    ch = Channel(Nil).new
    conn = PG.connect_listen(DB_URL, "foo", "bar") do |n|
      got = true
      ch.send(nil)
    end

    begin
      got.should eq(false)

      PG_DB.exec("notify wrong, 'hello'")
      got.should eq(false)

      PG_DB.exec("notify foo, 'hello'")
      ch.receive
      got.should eq(true)
      got = false

      PG_DB.exec("notify bar, 'hello'")
      ch.receive
      got.should eq(true)
    ensure
      conn.close
    end
  end
end

describe PG, "#read_next_row_start" do
  it "handles reading a notice" do
    with_connection do |db|
      db.exec "SET client_min_messages TO notice"
      db.exec <<-SQL
        CREATE OR REPLACE FUNCTION foo() RETURNS integer AS $$
        BEGIN
          RAISE NOTICE 'foo';
          RAISE NOTICE 'bar';
          RETURN 42;
        END;
        $$ LANGUAGE plpgsql;
        SQL

      received_notices = [] of String
      db.on_notice do |notice|
        received_notices << notice.message
      end
      db.scalar("SELECT foo()").should eq 42
      received_notices.should eq ["foo", "bar"]

      db.exec("DROP FUNCTION foo()")
    end
  end
end
