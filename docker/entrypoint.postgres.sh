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
    su postgres -c 'psql invidious < config/sql/channels.sql'
    su postgres -c 'psql invidious < config/sql/videos.sql'
    su postgres -c 'psql invidious < config/sql/channel_videos.sql'
    su postgres -c 'psql invidious < config/sql/users.sql'
    su postgres -c 'psql invidious < config/sql/nonces.sql'
    touch /var/lib/postgresql/data/setupFinished
    echo "### invidious database setup finished"
    exit
fi

echo "running postgres /usr/local/bin/docker-entrypoint.sh $CMD"
exec /usr/local/bin/docker-entrypoint.sh $CMD
