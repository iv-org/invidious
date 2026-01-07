/**
 * SABR Player - Main player initialization for SABR streaming
 * Ported from Kira project (https://github.com/LuanRT/kira)
 * 
 * This module provides:
 * - Innertube API initialization
 * - Onesie config fetching
 * - Shaka Player setup with SABR adapter
 * - Video playback management
 */

'use strict';

var SABRPlayer = (function() {
    // Constants
    var VOLUME_KEY = 'youtube_player_volume';
    var PLAYBACK_POSITION_KEY = 'youtube_playback_positions';
    var SAVE_POSITION_INTERVAL_MS = 5000;

    var DEFAULT_ABR_CONFIG = {
        enabled: true,
        restrictions: { maxHeight: 480 },
        switchInterval: 4,
        useNetworkInformation: false
    };

    // State
    var player = null;
    var ui = null;
    var sabrAdapter = null;
    var videoElement = null;
    var shakaContainer = null;
    var currentVideoId = '';
    var isLive = false;
    var innertube = null;
    var clientConfig = null;
    var savePositionInterval = null;
    var playbackWebPoToken = null;
    var coldStartToken = null;
    var playbackWebPoTokenContentBinding = null;
    var playbackWebPoTokenCreationLock = false;

    /**
     * Get saved volume from localStorage
     */
    function getSavedVolume() {
        try {
            var volume = localStorage.getItem(VOLUME_KEY);
            return volume ? parseFloat(volume) : 1;
        } catch (error) {
            return 1;
        }
    }

    /**
     * Save volume to localStorage
     */
    function saveVolume(volume) {
        try {
            localStorage.setItem(VOLUME_KEY, volume.toString());
        } catch (error) {
            // Ignore
        }
    }

    /**
     * Get all saved playback positions
     */
    function getPlaybackPositions() {
        try {
            var positions = localStorage.getItem(PLAYBACK_POSITION_KEY);
            return positions ? JSON.parse(positions) : {};
        } catch (error) {
            return {};
        }
    }

    /**
     * Save playback position
     */
    function savePlaybackPosition(videoId, time) {
        if (!videoId || time < 1) return;
        try {
            var positions = getPlaybackPositions();
            positions[videoId] = time;
            localStorage.setItem(PLAYBACK_POSITION_KEY, JSON.stringify(positions));
        } catch (error) {
            // Ignore
        }
    }

    /**
     * Get playback position for a video
     */
    function getPlaybackPosition(videoId) {
        var positions = getPlaybackPositions();
        return positions[videoId] || 0;
    }

    /**
     * Initialize Innertube API
     */
    async function initInnertube() {
        if (innertube) return innertube;

        try {
            console.info('[SABRPlayer]', 'Initializing InnerTube API');
            
            // Check if Innertube is available from youtubei.js
            if (typeof Innertube === 'undefined') {
                throw new Error('youtubei.js not loaded');
            }

            // Set up Platform.shim.eval for URL deciphering (like Kira does)
            // This is required because the browser bundle doesn't include Jinter
            if (typeof Platform !== 'undefined' && Platform.shim) {
                Platform.shim.eval = async function(data, env) {
                    var properties = [];

                    if (env.n) {
                        properties.push('n: exportedVars.nFunction("' + env.n + '")');
                    }

                    if (env.sig) {
                        properties.push('sig: exportedVars.sigFunction("' + env.sig + '")');
                    }

                    var code = data.output + '\nreturn { ' + properties.join(', ') + ' }';
                    return new Function(code)();
                };
                console.info('[SABRPlayer]', 'Platform.shim.eval configured for URL deciphering');
            } else {
                console.warn('[SABRPlayer]', 'Platform.shim not available, URL deciphering may fail');
            }

            // Create Innertube with proxy fetch for CSP compliance
            innertube = await Innertube.create({
                fetch: SABRHelpers.fetchWithProxy,
                retrieve_player: true,
                generate_session_locally: true
            });

            // Initialize BotGuard for PoToken generation
            BotguardService.init().then(function() {
                console.info('[SABRPlayer]', 'BotGuard client initialized');
            }).catch(function(err) {
                console.warn('[SABRPlayer]', 'BotGuard initialization failed:', err.message);
            });

            // Preload the redirector URL
            try {
                var redirectorResponse = await SABRHelpers.fetchWithProxy(
                    'https://redirector.googlevideo.com/initplayback?source=youtube&itag=0&pvi=0&pai=0&owc=yes&cmo:sensitive_content=yes&alr=yes&id=' + Math.round(Math.random() * 1E5),
                    { method: 'GET' }
                );
                var redirectorResponseUrl = await redirectorResponse.text();

                if (redirectorResponseUrl.startsWith('https://')) {
                    localStorage.setItem(SABRHelpers.REDIRECTOR_STORAGE_KEY, redirectorResponseUrl);
                }
            } catch (e) {
                console.warn('[SABRPlayer]', 'Failed to preload redirector URL', e);
            }

            return innertube;
        } catch (error) {
            console.error('[SABRPlayer]', 'Failed to initialize Innertube', error);
            return null;
        }
    }

    /**
     * Fetch Onesie client config
     */
    async function fetchOnesieConfig() {
        if (clientConfig && SABRHelpers.isConfigValid(clientConfig)) {
            return clientConfig;
        }

        // Try loading from cache
        var cachedConfig = SABRHelpers.loadCachedClientConfig();
        if (cachedConfig) {
            clientConfig = cachedConfig;
            return clientConfig;
        }

        try {
            var tvConfigResponse = await SABRHelpers.fetchWithProxy(
                'https://www.youtube.com/tv_config?action_get_config=true&client=lb4&theme=cl',
                {
                    method: 'GET',
                    headers: {
                        'User-Agent': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version'
                    }
                }
            );

            var tvConfigText = await tvConfigResponse.text();
            var tvConfigJson = JSON.parse(tvConfigText.slice(4));
            var webPlayerContextConfig = tvConfigJson.webPlayerContextConfig.WEB_PLAYER_CONTEXT_CONFIG_ID_LIVING_ROOM_WATCH;
            var onesieHotConfig = webPlayerContextConfig.onesieHotConfig;

            // Helper to decode base64 to Uint8Array
            function base64ToU8(base64) {
                var binary = atob(base64);
                var bytes = new Uint8Array(binary.length);
                for (var i = 0; i < binary.length; i++) {
                    bytes[i] = binary.charCodeAt(i);
                }
                return bytes;
            }

            clientConfig = {
                clientKeyData: base64ToU8(onesieHotConfig.clientKey),
                keyExpiresInSeconds: onesieHotConfig.keyExpiresInSeconds,
                encryptedClientKey: base64ToU8(onesieHotConfig.encryptedClientKey),
                onesieUstreamerConfig: base64ToU8(onesieHotConfig.onesieUstreamerConfig),
                baseUrl: onesieHotConfig.baseUrl,
                timestamp: Date.now()
            };

            SABRHelpers.saveCachedClientConfig(clientConfig);
            return clientConfig;
        } catch (error) {
            console.error('[SABRPlayer]', 'Failed to fetch Onesie client config', error);
            return null;
        }
    }

    /**
     * Mint content-bound PoToken
     */
    async function mintContentWebPO() {
        console.log('[SABRPlayer] mintContentWebPO called, binding:', playbackWebPoTokenContentBinding);
        if (!playbackWebPoTokenContentBinding || playbackWebPoTokenCreationLock) {
            console.log('[SABRPlayer] mintContentWebPO skipped:', { binding: !!playbackWebPoTokenContentBinding, locked: playbackWebPoTokenCreationLock });
            return;
        }

        playbackWebPoTokenCreationLock = true;
        try {
            coldStartToken = BotguardService.mintColdStartToken(playbackWebPoTokenContentBinding);
            console.info('[SABRPlayer]', 'Cold start token created:', coldStartToken ? coldStartToken.substring(0, 30) + '...' : 'null');

            if (!BotguardService.isInitialized()) {
                console.log('[SABRPlayer] BotGuard not initialized, reinitializing...');
                await BotguardService.reinit();
            }

            if (BotguardService.isInitialized()) {
                playbackWebPoToken = await BotguardService.mintWebPoToken(
                    decodeURIComponent(playbackWebPoTokenContentBinding)
                );
                console.info('[SABRPlayer]', 'WebPO token created:', playbackWebPoToken ? playbackWebPoToken.substring(0, 30) + '...' : 'null');
            } else {
                console.warn('[SABRPlayer]', 'BotGuard still not initialized after reinit');
            }
        } catch (err) {
            console.error('[SABRPlayer]', 'Error minting WebPO token', err);
        } finally {
            playbackWebPoTokenCreationLock = false;
        }
    }

    /**
     * Initialize Shaka Player
     */
    async function initializeShakaPlayer(containerElement) {
        if (!shaka.Player.isBrowserSupported()) {
            throw new Error('Shaka Player is not supported in this browser');
        }

        // Install polyfills
        shaka.polyfill.installAll();

        shakaContainer = document.createElement('div');
        shakaContainer.className = 'sabr-player-container';
        shakaContainer.style.width = '100%';
        shakaContainer.style.height = '100%';

        videoElement = document.createElement('video');
        videoElement.autoplay = true;
        videoElement.style.width = '100%';
        videoElement.style.height = '100%';
        videoElement.style.backgroundColor = '#000';

        shakaContainer.appendChild(videoElement);
        containerElement.appendChild(shakaContainer);

        player = new shaka.Player();

        player.configure({
            preferredAudioLanguage: 'en-US',
            abr: DEFAULT_ABR_CONFIG,
            streaming: {
                bufferingGoal: 120,
                rebufferingGoal: 0.01,
                bufferBehind: 300,
                retryParameters: {
                    maxAttempts: 8,
                    fuzzFactor: 0.5,
                    timeout: 30 * 1000
                }
            }
        });

        videoElement.volume = getSavedVolume();
        videoElement.addEventListener('volumechange', function() {
            saveVolume(videoElement.volume);
        });
        videoElement.addEventListener('playing', function() {
            player.configure('abr.restrictions.maxHeight', Infinity);
        });
        videoElement.addEventListener('pause', function() {
            if (currentVideoId) {
                savePlaybackPosition(currentVideoId, videoElement.currentTime);
            }
        });

        await player.attach(videoElement);

        // Initialize UI if available
        if (shaka.ui && shaka.ui.Overlay) {
            ui = new shaka.ui.Overlay(player, shakaContainer, videoElement);
            ui.configure({
                addBigPlayButton: true,
                overflowMenuButtons: [
                    'captions',
                    'quality',
                    'language',
                    'playback_rate',
                    'loop',
                    'picture_in_picture'
                ]
            });
        }

        return player;
    }

    /**
     * Initialize SABR adapter
     */
    async function initializeSabrAdapter() {
        if (!player || !innertube) return;

        // Check if SabrStreamingAdapter is available from googlevideo
        if (typeof SabrStreamingAdapter === 'undefined') {
            console.error('[SABRPlayer]', 'googlevideo library not loaded');
            return;
        }

        // Create the player adapter
        var playerAdapter = new ShakaPlayerAdapter();
        
        // Use YouTube.js ANDROID client constants
        var androidClient = Constants.CLIENTS.ANDROID;
        
        sabrAdapter = new SabrStreamingAdapter({
            playerAdapter: playerAdapter,
            clientInfo: {
                osName: 'Android',
                osVersion: androidClient.OS_VERSION || '14',
                clientName: 3, // ANDROID - Used exclusively for SABR streaming requests
                clientVersion: androidClient.VERSION
            }
        });

        sabrAdapter.onMintPoToken(async function() {
            console.log('[SABRPlayer] onMintPoToken callback invoked');
            if (!playbackWebPoToken) {
                if (isLive) {
                    await mintContentWebPO();
                } else {
                    mintContentWebPO(); // Don't block for VOD
                }
            }
            var token = playbackWebPoToken || coldStartToken || '';
            console.log('[SABRPlayer] Returning token:', token ? 'token present (' + token.substring(0, 20) + '...)' : 'empty');
            return token;
        });

        sabrAdapter.attach(player);
        return sabrAdapter;
    }

    /**
     * Setup request filters for proxying
     */
    async function setupRequestFilters() {
        var networkingEngine = player?.getNetworkingEngine();
        if (!networkingEngine) return;

        var config = SABRHelpers.getProxyConfig();

        networkingEngine.registerRequestFilter(async function(type, request) {
            var url = new URL(request.uris[0]);

            // Proxy googlevideo requests
            if (url.host.endsWith('.googlevideo.com') || url.host.includes('youtube')) {
                var newUrl = new URL(url.toString());
                newUrl.searchParams.set('__host', url.host);
                newUrl.host = config.PROXY_HOST;
                newUrl.port = config.PROXY_PORT;
                newUrl.protocol = config.PROXY_PROTOCOL + ':';
                newUrl.pathname = '/proxy' + url.pathname;
                
                // Add required headers for googlevideo requests to avoid 403
                var proxyHeaders = [
                    ['user-agent', navigator.userAgent],
                    ['origin', 'https://www.youtube.com'],
                    ['referer', 'https://www.youtube.com/']
                ];
                
                // CRITICAL: Add content-type for POST requests (SABR videoplayback)
                // This is REQUIRED for YouTube to accept the protobuf request body
                if (request.body && request.body.byteLength > 0) {
                    proxyHeaders.push(['content-type', 'application/x-protobuf']);
                    console.log('[SABRPlayer] Adding content-type: application/x-protobuf for POST request');
                }
                
                // Add visitor ID if available from innertube session
                if (innertube?.session?.context?.client?.visitorData) {
                    proxyHeaders.push(['x-goog-visitor-id', innertube.session.context.client.visitorData]);
                }
                
                // Add client name and version - Force ANDROID (3) for SABR requests
                proxyHeaders.push(['x-youtube-client-name', '3']); // ANDROID
                if (innertube?.session?.context?.client?.clientVersion) {
                    proxyHeaders.push(['x-youtube-client-version', innertube.session.context.client.clientVersion]);
                }
                
                newUrl.searchParams.set('__headers', JSON.stringify(proxyHeaders));
                
                request.uris[0] = newUrl.toString();
            }
        });
    }

    /**
     * Load a video
     */
    async function loadVideo(videoId, containerElement, options) {
        options = options || {};
        currentVideoId = videoId;
        playbackWebPoToken = null;
        playbackWebPoTokenContentBinding = videoId;

        try {
            // Initialize components if needed
            if (!innertube) {
                innertube = await initInnertube();
                if (!innertube) {
                    throw new Error('Failed to initialize Innertube');
                }
            }

            if (!clientConfig) {
                clientConfig = await fetchOnesieConfig();
            }

            if (!player) {
                await initializeShakaPlayer(containerElement);
            } else {
                // Reset player configuration
                player.configure('abr', DEFAULT_ABR_CONFIG);
            }

            if (!sabrAdapter) {
                await initializeSabrAdapter();
            }

            await setupRequestFilters();

            // Fetch video info using Innertube
            var videoInfo = await innertube.getInfo(videoId);
            
            if (!videoInfo || videoInfo.playability_status?.status !== 'OK') {
                var reason = videoInfo?.playability_status?.reason || 'Unknown error';
                throw new Error('Video unavailable: ' + reason);
            }

            isLive = !!videoInfo.basic_info?.is_live;

            // Get streaming URL
            var streamingData = videoInfo.streaming_data;
            if (!streamingData) {
                throw new Error('No streaming data available');
            }

            var manifestUri;

            if (isLive) {
                // For live streams, use HLS or DASH manifest
                manifestUri = streamingData.hls_manifest_url || streamingData.dash_manifest_url;
            } else {
                // For VOD, generate DASH manifest from adaptive formats
                if (sabrAdapter && streamingData.server_abr_streaming_url) {
                    // SABR mode - need to decipher the server_abr_streaming_url first
                    var sabrUrl = streamingData.server_abr_streaming_url;
                    
                    // Decipher the URL if the player has a decipher function
                    if (innertube?.session?.player?.decipher) {
                        try {
                            sabrUrl = await innertube.session.player.decipher(sabrUrl);
                            console.log('[SABRPlayer] Deciphered streaming URL:', sabrUrl?.substring(0, 100) + '...');
                        } catch (decipherErr) {
                            console.error('[SABRPlayer] Failed to decipher URL:', decipherErr);
                            // Try to use the raw URL anyway
                            console.warn('[SABRPlayer] Trying raw URL instead');
                        }
                    } else {
                        console.warn('[SABRPlayer] Player decipher not available, using raw URL');
                    }
                    
                    console.log('[SABRPlayer] Setting streaming URL:', sabrUrl);
                    sabrAdapter.setStreamingURL(sabrUrl);
                    
                    // Build SABR formats
                    console.log('[SABRPlayer] Checking SABR format requirements:', {
                        buildSabrFormat: typeof buildSabrFormat,
                        adaptive_formats: !!streamingData.adaptive_formats,
                        formats_length: streamingData.adaptive_formats?.length
                    });
                    
                    if (typeof buildSabrFormat !== 'undefined' && streamingData.adaptive_formats) {
                        console.log('[SABRPlayer] Building SABR formats from', streamingData.adaptive_formats.length, 'adaptive formats');
                        var sabrFormats = streamingData.adaptive_formats.map(function(fmt) {
                            return buildSabrFormat(fmt);
                        });
                        console.log('[SABRPlayer] Setting', sabrFormats.length, 'SABR formats on adapter');
                        sabrAdapter.setServerAbrFormats(sabrFormats);
                        console.log('[SABRPlayer] SABR formats set successfully');
                    } else {
                        console.warn('[SABRPlayer] buildSabrFormat not available or no adaptive formats', {
                            buildSabrFormat: typeof buildSabrFormat,
                            has_adaptive_formats: !!streamingData.adaptive_formats
                        });
                    }
                    
                    // Set ustreamer config
                    var ustreamerConfig = videoInfo.player_config?.media_common_config?.media_ustreamer_request_config?.video_playback_ustreamer_config;
                    if (ustreamerConfig) {
                        sabrAdapter.setUstreamerConfig(ustreamerConfig);
                    }
                }

                // Generate DASH manifest
                var dashManifest = await videoInfo.toDash({
                    manifest_options: {
                        is_sabr: !!sabrAdapter,
                        captions_format: 'vtt',
                        include_thumbnails: false
                    }
                });

                manifestUri = 'data:application/dash+xml;base64,' + btoa(dashManifest);
            }

            if (!manifestUri) {
                throw new Error('Could not find a valid manifest URI');
            }

            // Determine start time
            var startTime = options.startTime;
            if (startTime === undefined && options.savePlayerPos !== false) {
                startTime = getPlaybackPosition(videoId);
            }

            // Load the manifest
            await player.load(manifestUri, isLive ? undefined : startTime);

            // Start playback
            videoElement.play().catch(function(err) {
                if (err.name === 'NotAllowedError') {
                    console.warn('[SABRPlayer]', 'Autoplay was prevented by the browser');
                }
            });

            // Start saving position periodically
            if (savePositionInterval) {
                clearInterval(savePositionInterval);
            }
            savePositionInterval = setInterval(function() {
                if (videoElement && currentVideoId && !videoElement.paused) {
                    savePlaybackPosition(currentVideoId, videoElement.currentTime);
                }
            }, SAVE_POSITION_INTERVAL_MS);

            return {
                player: player,
                videoElement: videoElement,
                videoInfo: videoInfo
            };
        } catch (error) {
            console.error('[SABRPlayer]', 'Error loading video:', error);
            throw error;
        }
    }

    /**
     * Dispose of the player
     */
    async function dispose() {
        if (savePositionInterval) {
            clearInterval(savePositionInterval);
            savePositionInterval = null;
        }

        if (videoElement && currentVideoId) {
            savePlaybackPosition(currentVideoId, videoElement.currentTime);
        }

        if (sabrAdapter) {
            sabrAdapter.dispose();
            sabrAdapter = null;
        }

        if (player) {
            await player.destroy();
            player = null;
        }

        if (ui) {
            ui.destroy();
            ui = null;
        }

        if (shakaContainer && shakaContainer.parentNode) {
            shakaContainer.parentNode.removeChild(shakaContainer);
        }

        videoElement = null;
        shakaContainer = null;
        currentVideoId = '';
    }

    /**
     * Get current player instance
     */
    function getPlayer() {
        return player;
    }

    /**
     * Get current video element
     */
    function getVideoElement() {
        return videoElement;
    }

    return {
        loadVideo: loadVideo,
        dispose: dispose,
        getPlayer: getPlayer,
        getVideoElement: getVideoElement,
        initInnertube: initInnertube,
        fetchOnesieConfig: fetchOnesieConfig
    };
})();

// Export for use
window.SABRPlayer = SABRPlayer;
