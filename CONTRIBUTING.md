# CONTRIBUTING

## Introduction

This document explains how to contribute to Invidious.

Each section below describes a different way to contribute, based on your skills and experience
with Invidious. Here is a summary:

* [Issues](#issues): You are a regular user, and want to report a bug, ask for a new feature or for
  an existing feature to be improved.

* [Translations](#translations): You speak English and you're fluent in another language, and want
  to help us reach more users around the globe.

* [Hosting an instance](#hosting-an-instance): You're a sysadmin and have some time and server
  ressources to spare, with some prior experience with Invidious.

* [Testing](#testing): You're an advanced user, who is already running their own instance, is not
  worried of compiling Invidious from source, and wants to help us test bug fixes or new features.

* [Development](#development): You're a developer and want to contribute code, or help with
  reviewing the code written by others.



## Issues

We use the [Github issue tracker](https://github.com/iv-org/invidious/issues) to track and manage
bug reports, feature requests and improvements.

**Note: Before opening any kind of issue, make sure to search on the tracker with various keywords
to verify that no other similar issue have already been opened (and/or closed).**

In order for everyone to be able to understand eachother, all exchanges are done in English.
You can obviously use a translator if needed, but if you do, please mention it in your message, so
that we can be aware of it, and respond accordingly: nuance often gets lost in translation.

Please be polite and respectful in your exchanges. Remember that we're volunteers providing that
service for free. We don't have the time nor energy to deal with bad manners.

Users who (understandably) do not want to use GitHub can [contact us](https://invidious.io/contact/)
with the required details. If you can write something we can directly paste into a GitHub issue that
would be perfect!


### Bug reports

The most common case is that you ended up on a page saying "you encountered a bug in Invidious"
while you were browsing a channel or watching a video.

Before anything else, **make sure to test a few other instances**, just to check that the
problem you're facing is not temporary (E.g an overloaded instance, a network outage, etc.) or
caused by a configuration error on that specific instance.

If a bug report already exists for your problem, you can add a comment with more details, but make
sure that it's useful and adds value to the discussion. If 20 people did that already, it might not
be relevant to post a new comment.

Otherwise, you should open a "bug report". Please include as many details as possible, so that we
can easily reproduce your problem on our side. Here is a non-exhaustive list of details that will
help us:

  * **A clear and concise list of steps to reproduce the problem**
  * A link to the page where the bug happened
  * Browser/OS version, device type (mobile, desktop, etc..)
  * Are you logged in?
  * If the bug is caused by an external file (ex: when importing subscriptions), try to include
    it too ([Get in touch](https://invidious.io/contact/) with us if you want to share these files privately).
  * If you're hosting your own instance, include relevant config file(s).\
    **Make sure to redact secrets like your DB password and HMAC key first!!**


**Note: Security-related issues should be reported by e-mail at
[security@invidious.io](mailto:security@invidious.io).**


### Enhancement

If you feel that some existing feature can be improved, you should open an "enhancement" issue.

In your issue, describe what the Invidious currently does, what you don't like about it, and propose
ways to improve that feature. If you can provide screenshots or drawings to support your explanation
that's even better!

Please be aware that Invidious is heavily aimed towards simplicity and being usable without
Javascript. It means that we have to deal with compromises all over the place, and some features
might not be as good as JavaScript-rich alternatives (like Freetube), that allows much more
flexibility.


### Feature requests

If you think that Invidious lacks some feature or another, you should open a "feature request".

Do note that Invidious is and will remain a Youtube-only front-end. Requests to add support for
other services (e.g: Bandcamp, [Odyssee](https://github.com/iv-org/invidious/issues/3022)) will be
systematically rejected.



## Translations

Invidious is translated in many languages using Weblate:
https://hosted.weblate.org/projects/invidious/.

We recommend creating an account or connecting with one of the other authentication providers that
Weblate supports (Github, GitLab, etc..) for a better experience.

We also accept translation updates using Pull requests, but please be aware that it represents more
work for us to merge those.



## Hosting an instance

Another way to contribute to invidious is to host a [public instance]
(https://instances.invidious.io/).

To do so, you need a server with [enough ressources]
(https://docs.invidious.io/installation/#hardware-requirements) to handle the load. You will also
need a domain name with a valid TLS certificate.

Then, if your instance follows the
[rules listed here](https://docs.invidious.io/instances/#rules-to-have-your-instance-in-this-list),
you can request your instance to be added to the list by
[creating an issue on the documentation repository](https://github.com/iv-org/documentation/issues).

Once you've filled the form with your instance's informations, your instance will be added to our
uptime monitor. From there, a probatory period of 30 days will start, to make sure that you can
keep your instance online and up to date. Finally, your instance will be added to the list. After
that We will invite you to a dedicated Matrix room for instance maintainers.

Joining this room is not mandatory but strongly recommended, as we use it to broadcast information
about important updates, and you can also exchange with other maintainers.



## Testing

New features and bug fixes must be tested before being merged.

Once reviewed, pull requests that need to be tested will be labelled as [`need-testing`]
(https://github.com/iv-org/invidious/pulls?q=is%3Apr+is%3Aopen+label%3Aneed-testing). When one PR is
deployed on our test instance, it will be marked accordingly as [`in-testing`]
(https://github.com/iv-org/invidious/pulls?q=is%3Apr+is%3Aopen+label%3Ain-testing).

If you have prior knowledge of Invidious, that's great, but if you don't, that's also okay! We have
a Matrix room (also bridged to IRC) that you can join to get help. We'll do our best to help you
getting started with the project.

In general, testing these changes yourself can be achieved using the commands below (change the PR
number as required):
```bash
# Clone the repository
git clone https://github.com/iv-org/invidious
cd invidious

# Fetch the code to a new branch (here "testing") and make it the current working tree
# Don't forget to change the PR number!
git fetch upstream pull/1234/head:testing
git checkout testing

# Finally, run a test instance using docker
docker compose up
```

Once you have deployed the patch on your test instance, try the changes mentionned in the pull
request. Often times, the linked issue might contain examples of channels/comments/videos impacted.
Definitely use those to check that the behavior you see is the expected one. After that, add a
comment on that PR with your test methodology and your findings. Add screenshots (for interface
changes) and code snippets (for API changes) as needed.



## Development

Code contributions are handled through
[Github's Pull Requests (PRs)](https://github.com/iv-org/invidious/pulls).


### Generalities

#### Server side

The server part of Invidious is developed in [Crystal](https://crystal-lang.org/), a compiled
language inspired by Ruby. The HTML templates are generated at compile time from the ECR files
present in the `src/invidious/views` folder, meaning that you need to re-compile Invidious after
changing those.

Regarding coding style, Invidious tries to follow the [Crystal coding convention]
(https://crystal-lang.org/reference/latest/conventions/coding_style.html#directory-and-file-names),
as closely as possible. Most of the rules listed here will be enforced if you run `make format`.

We also use [Ameba](https://github.com/crystal-ameba/ameba), a static code analysis tool for Crystal.
Ameba is part of our CI/CD pipeline, but it is recommended to run it locally before pushing you
change and making a PR, like so:

```sh
# Make sure to have all dependencies installed, including the development ones
# (this command only needs to be run once)
shards install

# Run ameba
./bin/ameba
```

#### Client side

The client side of Invidious is developped with some basic ("vanilla") JavaScript and CSS.
No complex JS framework or tooling is required (e.g NPM).

The only dependencies Invidious has is [VideoJS](https://github.com/videojs/video.js/) plus some of
its plug-ins. VideoJS is automatically downloaded when you run `make`.


#### Other

If you need to edit files the `locales/` directory, please make sure to keep the indentation as four
spaces. Any other identation will break Weblate, our translation tool (See #Translations above).


### Contributing code

TODO


### Reviewing code

TODO
