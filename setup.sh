#!/bin/bash

createdb invidious
#createuser kemal
psql -c "CREATE USER kemal WITH PASSWORD 'kemal';"
psql invidious < config/sql/channels.sql
psql invidious < config/sql/videos.sql
psql invidious < config/sql/channel_videos.sql
psql invidious < config/sql/users.sql
psql invidious < config/sql/nonces.sql
