#!/bin/bash

createdb invidious
createuser kemal
psql invidious < config/sql/channels.sql
psql invidious < config/sql/videos.sql
