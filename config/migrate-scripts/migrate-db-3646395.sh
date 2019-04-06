#!/bin/sh

psql invidious < config/sql/session_ids.sql
psql invidious kemal -c "INSERT INTO session_ids (SELECT unnest(id), email, CURRENT_TIMESTAMP FROM users) ON CONFLICT (id) DO NOTHING"
psql invidious kemal -c "ALTER TABLE users DROP COLUMN id"
