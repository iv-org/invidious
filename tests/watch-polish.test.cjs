const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');

const watchView = fs.readFileSync('src/invidious/views/watch.ecr', 'utf8');
const watchCss = fs.readFileSync('assets/css/watch-layout.css', 'utf8');
const playerCss = fs.readFileSync('assets/css/player.css', 'utf8');
const playerSources = fs.readFileSync('src/invidious/views/components/player_sources.ecr', 'utf8');
const playerJs = fs.readFileSync('assets/js/player.js', 'utf8');
const dependencies = fs.readFileSync('videojs-dependencies.yml', 'utf8');

test('watch title uses the accepted 25px desktop role', () => {
  assert.match(watchCss, /\.watch-title h1\s*\{[^}]*font-size:\s*clamp\([^;]*1\.5625rem\)/s);
});

test('YouTube quick action is icon-only but retains an accessible label', () => {
  const link = watchView.match(/<a id="link-yt-watch"[^>]*>[\s\S]*?<\/a>/)?.[0] || '';
  assert.match(link, /aria-label="<%= I18n\.translate\(locale, "videoinfo_watch_on_youTube"\) %>"/);
  assert.match(link, /ion-logo-youtube/);
  assert.doesNotMatch(link, /watch-action-label/);
});

test('clip boundary markers remain functional without a visible red rail artifact', () => {
  assert.match(playerJs, /player\.markers\(/);
  assert.match(playerJs, /player\.currentTime\(video_data\.params\.video_start\)/);
  assert.match(playerCss, /\.video-js \.vjs-marker\s*\{[^}]*display:\s*none\s*!important/s);
});

test('unused Video.js share plugin is not requested or initialized', () => {
  assert.doesNotMatch(playerSources, /videojs-share/);
  assert.doesNotMatch(playerJs, /shareOptions|vjs-share-control|player\.share/);
  assert.doesNotMatch(dependencies, /^videojs-share:/m);
});
