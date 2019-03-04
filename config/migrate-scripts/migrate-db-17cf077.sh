#!/bin/sh

psql invidious -c "ALTER TABLE channels ADD COLUMN subscribed bool;"
psql invidious -c "UPDATE channels SET subscribed = false;"
