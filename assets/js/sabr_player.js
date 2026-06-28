/**
 * SABR Player - Main player initialization for SABR streaming
 *
 * Re-engineered (from the kira-based POC) to use FreeTube's SABR engine:
 * - Builds a data:application/sabr+json manifest from the youtube.js VideoInfo
 * - Registers FreeTube's sabr: networking scheme (sabr_scheme_plugin.js)
 * - Drives Shaka 5 via the application/sabr+json manifest parser
 *
 * PoToken is minted browser-side via bgutils-js BotGuard and proxied through
 * the Invidious /proxy route for CSP compliance.
 */

'use strict';

var SABRPlayer = (function () {
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

  var sabrStream = null;         // handle returned by setupSabrScheme
  var sabrManifest = null;       // captured from player.getManifest() on 'loaded'
  var currentLoadOptions = null; // for onReloadOnce -> re-run loadVideo
  var reloadCount = 0;           // cap reloads to prevent infinite loop on blocked/throttled videos
  var MAX_RELOADS = 3;

  function getSavedVolume() {
    try {
      var v = localStorage.getItem(VOLUME_KEY);
      return v ? parseFloat(v) : 1;
    } catch (e) { return 1; }
  }
  function saveVolume(volume) {
    try { localStorage.setItem(VOLUME_KEY, volume.toString()); } catch (e) {}
  }
  function getPlaybackPositions() {
    try {
      var p = localStorage.getItem(PLAYBACK_POSITION_KEY);
      return p ? JSON.parse(p) : {};
    } catch (e) { return {}; }
  }
  function savePlaybackPosition(videoId, time) {
    if (!videoId || time < 1) return;
    try {
      var positions = getPlaybackPositions();
      positions[videoId] = time;
      localStorage.setItem(PLAYBACK_POSITION_KEY, JSON.stringify(positions));
    } catch (e) {}
  }
  function getPlaybackPosition(videoId) {
    var positions = getPlaybackPositions();
    return positions[videoId] || 0;
  }

  function base64ToU8(base64) {
    // base64ToU8 from googlevideo handles websafe, but for client config we need raw.
    var binary = atob(base64);
    var bytes = new Uint8Array(binary.length);
    for (var i = 0; i < binary.length; i++) bytes[i] = binary.charCodeAt(i);
    return bytes;
  }

  async function initInnertube() {
    if (innertube) return innertube;
    try {
      console.info('[SABRPlayer]', 'Initializing InnerTube API');
      if (typeof Innertube === 'undefined') throw new Error('youtubei.js not loaded');

      // Set up Platform.shim.eval for URL deciphering (browser bundle lacks Jinter).
      if (typeof Platform !== 'undefined' && Platform.shim) {
        Platform.shim.eval = async function (data, env) {
          var properties = [];
          if (env.n) properties.push('n: exportedVars.nFunction("' + env.n + '")');
          if (env.sig) properties.push('sig: exportedVars.sigFunction("' + env.sig + '")');
          var code = data.output + '\nreturn { ' + properties.join(', ') + ' }';
          return new Function(code)();
        };
        console.info('[SABRPlayer]', 'Platform.shim.eval configured for URL deciphering');
      } else {
        console.warn('[SABRPlayer]', 'Platform.shim not available, URL deciphering may fail');
      }

      innertube = await Innertube.create({
        fetch: SABRHelpers.fetchWithProxy,
        retrieve_player: true,
        generate_session_locally: true
      });

      // Kick off BotGuard init (don't block player setup).
      BotguardService.init().then(function () {
        console.info('[SABRPlayer]', 'BotGuard client initialized');
      }).catch(function (err) {
        console.warn('[SABRPlayer]', 'BotGuard initialization failed:', err.message);
      });

      // Preload the redirector URL.
      try {
        var redirectorResponse = await SABRHelpers.fetchWithProxy(
          'https://redirector.googlevideo.com/initplayback?source=youtube&itag=0&pvi=0&pai=0&owc=yes&cmo:sensitive_content=yes&alr=yes&id=' + Math.round(Math.random() * 1e5),
          { method: 'GET' }
        );
        var redirectorResponseUrl = await redirectorResponse.text();
        if (redirectorResponseUrl.indexOf('https://') === 0) {
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

  async function fetchOnesieConfig() {
    if (clientConfig && SABRHelpers.isConfigValid(clientConfig)) return clientConfig;
    var cached = SABRHelpers.loadCachedClientConfig();
    if (cached) { clientConfig = cached; return clientConfig; }
    try {
      var tvConfigResponse = await SABRHelpers.fetchWithProxy(
        'https://www.youtube.com/tv_config?action_get_config=true&client=lb4&theme=cl',
        {
          method: 'GET',
          headers: { 'User-Agent': 'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/Version' }
        }
      );
      var tvConfigText = await tvConfigResponse.text();
      var tvConfigJson = JSON.parse(tvConfigText.slice(4));
      var webPlayerContextConfig = tvConfigJson.webPlayerContextConfig.WEB_PLAYER_CONTEXT_CONFIG_ID_LIVING_ROOM_WATCH;
      var onesieHotConfig = webPlayerContextConfig.onesieHotConfig;

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

  async function mintContentWebPO() {
    if (!playbackWebPoTokenContentBinding || playbackWebPoTokenCreationLock) return;
    playbackWebPoTokenCreationLock = true;
    try {
      coldStartToken = BotguardService.mintColdStartToken(playbackWebPoTokenContentBinding);
      console.info('[SABRPlayer]', 'Cold start token created:', coldStartToken ? coldStartToken.substring(0, 30) + '...' : 'null');

      if (!BotguardService.isInitialized()) {
        await BotguardService.reinit();
      }
      if (BotguardService.isInitialized()) {
        playbackWebPoToken = await BotguardService.mintWebPoToken(decodeURIComponent(playbackWebPoTokenContentBinding));
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

  async function initializeShakaPlayer(containerElement, listenMode) {
    if (!shaka.Player.isBrowserSupported()) {
      throw new Error('Shaka Player is not supported in this browser');
    }
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
      abr: DEFAULT_ABR_CONFIG,
      streaming: {
        bufferingGoal: 120,
        rebufferingGoal: 0.01,
        bufferBehind: 300,
        retryParameters: { maxAttempts: 8, fuzzFactor: 0.5, timeout: 30 * 1000 }
      },
      manifest: {
        // disableVideo is read by our SabrManifestParser to skip video streams for audio-only/listen mode.
        disableVideo: !!listenMode
      }
    });

    videoElement.volume = getSavedVolume();
    videoElement.addEventListener('volumechange', function () { saveVolume(videoElement.volume); });
    videoElement.addEventListener('playing', function () {
      player.configure('abr.restrictions.maxHeight', Infinity);
    });
    videoElement.addEventListener('pause', function () {
      if (currentVideoId) savePlaybackPosition(currentVideoId, videoElement.currentTime);
    });

    await player.attach(videoElement);

    if (shaka.ui && shaka.ui.Overlay) {
      ui = new shaka.ui.Overlay(player, shakaContainer, videoElement);
      ui.configure({
        overflowMenuButtons: ['captions', 'quality', 'language', 'playback_rate', 'loop', 'picture_in_picture']
      });
    }

    return player;
  }

  // Route non-sabr: requests (captions, storyboards, image tiles) through the
  // Invidious /proxy so they satisfy CSP. The sabr: scheme is handled
  // separately by setupSabrScheme and also routes through /proxy internally.
  function setupRequestFilters() {
    var networkingEngine = player && player.getNetworkingEngine ? player.getNetworkingEngine() : null;
    if (!networkingEngine) return;

    networkingEngine.registerRequestFilter(function (type, request) {
      var uri = request.uris[0];
      if (!uri) return;
      // sabr: is owned by the SABR scheme plugin; never rewrite it here.
      if (uri.indexOf('sabr:') === 0) return;
      try {
        var url = new URL(uri);
      } catch (e) { return; }

      var isGoogleVideo = url.hostname.endsWith('.googlevideo.com') || url.hostname.indexOf('googlevideo') !== -1;
      var isYouTube = url.hostname.endsWith('.youtube.com');
      if (!isGoogleVideo && !isYouTube) return;

      // Reuse the shared proxy helper so __host/__headers are set consistently.
      var proxied = SABRHelpers.proxyUrl(url, request.headers || {});
      proxied.searchParams.set('alr', 'yes');
      request.uris[0] = proxied.toString();
    });
  }

  // Map a youtube.js Format to the SabrManifest "formats" entry shape expected
  // by sabr_manifest_parser.js (port of FreeTube's SabrManifestParser).
  function mapFormatToManifestEntry(fmt) {
    var audioTrack = fmt.audio_track || null;
    var colorInfo = fmt.color_info || null;
    return {
      itag: fmt.itag,
      lastModified: fmt.last_modified_ms,
      mimeType: fmt.mime_type,
      xtags: fmt.xtags,
      bitrate: fmt.bitrate,
      initRange: fmt.init_range,
      indexRange: fmt.index_range,
      width: fmt.width,
      height: fmt.height,
      frameRate: fmt.fps,
      quality: fmt.quality,
      language: fmt.language,
      audioSampleRate: fmt.audio_sample_rate,
      audioChannels: fmt.audio_channels,
      isDrc: fmt.is_drc,
      isVoiceBoost: fmt.is_vb,
      isOriginal: fmt.is_original,
      isDubbed: fmt.is_dubbed,
      isAutoDubbed: fmt.is_auto_dubbed,
      isDescriptive: fmt.is_descriptive,
      isSecondary: fmt.is_secondary,
      spatialAudio: !!(fmt.spatial_audio_type),
      label: audioTrack ? audioTrack.display_name : undefined,
      colorTransferCharacteristics: colorInfo ? colorInfo.transfer_characteristics : undefined,
      colorPrimaries: colorInfo ? colorInfo.primaries : undefined
    };
  }

  function buildCaptions(videoInfo) {
    var out = [];
    var tracks = videoInfo.captions && videoInfo.captions.caption_tracks;
    if (!tracks) return out;
    for (var i = 0; i < tracks.length; i++) {
      var c = tracks[i];
      var url;
      try {
        url = new URL(c.base_url);
        url.searchParams.set('fmt', 'vtt');
        url = url.toString();
      } catch (e) {
        url = c.base_url;
      }
      out.push({
        id: c.vss_id,
        url: url,
        label: c.name ? c.name.text : (c.language_code || ''),
        language: c.language_code || 'und',
        mimeType: 'text/vtt'
      });
    }
    return out;
  }

  function buildStoryboards(videoInfo) {
    var out = [];
    var sb = videoInfo.storyboards;
    if (!sb || sb.type !== 'PlayerStoryboardSpec') return out;
    var boards = sb.boards || [];
    // Pick the highest-res storyboard (matches FreeTube behaviour).
    var board = boards.length ? boards[boards.length - 1] : null;
    if (!board) return out;
    out.push({
      templateUrl: board.template_url,
      mimeType: 'image/webp',
      columns: board.columns,
      rows: board.rows,
      thumbnailCount: board.thumbnail_count,
      thumbnailWidth: board.thumbnail_width,
      thumbnailHeight: board.thumbnail_height,
      storyboardCount: board.storyboard_count,
      interval: board.interval > 0 ? board.interval / 1000 : 0
    });
    return out;
  }

  function buildChapters(videoInfo) {
    var out = [];
    var ch = videoInfo.chapters;
    if (!ch || !ch.get) return out;
    try {
      var list = ch.get();
      if (!list || !list.length) return out;
      for (var i = 0; i < list.length; i++) {
        var c = list[i];
        out.push({
          title: c.title || '',
          startSeconds: c.start || 0,
          endSeconds: c.end || (i + 1 < list.length ? (list[i + 1].start || 0) : 0)
        });
      }
    } catch (e) {
      // chapters not available for this video - harmless
    }
    return out;
  }

  // Build a data:application/sabr+json manifest URI from a youtube.js VideoInfo.
  // Port of FreeTube's Watch.js#createLocalSabrManifest.
  function buildSabrManifest(videoInfo, poToken, clientInfo) {
    var streamingData = videoInfo.streaming_data;
    if (!streamingData || !streamingData.server_abr_streaming_url || !streamingData.adaptive_formats) {
      return null;
    }

    var url = new URL(streamingData.server_abr_streaming_url);
    url.searchParams.set('alr', 'yes');
    if (videoInfo.cpn) url.searchParams.set('cpn', videoInfo.cpn);

    var sabrData = {
      url: url.toString(),
      poToken: poToken || '',
      ustreamerConfig: videoInfo.player_config &&
        videoInfo.player_config.media_common_config &&
        videoInfo.player_config.media_common_config.media_ustreamer_request_config &&
        videoInfo.player_config.media_common_config.media_ustreamer_request_config.video_playback_ustreamer_config || '',
      clientInfo: clientInfo
    };
    SABRPlayer._lastSabrData = sabrData;

    var adaptiveFormats = streamingData.adaptive_formats;
    var duration = Infinity;
    for (var i = 0; i < adaptiveFormats.length; i++) {
      var d = adaptiveFormats[i].approx_duration_ms;
      if (typeof d === 'number' && d < duration) duration = d;
    }
    if (!isFinite(duration)) duration = (videoInfo.basic_info && videoInfo.basic_info.duration) ? videoInfo.basic_info.duration * 1000 : 0;
    duration = duration / 1000;

    var formats = [];
    for (var j = 0; j < adaptiveFormats.length; j++) {
      formats.push(mapFormatToManifestEntry(adaptiveFormats[j]));
    }

    var sabrManifest = {
      duration: duration,
      formats: formats,
      captions: buildCaptions(videoInfo),
      storyboards: buildStoryboards(videoInfo),
      chapters: buildChapters(videoInfo)
    };

    return 'data:' + window.MANIFEST_TYPE_SABR + ',' + encodeURIComponent(JSON.stringify(sabrManifest));
  }

  function getPlayerWidth() { return videoElement ? videoElement.clientWidth : 1280; }
  function getPlayerHeight() { return videoElement ? videoElement.clientHeight : 720; }
  function getPlayer() { return player; }
  function getManifest() { return sabrManifest; }

  function wireSabrStream(loadFn) {
    if (!sabrStream) return;
    sabrStream.onBackoffRequested(function (info) {
      var ms = info && info.backoffMs ? info.backoffMs : 0;
      console.warn('[SABRPlayer] SABR backoff requested:', ms, 'ms');
      var toast = document.querySelector('.sabr-backoff-toast');
      if (!toast && shakaContainer) {
        toast = document.createElement('div');
        toast.className = 'sabr-backoff-toast';
        toast.style.cssText = 'position:absolute;bottom:48px;left:50%;transform:translateX(-50%);background:rgba(0,0,0,0.75);color:#fff;padding:6px 12px;border-radius:4px;font-size:13px;pointer-events:none;z-index:10';
        shakaContainer.appendChild(toast);
      }
      if (toast) {
        toast.textContent = 'SABR throttled by YouTube, retrying in ' + (ms / 1000).toFixed(1) + 's…';
        clearTimeout(toast._t);
        toast._t = setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, Math.max(ms + 500, 2000));
      }
    });
    sabrStream.onReloadOnce(function () {
      reloadCount++;
      if (reloadCount >= MAX_RELOADS) {
        console.error('[SABRPlayer] SABR reload limit reached; giving up on video', currentVideoId);
        if (shakaContainer) {
          var errDiv = document.createElement('div');
          errDiv.className = 'sabr-error-display';
          errDiv.innerHTML = '<p>This video is currently unavailable via SABR.</p>' +
            '<p>YouTube is throttling this request.</p>' +
            '<p><a href="?quality=dash">Try DASH player instead</a></p>';
          shakaContainer.appendChild(errDiv);
        }
        return;
      }
      console.warn('[SABRPlayer] SABR reload requested by server; re-loading video (attempt ' + reloadCount + '/' + MAX_RELOADS + ')');
      if (currentVideoId && loadFn) loadFn(currentVideoId, shakaContainer, currentLoadOptions || {});
    });
  }

  async function loadVideo(videoId, containerElement, options) {
    options = options || {};
    if (videoId !== currentVideoId) reloadCount = 0;
    currentVideoId = videoId;
    currentLoadOptions = options;
    playbackWebPoToken = null;
    playbackWebPoTokenContentBinding = videoId;

    try {
      // Start Shaka player init (DOM + polyfills) in parallel with network init.
      var shakaPromise;
      if (!player) {
        shakaPromise = initializeShakaPlayer(containerElement, options.listen);
      } else {
        player.configure('abr', DEFAULT_ABR_CONFIG);
        player.configure('manifest.disableVideo', !!options.listen);
        shakaPromise = Promise.resolve();
      }

      // Network init chain: Innertube → Onesie config → PoToken.
      var netPromise = (async function () {
        if (!innertube) {
          innertube = await initInnertube();
          if (!innertube) throw new Error('Failed to initialize Innertube');
        }
        if (!clientConfig) {
          await fetchOnesieConfig();
        }
        // Mint a content-bound PoToken before getInfo so streaming_data includes
        // the server_abr_streaming_url and so the SABR requests authenticate.
        try { await mintContentWebPO(); } catch (e) { console.warn('[SABRPlayer] poToken mint failed, continuing', e); }
      })();

      await Promise.all([shakaPromise, netPromise]);
      var poToken = playbackWebPoToken || coldStartToken || '';

      setupRequestFilters();

      var videoInfo = await innertube.getInfo(videoId, { po_token: poToken || undefined });
      if (!videoInfo || !videoInfo.playability_status || videoInfo.playability_status.status !== 'OK') {
        var reason = (videoInfo && videoInfo.playability_status && videoInfo.playability_status.reason) || 'Unknown error';
        throw new Error('Video unavailable: ' + reason);
      }
      isLive = !!(videoInfo.basic_info && videoInfo.basic_info.is_live);

      var streamingData = videoInfo.streaming_data;
      if (!streamingData) throw new Error('No streaming data available');

      // Derive clientInfo from the innertube session (matches FreeTube's local.js).
      var ctxClient = innertube.session && innertube.session.context && innertube.session.context.client;
      var clientName = ctxClient ? ctxClient.clientName : 'ANDROID';
      var clientInfo = {
        clientName: (typeof Constants !== 'undefined' && Constants.CLIENT_NAME_IDS && Constants.CLIENT_NAME_IDS[clientName]) || 3,
        clientVersion: ctxClient ? ctxClient.clientVersion : (Constants.CLIENTS && Constants.CLIENTS.ANDROID ? Constants.CLIENTS.ANDROID.VERSION : '19.09.37'),
        osName: ctxClient ? ctxClient.osName : 'Android',
        osVersion: ctxClient ? ctxClient.osVersion : '14'
      };

      var manifestUri;
      if (isLive) {
        // Live: don't route through the SABR parser yet; use HLS/DASH.
        manifestUri = streamingData.hls_manifest_url || streamingData.dash_manifest_url;
        if (streamingData.hls_manifest_url) {
          if (innertube.session && innertube.session.player && innertube.session.player.decipher) {
            try { streamingData.hls_manifest_url = await innertube.session.player.decipher(streamingData.hls_manifest_url); } catch (e) {}
          }
          manifestUri = streamingData.hls_manifest_url;
        }
      } else {
        if (streamingData.server_abr_streaming_url && innertube.session && innertube.session.player && innertube.session.player.decipher) {
          try {
            streamingData.server_abr_streaming_url = await innertube.session.player.decipher(streamingData.server_abr_streaming_url);
          } catch (e) {
            console.warn('[SABRPlayer] Failed to decipher server_abr_streaming_url', e);
          }
        }

        manifestUri = buildSabrManifest(videoInfo, poToken, clientInfo);
        if (!manifestUri) {
          // No SABR URL available - fall back to DASH.
          var dashManifest = await videoInfo.toDash({ manifest_options: { captions_format: 'vtt', include_thumbnails: false } });
          manifestUri = 'data:application/dash+xml;base64,' + btoa(dashManifest);
        }
      }

      if (!manifestUri) throw new Error('Could not find a valid manifest URI');

      // Register the sabr: scheme before loading (idempotent re-registration is fine).
      if (!isLive && window.setupSabrScheme && SABRPlayer._lastSabrData) {
        if (sabrStream) {
          try { sabrStream.cleanup(); } catch (e) {}
        }
        sabrStream = window.setupSabrScheme(SABRPlayer._lastSabrData, getPlayer, getManifest, getPlayerWidth, getPlayerHeight);
        wireSabrStream(loadVideo);
      }

      // Capture the parsed manifest once Shaka has loaded it, so the sabr:
      // scheme plugin can read variant/segment indices from it.
      player.addEventListener('loaded', function () {
        if (typeof player.getManifest === 'function') {
          sabrManifest = player.getManifest();
        }
      });

      var startTime = options.startTime;
      if (startTime === undefined && options.savePlayerPos !== false) {
        startTime = getPlaybackPosition(videoId);
      }

      var mimeType = (!isLive && manifestUri.indexOf('data:' + window.MANIFEST_TYPE_SABR) === 0)
        ? window.MANIFEST_TYPE_SABR
        : undefined;
      await player.load(manifestUri, isLive ? undefined : startTime, mimeType);

      videoElement.play().catch(function (err) {
        if (err.name === 'NotAllowedError') console.warn('[SABRPlayer]', 'Autoplay was prevented by the browser');
      });

      if (savePositionInterval) clearInterval(savePositionInterval);
      savePositionInterval = setInterval(function () {
        if (videoElement && currentVideoId && !videoElement.paused) {
          savePlaybackPosition(currentVideoId, videoElement.currentTime);
        }
      }, SAVE_POSITION_INTERVAL_MS);

      return { player: player, videoElement: videoElement, videoInfo: videoInfo };
    } catch (error) {
      console.error('[SABRPlayer]', 'Error loading video:', error);
      throw error;
    }
  }

  async function dispose() {
    if (savePositionInterval) { clearInterval(savePositionInterval); savePositionInterval = null; }
    if (videoElement && currentVideoId) savePlaybackPosition(currentVideoId, videoElement.currentTime);

    if (sabrStream) { try { sabrStream.cleanup(); } catch (e) {} sabrStream = null; }
    if (player) { await player.destroy(); player = null; }
    if (ui) { ui.destroy(); ui = null; }
    if (shakaContainer && shakaContainer.parentNode) shakaContainer.parentNode.removeChild(shakaContainer);

    videoElement = null;
    shakaContainer = null;
    currentVideoId = '';
    sabrManifest = null;
  }

  function getPlayerInstance() { return player; }
  function getVideoElement() { return videoElement; }

  return {
    loadVideo: loadVideo,
    dispose: dispose,
    getPlayer: getPlayerInstance,
    getVideoElement: getVideoElement,
    initInnertube: initInnertube,
    fetchOnesieConfig: fetchOnesieConfig
  };
})();

window.SABRPlayer = SABRPlayer;