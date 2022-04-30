#!/bin/sh

#
# Parameters
#

interactive=true

if [ "$1" == "--no-interactive" ]; then
	interactive=false
fi

#
# Enable and start Postgres
#

sudo systemctl start postgresql.service
sudo systemctl enable postgresql.service

#
# Create databse and user
#

if [ "$interactive" == "true" ]; then
	sudo -u postgres -- createuser -P kemal
	sudo -u postgres -- createdb -O kemal invidious
else
	# Generate a DB password
	if [ -z "$POSTGRES_PASS" ]; then
		echo "Generating database password"
		POSTGRES_PASS=$(tr -dc 'A-Za-z0-9.;!?{[()]}\\/' < /dev/urandom | head -c16)
	fi

	# hostname:port:database:username:password
	echo "Writing .pgpass"
	echo "127.0.0.1:*:invidious:kemal:${POSTGRES_PASS}" > "$HOME/.pgpass"

	sudo -u postgres -- psql -c "CREATE USER kemal WITH PASSWORD '$POSTGRES_PASS';"
	sudo -u postgres -- psql -c "CREATE DATABASE invidious WITH OWNER kemal;"
	sudo -u postgres -- psql -c "GRANT ALL ON DATABASE invidious TO kemal;"
fi
