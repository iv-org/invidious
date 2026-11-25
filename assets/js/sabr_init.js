/**
 * SABR Init - Initialize SABR player when page loads
 * This file handles the SABR player initialization without inline scripts.
 * Settings and translated strings come from data-* attributes of the
 * #sabr-player-container element (see views/components/player.ecr).
 */

'use strict';

(function() {
    var started = false;

    function parsePreferredCaptions(json) {
        try {
            var list = JSON.parse(json || '[]');
            return Array.isArray(list) ? list.filter(function (c) { return typeof c === 'string' && c; }) : [];
        } catch (e) {
            return [];
        }
    }

    function readOptions(container) {
        var data = container.dataset;
        var query = new URLSearchParams(window.location.search);
        // An explicit start time in the link (t / time_continue / start) wins over
        // the saved position, like in the classic player.
        var hasStartParam = query.has('t') || query.has('time_continue') || query.has('start');
        var videoStart = parseFloat(data.start);
        var videoEnd = parseFloat(data.end);
        // Like the start time, only an explicit volume in the link overrides the
        // volume remembered by the player.
        var volume = query.has('volume') ? parseInt(data.volume, 10) : NaN;

        return {
            autoplay: data.autoplay === 'true',
            loop: data.videoLoop === 'true',
            listen: data.listen === 'true',
            speed: parseFloat(data.speed) || 1,
            startTime: (hasStartParam || videoStart > 0) && isFinite(videoStart) ? videoStart : undefined,
            endTime: videoEnd > 0 ? videoEnd : undefined,
            volume: isFinite(volume) ? Math.min(Math.max(volume, 0), 100) / 100 : undefined,
            volumePreference: isFinite(parseInt(data.volumePreference, 10)) ? Math.min(Math.max(parseInt(data.volumePreference, 10), 0), 100) / 100 : undefined,
            controls: data.controls !== 'false',
            preferredCaptions: parsePreferredCaptions(data.preferredCaptions),
            savePlayerPos: data.savePlayerPos === 'true',
            codecPreference: data.qualitySabr || 'vp9',
            qualityPreference: data.qualitySabrResolution || 'auto'
        };
    }

    function readMessages(container) {
        var data = container.dataset;
        return {
            loadFailed: data.i18nLoadFailed,
            unavailable: data.i18nUnavailable,
            throttled: data.i18nThrottled,
            tryDash: data.i18nTryDash,
            audioTrack: data.i18nAudioTrack,
            backoff: data.i18nBackoff
        };
    }

    function showError(container, detail) {
        var lines = [container.dataset.i18nLoadFailed || 'Failed to load video with SABR player.'];
        if (detail) lines.push(detail);

        var errorDiv;
        if (window.SABRPlayer && SABRPlayer.createErrorDisplay) {
            errorDiv = SABRPlayer.createErrorDisplay(lines);
        } else {
            errorDiv = document.createElement('div');
            errorDiv.className = 'sabr-error-display';
            lines.forEach(function (line) {
                var p = document.createElement('p');
                p.textContent = line;
                errorDiv.appendChild(p);
            });
        }
        container.textContent = '';
        container.appendChild(errorDiv);
    }

    // preload=0 without autoplay: show the poster and a play button, and only fetch
    // anything (player response, media) once the viewer starts playback.
    function waitForPlayClick(container, options) {
        return new Promise(function (resolve) {
            var button = document.createElement('button');
            button.type = 'button';
            button.className = 'sabr-click-to-play';
            button.setAttribute('aria-label', 'Play');
            if (container.dataset.poster) button.style.backgroundImage = 'url("' + container.dataset.poster.replace(/["\\]/g, '') + '")';
            function release() {
                window.SABRReleaseStartGate = null;
                button.remove();
                options.autoplay = true;
                resolve();
            }
            button.addEventListener('click', release, { once: true });
            // The page scripts' player.play() (e.g. a timestamp link) also starts loading
            window.SABRReleaseStartGate = release;
            container.appendChild(button);
        });
    }

    async function start() {
        if (started) return;
        started = true;

        var container = document.getElementById('sabr-player-container');
        if (!container) {
            console.error('[SABR]', 'Player container not found');
            return;
        }

        var options = readOptions(container);
        if (container.dataset.preload === 'false' && !options.autoplay) {
            await waitForPlayClick(container, options);
        }

        try {
            // sabr_player.js is loaded separately from the libraries: report it missing
            // like any other startup failure.
            if (!window.SABRPlayer) throw new Error('The SABR player script failed to load');
            SABRPlayer.setMessages(readMessages(container));
            var result = await SABRPlayer.loadVideo(container.dataset.videoId, container, options);
            console.info('[SABR]', 'Video loaded successfully', result.videoInfo?.basic_info?.title);
            // Connect the page scripts' `player` object (sabr_page_player.js) to the video.
            if (window.SABRPagePlayer) SABRPagePlayer.attach(result.videoElement);
        } catch (error) {
            console.error('[SABR]', 'Failed to load video:', error);
            showError(container, error && error.message);
        }
    }

    function fail(error) {
        if (started) return;
        started = true;
        console.error('[SABR]', 'Failed to load the SABR libraries:', error);
        var container = document.getElementById('sabr-player-container');
        if (container) showError(container, error && error.message);
    }

    // sabr_loader.js (an ES module) runs after this script and reports the library
    // load result with an event; also check the state in case it already ran.
    // sabr_loader.js itself failed to load (e.g. 404): it can't report anything
    var loaderScript = document.getElementById('sabr-loader');
    if (loaderScript) {
        loaderScript.addEventListener('error', function () {
            fail(new Error('The SABR loader script failed to load'));
        });
    }
    window.addEventListener('sabr-libs-loaded', start);
    window.addEventListener('sabr-libs-failed', function (e) { fail(e.detail); });
    if (window.SABR_LIBS_STATE === 'loaded') start();
    else if (window.SABR_LIBS_STATE === 'failed') fail(window.SABR_LIBS_ERROR);
})();
