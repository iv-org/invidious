# Invidious UI refinement

## Purpose

The primary user is someone who wants to search and browse YouTube privately,
then sign in only when saved preferences or subscriptions need an account. The
interface is used in wide desktop browsing sessions and narrow touch sessions.
It remains server-rendered and usable with JavaScript disabled.

The approved direction is the refined proposal: B's distinct channel treatment
and contained video cards, paired with a compact account form. Search results
should scan as media destinations, while a channel remains visibly different
from a video result. Existing search filters, saved home/feed preferences,
localization, thin mode, theme choice, authentication, CAPTCHA, and all
existing links/forms retain their behavior.

## Tokens

The implementation exposes the following values in `assets/css/redesign.css`.
They are semantic roles, not a new user preference. `.light-theme`,
`.dark-theme`, and the system-controlled `.no-theme` each assign the same
roles. Client-side theme changes must retain the structural `redesign-ui` body
class while replacing only the theme class.

| Role | Light | Dark | Use |
| --- | --- | --- | --- |
| `--redesign-canvas` | `#f7f8fa` | `#0b0c0e` | Page background |
| `--redesign-surface` | `#ffffff` | `#15161a` | Media cards |
| `--redesign-control` | `#fbfcfd` | `#111216` | Search and text inputs |
| `--redesign-text` | `#17181b` | `#f4f4f5` | Primary text and titles |
| `--redesign-muted` | `#656a73` | `#a9abb1` | Metadata and quiet navigation |
| `--redesign-line` | `#d9dce2` | `#303239` | Stable boundaries |
| `--redesign-accent` | `#255fbe` | `#83b5fc` | Links and primary submit action |
| `--redesign-accent-hover` | `#174a9f` | `#b2d0ff` | Link and submit hover/focus state |
| `--redesign-on-accent` | `#ffffff` | `#121315` | Submit-action foreground |
| `--redesign-focus` | `#0b6ece` | `#83b5fc` | 3 px keyboard focus outline |
| `--redesign-radius` | `8px` | `8px` | Results and form surfaces |
| `--redesign-control-radius` | `6px` | `6px` | Inputs and compact controls |
| `--redesign-shadow` | `0 1px 2px rgb(15 23 42 / 0.08)` | `0 1px 2px rgb(0 0 0 / 0.38)` | Card edge separation only |

The typeface remains the project’s existing system stack. Results use 16 px,
650-weight titles at a 1.32 line-height; channel names use 22 px at 1.3;
metadata uses 13–14 px and stays readable in both themes. The spacing scale is
`--redesign-space-1` = 8 px, `--redesign-space-2` = 12 px,
`--redesign-space-3` = 16 px, and `--redesign-space-4` = 24 px.

## Layout and components

- The navigation bar has a 64 px minimum height, a border separating it from
  content, and a single clear search field. Search stays in the header row; below 600px a native icon disclosure opens the field.
- Search channel matches occupy their own horizontally scrollable row above
  the continuous media grid. Each match keeps its avatar, linked identity,
  metadata and description. Channels never act as headings for unrelated
  video results; selecting a channel follows its existing channel link.
- Videos and playlists are contained cards with a 16:9 thumbnail, then title,
  author and metadata. They use two columns from 768 px and three from 1100 px;
  under 768 px each card is full width. The thumbnail’s duration and existing
  action controls remain in their established positions.
- The login form is at most 352 px wide, sits directly on the canvas without an outer card, has persistent labels, native inputs, and
  one full-width submit action. Existing server validation and CAPTCHA
  rendering remain in the same form flow. The heading-to-field gap is 24 px; the page fills the viewport and its footer follows the flexible main area near the bottom.

There are only two raised surface types: media cards and the expanded
filter panel. Each has a one-pixel boundary plus the same restrained shadow;
the page, navigation, and footer remain on the base plane.

The watch-layout layer consumes the same theme through `--watch-border`,
`--watch-panel`, `--watch-muted`, and `--watch-focus` aliases. It owns the
watch composition and player controls; the shared stylesheet only supplies the
common color roles.

## Access and adaptation

All existing links, buttons, checkbox/radio controls, labels, forms, and
server-side errors retain their native semantics. A skip link targets the main
content. Keyboard focus uses the `--redesign-focus` outline with a 3 px offset;
focus is never indicated by color alone. Controls remain at least 36–44 px in
their compact contexts, and the account submit/input controls are 44 px high.

Long translated titles and channel names wrap; no title or metadata is clamped.
The dark, light, and system theme roles are explicit. Reduced-motion users do
not receive new animated effects. Thin mode retains its placeholders and does
not request thumbnails.

## Evidence and open questions

`DESIGN.html` renders the token values, wide/narrow card compositions, focus,
the channel distinction, and login/CAPTCHA state using the same rules. The
application build and browser checks are recorded by the coordinating agent.
There are no unresolved visual decisions in this approved scope.

## Watch page and optional player enhancements

The accepted A watch composition places the player beside a compact related
rail, with the title, channel, compact action row, description and comments
beneath the player. The native theater checkbox expands the same video across
the grid; it preserves playback and also works without scripts. Below 900 px,
related videos follow the main content. All stream/source and download links
retain their existing behavior.

