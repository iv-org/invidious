#!/bin/bash

createdb invidious
createuser kemal
psql invidious < config/sql/channels.sql
psql invidious < config/sql/videos.sql
psql invidious < config/sql/channel_videos.sql
psql invidious < config/sql/users.sql
