#!/bin/sh

psql invidious kemal -c "ALTER TABLE channels ADD COLUMN subscribed bool;"
psql invidious kemal -c "UPDATE channels SET subscribed = false;"
