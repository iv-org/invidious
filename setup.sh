#!/bin/bash

createdb invidious
psql invidious < videos.sql
