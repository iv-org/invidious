/**
 * SABR Init - Initialize SABR player when page loads
 * This file handles the SABR player initialization without inline scripts
 */

'use strict';

(function() {
    // Wait for SABR libs to be loaded
    window.addEventListener('sabr-libs-loaded', async function() {
        var container = document.getElementById('sabr-player-container');
        if (!container) {
            console.error('[SABR]', 'Player container not found');
            return;
        }

        var videoId = container.dataset.videoId;
        var autoplay = container.dataset.autoplay === 'true';
        var videoLoop = container.dataset.videoLoop === 'true';
        var codecPref = container.dataset.qualitySabr || 'vp9';

        try {
            var result = await SABRPlayer.loadVideo(videoId, container, {
                autoplay: autoplay,
                loop: videoLoop,
                codecPreference: codecPref
            });
            console.info('[SABR]', 'Video loaded successfully', result.videoInfo?.basic_info?.title);
        } catch (error) {
            console.error('[SABR]', 'Failed to load video:', error);
            // Show error message in container
            var errorDiv = document.createElement('div');
            errorDiv.className = 'sabr-error-display';
            errorDiv.innerHTML = '<p>Failed to load video with SABR player.</p>' +
                '<p>' + error.message + '</p>' +
                '<p><a href="?quality=dash">Try DASH player instead</a></p>';
            container.innerHTML = '';
            container.appendChild(errorDiv);
        }
    });
})();
