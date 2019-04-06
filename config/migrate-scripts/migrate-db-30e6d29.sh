#!/bin/sh

psql invidious kemal -c "ALTER TABLE channels ADD COLUMN deleted bool;"
psql invidious kemal -c "UPDATE channels SET deleted = false;"
