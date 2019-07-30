#!/bin/sh

psql invidious kemal -c "ALTER TABLE users ADD COLUMN feed_needs_update boolean"
