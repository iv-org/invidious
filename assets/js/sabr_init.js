/**
 * SABR Init - Initialize SABR player when page loads
 * This file handles the SABR player initialization without inline scripts.
 * Settings and translated strings come from data-* attributes of the
 * #sabr-player-container element (see views/components/player.ecr).
 */

'use strict';

(function() {
    var started = false;

    function readOptions(container) {
        var data = container.dataset;
        var query = new URLSearchParams(window.location.search);
        // An explicit start time in the link (t / time_continue / start) wins over
        // the saved position, like in the classic player.
        var hasStartParam = query.has('t') || query.has('time_continue') || query.has('start');
        var videoStart = parseFloat(data.start);

        return {
            autoplay: data.autoplay === 'true',
            loop: data.videoLoop === 'true',
            listen: data.listen === 'true',
            speed: parseFloat(data.speed) || 1,
            startTime: (hasStartParam || videoStart > 0) && isFinite(videoStart) ? videoStart : undefined,
            savePlayerPos: data.savePlayerPos === 'true',
            codecPreference: data.qualitySabr || 'vp9'
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

    async function start() {
        if (started) return;
        started = true;

        var container = document.getElementById('sabr-player-container');
        if (!container) {
            console.error('[SABR]', 'Player container not found');
            return;
        }

        SABRPlayer.setMessages(readMessages(container));

        try {
            var result = await SABRPlayer.loadVideo(container.dataset.videoId, container, readOptions(container));
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
    window.addEventListener('sabr-libs-loaded', start);
    window.addEventListener('sabr-libs-failed', function (e) { fail(e.detail); });
    if (window.SABR_LIBS_STATE === 'loaded') start();
    else if (window.SABR_LIBS_STATE === 'failed') fail(window.SABR_LIBS_ERROR);
})();
