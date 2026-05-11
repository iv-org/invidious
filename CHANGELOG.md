# CHANGELOG

## vX.Y.0 (future)

## v2.20260207.0

### Wrap-up

This release hardens the Invidious companion pipeline and cleans up a long list of UI papercuts. Companion downloads now work end-to-end, CSP headers and check identifiers are generated once and reused, proxy responses strip stray headers, and the final traces of the legacy signature helper are gone so the helper can be rolled out safely.

Livestream navigation, playlists, and channel metadata also see overdue fixes: Trending once again lists livestreams, "Watch on YouTube" buttons stop jumping to arbitrary timestamps, playlist imports/API calls handle missing data, and channel pages now display creator pronouns and playlist thumbnails. Deployments benefit from compiling OpenSSL into docker images to mitigate a long-standing memory leak observed with Alpine-provided OpenSSL, Crystal pinned back to 1.16.3 for docker and OCI builds, a rewritten static file handler, clarified README/HTTP proxy/unix socket docs, and dozens of smaller cleanups.

### New features & important changes
#### For Users
  - Livestream experiences are restored: Trending shows livestreams again, the gaming feed remains accessible, and "Watch on YouTube" links stop carrying stale timestamps (#5480, #5555, #5481)
  - Channel and playlist metadata is richer thanks to pronoun support, topic playlist thumbnails, and accurate related video counts (#5617, #5616, #5446)
  - Downloads get smoother because download actions are URL-safe and downloads can flow through Invidious companion when available (#5367, #5561)
  - Users see clearer feedback with Erroneous CAPTCHA messages, DMCA controls restored, and a footer link pointing at the current release (#5508, #5228, #4702)

#### For instance owners
  - Companion integration is sturdier: CSP is generated once, check identifiers persist, and the helper hyperlink is fixed (#5497, #5575, #5491)
  - Proxied images and videoplayback strip unwanted response headers (shared header-strip list) (#5595)
  - Runtime and packaging updates pin docker/OCI builds to Crystal 1.16.3, bring an optional Crystal 1.18.2 + Alpine 3.23 image, and compile OpenSSL from source to mitigate the memory leak seen with Alpine-provided OpenSSL (#5604, #5577, #5574, #5441)
  - Configuration docs saw polish with unix socket instructions, refreshed HTTP proxy comments, and corrected README commands (#5347, #5586, #5607)
  - Server stability improves via a larger `max_request_line_size` that is required to be able to access some next pages of Youtube channels videos and a rewritten static file handler (#5566, #5338)

#### For developers
  - Top-level constants moved into dedicated modules, preferences handling was cleaned up, and the legacy signature helper is finally removed (#5596, #5450, #5550)
  - Crystal API updates replaced the deprecated `Socket#blocking` property and restored the shard target plus SPDX license metadata (#5538, #5608, #5552)
  - CI/tooling stayed current with newer GitHub Actions, install-crystal releases, and cache/checkout bumps (#5569, #5544, #5530, #5499)

### Bugs fixed
#### User-side
  - Playlist importer edge cases, playlist API author URLs, and channel continuation tokens now handle empty values without crashing (#4787, #5618, #5614)
  - Thin mode community posts, posts that reference unavailable videos, and DMCA content toggles work again (#5567, #5549, #5228)
  - UI cleanups prevent channel name/button overflow, show explicit Erroneous CAPTCHA errors, and keep livestream timestamps clean (#5553, #5452, #5508, #5481)
  - Trending feeds and related video counts regained accuracy alongside livestream/gaming categories (#5555, #5480, #5446)

#### For instance owners
  - Companion downloads, CSP reuse, and check id generation behave predictably even under load (#5561, #5497, #5575)
  - Proxy responses drop stray headers and HTTP proxy examples in the config were clarified (#5595, #5586)
  - Docker/OCI builds were pinned to stable Crystal releases with OpenSSL bundled to avoid memory leaks (#5604, #5577, #5441)

#### For developers
  - README commit instructions, shard targets, and unix socket docs were corrected (#5607, #5608, #5347)
  - Thin mode preference comparisons no longer convert unnecessary strings (#5568)
  - URL encoding fixes in the download widget and socket API updates prevent regressions when upgrading Crystal (#5367, #5538)

### Full list of pull requests merged since the last release (newest first)

* refactor: Move top level constants to it's own modules (https://github.com/iv-org/invidious/pull/5596, by @Fijxu)
* pages/watch: URL encode 'action' in download widget (https://github.com/iv-org/invidious/pull/5367, by @SamantazFox)
* Document use of unix sockets for `db` (https://github.com/iv-org/invidious/pull/5347, by @Fijxu)
* Generate companion CSP only once to reuse it (https://github.com/iv-org/invidious/pull/5497, by @Fijxu)
* Fix youtube CSV playlist importer (https://github.com/iv-org/invidious/pull/4787, by @ThatMatrix)
* Playlist API: return empty author url if ucid is empty (https://github.com/iv-org/invidious/pull/5618, by @radmorecameron)
* Channels: parse pronouns and display them on channel page (https://github.com/iv-org/invidious/pull/5617, by @radmorecameron)
* playlist: parse playlist thumbnails for topic autogenerated playlists (https://github.com/iv-org/invidious/pull/5616, by @radmorecameron)
* fix: add missing embedded protobuf message in continuation token for channel videos (https://github.com/iv-org/invidious/pull/5614, by @Fijxu)
* Update shard.yml to include target that was removed in commit 9d54cf9 (https://github.com/iv-org/invidious/pull/5608, by @Harm133)
* chore: Do not convert thin_mode preference to string to compare it in before_all (https://github.com/iv-org/invidious/pull/5568, by @Fijxu)
* Fix thin_mode preference for channel community page (https://github.com/iv-org/invidious/pull/5567, by @Fijxu)
* Fix commit command in README instructions, as per #5606 (https://github.com/iv-org/invidious/pull/5607, by @kirisakow)
* Revert "Bump crystallang/crystal from 1.16.3-alpine to 1.19.0-alpine in /docker" (https://github.com/iv-org/invidious/pull/5604, by @unixfox)
* Bump crystallang/crystal from 1.16.3-alpine to 1.19.0-alpine in /docker (https://github.com/iv-org/invidious/pull/5603, by @dependabot[bot])
* doc: Update HTTP proxy configuration comments (https://github.com/iv-org/invidious/pull/5586, by @unixfox)
* Strip unwanted headers from response headers in images and videoplayback (https://github.com/iv-org/invidious/pull/5595, by @Fijxu)
* Generate companion check id one time and add missing companion check id on captions (https://github.com/iv-org/invidious/pull/5575, by @Fijxu)
* Downgrade Crystal to 1.16.3 in OCI (https://github.com/iv-org/invidious/pull/5577, by @Fijxu)
* Allow downloading via companion (https://github.com/iv-org/invidious/pull/5561, by @JeroenBoersma)
* chore: crystal 1.8.2 + alpine 3.23 (https://github.com/iv-org/invidious/pull/5574, by @unixfox)
* Replace deprecated `blocking` property of `Socket` (https://github.com/iv-org/invidious/pull/5538, by @Fijxu)
* Replace `Kemal::StaticFileHandler` with direct subclass of stdlib `HTTP::StaticFileHandler` on Crystal >= 1.17.0 (https://github.com/iv-org/invidious/pull/5338, by @syeopite)
* dockerfile: compile openssl instead of using the one bundled on the crystal alpine image. (https://github.com/iv-org/invidious/pull/5441, by @Fijxu)
* Bump actions/cache from 4 to 5 (https://github.com/iv-org/invidious/pull/5569, by @dependabot[bot])
* Set Kemal `max_request_line_size` to 16384 for large channel continuation query parameters. (https://github.com/iv-org/invidious/pull/5566, by @Fijxu)
* Add link to GitHub release/tag/commit in footer (https://github.com/iv-org/invidious/pull/4702, by @shaedrich)
* Display "Erroneous CAPTCHA" for invalid captchas (https://github.com/iv-org/invidious/pull/5508, by @Fijxu)
* Fix channel name overflow (https://github.com/iv-org/invidious/pull/5553, by @Fijxu)
* Fix trending page by leaving livestream and gaming trending pages (https://github.com/iv-org/invidious/pull/5555, by @Fijxu)
* fix: restore dmca_content functionality (https://github.com/iv-org/invidious/pull/5228, by @Fijxu)
* Remove signature helper completely from Invidious (https://github.com/iv-org/invidious/pull/5550, by @Fijxu)
* Fix community posts when there is a unavailable video in a post (https://github.com/iv-org/invidious/pull/5549, by @Fijxu)
* chore: Update shard.yml to use SPDX license identifier (https://github.com/iv-org/invidious/pull/5552, by @Fijxu)
* Store `preferences` in a variable when reused and rename `prefs` to `preferences` (https://github.com/iv-org/invidious/pull/5450, by @Fijxu)
* Bump actions/checkout from 5 to 6 (https://github.com/iv-org/invidious/pull/5544, by @dependabot[bot])
* Bump crystal-lang/install-crystal from 1.8.3 to 1.9.1 (https://github.com/iv-org/invidious/pull/5530, by @dependabot[bot])
* Fix 0 view count on related videos section (https://github.com/iv-org/invidious/pull/5446, by @shiny-comic)
* Prevent timestamp from being set for Livestreams on "Watch on Youtube" links (https://github.com/iv-org/invidious/pull/5481, by @Fijxu)
* Add Livestreams to trending page (https://github.com/iv-org/invidious/pull/5480, by @Fijxu)
* Fix button overflow (https://github.com/iv-org/invidious/pull/5452, by @Fijxu)
* Bump crystal-lang/install-crystal from 1.8.2 to 1.8.3 (https://github.com/iv-org/invidious/pull/5499, by @dependabot[bot])
* Fixed broken companion hyperlink (https://github.com/iv-org/invidious/pull/5491, by @ndsvw)

## v2.20250913.0

### Wrap-up

This release primarily marks Invidious companion's ascend out of beta and its stable integration thereof into Invidious!

For those unaware Invidious companion is the successor to the `inv-sig-helper` tool, designed to securely pass YouTube's attestation checks and allow for the efficient retrieval and playback of video streams reliably.

Companion delivers YouTube fixes faster since it’s built on the community-driven [YouTube.js](https://github.com/LuanRT/YouTube.js) project, used by many open source projects such as [FreeTube](https://github.com/FreeTubeApp/FreeTube).

For more information see https://github.com/iv-org/invidious-companion and https://docs.invidious.io/installation/

But companion isn't the only new thing in this release!

Invidious will no longer error out completely as soon as a single item failed to parse in search results, channel pages, etc. Instead it now handles it gracefully by substituting those problematic items with an error card and rendering the page normally.

The player has gained some quality of life features such as being able to choose a default playlist for videos to be added to, or persisting caption appearance settings across the session.

Base Invidious video retrieval without Invidious companion has also been made more stable.

And finally a significant amount of bugs were fixed alongside many other minor improvements.

### New features & important changes
#### For Users
  - DASH is now enabled by default due to YouTube's removal of the 720p non-dash streams
  - Javascript licencing info has been added to all of Invidious' scripts, restoring full compatibility with LibreJS
  - There is no longer an option for a text captcha during registration due to the shutdown (presumably) of the upstream service
  - Parse errors in feeds will no longer render the entire feed unusable and instead will substitute only the broken items with error cards
  - Keyboard shortcuts have been added to configure caption styles:
    - `-`,`=` can be used to change the font size
    - `o` can be used to cycle the opacity of the caption text
    - `w` can be used to cycle the opacity of the caption box
  - Caption styles changed through the VideoJS menu will now persist
  - You can now choose a default playlist to add videos to instead of needing to manually select one each time

#### For instance owners
  - Invidious companion support has been added to replace the deprecated inv-sig-helper
  - **DASH is now the default resolution! Please ensure that your instances can withstand the significantly higher bandwidth usage or manually configure your instance to use non-dash streams by default**
  - Invidious will now warn when it is unable to connect to the database instead of failing silently
  - **The text captcha during registration has been removed due to the shutdown (presumably) of the upstream service**

#### For developers
  - Dependabot has been added to keep Github Actions and Docker dependencies up-to-date.
  - CI version matrix has been bumped to the latest patch release for each minor version
  - The versions of Crystal that we test in CI/CD are now: `1.12.2`, `1.13.3`, `1.14.1`, `1.15.1`, `1.16.3`
  - `Kilt` is no longer a dependency of Invidious
  - The ARM64 docker image builds (and the test CI) has been changed to use Github's ARM64 runner instead of QEMU
  - **An "error" JSON object can now be returned in various API responses in-place of an item that has failed to parse**:

      ```json
        {
          "type": "parse-error",
          "errorMessage": "...",
          "errorBacktrace": "..."
        }
      ```

### Bugs fixed
#### User-side
  - Livestream will now be properly proxied again allowing playback from the UI
  - The proxy video preference for logged-in users will no longer get ignored when a default value is set by the instance
  - Fixes the missing `label` key error on select search results and other feeds
  - Invidious will no longer strip out spaces from search queries when navigating back from the preferences page
  - Restores functionality to the `subscriptions:true` search keyword
  - The channel RSS feeds will no longer have an empty title
  - Individual community posts can be viewed again
  - The playlists tab of channels can be viewed again
  - Fix incorrect dates, region, etc of videos
  - Various minor fixes were made to how video info is extracted in setups without Invidious companion to improve resiliency and chances of success
  - Fix issue where the notification count becomes `TRUE` rather than an actual number
#### For instance owners
  - Fixed a minor typo in config.example.yml (`effet` -> `effect`)
#### For developers
  - The docker image test CI will now properly check whether Invidious has started

### Full list of pull requests merged since the last release (newest first)

* Add Invidious companion support (https://github.com/iv-org/invidious/pull/4985, by @unixfox)
* Bump shards.yml version to dev version (https://github.com/iv-org/invidious/pull/5206, by @syeopite)
* chore: enforce 16 characters for invidious_companion_key (https://github.com/iv-org/invidious/pull/5220, by @unixfox)
* chore: set dash by default (https://github.com/iv-org/invidious/pull/5216, by @unixfox)
* Fix minor casing issues in brand names (https://github.com/iv-org/invidious/pull/5258, thanks @efb4f5ff-1298-471a-8973-3d47447115dc)
* feat: route to invidious companion on downloads (https://github.com/iv-org/invidious/pull/5224, by @alexmaras)
* Fix proxying live DASH streams (https://github.com/iv-org/invidious/pull/4589, thanks @absidue)
* Reflect companion secret character limit in example config comment (https://github.com/iv-org/invidious/pull/5269, thanks @Vyquos)
* chore: Add dependabot for docker and github actions (https://github.com/iv-org/invidious/pull/5285, by @unixfox)
* Bump actions/stale from 8 to 9 (https://github.com/iv-org/invidious/pull/5291, thanks @dependabot[bot])
* Bump actions/cache from 3 to 4 (https://github.com/iv-org/invidious/pull/5289, thanks @dependabot[bot])
* Bump alpine from 3.20 to 3.21 in /docker (https://github.com/iv-org/invidious/pull/5288, thanks @dependabot[bot])
* Bump docker/build-push-action from 5 to 6 (https://github.com/iv-org/invidious/pull/5287, thanks @dependabot[bot])
* Bump crystal-lang/install-crystal from 1.8.0 to 1.8.2 (https://github.com/iv-org/invidious/pull/5286, thanks @dependabot[bot])
* Bump crystallang/crystal from 1.12.2-alpine to 1.16.2-alpine in /docker (https://github.com/iv-org/invidious/pull/5290, thanks @dependabot[bot])
* Bump crystallang/crystal from 1.16.2-alpine to 1.16.3-alpine in /docker (https://github.com/iv-org/invidious/pull/5301, thanks @dependabot[bot])
* CI: Bump Crystal version matrix (https://github.com/iv-org/invidious/pull/5293, by @Fijxu)
* fix(typo): 'Salect' -> 'Select' (https://github.com/iv-org/invidious/pull/5242, by @Fijxu)
* fix: set CSP header after setting preferences of registered users (https://github.com/iv-org/invidious/pull/5275, by @Fijxu)
* fix: safely access "label" key (https://github.com/iv-org/invidious/pull/5282, by @Fijxu)
* Add missing javascript licenses (https://github.com/iv-org/invidious/pull/5292, by @Fijxu)
* Add Javascript licence information automatically (https://github.com/iv-org/invidious/pull/5297, by @syeopite)
* Remove text captcha due to textcaptcha.com being down (https://github.com/iv-org/invidious/pull/5308, by @Fijxu)
* Release versioning maintenance (https://github.com/iv-org/invidious/pull/5310, by @syeopite)
* Update Kemal to 1.6.0 and remove Kilt (https://github.com/iv-org/invidious/pull/5120, by @syeopite)
* Translations update from Hosted Weblate (https://github.com/iv-org/invidious/pull/5192, thanks @weblate)
* require base_job before the other jobs (https://github.com/iv-org/invidious/pull/5194, by @Fijxu)
* Handle parse errors gracefully on timeline items (https://github.com/iv-org/invidious/pull/5196, by @syeopite)
* fix: do not strip '+' character from referer (https://github.com/iv-org/invidious/pull/5276, by @Fijxu)
* fix: pass user to `query.process` if present. (https://github.com/iv-org/invidious/pull/5277, by @Fijxu)
* Add missing xml.text on "title" element for channels RSS (https://github.com/iv-org/invidious/pull/5320, by @Fijxu)
* Remove `@iv-org/developers` from codeowners (https://github.com/iv-org/invidious/pull/5314, by @syeopite)
* Make base-Invidious video info extraction more resilient (https://github.com/iv-org/invidious/pull/5312, by @syeopite)
* Bump actions/checkout from 4 to 5 (https://github.com/iv-org/invidious/pull/5415, thanks @dependabot[bot])
* Player: Add keyboard shortcuts to configure captions (https://github.com/iv-org/invidious/pull/5188, thanks @epicsam123)
* CI: Use public ARM64 Github actions runners for ARM64 builds. (https://github.com/iv-org/invidious/pull/5305, by @Fijxu)
* CI: Fix docker ci job not checking if Invidious starts successfully or not (https://github.com/iv-org/invidious/pull/5306, by @Fijxu)
* YtAPI: Bump client versions (https://github.com/iv-org/invidious/pull/5325, by @Fijxu)
* YTAPI: Add `TvSimply` client (https://github.com/iv-org/invidious/pull/5344, by @Fijxu)
* Videos: Add fallback to TvSimply client (https://github.com/iv-org/invidious/pull/5345, by @Fijxu)
* Show message when connection to the database is not possible (https://github.com/iv-org/invidious/pull/5346, by @Fijxu)
* Channels: Fix fetching of individual community posts (https://github.com/iv-org/invidious/pull/5361, thanks @ChunkyProgrammer)
* Videos: Fix missing .id to retrieve first playlist video ID (https://github.com/iv-org/invidious/pull/5366, by @SamantazFox)
* HTML: Add Missing Noreferrers (https://github.com/iv-org/invidious/pull/5368, thanks @epicsam123)
* Documentation: Fix typo (effet -> effect) (https://github.com/iv-org/invidious/pull/5369, thanks @nsunami)
* Frontend: Fix notification count of `TRUE` (https://github.com/iv-org/invidious/pull/5391, thanks @fieryhenry)
* Player: Persist caption settings (https://github.com/iv-org/invidious/pull/5417, thanks @p-himik)
* Channels: Fix fetching channel playlists (https://github.com/iv-org/invidious/pull/5418, thanks @KrisVos130)
* CI: fix wrong if statement for build-docker job (https://github.com/iv-org/invidious/pull/5442, by @Fijxu)
* initial base_url companion support + proxy companion (https://github.com/iv-org/invidious/pull/5266, by @unixfox)
* Prevent player microformat from being overwritten by the next microformat (https://github.com/iv-org/invidious/pull/5453, by @Fijxu)
* Bump actions/stale from 9 to 10 (https://github.com/iv-org/invidious/pull/5457, thanks @dependabot[bot])
* Better documentation for the specific case public_url with companion (https://github.com/iv-org/invidious/pull/5461, by @unixfox)
* Add default playlist preference (https://github.com/iv-org/invidious/pull/5449, by @Fijxu)
* Translations update from Hosted Weblate (https://github.com/iv-org/invidious/pull/5313, thanks to our many translators)
* Release `v2.20250913.0` (https://github.com/iv-org/invidious/pull/5463, by @syeopite)

## v2.20250517.0

Inverse fallback for the YouTube client from TVHTML then MWEB. Fixes https://github.com/iv-org/invidious/issues/5273

## v2.20250504.0

Small release with quick workaround fix for issue #4251 (Nil assertion failed).

PR: https://github.com/iv-org/invidious/issues/5262

## v2.20250314.0

### Wrap-up

This release brings the long awaited feature of supporting multiple audio tracks in a video, some bug fixes and UX improvements, and many other things primarily oriented to self-hosting instances, and developers using the API.

The `Community` channel tab has been replaced by `Posts` in light of YouTube changes, but the URL remains the same.

Tamil is now available as an interface language

Automatic instance redirects will no longer have the chance to annoyingly redirect to the same instance you're on.

Due to their requirements for video playback, Invidious will log warning messages when either inv-sig-helper, `po_token` or `visitor_data` is not configured

Invidious is now able to listen through a UNIX socket

User notifications are now batched for each channel

**The minimum Crystal version supported by Invidious now `1.12.0`**

### New features & important changes

#### For users

* Invidious now supports videos with multiple audio tracks allowing you to select which one you want to hear with!
* Channel pages now have a proper previous page button
* RSS feeds for channels will no longer contain the channel's profile picture
* Support for channel `courses` page has been added
* `Community` tabs has been replaced with `Posts` to comply with YouTube changes
* Tamil is now an available interface language.

#### For instance owners
* Invidious is now able to listen on a UNIX socket
* User notifications are now batched by channels, significantly reducing database load.
* **`1.12.0` is now the oldest Crystal version that Invidious supports**
* The example config will no longer force an http proxy to be configured
* Invidious will now warn when any top-level config option must be set to a custom value, instead of just `HMAC_KEY`
* Due to their requirements for video playback, Invidious will log warning messages when either inv-sig-helper, `po_token` or `visitor_data` is not configured

#### For developers
* Invidious is now compliant to Crystal 1.15 formatting rules, which are incompatible with earlier versions.
* `/api/v1/transcripts/{id}` has been added to the API to allow for fetching the transcripts for a video. The arguments are the same as the captions endpoint.
* `author_thumbnail` field has been added to videos in the various paged api endpoints
* `published` field has been added to the API response for a video's related videos.
* Docker builds now uses the Crystal compiler cache, reducing build times on repeated builds significantly.
* Invidious ajax action handlers has undergone a clean up and may face compatibility issues with code that depends on these endpoints.
* The versions of Crystal that we test in CI/CD are now: `1.12.1`, `1.13.2`, `1.14.0`, `1.15.0`

### Bugs fixed

#### User-side
* Local video listen mode is now preserved when clicking on a video in the sidebar playlist widget
* Automatic instance redirects will no longer redirect to the same instance the user is on
* Fix some thumbnails responses returning 404
* Videos: Fix missing host parameter on playback URLs when `local=true`
* Fix HLS being used for non-livestream videos
* Fix timeupdate event errors when required elements are missing
* User: Ensure IO is properly closed when importing NewPipe subscriptions

#### For instance owners
* Fix http proxy configuration being forced by the standard example config

#### API
* `/api/v1/videos/{id}` will no longer return an occasional empty JSON response

### Full list of pull requests merged since the last release (newest first)
* Make Invidious compliant to Crystal 1.15 formatting rules (https://github.com/iv-org/invidious/pull/5014, by @syeopite)
* Remove formatter check on container workflows (https://github.com/iv-org/invidious/pull/5153, by @syeopite)
* Videos: Fix missing host parameter on playback URLs when `local=true` (https://github.com/iv-org/invidious/pull/4992, by @SamantazFox)
* Remove stdlib override for proxy initialization (https://github.com/iv-org/invidious/pull/5065, by @syeopite)
* Add support for author thumbnails in search api for videos (https://github.com/iv-org/invidious/pull/5072, thanks @ChunkyProgrammer)
* Skip route if resp got closed by before handlers (https://github.com/iv-org/invidious/pull/5073, by @syeopite)
* Fix video thumbnails in mixes (https://github.com/iv-org/invidious/pull/5116, thanks @iBicha)
* CI: Drop support for versions prior to 1.12 and add 1.15.0 (https://github.com/iv-org/invidious/pull/5148, by @syeopite)
* [Continuing #5094] Set language info for dash audio streams and sort (https://github.com/iv-org/invidious/pull/5149, thanks @giuliano-macedo)
* Warn when any top-level config is "CHANGE_ME!!" (https://github.com/iv-org/invidious/pull/5150, by @syeopite)
* Comment out http_proxy in example config (https://github.com/iv-org/invidious/pull/5151, by @syeopite)
* API: Add a 'published' video parameter for related videos (https://github.com/iv-org/invidious/pull/4149, thanks @RadoslavL)
* Ensure IO is properly closed when importing NewPipe subscriptions (https://github.com/iv-org/invidious/pull/4346, thanks @ChunkyProgrammer)
* Carry over audio-only mode in playlist links (https://github.com/iv-org/invidious/pull/4784, thanks @krystof1119)
* Routes: Clean ajax actions handlers (https://github.com/iv-org/invidious/pull/5036, by @SamantazFox)
* Frontend: Add a first page and previous page buttons for channel navigation (https://github.com/iv-org/invidious/pull/4123, thanks @RadoslavL)
* RSS: Channel + Playlist improvements (https://github.com/iv-org/invidious/pull/4298, thanks @ChunkyProgrammer)
* Batch user notifications together (https://github.com/iv-org/invidious/pull/4486, thanks @999eagle)
* JS: Update timeupdate event making it more defensive to prevent errors (https://github.com/iv-org/invidious/pull/4782, thanks @PMK)
* Add API endpoint for fetching transcripts from YouTube by (https://github.com/iv-org/invidious/pull/4788, by @syeopite)
* Translations update from Hosted Weblate by (https://github.com/iv-org/invidious/pull/4989, thanks to our many translators)
* Add the ability to listen on UNIX sockets (https://github.com/iv-org/invidious/pull/5112, thanks @Caian)
* Pick a different instance upon redirect (https://github.com/iv-org/invidious/pull/5154, thanks @epicsam123)
* Add Courses to channel page and channel API (https://github.com/iv-org/invidious/pull/5158, thanks @ChunkyProgrammer)
* fix /api/v1/videos/:id returns 200 with no content (https://github.com/iv-org/invidious/pull/5162, thanks @Drikanis)
* Use Crystal compiler cache in docker builds (https://github.com/iv-org/invidious/pull/5163, by @syeopite)
* Channels: Fix community tab by (https://github.com/iv-org/invidious/pull/5183, thanks @Fijxu)
* Fix typo in `src/invidious/routes/images.cr` (https://github.com/iv-org/invidious/pull/5184, by @syeopite)
* Fix an issue with the HLS manifest check for livestream videos (https://github.com/iv-org/invidious/pull/5189, thanks @alexmaras)
* Warn when `po_token`, `visitor_data` and/or `inv-sig-helper` is not configured (https://github.com/iv-org/invidious/pull/5202, by @syeopite)
## v2.20241110.0

### Wrap-up

This release is most importantly here to fix to the annoying "Youtube API returned error 400"
error that prevented all channel pages from loading.

If you're updating from the previous release, it provides no improvements on the ability to play
videos. If updating from a commit in-between release, it removes the "Please sign in" error caused
by a previous attempt at restoring video playback on large instances.

In the preferences, a new option allows for control of video preload. When enabled, this option
tells the browser to load the video as soon as the page is loaded (this used to be the default).
When disabled, the video starts loading only when the "play" button is pressed.

New interface languages available: Bulgarian, Welsh and Lombard

New dependency required: `tzdata`.

An HTTP proxy can be configured directly in Invidious, if needed. \
**NOTE:** In that case, it is recommended to comment out `force_resolve`.


### New features & important changes

#### For users

* Channels: Fix "Youtube API returned error 400" error preventing channel pages from loading
* Channels: Shorts can now be sorted by "newest", "oldest" and "popular"
* Preferences: Addition of the new "preload" option
* New interface languages available: Bulgarian, Welsh and Lombard
* Added "Filipino (auto-generated)" to the list of caption languages available
* Lots of new translations from Weblate

#### For instance owners

* Allow the configuration of an HTTP proxy to talk to Youtube
* Invidious tries to reconnect to `inv_sig_helper` if the socket is closed
* The instance list is downloaded in the background to improve redirection speed
* New `colorize_logs` option makes each log level a different color

#### For developpers

* `/api/v1/channels/{id}/shorts` now supports the `sort-by` parameter with the following values:
  `newest`, `oldest` and `popular`
* Older `/api/v1/channels/xyz/{id}` (tab name before UCID) were removed
* API/Search: New video metadata available: `isNew`, `is4k`, `is8k`, `isVr180`, `isVr360`,
  `is3d` and `hasCaptions`

### Bugs fixed

#### User-side

* Channels: The second page of shorts now loads as expected
* Channels: Fixed intermittent empty "playlists" tab
* Search: Fixed `youtu.be` URLs not being properly redirected to the watch page
* Fixed `DB::MappingException` error on the subscriptions feed (due to missing `tzdata` in docker)
* Switching to another instance is much faster
* Fixed an "invalid byte sequence" error when subscribing to a playlist
* Videos: Playback URLs were sometimes broken when cached and `inv_sig_helper` was used

#### For instance owners

* Fix `force_resolve` being ignored in some cases

#### API

* API/Videos: Fixed `live_now` and `premiere_timestamp` sometimes not having the right values


### Full list of pull requests merged since the last release (newest first)

* API: Add "sort_by" parameter to channels/shorts endpoint ([#5071], thanks @iBicha)
* Docker: Install tzdata in Dockerfile ([#5070], by @SamantazFox)
* Videos: Stop using TVHTML5_SIMPLY_EMBEDDED_PLAYER ([#5063], thanks @unixfox)
* Routing: Deprecate old channel API routes ([#5045], by @SamantazFox)
* Videos: use WEB client instead of WEB CREATOR ([#4984], thanks @unixfox)
* Parsers: Fix parsing live_now and premiere_timestamp ([#4934], thanks @absidue)
* Stale bot updates ([#5060], thanks @syeopite)
* Channels: Fix "Youtube API returned error 400" ([#5059], by @SamantazFox)
* Channels: Fix for live videos ([#5027], thanks @iBicha)
* Locales: Add Bulgarian, Welsh and Lombard to the list ([#5046], by @SamantazFox)
* Shards: Update database dependencies ([#5034], by @SamantazFox)
* Logger: Add color support for different log levels ([#4931], thanks @Fijxu)
* Fix named arg syntax when passing force_resolve ([#4754], thanks @syeopite)
* Use make_client instead of calling HTTP::Client ([#4709], thanks @syeopite)
* Add "Filipino (auto-generated)" to the list of caption languages ([#4995], by @SamantazFox)
* Makefile: Add MT option to enable the 'preview_mt' flag ([#4993], by @SamantazFox)
* SigHelper: Reconnect to signature helper ([#4991], thanks @Fijxu)
* Fix player menus hiding onHover ready ([#4750], thanks @giacomocerquone)
* Use connection pools when requesting images from YouTube ([#4326], thanks @syeopite)
* Add support for using Invidious through a HTTP Proxy ([#4270], thanks @syeopite)
* Search: Fix 'youtu.be' URLs in sanitizer ([#4894], by @SamantazFox)
* Ameba: Disable Style/RedundantNext rule ([#4888], thanks @syeopite)
* Playlists: Fix 'invalid byte sequence' error when subscribing ([#4887], thanks @DmitrySandalov)
* Parse more metadata badges for SearchVideos ([#4863], thanks @ChunkyProgrammer)
* Translations update from Hosted Weblate ([#4862], thanks to our many translators)
* Videos: Convert URL before putting result into cache ([#4850], by @SamantazFox)
* HTML: Add error message to "search issues on GitHub" link ([#4652], thanks @tracedgod)
* Preferences: Add option to control preloading of video data ([#4122], thanks @Nerdmind)
* Performance: Improve speed of automatic instance redirection ([#4193], thanks @syeopite)
* Remove myself from CODEOWNERS on the config file ([#4942], by @TheFrenchGhosty)
* Update latest version WEB_CREATOR + fix comment web embed ([#4930], thanks @unixfox)
* use WEB_CREATOR when po_token with WEB_EMBED as a fallback ([#4928], thanks @unixfox)
* Revert "use web screen embed for fixing potoken functionality"
* use web screen embed for fixing potoken functionality ([#4923], thanks @unixfox)

[#4122]: https://github.com/iv-org/invidious/pull/4122
[#4193]: https://github.com/iv-org/invidious/pull/4193
[#4270]: https://github.com/iv-org/invidious/pull/4270
[#4326]: https://github.com/iv-org/invidious/pull/4326
[#4652]: https://github.com/iv-org/invidious/pull/4652
[#4709]: https://github.com/iv-org/invidious/pull/4709
[#4750]: https://github.com/iv-org/invidious/pull/4750
[#4754]: https://github.com/iv-org/invidious/pull/4754
[#4850]: https://github.com/iv-org/invidious/pull/4850
[#4862]: https://github.com/iv-org/invidious/pull/4862
[#4863]: https://github.com/iv-org/invidious/pull/4863
[#4887]: https://github.com/iv-org/invidious/pull/4887
[#4888]: https://github.com/iv-org/invidious/pull/4888
[#4894]: https://github.com/iv-org/invidious/pull/4894
[#4923]: https://github.com/iv-org/invidious/pull/4923
[#4928]: https://github.com/iv-org/invidious/pull/4928
[#4930]: https://github.com/iv-org/invidious/pull/4930
[#4931]: https://github.com/iv-org/invidious/pull/4931
[#4934]: https://github.com/iv-org/invidious/pull/4934
[#4942]: https://github.com/iv-org/invidious/pull/4942
[#4984]: https://github.com/iv-org/invidious/pull/4984
[#4991]: https://github.com/iv-org/invidious/pull/4991
[#4993]: https://github.com/iv-org/invidious/pull/4993
[#4995]: https://github.com/iv-org/invidious/pull/4995
[#5027]: https://github.com/iv-org/invidious/pull/5027
[#5034]: https://github.com/iv-org/invidious/pull/5034
[#5045]: https://github.com/iv-org/invidious/pull/5045
[#5046]: https://github.com/iv-org/invidious/pull/5046
[#5059]: https://github.com/iv-org/invidious/pull/5059
[#5060]: https://github.com/iv-org/invidious/pull/5060
[#5063]: https://github.com/iv-org/invidious/pull/5063
[#5070]: https://github.com/iv-org/invidious/pull/5070
[#5071]: https://github.com/iv-org/invidious/pull/5071


## v2.20240825.2 (2024-08-26)

This releases fixes the container tags pushed on quay.io.
Previously, the ARM64 build was released under the `latest` tag, instead of `latest-arm64`.

### Full list of pull requests merged since the last release (newest first)

CI: Fix docker container tags ([#4883], by @SamantazFox)

[#4877]: https://github.com/iv-org/invidious/pull/4877


## v2.20240825.1 (2024-08-25)

Add patch component to be [semver] compliant and make github actions happy.

[semver]: https://semver.org/

### Full list of pull requests merged since the last release (newest first)

Allow manual trigger of release-container build ([#4877], thanks @syeopite)

[#4877]: https://github.com/iv-org/invidious/pull/4877


## v2.20240825.0 (2024-08-25)

### New features & important changes

#### For users

* The search bar now has a button that you can click!
* Youtube URLs can be pasted directly in the search bar. Prepend search query with a
  backslash (`\`) to disable that feature (useful if you need to search for a video whose
  title contains some youtube URL).
* On the channel page the "streams" tab can be sorted by either: "newest", "oldest" or "popular"
* Lots of translations have been updated (thanks to our contributors on Weblate!)
* Videos embedded in local HTML files (e.g: a webpage saved from a blog) can now be played

#### For instance owners

* Invidious now has the ability to provide a `po_token` and `visitordata` to Youtube in order to
  circumvent current Youtube restrictions.
* Invidious can use an (optional) external signature server like [inv_sig_helper]. Please note that
  some videos can't be played without that signature server.
* The Helm charts were moved to a separate repo: https://github.com/iv-org/invidious-helm-chart
* We have changed how containers are released: the `latest` tag now tracks tagged releases, whereas
  the `master` tag tracks the most recent commits of the `master` branch ("nightly" builds).

[inv_sig_helper]: https://github.com/iv-org/inv_sig_helper

#### For developpers

* The versions of Crystal that we test in CI/CD are now: `1.9.2`, `1.10.1`, `1.11.2`, `1.12.1`.
  Please note that due to a bug in the `libxml` bindings (See [#4256]), versions prior to `1.10.0`
  are not recommended to use.
* Thanks to @syeopite, the code is now [ameba] compliant.
* Ameba is part of our CI/CD pipeline, and its rules will be enforced in future PRs.
* The transcript code has been rewritten to permit transcripts as a feature rather than being
  only a workaround for captions. Trancripts feature is coming soon!
* Various fixes regarding the logic interacting with Youtube
* The `sort_by` parameter can be used on the `/api/v1/channels/{id}/streams` endpoint. Accepted
  values are: "newest", "oldest" and "popular"

[ameba]: https://github.com/crystal-ameba/ameba
[#4256]: https://github.com/iv-org/invidious/issues/4256


### Bugs fixed

#### User-side

* Channels: fixed broken "subscribers" and "views" counters
* Watch page: playback position is reset at the end of a video, so that the next time this video
  is watched, it will start from the beginning rather than 15 seconds before the end
* Watch page: the items in the "add to playlist" drop down are now sorted alphabetically
* Videos: the "genre" URL is now always pointing to a valid webpage
* Playlists: Fixed `Could not parse N episodes` error on podcast playlists
* All external links should now have the [`rel`] attibute set to `noreferrer noopener` for
  increased privacy.
* Preferences: Fixed the admin-only "modified source code" input being ignored
* Watch/channel pages: use the full image URL in `og:image` and `twitter:image` meta tags

[`rel`]: https://developer.mozilla.org/en-US/docs/Web/HTML/Attributes/rel

#### API

* fixed the `local` parameter not applying to `formatStreams` on `/api/v1/videos/{id}`
* fixed an `Index out of bounds` error hapenning when a playlist had no videos
* fixed duplicated query parameters in proxied video URLs
* Return actual video height/width/fps rather than hard coded values
* Fixed the `/api/v1/popular` endpoint not returning a proper error code/message when the
  popular page/endpoint are disabled.


### Full list of pull requests merged since the last release (newest first)

* HTML: Sort playlists alphabetically in watch page drop down ([#4853], by @SamantazFox)
* Videos: Fix XSS vulnerability in description/comments ([#4852], thanks _anonymous_)
* YtAPI: Bump client versions ([#4849], by @SamantazFox)
* SigHelper: Fix inverted time comparison in 'check_update' ([#4845], by @SamantazFox)
* Storyboards: Various fixes and code cleaning ([#4153], by SamantazFox)
* Fix lint errors introduced in #4146 and #4295 ([#4876], thanks @syeopite)
* Search: Add support for Youtube URLs ([#4146], by @SamantazFox)
* Channel: Render age restricted channels ([#4295], thanks @ChunkyProgrammer)
* Ameba: Miscellaneous fixes ([#4807], thanks @syeopite)
* API: Proxy formatStreams URLs too ([#4859], thanks @colinleroy)
* UI: Add search button to search bar ([#4706], thanks @thansk)
* Add ability to set po_token and visitordata ID ([#4789], thanks @unixfox)
* Add support for an external signature server ([#4772], by @SamantazFox)
* Ameba: Fix Naming/VariableNames ([#4790], thanks @syeopite)
* Translations update from Hosted Weblate ([#4659])
* Ameba: Fix Lint/UselessAssign ([#4795], thanks @syeopite)
* HTML: Add rel="noreferrer noopener" to external links ([#4667], thanks @ulmemxpoc)
* Remove unused methods in Invidious::LogHandler ([#4812], thanks @syeopite)
* Ameba: Fix Lint/NotNilAfterNoBang ([#4796], thanks @syeopite)
* Ameba: Fix unused argument Lint warnings ([#4805], thanks @syeopite)
* Ameba: i18next.cr fixes ([#4806], thanks @syeopite)
* Ameba: Disable rules ([#4792], thanks @syeopite)
* Channel: parse subscriber count and channel banner ([#4785], thanks @ChunkyProgrammer)
* Player: Fix playback position of already watched videos ([#4731], thanks @Fijxu)
* Videos: Fix genre url being unusable ([#4717], thanks @meatball133)
* API: Fix out of bound error on empty playlists ([#4696], thanks @Fijxu)
* Handle playlists cataloged as Podcast ([#4695], thanks @Fijxu)
* API: Fix duplicated query parameters in proxied video URLs ([#4587], thanks @absidue)
* API: Return actual stream height, width and fps ([#4586], thanks @absidue)
* Preferences: Fix handling of modified source code URL ([#4437], thanks @nooptek)
* API: Fix URL for vtt subtitles ([#4221], thanks @karelrooted)
* Channels: Add sort options to streams ([#4224], thanks @src-tinkerer)
* API: Fix error code for disabled popular endpoint ([#4296], thanks @iBicha)
* Allow embedding videos in local HTML files ([#4450], thanks @tomasz1986)
* CI: Bump Crystal version matrix ([#4654], by @SamantazFox)
* YtAPI: Remove API keys like official clients ([#4655], by @SamantazFox)
* HTML: Use full URL in the og:image property ([#4675], thanks @Fijxu)
* Rewrite transcript logic to be more generic ([#4747], thanks @syeopite)
* CI: Run Ameba ([#4753], thanks @syeopite)
* CI: Add release based containers ([#4763], thanks @syeopite)
* move helm chart to a dedicated github repository ([#4711], thanks @unixfox)

[#4146]: https://github.com/iv-org/invidious/pull/4146
[#4153]: https://github.com/iv-org/invidious/pull/4153
[#4221]: https://github.com/iv-org/invidious/pull/4221
[#4224]: https://github.com/iv-org/invidious/pull/4224
[#4295]: https://github.com/iv-org/invidious/pull/4295
[#4296]: https://github.com/iv-org/invidious/pull/4296
[#4437]: https://github.com/iv-org/invidious/pull/4437
[#4450]: https://github.com/iv-org/invidious/pull/4450
[#4586]: https://github.com/iv-org/invidious/pull/4586
[#4587]: https://github.com/iv-org/invidious/pull/4587
[#4654]: https://github.com/iv-org/invidious/pull/4654
[#4655]: https://github.com/iv-org/invidious/pull/4655
[#4659]: https://github.com/iv-org/invidious/pull/4659
[#4667]: https://github.com/iv-org/invidious/pull/4667
[#4675]: https://github.com/iv-org/invidious/pull/4675
[#4695]: https://github.com/iv-org/invidious/pull/4695
[#4696]: https://github.com/iv-org/invidious/pull/4696
[#4706]: https://github.com/iv-org/invidious/pull/4706
[#4711]: https://github.com/iv-org/invidious/pull/4711
[#4717]: https://github.com/iv-org/invidious/pull/4717
[#4731]: https://github.com/iv-org/invidious/pull/4731
[#4747]: https://github.com/iv-org/invidious/pull/4747
[#4753]: https://github.com/iv-org/invidious/pull/4753
[#4763]: https://github.com/iv-org/invidious/pull/4763
[#4772]: https://github.com/iv-org/invidious/pull/4772
[#4785]: https://github.com/iv-org/invidious/pull/4785
[#4789]: https://github.com/iv-org/invidious/pull/4789
[#4790]: https://github.com/iv-org/invidious/pull/4790
[#4792]: https://github.com/iv-org/invidious/pull/4792
[#4795]: https://github.com/iv-org/invidious/pull/4795
[#4796]: https://github.com/iv-org/invidious/pull/4796
[#4805]: https://github.com/iv-org/invidious/pull/4805
[#4806]: https://github.com/iv-org/invidious/pull/4806
[#4807]: https://github.com/iv-org/invidious/pull/4807
[#4812]: https://github.com/iv-org/invidious/pull/4812
[#4845]: https://github.com/iv-org/invidious/pull/4845
[#4849]: https://github.com/iv-org/invidious/pull/4849
[#4852]: https://github.com/iv-org/invidious/pull/4852
[#4853]: https://github.com/iv-org/invidious/pull/4853
[#4859]: https://github.com/iv-org/invidious/pull/4859
[#4876]: https://github.com/iv-org/invidious/pull/4876


## v2.20240427 (2024-04-27)

Major bug fixes:
 * Videos: Use android test suite client (#4650, thanks @SamantazFox)
 * Trending: Un-nest category if this is the only one (#4600, thanks @ChunkyProgrammer)
 * Comments: Add support for new format (#4576, thanks @ChunkyProgrammer)

Minor bug fixes:
 * API: Add bitrate to formatStreams too (#4590, thanks @absidue)
 * API: Add 'authorVerified' field on recommended videos (#4562, thanks @ChunkyProgrammer)
 * Videos: Add support for new likes format (#4462, thanks @ChunkyProgrammer)
 * Proxy: Handle non-200 HTTP codes on DASH manifests (#4429, thanks @absidue)

Other improvements:
 * Remove legacy proxy code (#4570, thanks @syeopite)
 * API: convey info "is post live" from Youtube response (#4569, thanks @ChunkyProgrammer)
 * API: Parse channel's tags (#4294, thanks @ChunkyProgrammer)
 * Translations update from Hosted Weblate (#4164, thanks to our many translators)
