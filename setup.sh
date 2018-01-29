#!/bin/bash

dropdb invidious
createdb invidious

psql invidious < videos.sql
