#!/bin/sh

psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz;"
