#!/bin/sh

psql invidious kemal -c "ALTER TABLE channels DROP COLUMN subscribed"
psql invidious kemal -c "ALTER TABLE channels ADD COLUMN subscribed timestamptz"
psql invidious kemal -c "UPDATE channels SET subscribed = '2019-01-01 00:00:00+00'"
