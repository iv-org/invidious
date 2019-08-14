require "./spec_helper"

private def dump(source, target)
  source.using_connection do |conn|
    conn = conn.as(SQLite3::Connection)
    target.using_connection do |backup_conn|
      backup_conn = backup_conn.as(SQLite3::Connection)
      conn.dump(backup_conn)
    end
  end
end

describe Connection do
  it "opens a database and then backs it up to another db" do
    with_db do |db|
      with_db("./test2.db") do |backup_db|
        db.exec "create table person (name text, age integer)"
        db.exec "insert into person values (\"foo\", 10)"

        dump db, backup_db

        backup_name = backup_db.scalar "select name from person"
        backup_age = backup_db.scalar "select age from person"
        source_name = db.scalar "select name from person"
        source_age = db.scalar "select age from person"

        {backup_name, backup_age}.should eq({source_name, source_age})
      end
    end
  end

  it "opens a database, inserts records, dumps to an in-memory db, insers some more, then dumps to the source" do
    with_db do |db|
      with_mem_db do |in_memory_db|
        db.exec "create table person (name text, age integer)"
        db.exec "insert into person values (\"foo\", 10)"
        dump db, in_memory_db

        in_memory_db.scalar("select count(*) from person").should eq(1)
        in_memory_db.exec "insert into person values (\"bar\", 22)"
        dump in_memory_db, db

        db.scalar("select count(*) from person").should eq(2)
      end
    end
  end

  it "opens a database, inserts records (>1024K), and dumps to an in-memory db" do
    with_db do |db|
      with_mem_db do |in_memory_db|
        db.exec "create table person (name text, age integer)"
        db.transaction do |tx|
          100_000.times { tx.connection.exec "insert into person values (\"foo\", 10)" }
        end
        dump db, in_memory_db
        in_memory_db.scalar("select count(*) from person").should eq(100_000)
      end
    end
  end

  it "opens a connection without the pool" do
    with_cnn do |cnn|
      cnn.should be_a(SQLite3::Connection)

      cnn.exec "create table person (name text, age integer)"
      cnn.exec "insert into person values (\"foo\", 10)"

      cnn.scalar("select count(*) from person").should eq(1)
    end
  end
end
