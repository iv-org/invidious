#!/bin/sh

psql invidious -c "ALTER TABLE channel_videos DROP COLUMN live_now CASCADE"
psql invidious -c "ALTER TABLE channel_videos DROP COLUMN premiere_timestamp CASCADE"

psql invidious -c "ALTER TABLE channel_videos ADD COLUMN live_now bool"
psql invidious -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz"
