# Invidious

## Invidious is an alternative front-end to YouTube

- Audio-only mode (and no need to keep window open on mobile)
- [Open-source](https://github.com/omarroth/invidious) (AGPLv3 licensed)
- No ads
- No need to create a Google account to save subscriptions
- Lightweight (homepage is ~4 KB compressed)
- Tools for managing subscriptions:
  - Only show unseen videos
  - Only show latest (or latest unseen) video from each channel
  - Delivers notifications from all subscribed channels
  - Automatically redirect homepage to feed
  - Import subscriptions from YouTube
- Dark mode
- Embed support
- Set default player options (speed, quality, autoplay, loop)
- Does not require JS to play videos
- Support for Reddit comments in place of YT comments
- Import/Export subscriptions, watch history, preferences
- Does not use any of the official YouTube APIs
- Developer [API](https://github.com/omarroth/invidious/wiki/API)

Liberapay: https://liberapay.com/omarroth  
Patreon: https://patreon.com/omarroth  
BTC: 356DpZyMXu6rYd55Yqzjs29n79kGKWcYrY  
BCH: qq4ptclkzej5eza6a50et5ggc58hxsq5aylqut2npk

Onion links:

- kgg2m7yk5aybusll.onion
- axqzx4s6s54s32yentfqojs3x5i7faxza6xo3ehd4bzzsg2ii4fv2iid.onion

## Installation

### Docker:

#### Build and start cluster:

```bash
$ docker-compose up
```

And visit `localhost:3000` in your browser.

#### Rebuild cluster:

```bash
$ docker-compose build
```

#### Delete data and rebuild:

```bash
$ docker volume rm invidious_postgresdata
$ docker-compose build
```

### Linux:

#### Install dependencies

```bash
# Arch Linux
$ sudo pacman -S shards crystal imagemagick librsvg postgresql

# Ubuntu or Debian
$ curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
$ sudo apt update
$ sudo apt install crystal libssl-dev libxml2-dev libyaml-dev libgmp-dev libreadline-dev librsvg2-dev postgresql imagemagick libsqlite3-dev
```

#### Add invidious user and clone repository

```bash
$ useradd -m invidious
$ sudo -i -u invidious
$ git clone https://github.com/omarroth/invidious
$ exit
```

#### Setup PostgresSQL

```bash
$ sudo systemctl enable postgresql
$ sudo systemctl start postgresql
$ sudo -i -u postgres
$ psql -c "CREATE USER kemal WITH PASSWORD 'kemal';"
$ createdb -O kemal invidious
$ psql invidious < /home/invidious/invidious/config/sql/channels.sql
$ psql invidious < /home/invidious/invidious/config/sql/videos.sql
$ psql invidious < /home/invidious/invidious/config/sql/channel_videos.sql
$ psql invidious < /home/invidious/invidious/config/sql/users.sql
$ psql invidious < /home/invidious/invidious/config/sql/nonces.sql
$ exit
```

#### Setup Invidious

```bash
$ sudo -i -u invidious
$ cd invidious
$ shards
$ crystal build src/invidious.cr --release
# test compiled binary
$ ./invidious # stop with ctrl c
$ exit
```

#### systemd service
```bash
$ sudo cp invidious.service /etc/systemd/system/invidious.service
$ sudo systemctl enable invidious.service
$ sudo systemctl start invidious.service
```

### OSX:

```bash
# Install dependencies
$ brew update
$ brew install shards crystal-lang postgres imagemagick librsvg

# Clone repository and setup postgres database
$ git clone https://github.com/omarroth/invidious
$ cd invidious
$ brew services start postgresql
$ psql -c "CREATE ROLE kemal WITH LOGIN PASSWORD 'kemal';"
$ createdb invidious -U kemal
$ psql invidious < config/sql/channels.sql
$ psql invidious < config/sql/videos.sql
$ psql invidious < config/sql/channel_videos.sql
$ psql invidious < config/sql/users.sql
$ psql invidious < config/sql/nonces.sql

# Setup Invidious
$ shards
$ crystal build src/invidious.cr --release
```

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
    -t THREADS, --crawl-threads=THREADS
                                     Number of threads for crawling (default: 1)
    -c THREADS, --channel-threads=THREADS
                                     Number of threads for refreshing channels (default: 1)
    -f THREADS, --feed-threads=THREADS
                                     Number of threads for refreshing feeds (default: 1)
    -v THREADS, --video-threads=THREADS
                                     Number of threads for refreshing videos (default: 1)
```

Or for development:

```bash
$ curl -fsSLo- https://raw.githubusercontent.com/samueleaton/sentry/master/install.cr | crystal eval
$ ./sentry
```

## Extensions

- [Alternate Tube Redirector](https://addons.mozilla.org/en-US/firefox/addon/alternate-tube-redirector/): Automatically open Youtube Videos on alternate sites like Invidious or Hooktube.
- [Invidious Redirect](https://greasyfork.org/en/scripts/370461-invidious-redirect): Redirects Youtube URLs to Invidio.us (userscript)
- [iPhone Redirector Shortcut](https://www.icloud.com/shortcuts/6bbf26d989cf4d07a5fe1626efbc0950): Automatically open YouTube videos in Invidious (iPhone shortcut)
- [Youtube to Invidious](https://greasyfork.org/en/scripts/375264-youtube-to-invidious): Scan page for youtube embeds and urls and replace with Invidious (userscript)
- [Invidious Downloader](https://github.com/erupete/InvidiousDownloader): Tampermonkey userscript for downloading videos or audio on Invidious (userscript)

## Made with Invidious

- [FreeTube](https://github.com/FreeTubeApp/FreeTube): An Open Source YouTube app for privacy.
- [CloudTube](https://github.com/cloudrac3r/cadencegq): Website featuring pastebin, image host, and YouTube player
- [PeerTubeify](https://gitlab.com/Ealhad/peertubeify): On YouTube, displays a link to the same video on PeerTube, if it exists.

## Contributing

1.  Fork it ( https://github.com/omarroth/invidious/fork )
2.  Create your feature branch (git checkout -b my-new-feature)
3.  Commit your changes (git commit -am 'Add some feature')
4.  Push to the branch (git push origin my-new-feature)
5.  Create a new Pull Request

## Contact

Feel free to send an email to omarroth@protonmail.com or join our [Matrix Server](https://riot.im/app/#/room/#invidious:matrix.org), or #invidious on Freenode.

You can also view release notes on the [releases](https://github.com/omarroth/invidious/releases) page or in the CHANGELOG.md included in the repository.

## License

[![GNU AGPLv3 Image](https://www.gnu.org/graphics/agplv3-155x51.png)](http://www.gnu.org/licenses/agpl-3.0.en.html)

Invidious is Free Software: You can use, study share and improve it at your
will. Specifically you can redistribute and/or modify it under the terms of the
[GNU Affero General Public License](https://www.gnu.org/licenses/agpl.html) as
published by the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.
