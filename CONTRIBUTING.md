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
  ressources to spare, with some prior experience with invidious.

* [Testing](#testing): You're an advanced user, who is already running their own instance, is not
  worried of compiling Invidious from source, and wants to help us test bug fixes or new features.

* [Development](#development): You're a developper and want to contribute code, or help with
  reviewing the code written by others.



## Issues

We use the [Github issue tracker](https://github.com/iv-org/invidious/issues) to track and manage
bug reports, feature requests and improvements.

**Note: Before opening any kind of issue, make sure to search on the tracker
with various keywords to verify that no other similar issue have already been
opened (and/or closed).**

In order for everyone to be able to understand eachother, all exchanges are done in English.
You can obviously use a translator if needed.

Please be polite and respectful in your exchanges. Remember that we're volunteers providing that
service for free. We don't have the time nor energy to deal with bad manners.


### Bug reports

The most common case is that you ended up on a page saying "you encountered a
bug in Invidious" while you were browsing a channel or watching a video.

In that case, you should open a "bug report". Please include as many details as possible, so
that we can easily reproduce your problem on our side.

Before opening your issue, **make sure to test a few other instances**, just to check that the
problem you're facing is not temporary (E.g an overloaded instance, a network outage, etc.) or
caused by configuration error on your side.

If a bug report already exists for your problem, you can add a comment with more details, but make
sure that it's useful and adds value to the discussion. If 20 people did that already, it might not
be relevant to post a new comment.

Here is a non-exhaustive list of details that will help us:

  * **A clear and concise list of steps to reproduce the problem**
  * A link to the page where the bug happened
  * Browser/OS version, device type (mobile, desktop, etc..)
  * Were you logged in?
  * If the bug is caused by an external file (ex: when importing subscriptions), try to include
    that too (Get in touch with us if you want to share these files privately).
  * If you're hosting your own instance, include relevant config file(s).\
    **Make sure to redact secrets like your DB password or HMAC key first!!**


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


### Feature resquests

If you think that Invidious lacks some feature or another, you should open a "feature request".

Do note that Invidious is and will remain a Youtube-only front-end. Requests to add support for
other services (e.g: Bandcamp, [Odyssee](https://github.com/iv-org/invidious/issues/3022)) will be
systematically rejected.



## Translations

Invidious is translated in many languages using Weblate:
https://hosted.weblate.org/projects/invidious/.

We recommend creating an account or connecting with one of the other authentication providers that
Weblate supports (Github, GitLab, Google, etc..) for a better experience.

We also accept translation updates using Pull requests, but please be aware that it represents more
work for us to merge those.



## Hosting an instance

Another way to contribute to invidious is to host a [public instance]
(https://instances.invidious.io/).

To do so, you need a server (either a VPS or dedicated) with
[enough ressources](https://docs.invidious.io/installation/#hardware-requirements) to handle the
load. You'll also need a domain name with a valid TLS certificate (e.g provided by Let's Encrypt).

Then, if your instance follows the
[rules listed here](https://docs.invidious.io/instances/#rules-to-have-your-instance-in-this-list),
you can request your instance to be added to the list by
[creating an issue on the documentation repository](https://github.com/iv-org/documentation/issues).

Once you've filled the form with your instance's informations, your instance will be added to our
uptime monitor. From there, a probatory period of 30 days will start, to make sure that you can
keep your instance online and up to date. Finally, your instance will be added to the list. We'll
ask you to join our Matrix room, so that we can inform you of important updates and exchange with
other maintainers.



## Testing

Once reviewed, the new features or bug fixes must be tested before being merged. In general, this
can be achieved by running the following commands (change the PR number as required):
```bash
git clone https://github.com/iv-org/invidious
cd invidious
wget "https://github.com/iv-org/invidious/pull/4439.diff"
git apply 4439.diff
docker compose up
```

If you have prior knowledge of Invidious, that's great, but otherwise feel free to get in touch
with us on Matrix or IRC. We'll do our best to give you a better understanding of the project.

Once you have deployed the patch on your test instance, try the changes mentionned in the pull
request. Often times, the linked issue might contain examples of channels/comments/videos impacted.
Definitely use those to check that the behaviot you see is the expected one. After that, add a
comment on that PR with your test methodology and your findings. Add screenshots (for interface
changes) and code snippets (for API changes) as needed.



## Development

Code contributions are handled through
[Github's Pull Requests (PRs)](https://github.com/iv-org/invidious/pulls).

Invidious' backend is developped in Crystal, a compiled language inspired from Ruby. The frontend
is developped using Crystal's own templating engine (ECR) with some vanilla JS and CSS.

Invidious follows more or less closely the [Crystal coding convention]
(https://crystal-lang.org/reference/latest/conventions/coding_style.html#directory-and-file-names),
except for the "Directory and File Names" sections.


### Contributing code

TODO


### Reviewing code

TODO
