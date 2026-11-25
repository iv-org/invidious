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
            // preload=0: the player waits for a click before loading anything
            if (typeof window.SABRReleaseStartGate === 'function') window.SABRReleaseStartGate();
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

    // --- Parity with player.js (the classic video.js player) ---

    /**
     * Add the current time to a link (t=, or start= for YouTube embeds), like
     * player.js's addCurrentTimeToURL.
     */
    function addCurrentTimeToURL(url, base, param) {
        var urlUsed = new URL(url, base);
        urlUsed.searchParams.delete('start');
        var currentTime = Math.ceil(video ? video.currentTime : 0);
        if (currentTime > 0) urlUsed.searchParams.set(param || 't', currentTime);
        else if (urlUsed.searchParams.has('t')) urlUsed.searchParams.delete('t');
        return urlUsed;
    }

    // Initialized to 5s, like player.js: the links keep restarting from the
    // beginning until the viewer really started watching.
    var lastLinkUpdate = 5;
    function updateTimeLinks() {
        var currentSecond = Math.floor(video.currentTime);
        if (currentSecond === lastLinkUpdate) return;
        lastLinkUpdate = currentSecond;

        function update(id, base, param) {
            var element = document.getElementById(id);
            if (element) element.href = addCurrentTimeToURL(element.getAttribute('data-base-url'), base, param);
        }
        if (!window.video_data || !video_data.live_now) {
            update('link-yt-watch');
            update('link-yt-embed', undefined, 'start');
        }
        update('link-iv-embed', location.origin);
        update('link-iv-other', location.origin);
        update('link-iv-listen', location.origin);
    }

    function getCookieValue(name) {
        var prefix = name + '=';
        var cookie = document.cookie.split(';').map(function (c) { return c.trim(); })
            .find(function (c) { return c.indexOf(prefix) === 0; });
        return cookie ? cookie.slice(prefix.length) : null;
    }

    // Save a speed changed in the player in the PREFS cookie, like player.js's
    // updateCookie, so the next videos play at that speed.
    function saveSpeed(speed) {
        if (!window.video_data || !video_data.params) return;
        var prefs = {};
        var cookieValue = getCookieValue('PREFS');
        if (cookieValue !== null) {
            try { prefs = JSON.parse(decodeURIComponent(cookieValue)) || {}; } catch (e) { prefs = {}; }
        }
        prefs.volume = video_data.params.volume;
        prefs.speed = speed;

        var date = new Date();
        date.setFullYear(date.getFullYear() + 2);
        var ipRegex = /^((\d+\.){3}\d+|[\dA-Fa-f]*:[\d:A-Fa-f]*:[\d:A-Fa-f]+)$/;
        var domain = location.hostname;
        // Fix for a bug in FF where the leading dot in the FQDN is not ignored
        if (domain.charAt(0) !== '.' && !ipRegex.test(domain) && domain !== 'localhost') domain = '.' + location.hostname;
        var secure = location.protocol.indexOf('https') === 0 ? ' Secure;' : '';
        document.cookie = 'PREFS=' + encodeURIComponent(JSON.stringify(prefs)) + '; SameSite=Lax; path=/; domain=' +
            domain + '; expires=' + date.toGMTString() + ';' + secure;
        video_data.params.speed = speed;
    }

    function onRateChange() {
        var speed = video.playbackRate;
        // Shaka sets the rate to 0 while buffering: that isn't a speed choice.
        if (!(speed > 0) || !window.video_data || !video_data.params || speed === video_data.params.speed) return;
        saveSpeed(speed);
    }

    // Embeds: the video title (a link to the watch page) over the top of the
    // player before playback starts and while paused, like player.js's overlay.
    function addEmbedTitle() {
        if (location.pathname.indexOf('/embed/') !== 0 || !video.parentNode) return;
        var playerData = document.getElementById('player_data');
        var title = '';
        try { title = JSON.parse(playerData.textContent).title || ''; } catch (e) {}
        if (!title || !window.video_data) return;

        var overlay = document.createElement('div');
        overlay.className = 'sabr-embed-title';
        var heading = document.createElement('h1');
        var link = document.createElement('a');
        link.rel = 'noopener noreferrer';
        link.target = '_blank';
        link.href = location.origin + '/watch?v=' + encodeURIComponent(video_data.id);
        link.textContent = title;
        heading.appendChild(link);
        overlay.appendChild(heading);
        video.parentNode.appendChild(overlay);

        function update() { overlay.classList.toggle('sabr-embed-title-hidden', !video.paused); }
        video.addEventListener('playing', update);
        video.addEventListener('pause', update);
        update();
    }

    window.SABRPagePlayer = {
        attach: function (videoElement) {
            if (!videoElement || video === videoElement) return;
            video = videoElement;
            listeners.forEach(function (listener) { video.addEventListener(listener.type, listener.fn); });
            video.addEventListener('timeupdate', updateTimeLinks);
            video.addEventListener('ratechange', onRateChange);
            addEmbedTitle();
            if (pendingTime !== null) {
                var seekTo = pendingTime;
                pendingTime = null;
                // Shaka seeks to the load's start position once the metadata is
                // loaded: an earlier seek would be undone, so wait for the data.
                if (video.readyState >= 2) {
                    video.currentTime = seekTo;
                } else {
                    video.addEventListener('loadeddata', function () { video.currentTime = seekTo; }, { once: true });
                }
            }
            if (pendingPlay) {
                pendingPlay = false;
                video.play().catch(function () {});
            }
        }
    };
})();
