# crystal-sqlite3 [![Build Status](https://travis-ci.org/crystal-lang/crystal-sqlite3.svg?branch=master)](https://travis-ci.org/crystal-lang/crystal-sqlite3)

SQLite3 bindings for [Crystal](http://crystal-lang.org/).

Check [crystal-db](https://github.com/crystal-lang/crystal-db) for general db driver documentation. crystal-sqlite3 driver is registered under `sqlite3://` uri.

## Installation

Add this to your application's `shard.yml`:

```yml
dependencies:
  sqlite3:
    github: crystal-lang/crystal-sqlite3
```

### Usage

```crystal
require "sqlite3"

DB.open "sqlite3://./data.db" do |db|
  db.exec "create table contacts (name text, age integer)"
  db.exec "insert into contacts values (?, ?)", "John Doe", 30

  args = [] of DB::Any
  args << "Sarah"
  args << 33
  db.exec "insert into contacts values (?, ?)", args

  puts "max age:"
  puts db.scalar "select max(age) from contacts" # => 33

  puts "contacts:"
  db.query "select name, age from contacts order by age desc" do |rs|
    puts "#{rs.column_name(0)} (#{rs.column_name(1)})"
    # => name (age)
    rs.each do
      puts "#{rs.read(String)} (#{rs.read(Int32)})"
      # => Sarah (33)
      # => John Doe (30)
    end
  end
end
```

### DB::Any

* `Time` is implemented as `TEXT` column using `SQLite3::DATE_FORMAT` format.
* `Bool` is implemented as `INT` column mapping `0`/`1` values.
