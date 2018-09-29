# Invidious

## Invidious is an alternative front-end to YouTube

- Audio-only (and no need to keep window open on mobile)
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
- Import/Export subscriptions, watch history, preference
- Does not use any of the official YouTube APIs

Liberapay: https://liberapay.com/omarroth  
Patreon: https://patreon.com/omarroth  
BTC: 356DpZyMXu6rYd55Yqzjs29n79kGKWcYrY  
BCH: qq4ptclkzej5eza6a50et5ggc58hxsq5aylqut2npk

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

### Installing [Crystal](https://github.com/crystal-lang/crystal):

#### On Arch:

```bash
$ sudo pacman -S shards crystal
$ shards
```

#### On OSX:

```bash
$ brew update
$ brew install shards crystal-lang
$ shards
```

### Installing Postgres:

#### On Arch:

Install according to the [wiki](https://wiki.archlinux.org/index.php/PostgreSQL#Installing_PostgreSQL)

#### On OSX:

```bash
$ brew install postgres
```

### Setup Postgres:

```bash
$ ./setup.sh
```

### Installing ImageMagick (required for CAPTCHA):

#### On Arch:

```bash
$ sudo pacman -S imagemagick librsvg
```

## Usage:

```bash
$ crystal build src/invidious.cr --release
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
- [Invidio.us embed](https://greasyfork.org/en/scripts/370442-invidious-embed): Replaces YouTube embeds with Invidio.us embeds (userscript)

## Contributing

1.  Fork it ( https://github.com/omarroth/invidious/fork )
2.  Create your feature branch (git checkout -b my-new-feature)
3.  Commit your changes (git commit -am 'Add some feature')
4.  Push to the branch (git push origin my-new-feature)
5.  Create a new Pull Request

## Contributors

- [omarroth](https://github.com/omarroth) - creator, maintainer
