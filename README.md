# Invidious

> Invidious is what YouTube should be

## Installation

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
$ crystal build src/invidious.cr
$ ./invidious
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
