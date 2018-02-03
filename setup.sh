#!/bin/bash

createdb invidious
createuser kemal
psql invidious < videos.sql
