#!/bin/sh

[ -z "$POSTGRES_USER" ] && POSTGRES_USER=kemal
[ -z "$POSTGRES_DB" ] && POSTGRES_DB=invidious

psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channels DROP COLUMN subscribed"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channels ADD COLUMN subscribed timestamptz"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "UPDATE channels SET subscribed = '2019-01-01 00:00:00+00'"
