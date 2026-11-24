/**
 * SABR page player - a small video.js-like `player` object for the page scripts.
 *
 * watch.js, embed.js and handlers.js drive the classic player through a global
 * video.js `player` (and read the global `video_data` that player.js defines).
 * With the SABR player neither exists, so this script provides both. It loads
 * synchronously before those scripts; listeners and seeks registered before the
 * SABR player is ready are applied once sabr_init.js calls SABRPagePlayer.attach().
 *
 * Only what the page scripts use is implemented: on/off, currentTime, play, pause,
 * paused, duration.
 */

'use strict';

(function () {
    if (typeof window.video_data === 'undefined') {
        var videoDataElement = document.getElementById('video_data');
        if (videoDataElement) window.video_data = JSON.parse(videoDataElement.textContent);
    }

    var video = null;
    var listeners = []; // { type, fn }
    var pendingTime = null;
    var pendingPlay = false;

    var player = {
        on: function (type, fn) {
            listeners.push({ type: type, fn: fn });
            if (video) video.addEventListener(type, fn);
            return player;
        },
        // off(type) removes every listener of that type, like video.js.
        off: function (type, fn) {
            listeners = listeners.filter(function (listener) {
                var matches = listener.type === type && (!fn || listener.fn === fn);
                if (matches && video) video.removeEventListener(type, listener.fn);
                return !matches;
            });
            return player;
        },
        currentTime: function (time) {
            if (time === undefined) return video ? video.currentTime : (pendingTime || 0);
            var seconds = Number(time);
            if (!isFinite(seconds)) return player;
            if (video) video.currentTime = seconds;
            else pendingTime = seconds;
            return player;
        },
        play: function () {
            if (video) return video.play().catch(function () {});
            pendingPlay = true;
            return Promise.resolve();
        },
        pause: function () {
            if (video) video.pause();
            pendingPlay = false;
            return player;
        },
        paused: function () {
            return video ? video.paused : !pendingPlay;
        },
        duration: function () {
            return video ? video.duration : NaN;
        }
    };

    window.player = player;

    window.SABRPagePlayer = {
        attach: function (videoElement) {
            if (!videoElement || video === videoElement) return;
            video = videoElement;
            listeners.forEach(function (listener) { video.addEventListener(listener.type, listener.fn); });
            if (pendingTime !== null) {
                video.currentTime = pendingTime;
                pendingTime = null;
            }
            if (pendingPlay) {
                pendingPlay = false;
                video.play().catch(function () {});
            }
        }
    };
})();
