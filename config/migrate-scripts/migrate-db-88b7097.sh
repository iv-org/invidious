#!/bin/sh

psql invidious -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz;"
