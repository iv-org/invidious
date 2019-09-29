#!/bin/sh

# SPDX-FileCopyrightText: 2019 Omar Roth <omarroth@protonmail.com>
#
# SPDX-License-Identifier: AGPL-3.0-or-later

psql invidious kemal -c "ALTER TABLE channel_videos DROP COLUMN live_now CASCADE"
psql invidious kemal -c "ALTER TABLE channel_videos DROP COLUMN premiere_timestamp CASCADE"

psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN live_now bool"
psql invidious kemal -c "ALTER TABLE channel_videos ADD COLUMN premiere_timestamp timestamptz"
