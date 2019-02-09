#!/bin/sh

psql invidious -c "ALTER TABLE channels ADD COLUMN deleted bool;"
psql invidious -c "UPDATE channels SET deleted = false;"
