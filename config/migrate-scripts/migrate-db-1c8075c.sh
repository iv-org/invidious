#!/bin/sh

psql invidious kemal -c "ALTER TABLE channel_videos DROP COLUMN live_now CASCADE"
psql invidious kemal -c "ALTER TABLE channel_videos DROP COLUMN premiere_timestamp CASCADE"

psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN live_now bool"
psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz"
