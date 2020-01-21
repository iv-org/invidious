#!/usr/bin/env bash

CMD="$@"
if [ ! -f /var/lib/postgresql/data/setupFinished ]; then
    echo "### first run - setting up invidious database"
    /usr/local/bin/docker-entrypoint.sh postgres &
    sleep 10
    until runuser -l postgres -c 'pg_isready' 2>/dev/null; do
        >&2 echo "### Postgres is unavailable - waiting"
        sleep 5
    done
    >&2 echo "### importing table schemas"
    su postgres -c 'createdb invidious'
    su postgres -c 'psql -c "CREATE USER kemal WITH PASSWORD '"'kemal'"'"'
    su postgres -c 'psql invidious kemal < config/sql/privacy.sql'
    su postgres -c 'psql invidious kemal < config/sql/channels.sql'
    su postgres -c 'psql invidious kemal < config/sql/videos.sql'
    su postgres -c 'psql invidious kemal < config/sql/channel_videos.sql'
    su postgres -c 'psql invidious kemal < config/sql/users.sql'
    su postgres -c 'psql invidious kemal < config/sql/session_ids.sql'
    su postgres -c 'psql invidious kemal < config/sql/nonces.sql'
    su postgres -c 'psql invidious kemal < config/sql/annotations.sql'
    su postgres -c 'psql invidious kemal < config/sql/playlists.sql'
    su postgres -c 'psql invidious kemal < config/sql/playlist_videos.sql'
    touch /var/lib/postgresql/data/setupFinished
    echo "### invidious database setup finished"
    exit
fi

echo "running postgres /usr/local/bin/docker-entrypoint.sh $CMD"
exec /usr/local/bin/docker-entrypoint.sh $CMD
