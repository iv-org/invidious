#!/bin/sh

[ -z "$POSTGRES_USER" ] && POSTGRES_USER=kemal
[ -z "$POSTGRES_DB" ] && POSTGRES_DB=invidious

psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE users ADD COLUMN feed_needs_update boolean"