Player actions retain Video.js's familiar icons and accessible names. Time and
speed remain text. All players put a visible 4px seek track on its own row above icon controls; the duplicate remaining-time display is hidden to conserve space.
Only while focus is inside the player, J/L seek exactly ten seconds; K and a Space tap toggle playback. Holding Space
or the left mouse button on the video for 350 ms temporarily plays at exactly
2×, then restores the prior speed and paused state. Editable fields, menus,
controls and modified shortcuts are excluded. Holds never save a temporary
speed preference. Blur/cancel restores state. The post-hold mouseup and click
are consumed because Video.js toggles playback on mouseup.

## Runtime verification criterion

The actual application must retain the design after scripts initialize and
when themes change. Verify rendered desktop and narrow login/search/watch
pages, real media playback, hold release, theater continuity, and the native
no-JavaScript flow. Static screenshots and mocked gesture tests alone cannot
prove these behaviors. This is project guidance proposed by the user's runtime
correction; it does not modify shared Fleet guidance.

## Channel and feed navigation refinement

Channel content tabs and sort links form a horizontal toolbar; utility links
remain separate and quiet. Subscribe and RSS retain their existing actions.
The signed-in header reserves intrinsic width for account controls, uses native
logout button semantics. Search stays in the header and becomes an icon below 600px.
Subscription feeds have a clear title, management/history/RSS actions and an
empty state linking to subscription management. Saved feed choices remain
unchanged. On narrow screens controls wrap rather than collide.

The search results heading and top pagination share one row, with equal vertical
centers and outer edges aligned to the media cards. Pagination wraps within its
available space on narrow screens; card and channel geometry remain unchanged.

## Account disclosure and card metadata

Signed-in navigation shows the existing notification bell and a circular local
avatar. An initial is displayed only when show_nick is enabled; otherwise a
generic person icon preserves that privacy preference. A native details/summary
disclosure exposes the name, Preferences and CSRF-protected POST
logout. It works without JavaScript; optional script adds Escape, outside-click
and focus-out dismissal. No remote profile image or avatar service is used.

Video cards place title first, channel and views on the second row, date and
existing quick actions on the third. Existing verified badges use bright #3ea6ff in dark mode and #0878d1 in light mode, a .2em inline gap and -.08em baseline adjustment; no verification statuses are added or inferred.

Header avatars are 32px within 40px hit areas; the bell is approximately 22px.
Filter disclosure has horizontal padding, and card action links center their
glyphs alongside the date text. Theme choices set the requested mode explicitly
on both client and server; repeated selection never reverses the mode.

Theater mode sits beside fullscreen in the enhanced player and has an explicit
text label in the no-JavaScript fallback. Storyboard URLs preserve root-relative
paths; previews show one timestamp and clamp to player edges. The timeline has
a neutral track, lighter buffered range and bright blue progress.

Watch actions share a compact row: view/like counts on the left; Share, Download and More on the right. More holds audio-only mode, source/embed/instance links, annotations and metadata. Native disclosures retain download
formats, playlist forms and technical metadata, wrapping on narrow screens.
Subscribe is red (#d92332) with white text; subscribed state stays neutral. Channel verification marks stay bright blue; only comment verification is white. All keyboard handlers require focus
inside the player; search, page actions and outside clicks release shortcuts.

Player follow-up: the large play control is centered. Play-button focus accepts
shortcuts; external inputs remain excluded. Fullscreen clears fluid aspect-ratio
padding, captions reserve 68px above visible controls, and caption menus use
readable padded rows. Share is only below the video, with Invidious/YouTube URL
choices and optional clipboard buttons; native links work without JavaScript.
Action menus dismiss on outside click or Escape, and only one sibling stays
open. Header bottom padding is 4px with no divider. Related titles use primary
text, with muted channel/views and consistent thumbnail geometry.

Theater is the default watch layout, including without JavaScript; the player
button returns to the split layout. Light and Dark icon controls remain visible beside the avatar; Preferences stays inside its menu.

Final refinement: Audio mode and Watch on YouTube are quick actions alongside
Share, Download and More. Instance/embed/annotation links are hidden; More holds
remaining metadata. Menus have bounded scrollable height. Comment avatars are
36px with consistent author/body/metadata/reply spacing. Cards align metadata
rows and avoid inherited paragraph margins. Player corners are 12px, with a
12px gap below navigation. Light mode strengthens muted text and surface borders.

Embedded-fullscreen recovery: when the browser leaves native fullscreen pending
for 700ms, reuse Video.js full-window mode; F/button and Escape exit preserve
the same player and video. Regular browsers continue using native fullscreen.

The watch title tops out at 25px to retain hierarchy without competing with the
player. Watch on YouTube is a 36px icon action with a localized accessible name
and native tooltip. Start/end clip markers continue controlling playback but are
visually hidden because the blue progress rail already communicates position.
The unused Video.js share plugin is excluded; sharing remains in the watch action
row through native links and the optional copy enhancement.

The watch title tops out at 25px to retain hierarchy without competing with the
player. Watch on YouTube is a 36px icon action with a localized accessible name
and native tooltip. Start/end clip markers continue controlling playback but are
visually hidden because the blue progress rail already communicates position.
The unused Video.js share plugin is excluded; sharing remains in the watch action
row through native links and the optional copy enhancement.
