#!/bin/sh

# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

psql invidious kemal < config/sql/session_ids.sql
psql invidious kemal -c "INSERT INTO session_ids (SELECT unnest(id), email, CURRENT_TIMESTAMP FROM users) ON CONFLICT (id) DO NOTHING"
psql invidious kemal -c "ALTER TABLE users DROP COLUMN id"
