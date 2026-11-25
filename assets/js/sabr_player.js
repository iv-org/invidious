/**
 * SABR Player - Main player initialization for SABR streaming
 *
 * Re-engineered (from the kira-based POC) to use FreeTube's SABR engine:
 * - Builds a data:application/sabr+json manifest from the youtube.js VideoInfo
 * - Registers FreeTube's sabr: networking scheme (sabr_scheme_plugin.js)
 * - Drives Shaka 5 via the application/sabr+json manifest parser
 *
 * PoToken is minted browser-side via bgutils-js BotGuard (BotGuard/WAA requests
 * are proxied through the Invidious /proxy route for CSP compliance).
 */

'use strict';

var SABRPlayer = (function () {
  var VOLUME_KEY = 'youtube_player_volume';
  // The volume preference (0-1) the remembered volume was saved under
  var VOLUME_PREFERENCE_KEY = 'sabr_player_volume_preference';
  // Same key and format as the classic player (assets/js/player.js), so both players
  // share the saved positions. Only used when the "save player position" preference is on.
  var PLAYBACK_POSITION_KEY = 'save_player_pos';
  var LEGACY_PLAYBACK_POSITION_KEY = 'youtube_playback_positions';
  var MAX_SAVED_POSITIONS = 500;
  var SAVE_POSITION_INTERVAL_MS = 5000;

  // Video codec preference (quality_sabr) -> shaka codec prefixes.
  var CODEC_PREFERENCES = {
    vp9: ['vp09', 'vp9'],
    av1: ['av01'],
    h264: ['avc1']
  };

  var DEFAULT_ABR_CONFIG = {
    enabled: true,
    // Adapt quality to the player element size (like FreeTube), NOT a hard 480p cap.
    // A maxHeight:480 cap made shaka request the 480p format, which then set
    // stickyResolution/lastManualSelectedResolution=480 in the SABR request, so the
    // server LOCKED playback to a blurry 480p even after the cap was lifted.
    restrictToElementSize: true,
    switchInterval: 4,
    useNetworkInformation: false
  };

  // TEMP: bypass the Onesie player-response fetch and use a plain WEB getInfo()
  // instead. The Onesie path yields a ustreamerConfig that does NOT opt us into
  // SABR contexts (server never sends SABR_CONTEXT_UPDATE / context 5), which
  // breaks seeking. A normal WEB getInfo() (like FreeTube's createInnertube)
  // returns the full ustreamerConfig. Onesie to be revisited separately.
  var BYPASS_ONESIE = false;

  // InnerTube client used for the /player request. WebPO tokens minted from a
  // non-youtube.com origin are never attested on the WEB client, and SABR then stops
  // serving media after ~60s. googlevideo's sabr-shaka-example requests the player
  // response with the VISIONOS client instead, which doesn't need an attested token.
  // Overridable for debugging with window.SABR_PLAYER_CLIENT = 'WEB' (Onesie path).
  var PLAYER_CLIENT = 'VISIONOS';
  function playerClient() { return window.SABR_PLAYER_CLIENT || PLAYER_CLIENT; }

  // State
  var player = null;
  var ui = null;
  var videoElement = null;
  var shakaContainer = null;
  var currentVideoId = '';
  // Video whose media is actually loaded in the element (null while a load is pending),
  // and its duration: playback positions are only ever saved against it.
  var loadedVideoId = null;
  var loadedDuration = 0;
  var savePositionsEnabled = false;
  var hasPlayed = false;         // playback started at least once for the current load
  var loadGeneration = 0;        // bumped by every loadVideo()/dispose(), to drop stale async work
  var isLive = false;
  // An active broadcast (not a post-live DVR replay, which also plays from HLS).
  var isActiveLive = false;
  var innertube = null;
  var clientConfig = null;
  var savePositionInterval = null;
  var playbackWebPoToken = null;
  var coldStartToken = null;
  var playbackWebPoTokenContentBinding = null;
  var playbackWebPoTokenCreationLock = false;

  var hlsAudioFormats = [];      // audio formats used to patch live HLS master playlists
  var liveManifest = null;       // { uri, mimeType } of the current live stream, for recovery
  var liveRecoveries = 0;
  // Shaka's TS->MP4 transmuxer intermittently fails on YouTube live HLS segments
  // (error 3018 TRANSMUXING_FAILED, CRITICAL), which leaves the video buffer empty.
  // Reloading the live manifest recovers, so retry a few times.
  var MAX_LIVE_RECOVERIES = 3;
  var sabrStream = null;         // handle returned by setupSabrScheme
  // Guards so per-player-instance listeners/filters are installed once, not once
  // per reload (loadVideo re-runs on every SABR reload).
  var requestFiltersInstalled = false;
  var loadedListenerInstalled = false;
  var keydownInstalled = false;
  var sabrManifest = null;       // captured from player.getManifest() on 'loaded'
  var currentLoadOptions = null; // for onReloadOnce -> re-run loadVideo
  var reloadCount = 0;           // cap reloads to prevent infinite loop on blocked/throttled videos
  // YouTube walls SABR playback at ~60s of content on some videos and only lets a
  // fresh player response (new server_abr_streaming_url) through. FreeTube recovers
  // by reloading the SABR player several times (observed: ~4 reloads before it sticks),
  // so cap high enough to actually recover instead of giving up early — matching
  // FreeTube's behaviour — while still bounding a truly blocked/throttled video.
  var MAX_RELOADS = 10;

  // User-facing strings. The page passes translated ones (setMessages); these are fallbacks.
  var messages = {
    loadFailed: 'Failed to load video with SABR player.',
    unavailable: 'This video is currently unavailable via SABR.',
    throttled: 'YouTube is throttling this request.',
    tryDash: 'Try DASH player instead',
    audioTrack: 'Audio track',
    backoff: 'Throttled by YouTube, retrying in {seconds} s…'
  };
  function setMessages(newMessages) {
    Object.keys(newMessages || {}).forEach(function (key) {
      if (newMessages[key]) messages[key] = newMessages[key];
    });
  }

  // The current page with only the quality switched to the classic DASH player.
  function dashFallbackUrl() {
    var url = new URL(window.location.href);
    url.searchParams.set('quality', 'dash');
    return url.pathname + url.search + url.hash;
  }

  // Error overlay: one paragraph per line (plain text), then a link to the DASH player.
  function createErrorDisplay(lines) {
    var errorDiv = document.createElement('div');
    errorDiv.className = 'sabr-error-display';
    lines.forEach(function (line) {
      if (!line) return;
      var p = document.createElement('p');
      p.textContent = line;
      errorDiv.appendChild(p);
    });
    // Only offer the DASH player when it can actually play the video (the server
    // redirects DASH requests back to SABR when it has no stream of its own).
    var container = document.getElementById('sabr-player-container');
    if (!container || container.dataset.dashAvailable !== 'false') {
      var linkP = document.createElement('p');
      var link = document.createElement('a');
      link.href = dashFallbackUrl();
      link.textContent = messages.tryDash;
      linkP.appendChild(link);
      errorDiv.appendChild(linkP);
    }
    return errorDiv;
  }

  // The remembered volume, unless the volume preference changed since it was saved
  // (or nothing is remembered yet): then the preference applies.
  function getSavedVolume(preference) {
    var hasPreference = typeof preference === 'number' && isFinite(preference);
    try {
      var v = parseFloat(localStorage.getItem(VOLUME_KEY));
      if (isFinite(v) && (!hasPreference || localStorage.getItem(VOLUME_PREFERENCE_KEY) === String(preference))) {
        return Math.min(Math.max(v, 0), 1);
      }
    } catch (e) {}
    return hasPreference ? preference : 1;
  }
  function saveVolume(volume, preference) {
    try {
      localStorage.setItem(VOLUME_KEY, volume.toString());
      if (typeof preference === 'number' && isFinite(preference)) localStorage.setItem(VOLUME_PREFERENCE_KEY, String(preference));
    } catch (e) {}
  }
  function getPlaybackPositions() {
    try {
      var p = localStorage.getItem(PLAYBACK_POSITION_KEY);
      var positions = p ? JSON.parse(decodeURIComponent(p)) : {};
      return positions && typeof positions === 'object' ? positions : {};
    } catch (e) { return {}; }
  }
  function clearPlaybackPositions() {
    try {
      localStorage.removeItem(PLAYBACK_POSITION_KEY);
      localStorage.removeItem(LEGACY_PLAYBACK_POSITION_KEY);
    } catch (e) {}
  }
  // Save the current position of the loaded video (no-op when the preference is off
  // or no load has completed). Like the classic player, the last 15 s aren't saved.
  function saveCurrentPosition() {
    if (!savePositionsEnabled || !loadedVideoId || !videoElement || isActiveLive) return;
    var time = Math.floor(videoElement.currentTime);
    if (!isFinite(time) || time < 1) return;
    if (loadedDuration > 0 && time > loadedDuration - 15) return;
    try {
      var positions = getPlaybackPositions();
      // Re-insert so the key order is least -> most recently saved, then keep the newest.
      delete positions[loadedVideoId];
      positions[loadedVideoId] = time;
      var ids = Object.keys(positions);
      for (var i = 0; i < ids.length - MAX_SAVED_POSITIONS; i++) delete positions[ids[i]];
      localStorage.setItem(PLAYBACK_POSITION_KEY, encodeURIComponent(JSON.stringify(positions)));
    } catch (e) {}
  }
  function getPlaybackPosition(videoId) {
    var time = Number(getPlaybackPositions()[videoId]);
    return isFinite(time) && time > 0 ? time : 0;
  }
  function stopPositionSaving() {
    if (savePositionInterval) { clearInterval(savePositionInterval); savePositionInterval = null; }
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
        // youtubei.js >= 18 appends its own `return { n, sig }` to the player script output.
        Platform.shim.eval = async function (data) {
          return new Function(data.output)();
        };
        console.info('[SABRPlayer]', 'Platform.shim.eval configured for URL deciphering');
      } else {
        console.warn('[SABRPlayer]', 'Platform.shim not available, URL deciphering may fail');
      }

      innertube = await Innertube.create({
        fetch: SABRHelpers.fetchWithProxy,
        retrieve_player: true,
        // A locally generated visitorData is rejected on the VISIONOS client
        // ("Sign in to confirm you're not a bot"); fetch a real session instead.
        generate_session_locally: false
      });

      // The WEB client (Onesie path) needs BotGuard and the redirector URL; warm both
      // up so they're ready by the time the player response arrives. The default
      // VISIONOS path uses neither, so it doesn't wait for them.
      if (playerClient() === 'WEB') {
        BotguardService.init().catch(function (e) { console.warn('[SABRPlayer]', 'BotGuard init failed', e); });
        if (typeof window.fetchSabrRedirectorUrl === 'function') {
          try {
            await window.fetchSabrRedirectorUrl();
          } catch (e) {
            console.warn('[SABRPlayer]', 'Failed to preload redirector URL', e);
          }
        }
      }

      return innertube;
    } catch (error) {
      console.error('[SABRPlayer]', 'Failed to initialize Innertube', error);
      return null;
    }
  }

  async function fetchOnesieConfig() {
    if (clientConfig && SABRHelpers.isConfigValid(clientConfig)) return clientConfig;
    // Do NOT read a persisted (localStorage) config: its baseUrl embeds the egress IP
    // that YouTube saw at fetch time, so a cached config goes stale when the proxy/egress
    // IP changes and the CDN rejects the mismatched IP. Always refetch fresh.
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
      // Not persisted to localStorage on purpose (baseUrl embeds a now-stale-on-proxy-change ip).
      return clientConfig;
    } catch (error) {
      console.error('[SABRPlayer]', 'Failed to fetch Onesie client config', error);
      return null;
    }
  }

  // Mint a content-bound (video id) WebPO token in the browser with bgutils-js,
  // like googlevideo's sabr-shaka-example. A cold-start token is kept as a fallback
  // until BotGuard has produced an integrity token.
  async function mintContentWebPO() {
    if (!playbackWebPoTokenContentBinding || playbackWebPoTokenCreationLock) return;
    playbackWebPoTokenCreationLock = true;
    try {
      coldStartToken = BotguardService.mintColdStartToken(playbackWebPoTokenContentBinding);
      // Non-WEB clients (VISIONOS) don't need an attested WebPO token; a cold start token is enough.
      if (playerClient() !== 'WEB') return;
      if (!BotguardService.isInitialized()) await BotguardService.reinit();
      if (BotguardService.isInitialized()) {
        playbackWebPoToken = await BotguardService.mintWebPoToken(decodeURIComponent(playbackWebPoTokenContentBinding));
        console.info('[SABRPlayer]', 'WebPO token created for', playbackWebPoTokenContentBinding);
      } else {
        console.warn('[SABRPlayer]', 'BotGuard not initialized, using cold start token');
      }
    } catch (err) {
      console.error('[SABRPlayer]', 'Error minting WebPO token', err);
    } finally {
      playbackWebPoTokenCreationLock = false;
    }
  }

  // Mint a brand new content-bound WebPO token for the current video. Used by the
  // sabr: scheme when the server answers with StreamProtectionStatus 3
  // (ATTESTATION_REQUIRED) and refuses to send any more media until we re-attest.
  async function mintFreshPoToken() {
    var videoId = currentVideoId;
    var generation = loadGeneration;
    if (!videoId) return null;
    try {
      await BotguardService.reinit();
      if (!BotguardService.isInitialized()) return null;
      var token = await BotguardService.mintWebPoToken(videoId);
      // Another load started meanwhile: the token belongs to a retired request, don't
      // let it replace the new load's token.
      if (generation !== loadGeneration) return null;
      if (token) {
        playbackWebPoToken = token;
        console.info('[SABRPlayer]', 'Re-minted WebPO token after attestation request');
      }
      return token;
    } catch (err) {
      console.warn('[SABRPlayer]', 'Failed to re-mint WebPO token', err);
      return null;
    }
  }

  async function initializeShakaPlayer(containerElement, listenMode, controls, volumePreference) {
    if (!shaka.Player.isBrowserSupported()) {
      throw new Error('Shaka Player is not supported in this browser');
    }
    shaka.polyfill.installAll();

    shakaContainer = document.createElement('div');
    // Start in the loading state so the spinner is visible during the initial SABR init.
    shakaContainer.className = 'sabr-player-container is-loading';
    shakaContainer.style.width = '100%';
    shakaContainer.style.height = '100%';

    videoElement = document.createElement('video');
    // Playback is started explicitly after load, and only when autoplay is on.
    videoElement.autoplay = false;
    videoElement.style.width = '100%';
    videoElement.style.height = '100%';
    videoElement.style.backgroundColor = '#000';

    shakaContainer.appendChild(videoElement);

    // Loading spinner shown during our custom SABR init (Innertube/Onesie/PO token/load)
    // and whenever the video is buffering. Shaka's own spinner only covers its own
    // buffering phase (after player.load), not the pre-load init, so we drive our own.
    var spinnerEl = document.createElement('div');
    spinnerEl.className = 'sabr-loading-spinner';
    shakaContainer.appendChild(spinnerEl);

    containerElement.appendChild(shakaContainer);

    player = new shaka.Player();
    player.configure({
      abr: DEFAULT_ABR_CONFIG,
      streaming: {
        // Match FreeTube's SABR streaming config exactly (values YouTube itself uses):
        // large buffering goal, tiny rebuffering goal, big bufferBehind, and a doubled
        // (60s) retry timeout to tolerate the larger SABR UMP responses.
        bufferingGoal: 180,
        rebufferingGoal: 0.02,
        bufferBehind: 300,
        retryParameters: { timeout: 60 * 1000 }
      },
      manifest: {
        // disableVideo is read by our SabrManifestParser to skip video streams for audio-only/listen mode.
        disableVideo: !!listenMode
      }
    });

    videoElement.volume = getSavedVolume(volumePreference);
    videoElement.addEventListener('volumechange', function () { saveVolume(videoElement.volume, volumePreference); });
    videoElement.addEventListener('playing', function () {
      hasPlayed = true;
      player.configure('abr.restrictions.maxHeight', Infinity);
      hideSpinner();
    });
    videoElement.addEventListener('waiting', function () { showSpinner(); });
    videoElement.addEventListener('canplay', function () { hideSpinner(); });
    videoElement.addEventListener('pause', saveCurrentPosition);
    videoElement.addEventListener('timeupdate', enforceEndTime);

    // Page-level keyboard shortcuts (installed once per SABRPlayer instance).
    // controls=0: no playback shortcuts and no control overlay, like the classic player.
    if (controls && !keydownInstalled) {
      document.addEventListener('keydown', handleKeydown);
      keydownInstalled = true;
    }

    await player.attach(videoElement);

    player.addEventListener('error', function (event) {
      var err = event.detail;
      console.error('[SABRPlayer]', 'Shaka error', err && err.code, err);
      if (!err || err.severity !== shaka.util.Error.Severity.CRITICAL) return;
      recoverLive(loadGeneration);
    });

    if (controls && shaka.ui && shaka.ui.Overlay) {
      registerAudioTrackMenu();
      ui = new shaka.ui.Overlay(player, shakaContainer, videoElement);
      ui.configure({
        overflowMenuButtons: overflowMenuButtons(false),
        // Playback shortcuts are owned by handleKeydown (page-wide). Shaka's own would
        // also fire while a control is focused and toggle e.g. mute twice. Shaka still
        // handles its menu/focus navigation (Tab, Escape).
        enableKeyboardPlaybackControls: false,
        // Right-click menu like youtube.com's, with its "Stats for nerds" equivalent:
        // Shaka's statistics panel, limited to what is meaningful for YouTube streams.
        customContextMenu: true,
        // Shaka's default items (loop, picture in picture, copy/save the video frame)
        // plus the statistics panel.
        contextMenuElements: ['statistics', 'loop', 'picture_in_picture', 'copy_video_frame', 'save_video_frame'],
        statisticsList: [
          'width', 'height', 'currentCodecs', 'streamBandwidth', 'estimatedBandwidth',
          'droppedFrames', 'decodedFrames', 'corruptedFrames', 'bufferingTime',
          'liveLatency', 'loadLatency', 'timeToFirstFrame', 'playTime', 'pauseTime',
          'bytesDownloaded', 'stallsDetected', 'gapsJumped'
        ]
      });
    }

    return player;
  }

  // Reload the live manifest after a critical error (or a failed recovery load), up to
  // MAX_LIVE_RECOVERIES times. `generation` ties the attempt to the load it recovers:
  // it stops once another video load or dispose() replaced it.
  // `resume` is decided once, on the first attempt: a failed reload leaves the video
  // paused (Shaka clears its source), so retries must not read that state again.
  function recoverLive(generation, resume, position) {
    if (generation !== loadGeneration || !player) return;
    if (!isLive || !liveManifest || liveRecoveries >= MAX_LIVE_RECOVERIES) return;
    liveRecoveries++;
    console.warn('[SABRPlayer]', 'Reloading live stream after a critical error (attempt ' + liveRecoveries + '/' + MAX_LIVE_RECOVERIES + ')');
    // Resume playback after the reload unless the user had paused: the autoplay
    // choice only matters while playback hasn't started yet.
    if (resume === undefined) {
      resume = !!videoElement && (!videoElement.paused || (!hasPlayed && !!(currentLoadOptions && currentLoadOptions.autoplay)));
      // A post-live DVR replay has a fixed timeline: resume where the viewer was. An
      // active broadcast resumes at the live edge (no start position).
      if (!isActiveLive && videoElement && isFinite(videoElement.currentTime) && videoElement.currentTime > 0) {
        position = videoElement.currentTime;
      }
    }
    player.load(liveManifest.uri, position, liveManifest.mimeType).then(function () {
      if (resume && generation === loadGeneration && videoElement) videoElement.play().catch(function () {});
    }, function (e) {
      // LOAD_INTERRUPTED: another load (or unload) replaced this one; nothing to retry.
      if (e && e.code === shaka.util.Error.Code.LOAD_INTERRUPTED) return;
      console.error('[SABRPlayer]', 'Live stream reload failed', e);
      recoverLive(generation, resume, position);
    });
  }

  // --- Live HLS master playlist patching (port of FreeTube's patchLiveHlsMainManifest, #9996) ---
  // YouTube's live HLS master playlist doesn't declare the audio streams as EXT-X-MEDIA
  // renditions, so shaka doesn't treat them as one audio track at different qualities
  // (symptom: audio buffers but the video buffer stays empty and playback never starts).
  var MIME_TYPE_CODECS_REGEX = /codecs="?([^"]+)"?/;
  var HLS_AUDIO_PARAMS_ITAG_REGEX = /\/sgoap\/[^/]*?itag%3D(\d+)/;
  // eslint-disable-next-line no-control-regex
  var HLS_QUOTED_STRING_REGEX = /[\0-\u001F"\u007F-\u009F]/g;
  var ITAG_139_SAMPLE_RATE = '22050';

  function cleanHlsString(text) {
    return text.trim().replace(HLS_QUOTED_STRING_REGEX, '');
  }

  function getAudioTrackName(format) {
    if (format.audio_track && format.audio_track.display_name) return format.audio_track.display_name;
    if (format.language) {
      try {
        var name = new Intl.DisplayNames('en-US', { type: 'language', languageDisplay: 'standard', fallback: 'none' }).of(format.language);
        if (name !== undefined) return name;
      } catch (e) {}
    }
    return 'Untitled';
  }

  function patchLiveHlsMainManifest(data, audioFormats) {
    // HLS allows CRLF line endings; drop the CR so attributes appended below stay on the tag line.
    var lines = new TextDecoder().decode(data).trim().split(/\r?\n/);
    var linesToInsert = [];
    var firstStreamIndex = -1;

    for (var i = 0; i < lines.length; i++) {
      if (lines[i].indexOf('#EXT-X-STREAM-INF:') !== 0) continue;
      if (firstStreamIndex === -1) firstStreamIndex = i;

      var itagMatch = (lines[i + 1] || '').match(HLS_AUDIO_PARAMS_ITAG_REGEX);
      if (itagMatch !== null) {
        var itag = parseInt(itagMatch[1], 10);
        var format = audioFormats.find(function (f) { return f.itag === itag; });
        // itag 139 is in the HLS manifest but usually not in the API response; it matches
        // itag 140 except for half the sample rate.
        if (!format && itag === 139) format = audioFormats.find(function (f) { return f.itag === 140; });

        // Leave a rendition whose audio metadata is incomplete as it is.
        if (format && (!isFinite(format.audio_channels) || (itag !== 139 && !isFinite(format.audio_sample_rate)) ||
            !MIME_TYPE_CODECS_REGEX.test(format.mime_type || ''))) {
          format = null;
        }
        if (format) {
          var sampleRate = itag === 139 && format.itag !== 139 ? ITAG_139_SAMPLE_RATE : format.audio_sample_rate.toFixed(0);
          var codec = format.mime_type.match(MIME_TYPE_CODECS_REGEX)[1];
          var groupId = codec.split('.', 1)[0] + '-' + format.audio_channels + '-' + (sampleRate || 0);
          var mediaLine = '#EXT-X-MEDIA:TYPE=AUDIO,' +
            'GROUP-ID="' + groupId + '",' +
            'NAME="' + cleanHlsString(getAudioTrackName(format)) + '",' +
            'LANGUAGE="' + (format.language ? cleanHlsString(format.language) : 'und') + '",' +
            'DEFAULT=' + (format.is_original ? 'YES' : 'NO') + ',' +
            'AUTOSELECT=' + (format.is_auto_dubbed ? 'NO' : 'YES') + ',' +
            'CHANNELS=' + format.audio_channels.toFixed(0) + ',' +
            'SAMPLE-RATE=' + sampleRate;

          lines[i] = lines[i] + ',AUDIO=' + groupId;
          if (linesToInsert.indexOf(mediaLine) === -1) linesToInsert.push(mediaLine);
        }
      }
      // the next line is the URL line
      i++;
    }

    if (linesToInsert.length === 0) return data;
    Array.prototype.splice.apply(lines, [firstStreamIndex, 0].concat(linesToInsert));
    // EXT-X-MEDIA with CHANNELS needs version 7; keep a single EXT-X-VERSION tag.
    var versionIndex = lines.findIndex(function (line) { return line.indexOf('#EXT-X-VERSION:') === 0; });
    if (versionIndex === -1) {
      lines.splice(1, 0, '#EXT-X-VERSION:7');
    } else if (!(parseInt(lines[versionIndex].slice('#EXT-X-VERSION:'.length), 10) >= 7)) {
      lines[versionIndex] = '#EXT-X-VERSION:7';
    }
    return new TextEncoder().encode(lines.join('\n') + '\n');
  }

  // YouTube's live streams carry no audio language metadata (only the same audio at two
  // bitrates), so the language menu would just list "Undetermined" twice. Hide it for lives.
  function overflowMenuButtons(live) {
    var buttons = ['captions', 'quality', 'sabr_audio_tracks', 'playback_rate', 'loop', 'picture_in_picture'];
    return live ? buttons.filter(function (b) { return b !== 'sabr_audio_tracks'; }) : buttons;
  }

  // Video quality preference (quality_sabr_resolution), with the same rules as the
  // classic DASH player: "auto" keeps ABR; "best"/"worst" pin the highest/lowest
  // quality; a height pins the highest quality at or below it (the lowest one when
  // none is). The audio track in use is kept. Choosing "Auto" in the player's
  // quality menu turns ABR back on.
  function applyQualityPreference(quality) {
    if (!player || !quality || quality === 'auto') return;
    var all = player.getVariantTracks();
    var active = all.find(function (t) { return t.active; });
    if (!active) return;
    var tracks = all.filter(function (t) {
      return t.height && t.originalAudioId === active.originalAudioId;
    }).sort(function (a, b) { return (a.height - b.height) || (a.bandwidth - b.bandwidth); });
    if (tracks.length === 0) return;

    var target;
    if (quality === 'best') {
      target = tracks[tracks.length - 1];
    } else if (quality === 'worst') {
      target = tracks[0];
    } else {
      var maxHeight = parseInt(quality, 10);
      if (!isFinite(maxHeight)) return;
      var fitting = tracks.filter(function (t) { return t.height <= maxHeight; });
      target = fitting.length ? fitting[fitting.length - 1] : tracks[0];
    }

    player.configure('abr.enabled', false);
    player.selectVariantTrack(target, /* clearBuffer= */ true);
  }

  // Preferred captions (the captions preference, or `subtitles` in the link): like the
  // classic player, show the first track whose name or language matches, in order.
  function applyCaptionPreference(preferred) {
    if (!player || !preferred || preferred.length === 0) return;
    var tracks = player.getTextTracks();
    for (var i = 0; i < preferred.length; i++) {
      var wanted = preferred[i].toLowerCase();
      var track = tracks.find(function (t) {
        return (t.label || '').toLowerCase() === wanted ||
          (t.language || '').toLowerCase().split('-')[0] === wanted;
      });
      if (track) {
        // Shaka 5 shows a selected text track (there is no separate visibility toggle)
        player.selectTextTrack(track);
        return;
      }
    }
  }

  // Audio track menu (port of FreeTube's AudioTrackSelection). Shaka's own language
  // menu lists one entry per language + codec, and ignores labels: a video with
  // original and "Stable Volume" (DRC) audio showed "French AAC" twice and "French
  // Opus" twice. Here tracks are deduplicated by label, language, channel count and
  // spatial audio (the codec is left to ABR), and shown by their label.
  function deduplicateAudioTracks(tracks) {
    var known = new Map();
    tracks.forEach(function (track) {
      var id = track.label + '_' + track.language + '_' + track.channelsCount + '_' + track.spatialAudio;
      if (!known.has(id) || track.active) known.set(id, track);
    });
    return Array.from(known.values());
  }

  function audioTrackName(track) {
    if (track.label) return track.label;
    try {
      return new Intl.DisplayNames([document.documentElement.lang || 'en', 'en'], { type: 'language' }).of(track.language);
    } catch (e) {
      return track.language;
    }
  }

  var audioTrackMenuRegistered = false;
  function registerAudioTrackMenu() {
    if (audioTrackMenuRegistered || !shaka.ui || !shaka.ui.SettingsMenu || !shaka.ui.OverflowMenu) return;
    audioTrackMenuRegistered = true;
    var icons = shaka.ui.Enums.MaterialDesignSVGIcons;

    class AudioTrackSelection extends shaka.ui.SettingsMenu {
      constructor(parent, controls) {
        super(parent, controls, icons.LANGUAGE);
        this.button.classList.add('shaka-language-button', 'shaka-tooltip-status');
        this.menu.classList.add('shaka-audio-languages');

        var checkmark = new shaka.ui.Icon(null, icons.CHECKMARK).getSvgElement();
        checkmark.classList.add('shaka-chosen-item');
        checkmark.setAttribute('aria-hidden', 'true');
        this.checkmark_ = checkmark;

        this.backButton.ariaLabel = this.localization.resolve('BACK');
        this.button.ariaLabel = messages.audioTrack;
        this.nameSpan.textContent = messages.audioTrack;
        this.backSpan.textContent = messages.audioTrack;

        var update = this.updateAudioTracks_.bind(this);
        ['loading', 'trackschanged', 'variantchanged', 'adaptation'].forEach(function (name) {
          this.eventManager.listen(this.player, name, update);
        }, this);
        this.updateAudioTracks_();
      }

      checkAvailability() {
        this.updateAudioTracks_();
      }

      updateAudioTracks_() {
        var menu = this.menu;
        var tracks = deduplicateAudioTracks(this.player.getAudioTracks());
        // Quality changes (adaptation) fire often: only rebuild when the audio choices
        // changed, so a keyboard user browsing the menu doesn't lose focus.
        var signature = tracks.map(function (t) { return audioTrackName(t) + (t.active ? '*' : ''); }).join('|');
        if (signature === this.signature_ && menu.childElementCount > 0) {
          this.button.classList.toggle('shaka-hidden', tracks.length < 2 || this.isSubMenuOpened);
          return;
        }
        this.signature_ = signature;
        var hadFocus = menu.contains(document.activeElement);

        var backButton = menu.querySelector('.shaka-back-to-overflow-button');
        while (menu.firstChild) menu.removeChild(menu.firstChild);
        if (backButton) menu.appendChild(backButton);

        tracks.forEach(function (track) {
          var button = document.createElement('button');
          button.setAttribute('role', 'menuitemradio');
          button.addEventListener('click', this.onAudioTrackSelected_.bind(this, track));
          var span = document.createElement('span');
          span.textContent = audioTrackName(track);
          button.appendChild(span);
          if (track.active) {
            button.appendChild(this.checkmark_);
            span.classList.add('shaka-chosen-item');
            button.setAttribute('aria-checked', 'true');
            this.currentSelection.textContent = span.textContent;
          } else {
            button.setAttribute('aria-checked', 'false');
          }
          menu.appendChild(button);
        }, this);

        // Like Shaka's own menus, move the focus back to the chosen item after a rebuild
        if (hadFocus) {
          var chosen = menu.querySelector('[aria-checked="true"]') || backButton;
          if (chosen) chosen.focus();
        }

        this.button.setAttribute('shaka-status', this.currentSelection.textContent);
        // Only worth a menu when there is an actual choice
        this.button.classList.toggle('shaka-hidden', tracks.length < 2 || this.isSubMenuOpened);
      }

      onAudioTrackSelected_(track) {
        // Let ABR pick the codec for this track
        this.player.selectAudioTrack(Object.assign({}, track, { codecs: null }));
        var config = { preferSpatialAudio: !!track.spatialAudio };
        if (track.language && track.language !== 'und') config.preferredAudioLanguage = track.language;
        if (track.label) config.preferredAudioLabel = track.label;
        if (track.channelsCount) config.preferredAudioChannelCount = track.channelsCount;
        this.player.configure(config);
      }
    }

    shaka.ui.OverflowMenu.registerElement('sabr_audio_tracks', {
      create: function (rootElement, controls) { return new AudioTrackSelection(rootElement, controls); }
    });
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

      if (!SABRHelpers.isGoogleVideoURL(url)) return;

      // Reuse the shared proxy helper so __host/__headers are set consistently.
      var proxied = SABRHelpers.proxyUrl(url, request.headers || {});
      proxied.searchParams.set('alr', 'yes');
      request.uris[0] = proxied.toString();
    });

    networkingEngine.registerResponseFilter(function (type, response, context) {
      if (
        hlsAudioFormats.length > 0 &&
        type === shaka.net.NetworkingEngine.RequestType.MANIFEST &&
        context && context.type === shaka.net.NetworkingEngine.AdvancedRequestType.MASTER_PLAYLIST
      ) {
        response.data = patchLiveHlsMainManifest(response.data, hlsAudioFormats);
      }
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

  // Rewrite a storyboard template URL to a same-origin URL so the seek-bar thumbnail tiles
  // load under CSP img-src 'self'. Reuses Invidious's EXISTING storyboard proxy route (the
  // one the classic video.js player uses), matching src/invidious/videos/storyboard.cr:
  //   https://<authority>.ytimg.com/sb/<rest>  ->  /sb/<authority>/<rest>
  // A raw string swap (not URL parsing) preserves the '$M' tile placeholder and the literal
  // '$' inside the signature (sigh=rs$AOn...).
  function proxyStoryboardUrl(templateUrl) {
    var m = templateUrl.match(/^https?:\/\/(i\d?)\.ytimg\.com\/sb\/(.*)$/);
    if (m) {
      return '/sb/' + m[1] + '/' + m[2];
    }
    // Fallback for non-ytimg hosts: generic SABR /proxy (same-origin for CSP).
    try {
      var u = new URL(templateUrl);
      return '/proxy' + u.pathname +
        (u.search ? u.search + '&' : '?') +
        '__host=' + encodeURIComponent(u.host) + '&__headers=%5B%5D';
    } catch (e) {
      return templateUrl;
    }
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
      templateUrl: proxyStoryboardUrl(board.template_url),
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

  // Loading spinner: toggled via an 'is-loading' class on the player container.
  function showSpinner() { if (shakaContainer) shakaContainer.classList.add('is-loading'); }
  function hideSpinner() { if (shakaContainer) shakaContainer.classList.remove('is-loading'); }

  // Global keyboard shortcuts (YouTube-style). Shaka's built-in shortcuts only fire when a
  // control is focused, so we add a page-level handler. Ignored while typing in a field.
  function handleKeydown(e) {
    if (!player || !videoElement) return;
    if (e.ctrlKey || e.altKey || e.metaKey) return;
    var t = e.target;
    var tag = (t && t.tagName) || '';
    if (/^(INPUT|TEXTAREA|SELECT)$/.test(tag) || (t && t.isContentEditable)) return;
    // Let a focused button (e.g. a Shaka control or menu item) handle its own activation.
    if (tag === 'BUTTON' && (e.key === ' ' || e.key === 'Enter')) return;
    var dur = isFinite(videoElement.duration) ? videoElement.duration : Infinity;
    var handled = true;
    switch (e.key) {
      case ' ':
      case 'k':
        if (videoElement.paused) videoElement.play().catch(function () {}); else videoElement.pause();
        break;
      case 'ArrowLeft':
        videoElement.currentTime = Math.max(0, videoElement.currentTime - 5);
        break;
      case 'ArrowRight':
        videoElement.currentTime = Math.min(dur, videoElement.currentTime + 5);
        break;
      case 'j':
        videoElement.currentTime = Math.max(0, videoElement.currentTime - 10);
        break;
      case 'l':
        videoElement.currentTime = Math.min(dur, videoElement.currentTime + 10);
        break;
      case 'ArrowUp':
        videoElement.volume = Math.min(1, videoElement.volume + 0.05);
        break;
      case 'ArrowDown':
        videoElement.volume = Math.max(0, videoElement.volume - 0.05);
        break;
      case 'm':
        videoElement.muted = !videoElement.muted;
        break;
      case 'f':
        if (document.fullscreenElement) { document.exitFullscreen(); }
        else if (shakaContainer && shakaContainer.requestFullscreen) { shakaContainer.requestFullscreen(); }
        break;
      default:
        // number keys 0-9 -> seek to that fraction of the video
        if (e.key >= '0' && e.key <= '9' && isFinite(dur)) {
          videoElement.currentTime = dur * (parseInt(e.key, 10) / 10);
        } else {
          handled = false;
        }
    }
    if (handled) e.preventDefault();
  }

  function wireSabrStream(loadFn) {
    if (!sabrStream) return;
    // A reload request from a stream that a newer load replaced must not reload the
    // new video.
    var wiredGeneration = loadGeneration;
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
        toast.textContent = messages.backoff.replace('{seconds}', (ms / 1000).toFixed(1));
        clearTimeout(toast._t);
        toast._t = setTimeout(function () { if (toast.parentNode) toast.parentNode.removeChild(toast); }, Math.max(ms + 500, 2000));
      }
    });
    sabrStream.onReloadOnce(function () {
      if (wiredGeneration !== loadGeneration) return;
      reloadCount++;
      if (reloadCount >= MAX_RELOADS) {
        console.error('[SABRPlayer] SABR reload limit reached; giving up on video', currentVideoId);
        if (shakaContainer) {
          shakaContainer.appendChild(createErrorDisplay([messages.unavailable, messages.throttled]));
        }
        return;
      }
      console.warn('[SABRPlayer] SABR reload requested by server; re-loading video (attempt ' + reloadCount + '/' + MAX_RELOADS + ')');
      // Match FreeTube's reloadView(): re-fetch with a FRESH innertube session
      // (new visitorData) and a re-attested BotGuard, instead of reusing the same
      // session identity. The 60s SABR wall is tied to the session/streaming
      // context, so a fresh session is what actually lets the reload recover.
      var resumeAt = (videoElement && isFinite(videoElement.currentTime)) ? videoElement.currentTime : undefined;
      var wasPaused = !!(videoElement && videoElement.paused);
      innertube = null;
      clientConfig = null;
      playbackWebPoToken = null;
      coldStartToken = null;
      try { BotguardService.dispose(); } catch (e) {}
      var reloadOptions = Object.assign({}, currentLoadOptions || {});
      // The excerpt's own start (start=...) stays the loop start
      if (reloadOptions.loopStart === undefined) reloadOptions.loopStart = reloadOptions.startTime;
      if (resumeAt !== undefined && resumeAt > 1) reloadOptions.startTime = resumeAt;
      // A server-requested reload resumes at the same position, in the same play/pause
      // state, loop and speed (the user may have changed them since the page loaded).
      // Before playback has started, the video is paused because nothing called play()
      // yet: keep the requested autoplay instead of treating it as a user pause.
      if (hasPlayed) {
        reloadOptions.startPaused = wasPaused;
        reloadOptions.autoplay = !wasPaused;
      }
      if (videoElement) {
        reloadOptions.loop = videoElement.loop;
        reloadOptions.speed = videoElement.playbackRate;
      }
      if (currentVideoId && loadFn) {
        loadFn(currentVideoId, shakaContainer, reloadOptions).catch(function (e) {
          console.error('[SABRPlayer]', 'SABR reload failed', e);
          if (shakaContainer) shakaContainer.appendChild(createErrorDisplay([messages.loadFailed, e && e.message]));
        });
      }
    });
  }

  // streamerContext.clientInfo for the SABR requests, built from the innertube session
  // context (WEB), like FreeTube's local.js and googlevideo's sabr-shaka-example, which
  // also send WEB info with a VISIONOS player response. Do NOT switch this to the
  // VISIONOS client info: tested with ws46W52Xo4A, the server then answers the very
  // first SABR requests with RELOAD_PLAYER_RESPONSE on every reload and playback
  // never starts, while WEB info plays past 60 s and seeks fine.
  function buildClientInfo() {
    var ctxClient = innertube.session && innertube.session.context && innertube.session.context.client;
    var clientName = ctxClient ? ctxClient.clientName : 'WEB';
    return {
      clientName: parseInt(Constants.CLIENT_NAME_IDS[clientName], 10) || 1,
      clientVersion: ctxClient ? ctxClient.clientVersion : Constants.CLIENTS.WEB.VERSION,
      osName: ctxClient ? ctxClient.osName : undefined,
      osVersion: ctxClient ? ctxClient.osVersion : undefined
    };
  }

  // Apply the page's playback settings (speed, loop) to the media element.
  // The `end` parameter: at the end time, pause, or go back to the start of the
  // excerpt when looping (like the classic player's end marker).
  var endTimeReached = false;
  function enforceEndTime() {
    var endTime = currentLoadOptions && currentLoadOptions.endTime;
    if (!endTime || !videoElement || loadedVideoId === null) return;
    if (videoElement.currentTime < endTime) { endTimeReached = false; return; }
    if (endTimeReached) return;
    endTimeReached = true;
    if (videoElement.loop) {
      var loopStart = currentLoadOptions.loopStart !== undefined ? currentLoadOptions.loopStart : currentLoadOptions.startTime;
      videoElement.currentTime = loopStart || 0;
    } else {
      videoElement.pause();
    }
  }

  function applyPlaybackSettings(options) {
    if (typeof options.volume === 'number' && isFinite(options.volume)) videoElement.volume = options.volume;
    var speed = Number(options.speed);
    // Shaka drives the media element's rate (0 while buffering), so go through it.
    if (isFinite(speed) && speed > 0 && speed !== player.getPlaybackRate()) {
      player.trickPlay(speed);
    }
    videoElement.loop = !!options.loop;
  }

  /**
   * Load a video.
   * @param {string} videoId
   * @param {HTMLElement} containerElement
   * @param {Object} [options]
   * @param {boolean} [options.autoplay] - start playback once loaded
   * @param {boolean} [options.loop]
   * @param {boolean} [options.listen] - audio only
   * @param {number} [options.speed] - playback rate
   * @param {number} [options.startTime] - explicit start position (seconds)
   * @param {boolean} [options.savePlayerPos] - save/restore the playback position
   * @param {string} [options.codecPreference] - 'vp9' | 'av1' | 'h264'
   * @param {string} [options.qualityPreference] - 'auto' | 'best' | 'worst' | '1080p', ...
   */
  async function loadVideo(videoId, containerElement, options) {
    options = options || {};
    var generation = ++loadGeneration;
    hasPlayed = false;
    // Positions are only saved against media that finished loading: record the
    // current one, then stop saving until this load completes.
    saveCurrentPosition();
    stopPositionSaving();
    loadedVideoId = null;
    savePositionsEnabled = options.savePlayerPos === true;
    if (!savePositionsEnabled) clearPlaybackPositions();

    if (videoId !== currentVideoId) { reloadCount = 0; liveRecoveries = 0; }
    currentVideoId = videoId;
    currentLoadOptions = options;
    playbackWebPoToken = null;
    playbackWebPoTokenContentBinding = videoId;
    showSpinner(); // re-show on reloads (container already exists)

    try {
      // Start Shaka player init (DOM + polyfills) in parallel with network init.
      var shakaPromise;
      if (!player) {
        requestFiltersInstalled = false;
        loadedListenerInstalled = false;
        shakaPromise = initializeShakaPlayer(containerElement, options.listen, options.controls !== false, options.volumePreference);
      } else {
        player.configure('abr', DEFAULT_ABR_CONFIG);
        player.configure('manifest.disableVideo', !!options.listen);
        shakaPromise = Promise.resolve();
      }

      // Network init chain: Innertube -> (WEB only) Onesie config -> PoToken.
      var netPromise = (async function () {
        if (!innertube) {
          innertube = await initInnertube();
          if (!innertube) throw new Error('Failed to initialize Innertube');
        }
        // The Onesie client config is only used by the WEB/Onesie path.
        if (playerClient() === 'WEB' && !clientConfig) {
          await fetchOnesieConfig();
        }
        // Mint a content-bound PoToken before getInfo so streaming_data includes
        // the server_abr_streaming_url and so the SABR requests authenticate.
        try { await mintContentWebPO(); } catch (e) { console.warn('[SABRPlayer] poToken mint failed, continuing', e); }
      })();

      await Promise.all([shakaPromise, netPromise]);
      var poToken = playbackWebPoToken || coldStartToken || '';
      if (!requestFiltersInstalled) {
        setupRequestFilters();
        requestFiltersInstalled = true;
      }

      // Default: plain /player request with the VISIONOS client. Debug path
      // (window.SABR_PLAYER_CLIENT = 'WEB'): fetch it through Onesie so the SABR
      // streaming URL isn't bound to the proxy's egress IP, falling back to getInfo().
      // Media flows over SABR (sabr_scheme_plugin.js) either way.
      var videoInfo;
      var cpn = SABRHelpers.generateRandomString(16);
      if (playerClient() !== 'WEB') {
        var directResponse = await innertube.actions.execute('/player', {
          videoId: videoId,
          contentCheckOk: true,
          racyCheckOk: true,
          client: playerClient(),
          playbackContext: {
            contentPlaybackContext: {
              signatureTimestamp: innertube.session.player && innertube.session.player.signature_timestamp
            }
          }
        });
        videoInfo = new window.YT.VideoInfo([directResponse], innertube.actions, cpn);
        console.info('[SABRPlayer]', 'Player response fetched with the ' + playerClient() + ' client');
      } else try {
        if (BYPASS_ONESIE) {
          throw new Error('Onesie bypassed (BYPASS_ONESIE) - using plain WEB getInfo');
        }
        if (typeof window.fetchOnesiePlayerResponse !== 'function' || !window.YT || !window.YT.VideoInfo) {
          throw new Error('Onesie support not loaded');
        }
        var playerResponse = await window.fetchOnesiePlayerResponse(innertube, videoId, poToken || undefined, clientConfig);
        videoInfo = new window.YT.VideoInfo(
          [{ success: true, status_code: 200, data: playerResponse }],
          innertube.actions,
          cpn
        );
        console.info('[SABRPlayer]', 'Player response fetched via Onesie (WEB)');
      } catch (onesieErr) {
        console.warn('[SABRPlayer]', 'Onesie player request failed, falling back to getInfo:', onesieErr);
        videoInfo = await innertube.getInfo(videoId, { po_token: poToken || undefined });
      }
      if (!videoInfo || !videoInfo.playability_status || videoInfo.playability_status.status !== 'OK') {
        var reason = (videoInfo && videoInfo.playability_status && videoInfo.playability_status.reason) || 'Unknown error';
        throw new Error('Video unavailable: ' + reason);
      }
      // A newer load took over while this one waited for the player response: it
      // must not touch the shared state (the catch below reports it as superseded).
      if (generation !== loadGeneration) throw new Error('Load superseded');
      var basicInfo = videoInfo.basic_info || {};
      // Live and post-live DVR streams use YouTube's HLS/DASH manifest instead of SABR
      // (like FreeTube). Only an active broadcast starts at the live edge; a post-live
      // DVR replay keeps the requested start position.
      isLive = !!(basicInfo.is_live || basicInfo.is_post_live_dvr);
      var startAtLiveEdge = !!basicInfo.is_live;
      isActiveLive = startAtLiveEdge;

      var streamingData = videoInfo.streaming_data;
      if (!streamingData) throw new Error('No streaming data available');

      var clientInfo = buildClientInfo();

      var manifestUri;
      var manifestMimeType;
      hlsAudioFormats = [];
      if (isLive) {
        // Live: don't route through the SABR parser yet; use HLS/DASH.
        manifestUri = streamingData.hls_manifest_url || streamingData.dash_manifest_url;
        manifestMimeType = streamingData.hls_manifest_url ? 'application/x-mpegurl' : 'application/dash+xml';
        if (streamingData.hls_manifest_url) {
          hlsAudioFormats = (streamingData.adaptive_formats || []).filter(function (f) {
            return f.mime_type && f.mime_type.indexOf('audio/mp4') === 0;
          });
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
      // Check ownership again after the async steps above, before publishing the scheme,
      // the manifest and the player configuration.
      if (generation !== loadGeneration) throw new Error('Load superseded');

      // Register the sabr: scheme before loading (idempotent re-registration is fine).
      if (!isLive && window.setupSabrScheme && SABRPlayer._lastSabrData) {
        if (sabrStream) {
          try { sabrStream.cleanup(); } catch (e) {}
        }
        sabrStream = window.setupSabrScheme(
          SABRPlayer._lastSabrData, getPlayer, getManifest, getPlayerWidth, getPlayerHeight, mintFreshPoToken
        );
        wireSabrStream(loadVideo);
      }

      // Capture the parsed manifest once Shaka has loaded it, so the sabr:
      // scheme plugin can read variant/segment indices from it. Install once per
      // player instance (loadVideo re-runs on every reload).
      if (!loadedListenerInstalled) {
        player.addEventListener('loaded', function () {
          if (typeof player.getManifest === 'function') {
            sabrManifest = player.getManifest();
          }
        });
        loadedListenerInstalled = true;
      }

      // Default to the ORIGINAL audio track: its language (not a dub) and the 'main'
      // role (not the DRC "Stable Volume" or voice boost variants). Without this, shaka
      // picks the first variant or the highest bitrate one; it doesn't honor our
      // `primary`/original flag on its own. Each preference falls back to the next.
      if (!isLive && streamingData.adaptive_formats) {
        var originalAudioLang = '';
        for (var afi = 0; afi < streamingData.adaptive_formats.length; afi++) {
          var af = streamingData.adaptive_formats[afi];
          if (af.is_original && af.language) { originalAudioLang = af.language; break; }
        }
        var audioPreference = function (role) {
          return { language: originalAudioLang, role: role, label: '', channelCount: 0, codec: '' };
        };
        try { player.configure('preferredAudio', [audioPreference('main'), audioPreference('')]); } catch (e) {}
      }

      // Preferred video codec (quality_sabr preference). Shaka keeps a single codec
      // family; it falls back to another one when the preferred codec isn't available
      // or can't be decoded.
      var preferredCodecs = CODEC_PREFERENCES[options.codecPreference] || [];
      player.configure('preferredVideo', preferredCodecs.map(function (codec) {
        return { label: '', role: '', language: '', codec: codec, hdrLevel: '', layout: '' };
      }));

      var duration = Number(basicInfo.duration) || 0;
      var startTime = options.startTime;
      if (startTime === undefined && savePositionsEnabled) {
        var savedTime = getPlaybackPosition(videoId);
        // Like the classic player: a video watched (nearly) to the end starts over.
        startTime = (duration > 0 && savedTime >= duration - 20) ? 0 : savedTime;
      }

      liveManifest = isLive ? { uri: manifestUri, mimeType: manifestMimeType } : null;
      if (ui) ui.configure({ overflowMenuButtons: overflowMenuButtons(isLive) });
      var mimeType = isLive
        ? manifestMimeType
        : (manifestUri.indexOf('data:' + window.MANIFEST_TYPE_SABR) === 0 ? window.MANIFEST_TYPE_SABR : undefined);
      await player.load(manifestUri, startAtLiveEdge ? undefined : startTime, mimeType);

      if (generation !== loadGeneration) {
        // Another loadVideo() or dispose() took over while this one was loading.
        return { player: player, videoElement: videoElement, videoInfo: videoInfo };
      }

      applyPlaybackSettings(options);
      if (!options.listen) {
        applyQualityPreference(options.qualityPreference);
        applyCaptionPreference(options.preferredCaptions);
      }
      loadedVideoId = videoId;
      loadedDuration = isActiveLive ? 0 : duration;

      // Autoplay only when asked to; a server-requested reload that happened while the
      // user had the video paused stays paused (options.startPaused).
      if (options.autoplay && !options.startPaused) {
        videoElement.play().catch(function (err) {
          if (err.name === 'NotAllowedError') console.warn('[SABRPlayer]', 'Autoplay was prevented by the browser');
        });
      }

      if (savePositionsEnabled && !isActiveLive) {
        savePositionInterval = setInterval(function () {
          if (videoElement && !videoElement.paused) saveCurrentPosition();
        }, SAVE_POSITION_INTERVAL_MS);
      }

      return { player: player, videoElement: videoElement, videoInfo: videoInfo };
    } catch (error) {
      if (generation !== loadGeneration) {
        // Superseded (e.g. a server-requested reload interrupted this load): the
        // newer load owns the player now, so this one is not a failure.
        console.info('[SABRPlayer]', 'Load superseded by a newer one');
        return { player: player, videoElement: videoElement, videoInfo: null, superseded: true };
      }
      console.error('[SABRPlayer]', 'Error loading video:', error);
      hideSpinner();
      throw error;
    }
  }

  async function dispose() {
    loadGeneration++;
    hasPlayed = false;
    saveCurrentPosition();
    stopPositionSaving();
    loadedVideoId = null;
    if (keydownInstalled) { document.removeEventListener('keydown', handleKeydown); keydownInstalled = false; }

    if (sabrStream) { try { sabrStream.cleanup(); } catch (e) {} sabrStream = null; }
    // The UI overlay owns the player: destroy it first (it destroys the player too),
    // and only destroy the player directly when there is no overlay.
    if (ui) {
      await ui.destroy();
      ui = null;
    } else if (player) {
      await player.destroy();
    }
    player = null;
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
    setMessages: setMessages,
    createErrorDisplay: createErrorDisplay,
    initInnertube: initInnertube,
    fetchOnesieConfig: fetchOnesieConfig
  };
})();

window.SABRPlayer = SABRPlayer;