# Invidious

[![Build Status](https://travis-ci.org/omarroth/invidious.svg?branch=master)](https://travis-ci.org/omarroth/invidious)

## Invidious is an alternative front-end to YouTube

- Audio-only mode (and no need to keep window open on mobile)
- [Free software](https://github.com/omarroth/invidious) (AGPLv3 licensed)
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

## Why use Invidious?

You cannot use YouTube without running non-free Javascript or being tracked by Google.
Invidious is free software with which you can watch YouTube with zero requests to Google and play videos without Javascript.
Also, you do not need to create a Google account to save subscriptions and your watch history, Invidious is able to provide you with a fully featured local account.
You can import your current subscriptions YouTube, FreeTube and NewPipe.
Invidious also blocks ads without you having to use an adblock that may not even completely block all ads.

Reddit comments are an additional feature. You can display them instead of YouTube comments or next to them.
Invidious does not use any official YouTube API, so it does not violate any terms of service. It also provides a developer API that can be used by others.

## Invidious Instances

See [Invidious Instances](https://github.com/omarroth/invidious/wiki/Invidious-Instances) for a full list of publicly available instances.

### Official Instances

- [invidio.us](https://invidio.us) 🇺🇸  
  Issuer: Let's Encrypt, [SSLLabs Verification](https://www.ssllabs.com/ssltest/analyze.html?d=invidio.us)
- [kgg2m7yk5aybusll.onion](http://kgg2m7yk5aybusll.onion)
- [axqzx4s6s54s32yentfqojs3x5i7faxza6xo3ehd4bzzsg2ii4fv2iid.onion](http://axqzx4s6s54s32yentfqojs3x5i7faxza6xo3ehd4bzzsg2ii4fv2iid.onion)

## Screenshots

| Player                                                                                                                  | Preferences                                                                                                             | Subscriptions                                                                                                               |
| ----------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------- |
| [<img src="screenshots/01_player.png?raw=true" height="140" width="280">](screenshots/01_player.png?raw=true)           | [<img src="screenshots/02_preferences.png?raw=true" height="140" width="280">](screenshots/02_preferences.png?raw=true) | [<img src="screenshots/03_subscriptions.png?raw=true" height="140" width="280">](screenshots/03_subscriptions.png?raw=true) |
| [<img src="screenshots/04_description.png?raw=true" height="140" width="280">](screenshots/04_description.png?raw=true) | [<img src="screenshots/05_preferences.png?raw=true" height="140" width="280">](screenshots/05_preferences.png?raw=true) | [<img src="screenshots/06_subscriptions.png?raw=true" height="140" width="280">](screenshots/06_subscriptions.png?raw=true) |

## Installation

See [Invidious-Updater](https://github.com/tmiland/Invidious-Updater) for a self-contained script that can automatically install and update Invidious.

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
# First you have to add the repository to your APT configuration. For easy setup just run in your command line:
$ curl -sSL https://dist.crystal-lang.org/apt/setup.sh | sudo bash
# That will add the signing key and the repository configuration. If you prefer to do it manually, execute the following commands:
$ curl -sL "https://keybase.io/crystal/pgp_keys.asc" | sudo apt-key add -
$ echo "deb https://dist.crystal-lang.org/apt crystal main" | sudo tee /etc/apt/sources.list.d/crystal.list
$ sudo apt-get update
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
$ psql -c "CREATE USER kemal WITH PASSWORD 'kemal';" # Change 'kemal' here to a stronger password, and update `password` in config/config.yml
$ createdb -O kemal invidious
$ psql invidious kemal < /home/invidious/invidious/config/sql/channels.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/videos.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/channel_videos.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/users.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/session_ids.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/nonces.sql
$ psql invidious kemal < /home/invidious/invidious/config/sql/annotations.sql
$ exit
```

#### Setup Invidious

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

### OSX:

```bash
# Install dependencies
$ brew update
$ brew install shards crystal-lang postgres imagemagick librsvg

# Clone repository and setup postgres database
$ git clone https://github.com/omarroth/invidious
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

# Setup Invidious
$ shards update && shards install
$ crystal build src/invidious.cr --release
```

## Update Invidious

You can see how to update Invidious [here](https://github.com/omarroth/invidious/wiki/Updating).

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

[Documentation](https://github.com/omarroth/invidious/wiki) can be found in the wiki.

## Extensions

[Extensions](https://github.com/omarroth/invidious/wiki/Extensions) can be found in the wiki, as well as documentation for integrating it into other projects.

## Made with Invidious

- [FreeTube](https://github.com/FreeTubeApp/FreeTube): An Open Source YouTube app for privacy.
- [CloudTube](https://cadence.moe/cloudtube/subscriptions): A JS-rich alternate YouTube player
- [PeerTubeify](https://gitlab.com/Ealhad/peertubeify): On YouTube, displays a link to the same video on PeerTube, if it exists.
- [MusicPiped](https://github.com/deep-gaurav/MusicPiped): A materialistic music player that streams music from YouTube.

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
