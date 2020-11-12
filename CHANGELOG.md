# 0.20.0 (2019-011-06)

# Version 0.20.0: Custom Playlists

It's been quite a while since the last release! There've been [198 commits](https://github.com/omarroth/invidious/compare/0.19.0..0.20.0) from 27 contributors.

A couple smaller features have since been added. Channel pages and playlists in particular have received a bit of a face-lift, with both now displaying their descriptions as expected, and playlists providing video count and published information. Channels will also now provide video descriptions in their RSS feed.

Turkish (tr), Chinese (zh-TW, in addition to zh-CN), and Japanese (jp) are all now supported languages. Thank you as always to the hard work done by translators that makes this possible.

The feed menu and default home page are both now configurable for registered and unregistered users, and is quite a bit of an improvement for users looking to reduce distractions for their daily use.

## For Administrators

`feed_menu` and `default_home` are now configurable by the user, and have therefore been moved into `default_user_preferences`:

```yaml
feed_menu: ["Popular", "Top"]
default_home: Top

# becomes:

default_user_preferences:
  feed_menu: ["Popular", "Top"]
  default_home: Top
```

Several new options have also been added, including the ability to set a support email for the instance using `admin_email: EMAIL`, and forcing the use of a specific connection in the case of rate-limiting using `force_resolve` (see below).

## For Developers

Authenticated endpoints are now [properly documented](https://github.com/omarroth/invidious/wiki/Authenticated-Endpoints), as well how to generate and use API tokens. My hope is that this makes some of the more [interesting](https://github.com/omarroth/invidious/wiki/Authenticated-Endpoints#get-apiv1authnotifications) endpoints more accessible for developers to use in their own applications.

API endpoints for interacting with custom playlists have also been added with documentation available [here](https://github.com/omarroth/invidious/wiki/Authenticated-Endpoints#get-apiv1authplaylists).

## Custom playlists

This is probably the feature that has been the longest in the pipe and that I'm quite pleased is now implemented. It is now possible to create custom playlists, which can be played and edited through Invidious. API endpoints have also been added (documentation [here](https://github.com/omarroth/invidious/wiki/Authenticated-Endpoints#get-apiv1authplaylists)).

Overall I'm quite pleased with how smoothly it has been rolled out and with the experience so far, and I'm exctited for how it can be extended and improved in future.

## [instances.invidio.us](https://instances.invidio.us)

It is now possible to view a list of public instances (as provided in the [wiki](https://github.com/omarroth/invidious/wiki/Invidious-Instances)) through an API or a pretty new interface [here](https://instances.invidio.us). It combines uptime information, statistics from each instance and basic information already provided in the wiki. I expect it should be much more user-friendly than compiling the information yourself, and is already used by [Invidition](https://codeberg.org/Booteille/Invidition) to provide a list of instances for users to choose from.

The site itself is licensed under the AGPLv3 and the source is available [here](https://github.com/omarroth/instances.invidio.us).

## Video unavailable [#811](https://github.com/omarroth/invidious/issues/811)

Many users have likely noticed this error message if using Invidious directly or through another service, such as FreeTube. This issue is caused by rate-limiting by Google, and is not a new issuee for projects like Invidious (notably [youtube-dl](https://github.com/ytdl-org/youtube-dl#http-error-429-too-many-requests-or-402-payment-required)) and appears to be affecting smaller, private instances as well.

There is not a permanent fix for administrators currently, however there is some information available [here](https://github.com/omarroth/invidious/issues/811#issuecomment-540017772) that may provide a temporary solution. Unfortanately, in most cases the best option is to wait for the instance to be unbanned or to move the instance to a different IP. A more informative error message is also now provided, which should help an administrator more quickly diagnose the problem.

For those interested, I would recommend following [#811](https://github.com/omarroth/invidious/issues/811) for any future progress on the issue.

## BAT verified publisher

I'm quite late to this announcement, however I'm pleased to mention that Invidious is now a BAT verified publisher! I would recommend looking [here](https://basicattentiontoken.org/about/) or [here](https://www.reddit.com/r/BATProject/comments/7cr7yc/new_to_bat_read_this_introduction_to_basic/) for learning more about what it is and how it works. Overall I think it makes an interesting substitute for services like Liberapay, and a (hopefully) much less-intrusive alternative to direct advertising.

BAT is combined under other cryptocurrencies below. Currently there's a fairly significant delay in payout, which is the reason for the large fluctuation in crypto donations between September and October (and also the reason for the late announcement).

## Release schedule

Currently I'm quite pleased with the current state of the project. There's plenty of things I'd still like to add, however at this point I expect the rate of most new additions will slow down a bit, with more focus on stabililty and any long-standing bugs.

Because of this, I'm planning on releasing a new version quarterly, with any necessary hotfixes being pushed as a new patch release as necessary. As always it will be possible to run Invidious directly from [master](https://github.com/omarroth/invidious/wiki/Updating) if you'd still like to have the lastest version.

I'll plan on providing finances each release, with a similar monthly breakdown as below.

## Finances for September 2019

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$64.37
- [Liberapay](https://liberapay.com/omarroth) : \$76.04
- Crypto : ~\$99.89 (converted from BAT, BCH, BTC)
- Total : \$240.30

### Expenses

- invidious-lb1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node6 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node7 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node8 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node9 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node10 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node11 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node12 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node13 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node14 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node15 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node16 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$135.00

## Finances for October 2019

- [Liberapay](https://liberapay.com/omarroth) : \$134.40
- Crypto : ~\$8.29 (converted from BAT, BCH, BTC)
- Total : \$142.69

### Expenses

- invidious-lb1 (nyc1) : \$5.00 (load balancer)
- invidious-lb2 (nyc1) : \$5.00 (load balancer)
- invidious-lb3 (nyc1) : \$5.00 (load balancer)
- invidious-lb4 (nyc1) : \$5.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node6 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node7 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node8 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node9 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node10 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node11 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node12 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node13 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node14 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node15 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node16 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node17 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node18 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$155.00

# 0.19.0 (2019-07-13)

# Version 0.19.0: Communities

Hello again everyone! Focus this month has mainly been on improving playback performance, along with a couple new features I'd like to announce. There have been [109 commits](https://github.com/omarroth/invidious/compare/0.18.0...0.19.0) this past month from 10 contributors.

This past month has seen the addition of Chinese (`zh-CN`) and Icelandic (`is`) translations. I would like to give a huge thanks to their respective translators, and again an enormous thanks to everyone who helps translate the site.

I'm delighted to mention that [FreeTube 0.6.0](https://github.com/FreeTubeApp/FreeTube) now supports 1080p thanks to the Invidious API. I would very much recommend reading the [relevant post](https://freetube.writeas.com/freetube-release-0-6-0-beta-1080p-and-a-lot-of-qol) for some more information on how it works, along with several other major improvements. Folks that are interested in adding similar functionality for their own projects should feel free to get in touch.

This past month there has been quite a bit of work on improving memory usage and improving download and playback speeds. As mentioned in the previous release, some extra hardware has been allocated which should also help with this. I'm still looking for ways to improve performance and feedback is always appreciated.

Along with performance, a couple quality of life improvements have been added, including author thumbnails and banners, clickable titles for embedded videos, and better styling for captions, among some other enhancements.

## Communities

Support for YouTube's [communities tab](https://creatoracademy.youtube.com/page/lesson/community-tab) has been added. It's a very interesting but surprisingly unknown feature. Essentially, providing comments for a channel, rather than a video, where an author can post updates for their subscribers.

It's commonly used to promote interesting links and foster discussion. I hope this feature helps people find more interesting content that otherwise would have been overlooked.

## For Developers

For accessing channel communities, an `/api/v1/channels/comments/:ucid` endpoint has been added, with similar behavior and schema to `/api/v1/comments/:id`, with an extra `attachment` field for top-level comments. More info on usage and available data can be found in the [wiki](https://github.com/omarroth/invidious/wiki/API#get-apiv1channelscommentsucid-apiv1channelsucidcomments).

An `/api/v1/auth/feeds` endpoint has been added for programmatically accessing a user's subscription feed, with options for displaying notifications and filtering an existing feed.

An `/api/v1/search/suggestions` endpoint has been added for retrieving suggestions for a given query.

## For Administrators

It is now possible to disable more resource intensive features, such as downloads and DASH functionality by adding `disable_proxy` to your config. See [#453](https://github.com/omarroth/invidious/issues/453) and the [Wiki](https://github.com/omarroth/invidious/wiki/Configuration) for more information and example usage. I expect this to be a big help for folks with limited bandwidth when hosting their own instances.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$38.39
- [Liberapay](https://liberapay.com/omarroth) : \$84.85
- Crypto : ~\$0.00 (converted from BCH, BTC)
- Total : \$123.24

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node6 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node7 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node8 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node9 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node10 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$105.00

The goal on Patreon has been updated to reflect the above expenses. As mentioned above, the main reason for more hardware is to improve playback and download speeds, although I'm still looking into improving performance without allocating more hardware.

As always I'm grateful for everyone's support and feedback. I'll see you all next month.

# 0.18.0 (2019-06-06)

# Version 0.18.0: Native Notifications and Optimizations

Hope everyone has been doing well. This past month there have been [97 commits](https://github.com/omarroth/invidious/compare/0.17.0...0.18.0) from 10 contributors. For the most part changes this month have been on optimizing various parts of the site, mainly subscription feeds and support for serving images and other assets.

I'm quite happy to mention that support for Greek (`el`) has been added, which I hope will continue to make the site accessible for more users.

Subscription feeds will now only update when necessary, rather than periodically. This greatly lightens the load on DB as well as making the feeds generally more responsive when changing subscriptions, importing data, and when receiving new uploads.

Caching for images and other assets should be greatly improved with [#456](https://github.com/omarroth/invidious/issues/456). JavaScript has been pulled out into separate files where possible to take advantage of this, which should result in lighter pages and faster load times.

This past month several people have encountered issues with downloads and watching high quality video through the site, see [#532](https://github.com/omarroth/invidious/issues/532) and [#562](https://github.com/omarroth/invidious/issues/562). For this coming month I've allocated some more hardware which should help with this, and I'm also looking into optimizing how videos are currently served.

## For Developers

`viewCount` is now available for `/api/v1/popular` and all videos returned from `/api/v1/auth/notifications`. Both also now provide `"type"` for indicating available information for each object.

An `/authorize_token` page is now available for more easily creating new tokens for use in applications, see [this comment](https://github.com/omarroth/invidious/issues/473#issuecomment-496230812) in [#473](https://github.com/omarroth/invidious/issues/473) for more details.

A POST `/api/v1/auth/notifications` endpoint is also now available for correctly returning notifications for 150+ channels.

## For Administrators

There are two new schema changes for administrators: `views` for adding view count to the popular page, and `feed_needs_update` for tracking feed changes.

As always the relevant migration scripts are provided which should run when following instructions for [updating](https://github.com/omarroth/invidious/wiki/Updating). Otherwise, adding `check_tables: true` to your config will automatically make the required changes.

## Native Notifications

[<img src="https://omar.yt/81c3ae1839831bd9300d75e273b6552a86dc2352/native_notification.png" height="160" width="472">](https://omar.yt/81c3ae1839831bd9300d75e273b6552a86dc2352/native_notification.png "Example of native notification, available in repository under screnshots/native_notification.png")

It is now possible to receive [Web notifications](https://developer.mozilla.org/en-US/docs/Web/API/Notifications_API) from subscribed channels.

You can enable notifications by clicking "Enable web notifications" in your preferences. Generally they appear within 20-60 seconds of a new video being uploaded, and I've found them to be an enormous quality of life improvement.

Although it has been fairly stable, please feel free to report any issues you find [here](https://github.com/omarroth/invidious/issues) or emailing me directly at omarroth@protonmail.com.

Important to note for administrators is that instances require [`use_pubsub_feeds`](https://github.com/omarroth/invidious/wiki/Configuration) and must be served over HTTPS in order to correctly send web notifications.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$49.73
- [Liberapay](https://liberapay.com/omarroth) : \$100.57
- Crypto : ~\$11.12 (converted from BCH, BTC)
- Total : \$161.42

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node6 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$85.00

See you all next month!

# 0.17.0 (2019-05-06)

# Version 0.17.0: Player and Authentication API

Hello everyone! This past month there have been [130 commits](https://github.com/omarroth/invidious/compare/0.16.0..0.17.0) from 11 contributors. Large focus has been on improving the player as well as adding API access for other projects to make use of Invidious.

There have also been significant changes in preparation of native notifications (see [#195](https://github.com/omarroth/invidious/issues/195), [#469](https://github.com/omarroth/invidious/issues/469), [#473](https://github.com/omarroth/invidious/issues/473), and [#502](https://github.com/omarroth/invidious/issues/502)), and playlists. I expect to see both of these to be added in the next release.

I'm quite happy to mention that new translations have been added for Esperanto (`eo`) and Ukranian (`uk`). Support for pluralization has also been added, so it should now be possible to make a more native experience for speakers in other languages. The system currently in place is a bit cumbersome, so for any help using this feature please get in touch!

## For Administrators

A `check_tables` option has been added to automatically migrate without the use of custom scripts. This method will likely prove to be much more robust, and is currently enabled for the official instance. To prevent any unintended changes to the DB, `check_tables` is disabled by default and will print commands before executing. Having this makes features that require schema changes much easier to implement, and also makes it easier to upgrade from older instances.

As part of [#303](https://github.com/omarroth/invidious/issues/303), a `cache_annotations` option has been added to speed up access from `/api/v1/annotations/:id`. This vastly improves the experience for videos with annotations. Currently, only videos that contain legacy annotations will be cached, which should help keep down the size of the cache. `cache_annotations` is disabled by default.

## For Developers

An authorization API has been added which allows other applications to read and modify user subscriptions and preferences (see [#473](https://github.com/omarroth/invidious/issues/473)). Support for accessing user feeds and notifications is also planned. I believe this feature is a large step forward in supporting syncing subscriptions and preferences with other services, and I'm excited to see what other developers do with this functionality.

Support for server-to-client push notifications is currently underway. This allows Invidious users, as well as applications using the Invidious API, to receive notifications about uploads in near real-time (see #469). An `/api/v1/auth/notifications` endpoint is currently available. I'm very excited for this to be integrated into the site, and to see how other developers use it in their own projects.

An `/api/v1/storyboards/:id` endpoint has been added for accessing storyboard URLs, which allows developers to add video previews to their players (see below).

## Player

Support for annotations has been merged into master with [#303](https://github.com/omarroth/invidious/issues/303), thanks @glmdgrielson! Annotations can be enabled by default or only for subscribed channels, and can also be toggled per video. I'm extremely proud of the progress made here, and I'm so thankful to everyone that has made this possible. I expect this to be the last update with regards to supporting annotations, but I do plan on continuing to improve the experience as much as possible.

The Invidious player now supports video previews and a corresponding API endpoint `/api/v1/storyboards/:id` has been added for developers looking to add similar functionality to their own players. Not much else to say here. Overall it's a very nice quality of life improvement and an attractive addition to the site.

It is now possible to select specific sources for videos provided using DASH (see [#34](https://github.com/omarroth/invidious/issues/34)). I would consider support largely feature complete, although there are still several issues to be fixed before I would consider it ready for larger rollout. You can watch videos in 1080p by setting `Default quality` to `dash` in your preferences, or by adding `&quality=dash` to the end of video URLs.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$49.73
- [Liberapay](https://liberapay.com/omarroth) : \$63.03
- Crypto : ~\$0.00 (converted from BCH, BTC)
- Total : \$112.76

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$80.00

That's all for now. Thanks!

# 0.16.0 (2019-04-06)

# Version 0.16.0: API Improvements and Annotations

Hello again! This past month has seen [116 commits](https://github.com/omarroth/invidious/compare/0.15.0..0.16.0) from 13 contributors and a couple important changes I'd like to announce.

A privacy policy is now available [here](https://invidio.us/privacy). I've done my best to explain things as clearly as possible without oversimplifying, and would very much recommend reading it if you're concerned about your privacy and want to learn more about how Invidious uses your data. Please let me know if there is anything that needs clarification.

I'm also very happy to announce that a Spanish translation has been added to the site. You can use it with `?hl=es` or by setting `es` as your default locale. As always I'm extremely grateful to translators for making the site accessible to more people.

## For Administrators

Invidious now supports server-to-server [push notifications](https://developers.google.com/youtube/v3/guides/push_notifications). This uses [PubSubHubbub](https://pubsubhubbub.github.io/PubSubHubbub/pubsubhubbub-core-0.4.html) to automatically handle new videos sent to an instance, which is less resource intensive and generally faster. Note that it will not pull all videos from a subscribed channel, so recommended usage is in addition to `channel_threads`. Using PubSub requires a valid `domain` that updates can be sent to, and a random string that can be used to sign updates sent to the instance. You can enable it by adding `use_pubsub_feeds: true` to your `config.yml`. See [Configuration](https://github.com/omarroth/invidious/wiki/Configuration) for more info.

Unfortunately there are a couple necessary changes to the DB to support `liveNow` and `premiereTimestamp` in subscription feeds. Migration scripts have been provided that should be used automatically if following the instructions [here](https://github.com/omarroth/invidious/wiki/Updating).

You can now configure default user preferences for your instance. This allows you to set default locale, player preferences, and more. See [#415](https://github.com/omarroth/invidious/issues/415) for more details and example usage.

## For Developers

The [fields](https://developers.google.com/youtube/v3/getting-started#fields) API has been added with [#429](https://github.com/omarroth/invidious/pull/429) and is now supported on all JSON endpoints, thanks [**@afrmtbl**](https://github.com/afrmtbl)! Synax is straight-forward and can be used to reduce data transfer and create a simpler response for debugging. You can see an example [here](https://invidio.us/api/v1/videos/CvFH_6DNRCY?pretty=1&fields=title,recommendedVideos/title). I've been quite happy using it and hope it is similarly useful for others.

An `/api/v1/annotations/:id` endpoint has been added for pulling legacy annotation data from [this](https://archive.org/details/youtubeannotations) archive, see below for more details. You can also access annotation data available on YouTube using `?source=youtube`, although this will only return card data as legacy annotations were deleted on January 15th.

A couple minor changes to existing endpoints:

- A `premiereTimestamp` field has been added to `/api/v1/videos/:id`
- A `sort_by` param has been added to `/api/v1/comments/:id`, supports `new`, `top`.

More info is available in the [documentation](https://github.com/omarroth/invidious/wiki/API).

## Annotations

I'm pleased to announce that annotation data is finally available from the roughly 1.4 billion videos archived as part of [this](https://www.reddit.com/r/DataHoarder/comments/aa6czg/youtube_annotation_archive/) project. They are accessible from the Internet Archive [here](https://archive.org/details/youtubeannotations) or as a 355GB torrent, see [here](https://www.reddit.com/r/DataHoarder/comments/b7imx9/youtube_annotation_archive_annotation_data_from/) for more details. A corresponding `/api/v1/annotations/:id` endpoint has been added to Invidious which uses the collection from IA to provide legacy annotations.

Support for them in the player is possible thanks to [this](https://github.com/afrmtbl/videojs-youtube-annotations) plugin developed by [**@afrmtbl**](https://github.com/afrmtbl). A PR for adding support to the site is available as [#303](https://github.com/omarroth/invidious/pull/303). There's also an [extension](https://github.com/afrmtbl/AnnotationsRestored) for overlaying them on top of the YouTube player (again thanks to [**@afrmtbl**](https://github.com/afrmtbl)), and an [extension](https://tech234a.bitbucket.io/AnnotationsReloaded?src=invidious) for hooking into code still present in the YouTube player itself, developed by [**@tech234a**](https://github.com/tech234a).

I would recommend reading the [official announcement](https://www.reddit.com/r/DataHoarder/comments/b7imx9/youtube_annotation_archive_annotation_data_from/) for more details. I would like to again thank everyone that helped contribute to this project.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$42.42
- [Liberapay](https://liberapay.com/omarroth) : \$70.11
- Crypto : ~\$1.76 (converted from BCH, BTC, BSV)
- Total : \$114.29

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node5 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$80.00

This past month the site saw a couple abnormal peaks in traffic, so an additional webserver has been added to match the increased load. The goal on Patreon has been updated to match the above expenses.

Thanks everyone!

# 0.15.0 (2019-03-06)

## Version 0.15.0: Preferences and Channel Playlists

The project has seen quite a bit of activity this past month. Large focus has been on fixing bugs, but there's still quite a few new features I'm happy to announce. There have been [133 commits](https://github.com/omarroth/invidious/compare/0.14.0...0.15.0) from 15 contributors this past month.

As a couple miscellaneous changes, a couple [nice screenshots](https://github.com/omarroth/invidious#screenshots) have been added to the README, so folks can see more of what the site has to offer without creating an account.

The footer has also been cleaned up quite a bit, and now displays the current version, so it's easier to know what features are available from the current instance.

## For Administrators

This past month there has been a minor release - `0.14.1` - which fixes a breaking change made by YouTube for their polymer redesign.

There have been several new features that unfortunately require a database migration. There are migration scripts provided in `config/migrate-scripts`, and the [wiki](https://github.com/omarroth/invidious/wiki/Updating) has instructions for automatically applying them. I'll do my best to keep those changes to a minimum, and expect to see a corresponding script to automatically apply any new changes.

Administrator preferences have been added with [#312](https://github.com/omarroth/invidious/issues/312), which allows administrators to customize their instance. Administrators can change the order of feed menus, change the default homepage, disable open registration, and several other options. There's a short 'how-to' [here](https://github.com/omarroth/invidious/issues/312#issuecomment-468831842), and the new options are documented [here](https://github.com/omarroth/invidious/wiki/Configuration).

An `/api/v1/stats` endpoint has been added with [#356](https://github.com/omarroth/invidious/issues/356), which reports the instance version and number of active users. Statistics are disabled by default, and can be enabled in administator preferences. Statistics for the official instance are available [here](https://invidio.us/api/v1/stats?pretty=1).

## For Developers

`/api/v1/channels/:ucid` now provides an `autoGenerated` tag, which returns true for topic channels, and larger genre channels generated by YouTube. These channels don't have any videos of their own, so `latestVideos` will be empty. It is recommended instead to display a list of playlists generated by YouTube.

You can now pull a list of playlists from a channel with `/api/v1/channels/playlists/:ucid`. Supported options are documented in the [wiki](https://github.com/omarroth/invidious/wiki/API#get-apiv1channelsplaylistsucid-apiv1channelsucidplaylists). Pagination is handled with a `continuation` token, which is generated on each call. Of note is that auto-generated channels currently have one page of results, and subsequent calls will be empty.

For quickly pulling the latest 30 videos from a channel, there is now `/api/v1/channels/latest/:ucid`. It is much faster than a call to `/api/v1/channels/:ucid`. It will not convert an author name to a valid ucid automatically, and will not return any extra data about a channel.

## Preferences

In addition to administrator preferences mentioned above, you can now change your preferences without an account (see [#42](https://github.com/omarroth/invidious/pull/42)). I think this is quite an improvement to the usability of the site, and is much friendlier to privacy-conscious folks that don't want to make an account. Preferences will be automatically imported to a newly created account.

Several issues with sorting subscriptions have been fixed, and `/manage_subscriptions` has been sped up significantly. The subscription feed has also seen a bump in performance. Delayed notifications have unfortunately started becoming a problem now that there are more users on the site. Some new changes are currently being tested which should mostly resolve the issue, so expect to see more in the next release.

## Channel Playlists

You can now view available playlists from a channel, and [auto-generated channels](https://invidio.us/channel/UC-9-kyTW8ZkZNDHQJ6FgpwQ) are no longer empty. You can sort as you would on YouTube, and all the same functionality should be available. I'm quite pleased to finally have it implemented, since it's currently the only data available from the above mentioned auto-generated channels, and makes it much easier to consume music on the site.

There's also more discussion on improving Invidious for streaming music in [#304](https://github.com/omarroth/invidious/issues/304), and adding support for music.youtube.com. I would appreciate any thoughts on how to improve that experience, since it's a very large and useful part of YouTube.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$42.42
- [Liberapay](https://liberapay.com/omarroth) : \$30.97
- Crypto : ~\$0.00 (converted from BCH, BTC)
- Total : \$73.39

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$75.00

It's been very humbling to see how fast the project has grown, and I look forward to making the site even better. Thank you everyone.

# 0.14.0 (2019-02-06)

## Version 0.14.0: Community

This last month several contributors have made improvements specifically for the people using this project. New pages have been added to the wiki, and there is now a [Matrix Server](https://riot.im/app/#/room/#invidious:matrix.org) and IRC channel so it's easier and faster for people to ask questions or chat. There have been [101 commits](https://github.com/omarroth/invidious/compare/0.13.0...0.14.0) since the last major release from 8 contributors.

It has come to my attention in the past month how many people are self-hosting, and I would like to make it easier for them to do so.

With that in mind, expect future releases to have a section for For Administrators (if any relevant changes) and For Developers (if any relevant changes).

## For Administrators

This month the most notable change for administrators is releases. As always, there will be a major release each month. However, a new minor release will be made whenever there are any critical bugs that need to be fixed.

This past month is the first time there has been a minor release - `0.13.1` - which fixes a breaking change made by YouTube. Administrators using versioning for their instances will be able to rely on the latest version, and should have a system in place to upgrade their instance as soon as a new release is available.

Several new pages have been added to the [wiki](https://github.com/omarroth/invidious/wiki#for-administrators) (as mentioned below) that will help administrators better setup their own instances. Configuration, maintenance, and instructions for updating are of note, as well as several common issues that are encountered when first setting up.

## For Developers

There's now a `pretty=1` parameter for most endpoints so you can view data easily from the browser, which is convenient for debugging and casual use. You can see an example [here](https://invidio.us/api/v1/videos/CvFH_6DNRCY?pretty=1).

Unfortunately the `/api/v1/insights/:id` endpoint is no longer functional, as YouTube removed all publicly available analytics around a month ago. The YouTube endpoint now returns a 404, so it's unlikely it will be functional again.

## Wiki

There have been a sizable number of changes to the Wiki, including a [list of public Invidious instances](https://github.com/omarroth/invidious/wiki/Invidious-Instances), the [list of extensions](https://github.com/omarroth/invidious/wiki/Extensions), and documentation for administrators (as mentioned above) and developers.

The wiki is editable by anyone so feel free to add anything you think is useful.

## Matrix & IRC

Thee is now a [Matrix Server](https://riot.im/app/#/room/#invidious:matrix.org) for Invidious, so please feel free to hop on if you have any questions or want to chat. There is also a registered IRC channel: #invidious on Freenode which is bridged to Matrix.

## Features

Several new features have been added, including a download button, creator hearts and comment colors, and a French translation.

There have been fixes for Google logins, missing text in locales, invalid links to genre channels, and better error handling in the player, among others.

Several fixes and features are omitted for space, so I'd recommend taking a look at the [compare tab](https://github.com/omarroth/invidious/compare/0.13.0...0.14.0) for more information.

## Annotations Update

Annotations were removed January 15th, 2019 around15:00 UTC. Before they were deleted we were able to archive annotations from around 1.4 billion videos. I'd very much recommend taking a look [here](https://www.reddit.com/r/DataHoarder/comments/al7exa/youtube_annotation_archive_update_and_preview/) for more information and a list of acknowledgements. I'm extremely thankful to everyone who was able to contribute and I'm glad we were able to save such a large part of internet history.

There's been large strides in supporting them in the player as well, which you can follow in [#303](https://github.com/omarroth/invidious/pull/303). You can preview the functionality at https://dev.invidio.us . Before they are added to the main site expect to see an option to disable them, both site-wide and per video.

Organizing this project has unfortunately taken up quite a bit of my time, and I've been very grateful for everyone's patience.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth) : \$49.42
- [Liberapay](https://liberapay.com/omarroth) : \$27.89
- Crypto : ~\$0.00 (converted from BCH, BTC)
- Total : \$77.31

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$75.00

As always I'm grateful for everyone's contributions and support. I'll see you all in March.

# 0.13.1 (2019-01-19)

##

# 0.13.0 (2019-01-06)

## Version 0.13.0: Translations, Annotations, and Tor

I hope everyone had a happy New Year! There's been a couple new additions since last release, with [44 commits](https://github.com/omarroth/invidious/compare/0.12.0...0.13.0) from 9 contributors. It's been quite a year for the project, and I hope to continue improving the project into 2019! Starting off the new year:

## Translations

I'm happy to announce support for translations has been added with [`a160c64`](https://github.com/omarroth/invidious/a160c64). Currently, there is support for:

- Arabic (`ar`)
- Dutch (`nl`)
- English (`en-US`)
- German (`de`)
- Norwegian Bokmål (`nb_NO`)
- Polish (`pl`)
- Russian (`ru`)

Which you can change in your preferences under `Language`. You can also add `&hl=LANGUAGE` to the end of any request to translate it to your preferred language, for example https://invidio.us/?hl=ru. I'd like to say thank you again to everyone who has helped translate the site! I've mentioned this before, but I'm delighted that so many people find the project useful.

## Annotations

Recently, [YouTube announced that all annotations will be deleted on January 15th, 2019](https://support.google.com/youtube/answer/7342737). I believe that annotations have a very important place in YouTube's history, and [announced a project to archive them](https://www.reddit.com/r/DataHoarder/comments/aa6czg/youtube_annotation_archive/).

I expect annotations to be supported in the Invidious player once archiving is complete (see [#110](https://github.com/omarroth/invidious/issues/110) for details), and would also like to host them for other developers to use in their projects.

The code is available [here](https://github.com/omarroth/archive), and contains instructions for running a worker if you would like to contribute. There's much more information available in the announcement as well for anyone who is interested.

## Tor

I unfortunately missed the chance to mention this in the previous release, but I'm now happy to announce that you can now view Invidious through Tor at the following links:

kgg2m7yk5aybusll.onion  
axqzx4s6s54s32yentfqojs3x5i7faxza6xo3ehd4bzzsg2ii4fv2iid.onion

Invidious is well suited to use through Tor, as it does not require any JS and is fairly lightweight. I'd recommend looking [here](https://diasp.org/posts/10965196) and [here](https://www.reddit.com/r/TOR/comments/a3c1ak/you_can_now_watch_youtube_videos_anonymously_with/) for more details on how to use the onion links, and would like to say thank you to [/u/whonix-os](https://www.reddit.com/user/whonix-os) for suggesting it and providing support setting setting them up.

## Popular and Trending

You can now easily view videos trending on YouTube with [`a16f967`](https://github.com/omarroth/invidious/a16f967). It also provides support for viewing YouTube's various categories categories, such as `News`, `Gaming`, and `Music`. You can also change the `region` parameter to view trending in different countries, which should be made easier to use in the coming weeks.

A link to `/feed/popular` has also been added, which provides a list of videos sorted using the algorithm described [here](https://github.com/omarroth/invidious/issues/217#issuecomment-436503761). I think it better reflects what users watch on the site, but I'd like to hear peoples' thoughts on this and on how it could be improved.

## Finances

### Donations

- [Patreon](https://www.patreon.com/omarroth): \$64.63
- [Liberapay](https://liberapay.com/omarroth) : \$30.05
- Crypto : ~\$28.74 (converted from BCH, BTC)
- Total : \$123.42

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$75.00

### What will happen with what's left over?

I believe this is the first month that all expenses have been fully paid for by donations. Thank you! I expect to allocate the current amount for hardware to improve performance and for hosting annotation data, as mentioned above.

Anything that is left over is kept to continue hosting the project for as long as possible. Thank you again everyone!

I think that's everything for 2018. There's lots still planned, and I'm very excited for the future of this project!

# 0.12.0 (2018-12-06)

## Version 0.12.0: Accessibility, Privacy, Transparency

Hello again, it's been a while! A lot has happened since the last release. Invidious has seen [134 commits](https://github.com/omarroth/invidious/compare/0.11.0...0.12.0) from 3 contributors, and I'm quite happy with the progress that has been made. I enjoyed this past month, and I believe having a monthly release schedule allows me to focus on more long-term improvements, and I hope people enjoy these more substantial updates as well.

## Accessability and Privacy

There have been quite a few improvements for user privacy, and improvements that improve accessibility for both people and software.

You can now view comments without JS with [`19516ea`](https://github.com/omarroth/invidious/19516ea). Currently, this functionality is limited to the first 20 comments, but expect this functionality to be improved to come as close to the JS version as possible. Folks can track progress in [#204](https://github.com/omarroth/invidious/issues/204).

Invidious is now compatible with [LibreJS](https://www.gnu.org/software/librejs/), and provides license information [here](https://invidio.us/licenses) with [`7f868ec`](https://github.com/omarroth/invidious/7f868ec). As expected, all libraries are compatible under the AGPLv3, and I'm happy to mention that no other changes were required to make Invidious compatible with LibreJS.

A DNT policy has also been added with [`9194f47`](https://github.com/omarroth/invidious/9194f47) for compatibility with [Privacy Badger](https://www.eff.org/privacybadger). I'm pleased to mention that here too no other changes had to be made in order for Invidious to be compatible with this extension. I expect a privacy policy to be added soon as well, so users can better understand how Invidious uses their data.

For users that are visually impaired, there is now a text CAPTCHA available so it's easier to register and login. Because of the simple front-end of the project, I expect screen readers and other software to be able to easily understand the site's interface. In combination with the ability to listen-only, I believe Invidious is much more accessible than YouTube. Folks can read [#244](https://github.com/omarroth/invidious/issues/244) for more details, and I would very much appreciate any feedback on how this can be improved.

## User Preferences

There have been a lot of improvements to preferences. Options for enabling audio-only by default and continuous playback (autoplay) have been added with [`e39dec9`](https://github.com/omarroth/invidious/e39dec9), with [`4b76b93`](https://github.com/omarroth/invidious/4b76b93), respectively. Users can also now mark videos as watched from their subscription feed and view watch history by going to https://invidio.us/feed/history. I expect to add more information to history so that it's easier to use. Folks can track progress with [#182](https://github.com/omarroth/invidious/issues/182). As with all data Invidious keeps, watch history can be exported [here](https://invidio.us/data_control).

Users can now delete their account with [`b9c29bf`](https://github.com/omarroth/invidious/b9c29bf). This will remove _all_ user data from Invidious, including session IDs, watch history, and subscriptions. As mentioned above, it's easy to export that data and import it to a local instance, or export subscriptions for use with other applications such as [FreeTube](https://github.com/FreeTubeApp/FreeTube) or [NewPipe](https://github.com/TeamNewPipe/NewPipe).

## Translation and Internationalis(z)ation

Invidious has been approved for hosting by Weblate, available [here](https://hosted.weblate.org/projects/invidious/translations/). At the time of writing, translations for Arabic, Dutch, German, Polish, and Russian are currently underway. I would like to say a very big thank you to everyone working on them, and I hope to fully support them within around 2 weeks. Folks can track progress with [#251](https://github.com/omarroth/invidious/issues/251).

## Transperency and Finances

For the sake of transparency, I plan on publishing each month's finances. This is currently already done on Liberapay and Patreon, but there is not a total amount currently provided anywhere, and I would also like to include expenses to provide a better explanation of how patrons' money is being spent.

### Donations

- [Patreon](https://www.patreon.com/omarroth): \$43.60 (Patreon takes roughly 9%)
- [Liberapay](https://liberapay.com/omarroth) : \$22.10
- Crypto : ~\$1.25 (converted from BCH, BTC)
- Total : \$66.95

### Expenses

- invidious-load1 (nyc1) : \$10.00 (load balancer)
- invidious-update1 (s-1vcpu-1gb) : \$5.00 (updates feeds)
- invidious-node1 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node2 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node3 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-node4 (s-1vcpu-1gb) : \$5.00 (web server)
- invidious-db1 (s-4vcpu-8gb) : \$40.00 (database)
- Total : \$75.00

I'd be happy to provide any explanation where needed. I would also like to thank everyone who donates, it really helps and I can't say how happy I am to see that so many people find it valuable.

That's all for this month. I wish everyone the best for the holidays, and I'll see you all again in January!

# 0.11.0 (2018-10-23)

## Week 11: FreeTube and Styling

This past Friday I'm been very excited to see that FreeTube version [0.4.0](https://github.com/FreeTubeApp/FreeTube/tree/0.4.0) has been released! I'd recommend taking a look at the official patch notes, but to spoil a little bit here: FreeTube now uses the Invidious API for _all_ requests previously sent to YouTube, and has also seen support for playlists, keyboard shortcuts, and more default settings (speed, autoplay, and subtitles). I'm happy to see that FreeTube has reached 500 stars on Github, and I think it's very much deserved. I'd recommend keeping an eye on the newly-launched [FreeTube blog](https://freetube.writeas.com/) for updates on the project.

Quite a few styling changes have been added this past week, including channel subscriber count to the subscribe and unsubscribe buttons. The changes sound small, but they've been a very big improvement and I'm quite satisfied with how they look. Also to note is that partial support for duration in thumbnails have been added with [#202](https://github.com/omarroth/invidious/issues/202). Overall, I think the site is becoming much more pleasing visually, and I hope to continue to improve it.

I've been very pleased to see Invidious in its current state, and I believe it's many times more mature compared to even a month ago. Changes have also started slowing down a bit as it's become more mature, and therefore I'd like to transition to a monthly update schedule in order to provide more comprehensive updates for everyone. I want to thank you all for helping me reach this point. I can't say how happy I am for Invidious to be where it is now.

Enjoy the rest of your week everyone, I'll see you in November!

# 0.10.0 (2018-10-16)

## Week 10: Subscriptions

This week I'm happy to announce that subscriptions have been drastically sped up with
35e63fa. As I mentioned last week, this essentially "caches" a user's feed, meaning that operations that previously took 20 seconds or timed out, now can load in under a second. I'd take a look at [#173](https://github.com/omarroth/invidious/issues/173) for a sample benchmark. Previously features that made Invidious's feed so useful, such as filtering by unseen and by author would take too long to load, and so instead would timeout. I'm very happy that this has been fixed, and folks can get back to using these features.

Among some smaller features that have been added this week include [#118](https://github.com/omarroth/invidious/issues/118), which adds, in my opinion, some very attractive subscribe and unsubscribe buttons. I think it's also a bit of a functional improvement as well, since it doesn't require a user to reload the page in order to subscribe or unsubscribe to a channel, and also gives the opportunity to put the channel's sub count on display.

An option to swap between Reddit and YouTube comments without a page reload has been added with
5eefab6, bringing it somewhat closer in functionality to the popular [AlienTube](https://github.com/xlexi/alientube) extension, on which it is based (although the extension unfortunately appears now to be fragmented).

As always, there are a couple smaller improvements this week, including some minor fixes for geo-bypass with
e46e618 and [`245d0b5`](https://github.com/omarroth/invidious/245d0b5), playlist preferences with [`81b4477`](https://github.com/omarroth/invidious/81b4477), and YouTube comments with [`02335f3`](https://github.com/omarroth/invidious/02335f3).

This coming week I'd also recommend keeping an eye on the excellent [FreeTube](https://github.com/FreeTubeApp/FreeTube), which is looking forward to a new release. I've been very lucky to work with [**@PrestonN**](https://github.com/PrestonN) for the past few weeks to improve the Invidious API, and I'm quite looking forward to the new release.

That's all for this week folks, thank you all again for your continued interest and support.

# 0.9.0 (2018-10-08)

## Week 9: Playlists

Not as much to announce this week, but I'm still quite happy to announce a couple things, namely:

Playback support for playlists has finally been added with [`88430a6`](https://github.com/omarroth/invidious/88430a6). You can now view playlists with the `&list=` query param, as you would on YouTube. You can also view mixes with the mentioned `&list=`, although they require some extra handling that I would like to add in the coming week, as well as adding playlist looping and shuffle. I think playback support has been a roadblock for more exciting features such as [#114](https://github.com/omarroth/invidious/issues/114), and I look forward to improving the experience.

Comments have had a bit of a cosmetic upgrade with [#132](https://github.com/omarroth/invidious/issues/132), which I think helps better distinguish between Reddit and YouTube comments, as it makes them appear similarly to their respective sites. You can also now switch between YouTube and Reddit comments with a push of a button, which I think is quite an improvement, especially for newer or less popular videos with fewer comments.

I've had a small breakthrough in speeding up users' subscription feeds with PostgreSQL's [materialized views](https://www.postgresql.org/docs/current/static/rules-materializedviews.html). Without going into too much detail, materialized views essentially cache the result of a query, making it possible to run resource-intensive queries once, rather than every time a user visits their feed. In the coming week I hope to push this out to users, and hopefully close [#173](https://github.com/omarroth/invidious/issues/173).

I haven't had as much time to work on the project this week, but I'm quite happy to have added some new features. Have a great week everyone.

# 0.8.0 (2018-10-02)

## Week 8: Mixes

Hello again!

Mixes have been added with [`20130db`](https://github.com/omarroth/invidious/20130db), which makes it easy to create a playlist of related content. See [#188](https://github.com/omarroth/invidious/issues/188) for more info on how they work. Currently, they return the first 50 videos rather than a continuous feed to avoid tracking by Google/YouTube, which I think is a good trade-off between usability and privacy, and I hope other folks agree. You can create mixes by adding `RD` to the beginning of a video ID, an example is provided [here](https://www.invidio.us/mix?list=RDYE7VzlLtp-4) based on Big Buck Bunny. I've been quite happy with the results returned for the mixes I've tried, and it is not limited to music, which I think is a big plus. To emulate a continuous feed provided many are used to, using the last video of each mix as a new 'seed' has worked well for me. In the coming week I'd like to to add playback support in the player to listen to these easily.

A very big thanks to [**@flourgaz**](https://github.com/flourgaz) for Docker support with [#186](https://github.com/omarroth/invidious/pull/186). This is an enormous improvement in portability for the project, and opens the door for Heroku support (see [#162](https://github.com/omarroth/invidious/issues/162)), and seamless support on Windows. For most users, it should be as easy as running `docker-compose up`.

I've spent quite a bit of time this past week improving support for geo-bypass (see [#92](https://github.com/omarroth/invidious/issues/92)), and am happy to note that Invidious has been able to proxy ~50% of the geo-restricted videos I've tried. In addition, you can now watch geo-restricted videos if you have `dash` enabled as your `preferred quality`, for more details see [#34](https://github.com/omarroth/invidious/issues/34) and [#185](https://github.com/omarroth/invidious/issues/185), or last week's update. For folks interested in replicating these results for themselves, I'd take a look [here](https://gist.github.com/omarroth/3ce0f276c43e0c4b13e7d9cd35524688) for the script used, and [here](https://gist.github.com/omarroth/beffc4a76a7b82a422e1b36a571878ef) for a list of videos restricted in the US.

1080p has seen a fairly smooth roll-out, although there have been a couple issues reported, mainly [#193](https://github.com/omarroth/invidious/issues/193), which is likely an issue in the player. I've also encountered a couple other issues myself that I would like to investigate. Although none are major, I'd like to keep 1080p opt-in for registered users another week to better address these issues.

Have an excellent week everyone.

# 0.7.0 (2018-09-25)

## Week 7: 1080p and Search Types

Hello again everyone! I've got quite a couple announcements this week:

Experimental 1080p support has been added with [`b3ca392`](https://github.com/omarroth/invidious/b3ca392), and can be enabled by going to preferences and changing `preferred video quality` to `dash`. You can find more details [here](https://github.com/omarroth/invidious/issues/34#issuecomment-424171888). Currently quality and speed controls have not yet been integrated into the player, but I'd still appreciate feedback, mainly on any issues with buffering or DASH playback. I hope to integrate 1080p support into the player and push support site-wide in the coming weeks.

You can now filter content types in search with the `type:TYPE` filter. Supported content types are `playlist`, `channel`, and `video`. More info is available [here](https://github.com/omarroth/invidious/issues/126#issuecomment-423823148). I think this is quite an improvement in usability and I hope others find the same.

A [CHANGELOG](https://github.com/omarroth/invidious/blob/master/CHANGELOG.md) has been added to the repository, so folks will now receive a copy of all these updates when cloning. I think this is an improvement in hosting the project, as it is no longer tied to the `/releases` tab on Github or the posts on Patreon.

Recently, users have been reporting 504s when attempting to access their subscriptions, which is tracked in [#173](https://github.com/omarroth/invidious/issues/173). This is most likely caused by an uptick in usage, which I am absolutely grateful for, but unfortunately has resulted in an increase in costs for hosting the site, which is why I will be bumping my goal on Patreon from $60 to $80. I would appreciate any feedback on how subscriptions could be improved.

Other minor improvements include:

- Additional regions added to bypass geo-block with [`9a78523`](https://github.com/omarroth/invidious/9a78523)
- Fix for playlists containing less than 100 videos (previously shown as empty) with [`35ac887`](https://github.com/omarroth/invidious/35ac887)
- Fix for `published` date for Reddit comments (previously showing negative seconds) with [`6e09202`](https://github.com/omarroth/invidious/6e09202)

Thank you everyone for your support!

# 0.6.0 (2018-09-18)

## Week 6: Filters and Thumbnails

Hello again! This week I'm happy to mention a couple new features to search as well as some miscellaneous usability improvements.

You can now constrain your search query to a specific channel with the `channel:CHANNEL` filter (see [#165](https://github.com/omarroth/invidious/issues/165) for more details). Unfortunately, other search filters combined with channel search are not yet supported. I hope to add support for them in the coming weeks.

You can also now search only your subscriptions by adding `subscriptions:true` to your query (see [#30](https://github.com/omarroth/invidious/issues/30) for more details). It's not quite ready for widespread use but I would appreciate feedback as the site updates to fully support it. Other search filters are not yet supported with `subscriptions:true`, but I hope to add more functionality to this as well.

With [#153](https://github.com/omarroth/invidious/issues/153) and [#168](https://github.com/omarroth/invidious/issues/168) all images on the site are now proxied through Invidious. In addition to offering the user more protection from Google's eyes, it also allows the site to automatically pick out the highest resolution thumbnail for videos. I think this is quite a large aesthetic improvement and I hope others will find the same.

As a smaller improvement to the site, you can also now view RSS feeds for playlists with [#113](https://github.com/omarroth/invidious/issues/113).

These updates are also now listed under Github's [releases](https://github.com/omarroth/invidious/releases). I'm also planning on adding them as a `CHANGELOG.md` in the repository itself so people can receive a copy with the project's source.

That's all for this week. Thank you everyone for your support!

# 0.5.0 (2018-09-11)

## Week 5: Privacy and Security

I hope everyone had a good weekend! This past week I've been fixing some issues that have been brought to my attention to help better protect users and help them keep their anonymity.

An issue with open referers has been fixed with [`29a2186`](https://github.com/omarroth/invidious/29a2186), which prevents potential redirects to external sites on actions such as login or modifying preferences.

Additionally, X-XSS-Protection, X-Content-Type-Options, and X-Frame-Options headers have been added with [`96234e5`](https://github.com/omarroth/invidious/96234e5), which should keep users safer while using the site.

A potential XSS vector has also been fixed in YouTube comments with [`8c45694`](https://github.com/omarroth/invidious/8c45694).

All the above vulnerabilities were brought to my attention by someone who wishes to remain anonymous, but I would like to say again here how thankful I am. If anyone else would like to get in touch please feel free to email me at omarroth@hotmail.com or omarroth@protonmail.com.

This week a couple changes have been made to better protect user's privacy as well.
All CSS and JS assets are now served locally with [`3ec684a`](https://github.com/omarroth/invidious/3ec684a), which means users no longer need to whitelist unpkg.com. Although I personally have encountered few issues, I understand that many folks would like to keep their browsing activity contained to as few parties as possible. In the coming week I also hope to proxy YouTube images, so that no user data is sent to Google.

YouTube links in comments now should redirect properly to the Invidious alternate with [`1c8bd67`](https://github.com/omarroth/invidious/1c8bd67) and [`cf63c82`](https://github.com/omarroth/invidious/cf63c82), so users can more easily evade Google tracking.

I'm also happy to mention a couple quality of life features this week:

Invidious now shows a video's "license" if provided, see [#159](https://github.com/omarroth/invidious/issues/159) for more details. You can also search for videos licensed under the creative commons with "QUERY features:creative_commons".

Videos with only one source will always display the cog for changing quality, so that users can see what quality is currently playing. See [#158](https://github.com/omarroth/invidious/issues/158) for more details.

Folks have also probably noticed that the gutters on either side of the screen have been shrunk down quite significantly, so that more of the screen is filled with content. Hopefully this can be improved even more in the coming weeks.

"Music", "Sports", and "Popular on YouTube" channels now properly display their videos. You can subscribe to these channels just as you would normally.

This coming week I'm planning on spending time with my family, so I unfortunately may not be as responsive. I do still hope to add some smaller features for next week however, and I hope to continue development soon.
Thank you everyone again for your support.

# 0.4.0 (2018-09-06)

## Week 4: Genre Channels

Hello! I hope everyone enjoyed their weekend. Without further ado:
Just today genre channels have been added with [#119](https://github.com/omarroth/invidious/issues/119). More information on genre channels is available [here](https://support.google.com/youtube/answer/2579942). You can subscribe to them as normally, and view them as RSS. I think they offer an interesting alternative way to find new content and I hope people find them useful.

This past week folks have started reporting 504s on their subscription page (see [#144](https://github.com/omarroth/invidious/issues/144) for more details). Upgrading the database server appeared to fix the issue, as well as providing a smoother experience across the site. Unfortunately, that means I will be increasing the goal from $50 to $60 in order to meet the increased hosting costs.

With [#134](https://github.com/omarroth/invidious/issues/134), comments are now formatted correctly, providing support for bold, italics, and links in comments. I think this improvement makes them much easier to read, and I hope others find the same. Also to note is that links in both comments and the video description now no longer contain any of Google's tracking with [#115](https://github.com/omarroth/invidious/issues/115).

One of the major use cases for Invidious is as a stripped-down version of YouTube. In line with that, I'm happy to announce that you can now hide related videos if you're logged in, for users that prefer an even more lightweight experience.

Finally, I'm pleased to announce that Invidious has hit 100 stars on GitHub. I am very happy that Invidious has proven to be useful to so many people, and I can't say how grateful I am to everyone for their continued support.

Enjoy the rest of your week everyone!

# 0.3.0 (2018-09-06)

## Week 3: Quality of Life

Hello everyone! This week I've been working on some smaller features that will hopefully make the site more functional.
Search filters have been added with [#126](https://github.com/omarroth/invidious/issues/126). You can now specify 'sort', 'date', 'duration', and 'features' within your query using the 'operator:value' syntax. I'd recommend taking a look [here](https://github.com/omarroth/invidious/blob/master/src/invidious/search.cr#L33-L114) for a list of supported options and at [#126](https://github.com/omarroth/invidious/issues/126) for some examples. This also opens the door for features such as [#30](https://github.com/omarroth/invidious/issues/30) which can be implemented as filters. I think advanced search is a major point in which Invidious can improve on YouTube and hope to add more features soon!

This week a more advanced system for viewing fallback comments has been added (see [#84](https://github.com/omarroth/invidious/issues/84) for more details). You can now specify a comment fallback in your preferences, which Invidious will use. If, for example, no Reddit comments are available for a given video, it can choose to fallback on YouTube comments. This also makes it possible to turn comments off completely for users that prefer a more streamlined experience.

With [#98](https://github.com/omarroth/invidious/issues/98), it is now possible for users to specify preferences without creating an account. You can now change speed, volume, subtitles, autoplay, loop, and quality using query parameters. See the issue above for more details and several examples.

I'd also like to announce that I've set up an account on [Liberapay](https://liberapay.com/omarroth), for patrons that prefer a privacy-friendly alternative to Patreon. Liberapay also does not take any percentage of donations, so I'd recommend donating some to the Liberapay for their hard work. Go check it out!

[Two weeks ago](https://github.com/omarroth/invidious/releases/tag/0.1.0) I mentioned adding 1080p support into the player. Currently, the only thing blocking is [#207](https://github.com/videojs/http-streaming/pull/207) in the excellent [http-streaming](https://github.com/videojs/http-streaming) library. I hope to work with the videojs team to merge it soon and finally implement 1080p support!

That's all for this week, thank you again everyone for your support!

# 0.2.0 (2018-09-06)

## Week 2: Toward Playlists

Sorry for the late update! Not as much to announce this week, but still a couple things of note:
I'm happy to announce that a playlists page and API endpoint has been added so you can now view playlists. Currently, you cannot watch playlists through the player, but I hope to add that in the coming week as well as adding functionality to add and modify playlists. There is a good conversation on [#114](https://github.com/omarroth/invidious/issues/114) about giving playlists even more functionality, which I think is interesting and would appreciate feedback on.

As an update to the Invidious API announcement last week, I've been working with [**@PrestonN**](https://github.com/PrestonN), the developer of [FreeTube](https://github.com/FreeTubeApp/FreeTube), to help migrate his project to the Invidious API. Because of it's increasing popularity, he has had trouble keeping under the quota set by YouTube's API. I hope to improve the API to meet his and others needs and I'd recommend folks to keep an eye on his excellent project! There is a good discussion with his thoughts [here](https://github.com/FreeTubeApp/FreeTube/issues/100).

A couple of miscellaneous features and bugfixes:

- You can now login to Invidious simultaneously from multiple devices - [#109](https://github.com/omarroth/invidious/issues/109)

- Added a note for scheduled livestreams - [#124](https://github.com/omarroth/invidious/issues/124)

- Changed YouTube comment header to "View x comments" - [#120](https://github.com/omarroth/invidious/issues/120)

Enjoy your week everyone!

# 0.1.0 (2018-09-06)

## Week 1: Invidious API and Geo-Bypass

Hello everyone! This past week there have been quite a few things worthy of mention:

I'm happy to announce the [Invidious Developer API](https://github.com/omarroth/invidious/wiki/API). The Invidious API does not use any of the official YouTube APIs, and instead crawls the site to provide a JSON interface for other developers to use. It's still under development but is already powering [CloudTube](https://github.com/cloudrac3r/cadencegq). The API currently does not have a quota (compared to YouTube) which I hope to continue thanks to continued support from my Patrons. Hopefully other developers find it useful, and I hope to continue to improve it so it can better serve the community.

Just today partial support for bypassing geo-restrictions has been added with [fada57a](https://github.com/omarroth/invidious/commit/fada57a307d66d696d9286fc943c579a3fd22de6). If a video is unblocked in one of: United States, Canada, Germany, France, Japan, Russia, or United Kingdom, then Invidious will be able to serve video info. Currently you will not yet be able to access the video files themselves, but in the coming week I hope to proxy videos so that users can enjoy content across borders.

Support for generating DASH manifests has been fixed, in the coming week I hope to integrate this functionality into the watch page, so users can view videos in 1080p and above.

Thank you everyone for your continued interest and support!
