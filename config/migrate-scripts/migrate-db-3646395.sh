#!/bin/sh

[ -z "$POSTGRES_USER" ] && POSTGRES_USER=kemal
[ -z "$POSTGRES_DB" ] && POSTGRES_DB=invidious

psql "$POSTGRES_DB" "$POSTGRES_USER" < config/sql/session_ids.sql
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "INSERT INTO session_ids (SELECT unnest(id), email, CURRENT_TIMESTAMP FROM users) ON CONFLICT (id) DO NOTHING"
psql "$POSTGRES_DB" "$POSTGRES_USER" -c "ALTER TABLE users DROP COLUMN id"
