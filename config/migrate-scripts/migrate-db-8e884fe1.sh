#!/bin/sh

psql invidious -c "ALTER TABLE channels DROP COLUMN subscribed"
psql invidious -c "ALTER TABLE channels ADD COLUMN subscribed timestamptz"
