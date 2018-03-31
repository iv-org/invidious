# Invidious

> Invidious is what YouTube should be

## Installation

### Installing [Crystal](https://github.com/crystal-lang/crystal):

On Arch:

```bash
$ sudo pacman -Syu shards crystal
$ crystal deps
```

On OSX:

```bash
$ brew update
$ brew install shards crystal-lang
$ crystal deps
```

### Installing Postgres:

On Arch:  
Install according to the [wiki](https://wiki.archlinux.org/index.php/PostgreSQL#Installing_PostgreSQL)

On OSX:

```bash
$ brew install postgres
```

Then setup database with

```bash
$ ./setup.sh
```

## Usage:

```bash
$ crystal src/invidious.cr
```

Or for development:

```bash
$ curl -fsSLo- https://raw.githubusercontent.com/samueleaton/sentry/master/install.cr | crystal eval
$ ./sentry
```

## Contributing

1.  Fork it ( https://github.com/omarroth/invidious/fork )
2.  Create your feature branch (git checkout -b my-new-feature)
3.  Commit your changes (git commit -am 'Add some feature')
4.  Push to the branch (git push origin my-new-feature)
5.  Create a new Pull Request

## Contributors

* [omarroth](https://github.com/omarroth) - creator, maintainer
