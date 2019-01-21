#!/bin/bash

dbpass=$(openssl rand -hex 20)

createdb invidious
# create database user and import templates
psql -c "CREATE USER kemal WITH PASSWORD '$dbpass';"
psql invidious < config/sql/channels.sql
psql invidious < config/sql/videos.sql
psql invidious < config/sql/channel_videos.sql
psql invidious < config/sql/users.sql
psql invidious < config/sql/nonces.sql

# change password in config file
sed -i "s/replacethispassword/$dbpass/g" config/config.yml
