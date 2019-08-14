# crystal-pg
A native, non-blocking Postgres driver for Crystal

[![Build Status](https://circleci.com/gh/will/crystal-pg/tree/master.svg?style=svg)](https://circleci.com/gh/will/crystal-pg/tree/master)


## usage

This driver now uses the `crystal-db` project. Documentation on connecting,
querying, etc, can be found at:

* https://crystal-lang.org/docs/database/
* https://crystal-lang.org/docs/database/connection_pool.html

### shards

Add this to your `shard.yml` and run `shards install`

``` yml
dependencies:
  pg:
    github: will/crystal-pg
```

### Listen/Notify

There are two ways to listen for notifications. For docs on `NOTIFY`, please
read <https://www.postgresql.org/docs/current/static/sql-notify.html>.

1. Any connection can be given a callback to run on notifications. However they
   are only received when other traffic is going on.
2. A special listen-only connection can be established for instant notification
   processing with `PG.connect_listen`.

``` crystal
# see full example in examples/listen_notify.cr
PG.connect_listen("postgres:///", "a", "b") do |n| # connect and  listen on "a" and "b"
  puts "    got: #{n.payload} on #{n.channel}"     # print notifications as they come in
end
```

### Arrays

Crystal-pg supports several popular array types. If you only need a 1
dimensional array, you can cast down to the appropriate Crystal type:

``` crystal
PG_DB.query_one("select ARRAY[1, null, 3]", &.read(Array(Int32?))
# => [1, nil, 3]

PG_DB.query_one("select '{hello, world}'::text[]", &.read(Array(String))
# => ["hello", "world"]
```

## Requirements

Crystal-pg is [regularly tested on](https://circleci.com/gh/will/crystal-pg)
the Postgres versions the [Postgres project itself supports](https://www.postgresql.org/support/versioning/).
Since it uses protocol version 3, older versions probably also work but are not guaranteed.

## Supported Datatypes

- text
- boolean
- int8, int4, int2
- float4, float8
- timestamptz, date, timestamp (but no one should use ts when tstz exists!)
- json and jsonb
- uuid
- bytea
- numeric/decimal (1)
- varchar
- regtype
- geo types: point, box, path, lseg, polygon, circle, line
- array types: int8, int4, int2, float8, float4, bool, text, numeric, timestamptz, date, timestamp

1: A note on numeric: In Postgres this type has arbitrary precision. In this
    driver, it is represented as a `PG::Numeric` which retains all precision, but
    if you need to do any math on it, you will probably need to cast it to a
    float first. If you need true arbitrary precision, you can optionally
    require `pg_ext/big_rational` which adds `#to_big_r`, but requires that you
    have LibGMP installed.

