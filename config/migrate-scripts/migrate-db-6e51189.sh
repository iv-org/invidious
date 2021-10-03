#!/bin/sh

[ -z "$POSTGRES_USER" ] && POSTGRES_USER=kemal
[ -z "$POSTGRES_DB" ] && POSTGRES_DB=invidious

psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channel_videos ADD COLUMN live_now bool;"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "UPDATE channel_videos SET live_now = false;"
