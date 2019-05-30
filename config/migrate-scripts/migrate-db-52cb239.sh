#!/bin/sh

psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN views bigint;"
