#!/bin/sh

# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

psql invidious kemal -c "ALTER TABLE channels DROP COLUMN subscribed"
psql invidious kemal -c "ALTER TABLE channels ADD COLUMN subscribed timestamptz"
psql invidious kemal -c "UPDATE channels SET subscribed = '2019-01-01 00:00:00+00'"
