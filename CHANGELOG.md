# 0.6.0 (2018-09-18)

## Week 6: Filters and Thumbnails

Hello again! This week I'm happy to mention a couple new features to search as well as some miscellaneous usability improvements.

You can now constrain your search query to a specific channel with the `channel:CHANNEL` filter (see #165 for more details). Unfortunately, other search filters combined with channel search are not yet supported. I hope to add support for them in the coming weeks. 

You can also now search only your subscriptions by adding `subscriptions:true` to your query (see #30 for more details). It's not quite ready for widespread use but I would appreciate feedback as the site updates to fully support it. Other search filters are not yet supported with `subscriptions:true`, but I hope to add more functionality to this as well.

With #153 and #168 all images on the site are now proxied through Invidious. In addition to offering the user more protection from Google's eyes, it also allows the site to automatically pick out the highest resolution thumbnail for videos. I think this is quite a large aesthetic improvement and I hope others will find the same.

As a smaller improvement to the site, you can also now view RSS feeds for playlists with #113.

These updates are also now listed under Github's [releases](https://github.com/omarroth/invidious/releases). I'm also planning on adding them as a `CHANGELOG.md` in the repository itself so people can receive a copy with the project's source.

That's all for this week. Thank you everyone for your support!

# 0.5.0 (2018-09-11)

## Week 5: Privacy and Security

I hope everyone had a good weekend! This past week I've been fixing some issues that have been brought to my attention to help better protect users and help them keep their anonymity.

An issue with open referers has been fixed with 29a2186, which prevents potential redirects to external sites on actions such as login or modifying preferences.

Additionally, X-XSS-Protection, X-Content-Type-Options, and X-Frame-Options headers have been added with 96234e5, which should keep users safer while using the site.

A potential XSS vector has also been fixed in YouTube comments with 8c45694.

All the above vulnerabilities were brought to my attention by someone who wishes to remain anonymous, but I would like to say again here how thankful I am. If anyone else would like to get in touch please feel free to email me at omarroth@hotmail.com or omarroth@protonmail.com.

This week a couple changes have been made to better protect user's privacy as well. 
All CSS and JS assets are now served locally with 3ec684a, which means users no longer need to whitelist unpkg.com. Although I personally have encountered few issues, I understand that many folks would like to keep their browsing activity contained to as few parties as possible. In the coming week I also hope to proxy YouTube images, so that no user data is sent to Google.

YouTube links in comments now should redirect properly to the Invidious alternate with 1c8bd67 and cf63c82, so users can more easily evade Google tracking.

I'm also happy to mention a couple quality of life features this week:

Invidious now shows a video's "license" if provided, see #159 for more details. You can also search for videos licensed under the creative commons with "QUERY features:creative_commons".

Videos with only one source will always display the cog for changing quality, so that users can see what quality is currently playing. See #158 for more details.

Folks have also probably noticed that the gutters on either side of the screen have been shrunk down quite significantly, so that more of the screen is filled with content. Hopefully this can be improved even more in the coming weeks.

"Music", "Sports", and "Popular on YouTube" channels now properly display their videos. You can subscribe to these channels just as you would normally.

This coming week I'm planning on spending time with my family, so I unfortunately may not be as responsive. I do still hope to add some smaller features for next week however, and I hope to continue development soon.
Thank you everyone again for your support.

# 0.4.0 (2018-09-06)

## Week 4: Genre Channels

Hello! I hope everyone enjoyed their weekend. Without further ado:
Just today genre channels have been added with #119. More information on genre channels is available [here](https://support.google.com/youtube/answer/2579942). You can subscribe to them as normally, and view them as RSS. I think they offer an interesting alternative way to find new content and I hope people find them useful.

This past week folks have started reporting 504s on their subscription page (see #144 for more details). Upgrading the database server appeared to fix the issue, as well as providing a smoother experience across the site. Unfortunately, that means I will be increasing the goal from $50 to $60 in order to meet the increased hosting costs.

With #134, comments are now formatted correctly, providing support for bold, italics, and links in comments. I think this improvement makes them much easier to read, and I hope others find the same. Also to note is that links in both comments and the video description now no longer contain any of Google's tracking with #115.

One of the major use cases for Invidious is as a stripped-down version of YouTube. In line with that, I'm happy to announce that you can now hide related videos if you're logged in, for users that prefer an even more lightweight experience.

Finally, I'm pleased to announce that Invidious has hit 100 stars on GitHub. I am very happy that Invidious has proven to be useful to so many people, and I can't say how grateful I am to everyone for their continued support.

Enjoy the rest of your week everyone!

# 0.3.0 (2018-09-06)

## Week 3: Quality of Life

Hello everyone! This week I've been working on some smaller features that will hopefully make the site more functional.
Search filters have been added with #126. You can now specify 'sort', 'date', 'duration', and 'features' within your query using the 'operator:value' syntax. I'd recommend taking a look [here](https://github.com/omarroth/invidious/blob/master/src/invidious/search.cr#L33-L114) for a list of supported options and at #126 for some examples. This also opens the door for features such as #30 which can be implemented as filters. I think advanced search is a major point in which Invidious can improve on YouTube and hope to add more features soon!

This week a more advanced system for viewing fallback comments has been added (see #84 for more details). You can now specify a comment fallback in your preferences, which Invidious will use. If, for example, no Reddit comments are available for a given video, it can choose to fallback on YouTube comments. This also makes it possible to turn comments off completely for users that prefer a more streamlined experience.

With #98, it is now possible for users to specify preferences without creating an account. You can now change speed, volume, subtitles, autoplay, loop, and quality using query parameters. See the issue above for more details and several examples.

I'd also like to announce that I've set up an account on [Liberapay](https://liberapay.com/omarroth), for patrons that prefer a privacy-friendly alternative to Patreon. Liberapay also does not take any percentage of donations, so I'd recommend donating some to the Liberapay for their hard work. Go check it out!

[Two weeks ago](https://github.com/omarroth/invidious/releases/tag/0.1.0) I mentioned adding 1080p support into the player. Currently, the only thing blocking is [#207](https://github.com/videojs/http-streaming/pull/207) in the excellent [http-streaming](https://github.com/videojs/http-streaming) library. I hope to work with the videojs team to merge it soon and finally implement 1080p support!

That's all for this week, thank you again everyone for your support! 

# 0.2.0 (2018-09-06)

## Week 2: Toward Playlists

Sorry for the late update! Not as much to announce this week, but still a couple things of note:
I'm happy to announce that a playlists page and API endpoint has been added so you can now view playlists. Currently, you cannot watch playlists through the player, but I hope to add that in the coming week as well as adding functionality to add and modify playlists. There is a good conversation on #114 about giving playlists even more functionality, which I think is interesting and would appreciate feedback on.

As an update to the Invidious API announcement last week, I've been working with @PrestonN, the developer of [FreeTube](https://github.com/FreeTubeApp/FreeTube), to help migrate his project to the Invidious API. Because of it's increasing popularity, he has had trouble keeping under the quota set by YouTube's API. I hope to improve the API to meet his and others needs and I'd recommend folks to keep an eye on his excellent project! There is a good discussion with his thoughts [here](https://github.com/FreeTubeApp/FreeTube/issues/100).

A couple of miscellaneous features and bugfixes:

- You can now login to Invidious simultaneously from multiple devices - #109

- Added a note for scheduled livestreams - #124 

- Changed YouTube comment header to "View x comments" - #120 

Enjoy your week everyone!

# 0.1.0 (2018-09-06)

## Week 1: Invidious API and Geo-Bypass

Hello everyone! This past week there have been quite a few things worthy of mention:

I'm happy to announce the [Invidious Developer API](https://github.com/omarroth/invidious/wiki/API). The Invidious API does not use any of the official YouTube APIs, and instead crawls the site to provide a JSON interface for other developers to use. It's still under development but is already powering [CloudTube](https://github.com/cloudrac3r/cadencegq). The API currently does not have a quota (compared to YouTube) which I hope to continue thanks to continued support from my Patrons. Hopefully other developers find it useful, and I hope to continue to improve it so it can better serve the community.

Just today partial support for bypassing geo-restrictions has been added with [fada57a](https://github.com/omarroth/invidious/commit/fada57a307d66d696d9286fc943c579a3fd22de6). If a video is unblocked in one of: United States, Canada, Germany, France, Japan, Russia, or United Kingdom, then Invidious will be able to serve video info. Currently you will not yet be able to access the video files themselves, but in the coming week I hope to proxy videos so that users can enjoy content across borders.

Support for generating DASH manifests has been fixed, in the coming week I hope to integrate this functionality into the watch page, so users can view videos in 1080p and above.

Thank you everyone for your continued interest and support!
