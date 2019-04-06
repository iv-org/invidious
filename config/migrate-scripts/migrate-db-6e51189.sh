#!/bin/sh

psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN live_now bool;"
psql invidious kemal -c "UPDATE channel_videos SET live_now = false;"
