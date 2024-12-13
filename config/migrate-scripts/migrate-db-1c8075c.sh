#!/bin/sh

[ -z "$POSTGRES_USER" ] && POSTGRES_USER=kemal
[ -z "$POSTGRES_DB" ] && POSTGRES_DB=invidious

psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channel_videos DROP COLUMN live_now CASCADE"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channel_videos DROP COLUMN premiere_timestamp CASCADE"

psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channel_videos ADD COLUMN live_now bool"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz"
