# Invidious

[![Build Status](https://travis-ci.org/iv-org/invidious.svg?branch=master)](https://travis-ci.org/github/iv-org/invidious)

## Invidious is an alternative front-end to YouTube

## Invidious Instances

[Public Invidious instances are listed here.](https://github.com/iv-org/invidious/wiki/Invidious-Instances)

## Invidious Features

- [Copylefted libre software](https://github.com/iv-org/invidious) (AGPLv3+ licensed)
- Audio-only mode (and no need to keep window open on mobile)
- Lightweight (the homepage is ~4 KB compressed)
- Tools for managing subscriptions:
  - Only show unseen videos
  - Only show latest (or latest unseen) video from each channel
  - Delivers notifications from all subscribed channels
  - Automatically redirect homepage to feed
  - Import subscriptions from YouTube
- Dark mode
- Embed support
- Set default player options (speed, quality, autoplay, loop)
- Support for Reddit comments in place of YouTube comments
- Import/Export subscriptions, watch history, preferences
- [Developer API](https://github.com/iv-org/invidious/wiki/API)
- Does not use any of the official YouTube APIs
- Does not require JavaScript to play videos
- No need to create a Google account to save subscriptions
- No ads
- No CoC
- No CLA

Liberapay: https://liberapay.com/iv-org/




## Screenshots

| Player                                                                                                                  | Preferences                                                                                                             | Subscriptions                                                                                                               |
| ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| [<img src="screenshots/01_player.png?raw=true" height="140" width="280">](screenshots/01_player.png?raw=true)           | [<img src="screenshots/02_preferences.png?raw=true" height="140" width="280">](screenshots/02_preferences.png?raw=true) | [<img src="screenshots/03_subscriptions.png?raw=true" height="140" width="280">](screenshots/03_subscriptions.png?raw=true) |
| [<img src="screenshots/04_description.png?raw=true" height="140" width="280">](screenshots/04_description.png?raw=true) | [<img src="screenshots/05_preferences.png?raw=true" height="140" width="280">](screenshots/05_preferences.png?raw=true) | [<img src="screenshots/06_subscriptions.png?raw=true" height="140" width="280">](screenshots/06_subscriptions.png?raw=true) |

## Installation

To manually compile invidious you need at least 2GB of RAM. If you have less you can setup SWAP to have a combined amount of 2 GB or use Docker instead.

After installation take a look at the [Post-install steps](#post-install).

### Automated:

[Invidious-Updater](https://github.com/tmiland/Invidious-Updater) is a self-contained script that can automatically install and update Invidious.

### Docker:

#### Build and start cluster:

```bash
$ docker-compose up
```

Then visit `localhost:3000` in your browser.

#### Rebuild cluster:

```bash
$ docker-compose build
```

#### Delete data and rebuild:

```bash
$ docker volume rm invidious_postgresdata
$ docker-compose build
```

### Manually:

### Linux:

#### Install the dependencies

```bash
# Arch Linux
$ sudo pacman -S base-devel shards crystal librsvg postgresql

# Ubuntu or Debian
# First you have to add the repository to your APT configuration. For easy setup just run in your command line:
$ curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
# That will add the signing key and the repository configuration. If you prefer to do it manually, execute the following commands:
$ curl -sL "https://keybase.io/crystal/pgp_keys.asc" | sudo apt-key add -
$ echo "deb https://dist.crystal-lang.org/apt crystal main" | sudo tee /etc/apt/sources.list.d/crystal.list
$ sudo apt-get update
$ sudo apt install crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev postgresql librsvg2-bin libsqlite3-dev zlib1g-dev
```

#### Add an Invidious user and clone the repository

```bash
$ useradd -m invidious
$ sudo -i -u invidious
$ git clone https://github.com/iv-org/invidious
$ exit
```

#### Set up PostgresSQL

```bash
$ sudo systemctl enable postgresql
$ sudo systemctl start postgresql
$ sudo -i -u postgres
$ psql -c "CREATE USER kemal WITH PASSWORD 'kemal';" # Change 'kemal' here to a stronger password, and update `password` in config/config.yml
$ createdb -O kemal invidious
$ psql invidious kemal < /home/invidious/invidious/config/sql/channels.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/videos.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/channel_videos.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/users.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/session_ids.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/nonces.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/annotations.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/playlists.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/playlist_videos.sql
$ exit
```

#### Set up Invidious

```bash
$ sudo -i -u invidious
$ cd invidious
$ shards update && shards install
$ crystal build src/invidious.cr --release
# test compiled binary
$ ./invidious # stop with ctrl c
$ exit
```

#### systemd service

```bash
$ sudo cp /home/invidious/invidious/invidious.service /etc/systemd/system/invidious.service
$ sudo systemctl enable invidious.service
$ sudo systemctl start invidious.service
```

#### Logrotate

```bash
$ sudo echo "/home/invidious/invidious/invidious.log {
rotate 4
weekly
notifempty
missingok
compress
minsize 1048576
}" | tee /etc/logrotate.d/invidious.logrotate
$ sudo chmod 0644 /etc/logrotate.d/invidious.logrotate
```

### MacOS:

```bash
# Install dependencies
$ brew update
$ brew install shards crystal postgres imagemagick librsvg

# Clone the repository and set up a PostgreSQL database
$ git clone https://github.com/iv-org/invidious
$ cd invidious
$ brew services start postgresql
$ psql -c "CREATE ROLE kemal WITH PASSWORD 'kemal';" # Change 'kemal' here to a stronger password, and update `password` in config/config.yml
$ createdb -O kemal invidious
$ psql invidious kemal < config/sql/channels.sql
$ psql invidious kemal < config/sql/videos.sql
$ psql invidious kemal < config/sql/channel_videos.sql
$ psql invidious kemal < config/sql/users.sql
$ psql invidious kemal < config/sql/session_ids.sql
$ psql invidious kemal < config/sql/nonces.sql
$ psql invidious kemal < config/sql/annotations.sql
$ psql invidious kemal < config/sql/privacy.sql
$ psql invidious kemal < config/sql/playlists.sql
$ psql invidious kemal < config/sql/playlist_videos.sql

# Set up Invidious
$ shards update && shards install
$ crystal build src/invidious.cr --release
```

## Post-install:

Detailled configuration available in the [configuration guide](https://github.com/iv-org/invidious/wiki/Configuration).

If you use a reverse proxy, you **must** to configure invidious to properly serve request through it:

`https_only: true` : if your are serving your instance via https, set it to true

`domain: domain.ext`: if you have are serving your instance via a domain name, set it here

`external_port: 443`: if your are serving your instance via https, set it to 443

## Update Invidious

Instructions are available in the [updating guide](https://github.com/iv-org/invidious/wiki/Updating).

## Usage:

```bash
$ ./invidious -h
Usage: invidious [arguments]
    -b HOST, --bind HOST             Host to bind (defaults to 0.0.0.0)
    -p PORT, --port PORT             Port to listen for connections (defaults to 3000)
    -s, --ssl                        Enables SSL
    --ssl-key-file FILE              SSL key file
    --ssl-cert-file FILE             SSL certificate file
    -h, --help                       Shows this help
    -c THREADS, --channel-threads=THREADS
                                     Number of threads for refreshing channels (default: 1)
    -f THREADS, --feed-threads=THREADS
                                     Number of threads for refreshing feeds (default: 1)
    -o OUTPUT, --output=OUTPUT       Redirect output (default: STDOUT)
    -v, --version                    Print version
```

Or for development:

```bash
$ curl -fsSLo- https://raw.githubusercontent.com/samueleaton/sentry/master/install.cr | crystal eval
$ ./sentry
🤖  Your SentryBot is vigilant. beep-boop...
```

## Documentation

[Documentation](https://github.com/iv-org/invidious/wiki) can be found in the wiki.

## Extensions

[Extensions](https://github.com/iv-org/invidious/wiki/Extensions) can be found in the wiki, as well as documentation for integrating it into other projects.

## Made with Invidious

- [FreeTube](https://github.com/FreeTubeApp/FreeTube): A libre software YouTube app for privacy.
- [CloudTube](https://cadence.moe/cloudtube/subscriptions): A JavaScript-rich alternate YouTube player
- [PeerTubeify](https://gitlab.com/Cha_deL/peertubeify): On YouTube, displays a link to the same video on PeerTube, if it exists.
- [MusicPiped](https://github.com/deep-gaurav/MusicPiped): A material design music player that streams music from YouTube.
- [LapisTube](https://github.com/blubbll/lapis-tube): A fancy and advanced (experimental) YouTube front-end. Combined streams & custom YT features.
- [HoloPlay](https://github.com/stephane-r/HoloPlay): Funny Android application connecting on Invidious API's with search, playlists and favoris.

## Contributing

1.  Fork it ( https://github.com/iv-org/invidious/fork )
2.  Create your feature branch (git checkout -b my-new-feature)
3.  Commit your changes (git commit -am 'Add some feature')
4.  Push to the branch (git push origin my-new-feature)
5.  Create a new pull request

#### Translation

- Log in with an account you have elsewhere, or register an account and start translating at [Hosted Weblate](https://hosted.weblate.org/projects/invidious/).

## Contact

Feel free to send an e-mail to omarroth@protonmail.com or join our [Matrix server](https://riot.im/app/#/room/#invidious:matrix.org), or #invidious on freenode.

You can also read the release notes on the [page of releases](https://github.com/iv-org/invidious/releases) [CHANGELOG.md](https://github.com/iv-org/invidious/blob/master/CHANGELOG.md) included in the repository.
