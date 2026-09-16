#!/bin/bash
set -eou pipefail

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" -c "CREATE SCHEMA IF NOT EXISTS backup"

psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/channels.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/videos.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/channel_videos.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/users.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/session_ids.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/nonces.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/annotations.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/playlists.sql
psql --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" < config/sql/playlist_videos.sql
