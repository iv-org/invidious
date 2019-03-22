#!/bin/sh

psql invidious -c "ALTER TABLE channel_videos ADD COLUMN live_now bool;"
psql invidious -c "UPDATE channel_videos SET live_now = false;"