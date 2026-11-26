// Port of FreeTube's SabrSchemePlugin.js
// Registers the 'sabr' networking scheme with Shaka.
// Reads shaka from window.shaka, googlevideo symbols from window.googlevideo.
// Invidious is browser-sandboxed, so outbound fetches are routed through
// SABRHelpers.fetchWithProxy (the Crystal /proxy route) instead of hitting
// googlevideo directly.
// SABR_REDIRECT parts are followed (FreeTube #9689): the redirect URL replaces
// the stream's SABR URL for all subsequent requests. Redirect retries within one
// segment request are capped (MAX_REDIRECTS_PER_REQUEST).
// Exports window.setupSabrScheme.

'use strict';

(function () {
  // Lazily resolve dependencies at call time so load order is flexible.
  function shaka() { return window.shaka; }
  function gv() { return window.googlevideo; }

  // A segment request that is only ever answered with SABR_REDIRECT parts reloads
  // the player instead of looping forever.
  var MAX_REDIRECTS_PER_REQUEST = 5;

  function deepCopy(obj) {
    return JSON.parse(JSON.stringify(obj));
  }

  // "itag-lastModified-xtags": xtags is base64url, it can contain hyphens itself.
  function formatIdFromString(str) {
    var first = str.indexOf('-');
    var second = first === -1 ? -1 : str.indexOf('-', first + 1);
    var xtags = second === -1 ? '' : str.slice(second + 1);
    return {
      itag: parseInt(first === -1 ? str : str.slice(0, first), 10),
      lastModified: first === -1 ? undefined : str.slice(first + 1, second === -1 ? undefined : second),
      xtags: xtags.length ? xtags : undefined
    };
  }

  function createBufferedRange(formatId, buffered, segmentIndex) {
    var endSegmentIndex = segmentIndex.find(buffered.end);
    if (endSegmentIndex == null) {
      endSegmentIndex = segmentIndex.getNumReferences() - 1;
    }
    return {
      formatId: formatId,
      startTimeMs: String(Math.round(buffered.start * 1000)),
      durationMs: String(Math.round((buffered.end - buffered.start) * 1000)),
      startSegmentIndex: segmentIndex.find(buffered.start),
      endSegmentIndex: endSegmentIndex
    };
  }

  function createFullBufferRange(formatId) {
    var MAX_INT32_VALUE = gv().utils.MAX_INT32_VALUE;
    return {
      formatId: formatId,
      durationMs: MAX_INT32_VALUE,
      startTimeMs: '0',
      startSegmentIndex: parseInt(MAX_INT32_VALUE, 10),
      endSegmentIndex: parseInt(MAX_INT32_VALUE, 10),
      timeRange: {
        durationTicks: MAX_INT32_VALUE,
        startTicks: '0',
        timescale: 1000
      }
    };
  }

  function fillBufferedRanges(player, manifest, audioFormatsActive, streamIsVideo, streamIsAudio, bufferedRanges, activeVariant) {
    var bufferedInfo = player.getBufferedInfo();
    if (bufferedInfo.audio.length === 0 && bufferedInfo.video.length === 0) return;

    // The manifest can lag behind the player's tracks (e.g. during a reload), and
    // audio-only variants have no video stream: send no buffered ranges then.
    if (!manifest || !manifest.variants) return;
    var activeManifestVariant;
    if (audioFormatsActive) {
      activeManifestVariant = manifest.variants.find(function (variant) {
        return !!variant.audio && variant.audio.originalId === activeVariant.originalAudioId;
      });
    } else {
      activeManifestVariant = manifest.variants.find(function (variant) {
        return !!variant.audio && !!variant.video &&
          variant.audio.originalId === activeVariant.originalAudioId &&
          variant.video.originalId === activeVariant.originalVideoId;
      });
    }
    if (!activeManifestVariant || !activeManifestVariant.audio.segmentIndex) return;

    var audioFormatId = formatIdFromString(activeVariant.originalAudioId);
    var audioSegmentIndex = activeManifestVariant.audio.segmentIndex;

    if (streamIsVideo) {
      bufferedRanges.push(createFullBufferRange(audioFormatId));
    } else {
      for (var i = 0; i < bufferedInfo.audio.length; i++) {
        bufferedRanges.push(createBufferedRange(audioFormatId, bufferedInfo.audio[i], audioSegmentIndex));
      }
    }

    var videoFormatId;
    var videoSegmentIndex;

    if (streamIsAudio && bufferedInfo.video.length > 0) {
      videoFormatId = formatIdFromString(activeVariant.originalVideoId);
      bufferedRanges.push(createFullBufferRange(videoFormatId));
    } else {
      for (var j = 0; j < bufferedInfo.video.length; j++) {
        var buffered = bufferedInfo.video[j];
        if (!videoFormatId) {
          videoFormatId = formatIdFromString(activeVariant.originalVideoId);
        }
        if (!videoSegmentIndex) {
          videoSegmentIndex = activeManifestVariant.video && activeManifestVariant.video.segmentIndex;
          if (!videoSegmentIndex) break;
        }
        bufferedRanges.push(createBufferedRange(videoFormatId, buffered, videoSegmentIndex));
      }
    }
  }

  function createCacheResponse(ShakaAbortableOperation, uri, request, data) {
    return ShakaAbortableOperation.completed({
      data: data,
      fromCache: true,
      headers: {},
      originalRequest: request,
      originalUri: uri,
      uri: uri
    });
  }

  function createRecoverableNetworkError(code) {
    var ShakaError = shaka().util.Error;
    var args = Array.prototype.slice.call(arguments, 1);
    // shaka collects the trailing constructor arguments into error.data, so pass them positionally.
    return new ShakaError(ShakaError.Severity.RECOVERABLE, ShakaError.Category.NETWORK, code, ...args);
  }

  // Ask the player to reload (escape hatch for retry loops), aborting this request chain.
  // Stop the stream's requests and ask the player to reload. The `reload` event is
  // emitted once per stream, even when the fetch was already aborted (e.g. by a
  // MEDIA_END part in the same chunk).
  function requestPlayerReload(currentState) {
    currentState.sabrStreamState.playerReloadRequested = true;
    if (!currentState.abortController.signal.aborted) currentState.abortController.abort();
    if (!currentState.sabrStreamState.reloadEmitted) {
      currentState.sabrStreamState.reloadEmitted = true;
      currentState.eventEmitter.emit('reload');
    }
  }

  // Wait for ms, rejecting as soon as the signal aborts (or immediately if it already has).
  function abortableDelay(ms, signal) {
    return new Promise(function (resolve, reject) {
      if (signal.aborted) {
        reject(new Error('aborted'));
        return;
      }
      var timer = setTimeout(function () {
        signal.removeEventListener('abort', onAbort);
        resolve();
      }, ms);
      function onAbort() {
        clearTimeout(timer);
        reject(new Error('aborted'));
      }
      signal.addEventListener('abort', onAbort, { once: true });
    });
  }

  // Settle with the promise, or reject as soon as the signal aborts.
  function abortable(promise, signal) {
    if (signal.aborted) return Promise.reject(new Error('aborted'));
    return new Promise(function (resolve, reject) {
      function onAbort() { reject(new Error('aborted')); }
      signal.addEventListener('abort', onAbort, { once: true });
      promise.then(resolve, reject).finally(function () {
        signal.removeEventListener('abort', onAbort);
      });
    });
  }

  // The error for a request chain whose abort signal fired before it could complete.
  function abortedRequestError(operationInputs, currentState) {
    var ShakaError = shaka().util.Error;
    var code = currentState.abortStatus.timedOut ? ShakaError.Code.TIMEOUT : ShakaError.Code.OPERATION_ABORTED;
    return createRecoverableNetworkError(code, operationInputs.uri, operationInputs.requestType);
  }

  function prepareSabrContexts(sabrStreamState) {
    var sabrContexts = [];
    var unsentSabrContexts = [];
    sabrStreamState.sabrContexts.forEach(function (ctxUpdate) {
      if (sabrStreamState.activeSabrContextTypes.has(ctxUpdate.type)) {
        sabrContexts.push(ctxUpdate);
      } else {
        unsentSabrContexts.push(ctxUpdate.type);
      }
    });
    return { sabrContexts: sabrContexts, unsentSabrContexts: unsentSabrContexts };
  }

  // data: googlevideo/ump CompositeBuffer handed to UmpReader's onPart callback.
  function decodePart(data, decoder) {
    if (!data.chunks.length) return undefined;
    try {
      var concatenateChunks = gv().utils.concatenateChunks;
      var chunk = data.chunks.length === 1 ? data.chunks[0] : concatenateChunks(data.chunks);
      return decoder.decode(chunk);
    } catch (e) {
      return undefined;
    }
  }

  function createTimeoutController(callback, timeoutMs) {
    return {
      _timeout: setTimeout(callback, timeoutMs),
      _resetCount: 0,
      resetTimeoutOnce: function () {
        if (this._resetCount > 0) return;
        this.clearTimeout();
        this._timeout = setTimeout(callback, timeoutMs);
        this._resetCount++;
      },
      clearTimeout: function () {
        clearTimeout(this._timeout);
      }
    };
  }

  // Wrap the youtube/googlevideo fetch URL through the Invidious /proxy route,
  // forwarding the UMP headers youtube needs. Returns a fetch-compatible RequestInit.
  function proxyFetch(url, requestInit) {
    var headers = new Headers(requestInit.headers || {});
    // Ensure these headers survive the proxy hop.
    if (!headers.has('x-youtube-client-name')) {
      headers.set('x-youtube-client-name', '3');
    }
    return SABRHelpers.fetchWithProxy(url, Object.assign({}, requestInit, { headers: headers }));
  }

  async function doRequest(operationInputs, currentState) {
    var ShakaError = shaka().util.Error;
    var protos = gv().protos;
    var ump = gv().ump;
    var utils = gv().utils;
    var UmpReader = ump.UmpReader;
    var UMPPartId = protos.UMPPartId;
    var VideoPlaybackAbrRequest = protos.VideoPlaybackAbrRequest;
    var StreamProtectionStatus = protos.StreamProtectionStatus;
    var SabrError = protos.SabrError;
    var SabrRedirect = protos.SabrRedirect;
    var MediaHeader = protos.MediaHeader;
    var SabrContextSendingPolicy = protos.SabrContextSendingPolicy;
    var SabrContextUpdate = protos.SabrContextUpdate;
    var SabrContextWritePolicy = protos.SabrContextWritePolicy;
    var NextRequestPolicy = protos.NextRequestPolicy;
    var ReloadPlaybackContext = protos.ReloadPlaybackContext;

    var response;
    var responseDataChunks = [];
    var segmentComplete = false;
    var shouldRetry = false;
    var shouldRetryDueToNextRequestPolicy = false;
    var invalidPoToken = false;
    var redirected = false;
    var error;

    if (currentState.sabrStreamState.playerReloadRequested) {
      throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
    }

    try {
      var shouldReloadDueToBackoffLoop = false;
      if ((currentState.sabrStreamState.nextRequestPolicy?.backoffTimeMs || 0) > 0) {
        var currentBackoffTimeMs = currentState.sabrStreamState.nextRequestPolicy.backoffTimeMs;
        var timeoutMs = operationInputs.request.retryParameters.timeout;
        // Reload instead of waiting after repeated backoffs, or when this wait would
        // bring the total waited time to the request timeout. A wait that fits is
        // done, and the request is then sent.
        if (currentState.cumulativeBackOffRequested >= 3 ||
            (timeoutMs > 0 && timeoutMs <= currentState.cumulativeBackOffTimeMs + currentBackoffTimeMs)) {
          shouldReloadDueToBackoffLoop = true;
        } else {
          currentState.eventEmitter.emit('backoff-requested', { backoffMs: currentBackoffTimeMs });
          // Restart the request timer before waiting, so the admitted wait and the
          // request after it both fit in a full timeout (the check above compares
          // the waits with the whole timeout).
          currentState.timeoutController?.resetTimeoutOnce();
          await abortableDelay(currentBackoffTimeMs, currentState.abortController.signal);
          currentState.cumulativeBackOffTimeMs += currentBackoffTimeMs;
          currentState.cumulativeBackOffRequested += 1;

          // Another request may have asked for a reload while this one waited
          if (currentState.sabrStreamState.playerReloadRequested) {
            throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
          }
          // ...or renewed the PO token / playback cookie: rebuild the body from the
          // current stream state, like the URL read below.
          currentState.abrRequest.streamerContext.poToken = currentState.sabrStreamState.poToken;
          currentState.abrRequest.streamerContext.playbackCookie = currentState.sabrStreamState.nextRequestPolicy?.playbackCookie;
          currentState.requestInit.body = VideoPlaybackAbrRequest.encode(currentState.abrRequest).finish();
        }
      }
      if (shouldReloadDueToBackoffLoop || currentState.cumulativeRetryDueToNextRequestPolicy >= 100) {
        requestPlayerReload(currentState);
        throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
      }

      var fmtId = formatIdFromString(operationInputs.formatIdString);
      var itag = fmtId.itag;
      var lastModified = fmtId.lastModified;
      var xtags = fmtId.xtags;
      var mediaHeaderId;

      var umpReader = new UmpReader({
        onPart: function (partType, data) {
          switch (partType) {
            case UMPPartId.STREAM_PROTECTION_STATUS: {
              var streamProtectionStatus = decodePart(data, StreamProtectionStatus);
              if (!streamProtectionStatus) break;
              if (streamProtectionStatus.status === 3) {
                invalidPoToken = true;
                if (streamProtectionStatus.maxRetries) {
                  currentState.attestationMaxRetries = streamProtectionStatus.maxRetries;
                }
              }
              break;
            }
            case UMPPartId.SABR_ERROR: {
              var sabrError = decodePart(data, SabrError);
              if (!sabrError) break;
              error = 'SABR Error: type: ' + sabrError.type + ', code: ' + sabrError.code;
              break;
            }
            case UMPPartId.SABR_REDIRECT: {
              var sabrRedirect = decodePart(data, SabrRedirect);
              if (!sabrRedirect || !sabrRedirect.url) break;
              // Follow the redirect for all subsequent requests (FreeTube #9689).
              currentState.sabrStreamState.sabrUrl = sabrRedirect.url;
              redirected = true;
              shouldRetry = true;
              break;
            }
            case UMPPartId.MEDIA_HEADER: {
              if (mediaHeaderId === undefined) {
                var mediaHeader = decodePart(data, MediaHeader);
                // A header without a format ID can't be the requested segment
                if (!mediaHeader || !mediaHeader.formatId) break;
                if (
                  mediaHeader.formatId.itag === itag &&
                  mediaHeader.formatId.lastModified === lastModified &&
                  mediaHeader.formatId.xtags === xtags
                ) {
                  if (operationInputs.isInit && mediaHeader.isInitializationSegment) {
                    mediaHeaderId = mediaHeader.headerId;
                  } else if (!operationInputs.isInit && mediaHeader.segmentNum === operationInputs.sequenceNumber) {
                    mediaHeaderId = mediaHeader.headerId;
                  }
                }
              }
              break;
            }
            case UMPPartId.MEDIA: {
              if (mediaHeaderId === data.getUint8(0)) {
                var split = data.split(1);
                var remaining = split.remainingBuffer;
                for (var k = 0; k < remaining.chunks.length; k++) {
                  responseDataChunks.push(remaining.chunks[k]);
                }
              }
              break;
            }
            case UMPPartId.MEDIA_END: {
              if (mediaHeaderId === data.getUint8(0)) {
                segmentComplete = true;
                currentState.abortStatus.finished = true;
                currentState.abortController.abort();
              }
              break;
            }
            case UMPPartId.NEXT_REQUEST_POLICY: {
              var nextRequestPolicy = decodePart(data, NextRequestPolicy);
              shouldRetry = true;
              shouldRetryDueToNextRequestPolicy = true;
              currentState.sabrStreamState.nextRequestPolicy = nextRequestPolicy;
              currentState.abrRequest.streamerContext.playbackCookie = nextRequestPolicy?.playbackCookie;
              currentState.abrRequest.streamerContext.backoffTimeMs = nextRequestPolicy?.backoffTimeMs;
              break;
            }
            case UMPPartId.FORMAT_INITIALIZATION_METADATA: {
              break;
            }
            case UMPPartId.SABR_CONTEXT_UPDATE: {
              var sabrContextUpdate = decodePart(data, SabrContextUpdate);
              if (!sabrContextUpdate) break;
              if (sabrContextUpdate.type !== undefined && sabrContextUpdate.value?.length) {
                if (
                  sabrContextUpdate.writePolicy === SabrContextWritePolicy.KEEP_EXISTING &&
                  currentState.sabrStreamState.sabrContexts.has(sabrContextUpdate.type)
                ) {
                  break;
                }
                currentState.sabrStreamState.sabrContexts.set(sabrContextUpdate.type, sabrContextUpdate);
                if (sabrContextUpdate.sendByDefault) {
                  currentState.sabrStreamState.activeSabrContextTypes.add(sabrContextUpdate.type);
                }
              }
              break;
            }
            case UMPPartId.SABR_CONTEXT_SENDING_POLICY: {
              var sabrContextSendingPolicy = decodePart(data, SabrContextSendingPolicy);
              if (!sabrContextSendingPolicy) break;
              for (var i = 0; i < sabrContextSendingPolicy.startPolicy.length; i++) {
                var startPolicy = sabrContextSendingPolicy.startPolicy[i];
                if (!currentState.sabrStreamState.activeSabrContextTypes.has(startPolicy)) {
                  currentState.sabrStreamState.activeSabrContextTypes.add(startPolicy);
                }
              }
              for (var j = 0; j < sabrContextSendingPolicy.stopPolicy.length; j++) {
                var stopPolicy = sabrContextSendingPolicy.stopPolicy[j];
                if (currentState.sabrStreamState.activeSabrContextTypes.has(stopPolicy)) {
                  currentState.sabrStreamState.activeSabrContextTypes.delete(stopPolicy);
                }
              }
              for (var m = 0; m < sabrContextSendingPolicy.discardPolicy.length; m++) {
                var discardPolicy = sabrContextSendingPolicy.discardPolicy[m];
                if (currentState.sabrStreamState.sabrContexts.has(discardPolicy)) {
                  currentState.sabrStreamState.sabrContexts.delete(discardPolicy);
                }
              }
              break;
            }
            case UMPPartId.RELOAD_PLAYER_RESPONSE: {
              var reloadPlaybackContext = decodePart(data, ReloadPlaybackContext);
              if (!reloadPlaybackContext) break;
              requestPlayerReload(currentState);
              break;
            }
            default: {
              break;
            }
          }
        }
      });

      var sabrURL = new URL(currentState.sabrStreamState.sabrUrl);
      sabrURL.searchParams.set('rn', String(currentState.sabrStreamState.requestNumber++));
      // Stream through the Invidious proxy (CSP + CORS), honoring requestInit headers/body.
      response = await proxyFetch(sabrURL.toString(), currentState.requestInit);

      operationInputs.headersReceived({});

      // A non-OK status (or a bodiless response) is reported as BAD_HTTP_STATUS below.
      if (response.ok && response.body) {
        var reader = response.body.getReader();
        var readObj = await reader.read();

        while (!readObj.done && !currentState.abortStatus.finished) {
          await umpReader.feed(readObj.value);
          if (!currentState.abortStatus.finished) {
            readObj = await reader.read();
          }
        }
      }
    } catch (err) {
      if (err instanceof ShakaError) throw err;
      if (currentState.abortStatus.cancelled) {
        throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
      } else if (currentState.abortStatus.timedOut) {
        throw createRecoverableNetworkError(ShakaError.Code.TIMEOUT, operationInputs.uri, operationInputs.requestType);
      } else if (!currentState.abortStatus.finished) {
        throw createRecoverableNetworkError(ShakaError.Code.HTTP_ERROR, operationInputs.uri, err, operationInputs.requestType);
      }
    }

    if (currentState.abortStatus.cancelled) {
      throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
    } else if (currentState.abortStatus.timedOut) {
      throw createRecoverableNetworkError(ShakaError.Code.TIMEOUT, operationInputs.uri, operationInputs.requestType);
    }


    if (responseDataChunks.length > 0 && segmentComplete) {
      var concatenateChunks = utils.concatenateChunks;
      var data = concatenateChunks(responseDataChunks);
      if (operationInputs.isInit) {
        currentState.initDataCache.set(operationInputs.formatIdString, data);
      }
      return {
        uri: operationInputs.uri,
        originalUri: operationInputs.uri,
        data: data,
        status: response.status,
        headers: {},
        fromCache: false,
        originalRequest: operationInputs.request
      };
    } else if (shouldRetry || invalidPoToken) {
      // StreamProtectionStatus 3 = ATTESTATION_REQUIRED: the server is refusing to
      // send media until we re-attest. Retrying with the same PO token just loops on
      // the 2s backoff forever (the symptom: endless "SABR throttled" toasts), so
      // mint a fresh token before retrying and give up loudly once maxRetries is hit.
      if (invalidPoToken) {
        currentState.attestationRetries = (currentState.attestationRetries || 0) + 1;
        var attestationLimit = currentState.attestationMaxRetries || 10;
        if (currentState.attestationRetries > attestationLimit) {
          throw new ShakaError(
            ShakaError.Severity.CRITICAL,
            ShakaError.Category.NETWORK,
            ShakaError.Code.HTTP_ERROR,
            operationInputs.uri,
            new Error('SABR attestation required and PO token re-minting did not satisfy it'),
            operationInputs.requestType
          );
        }
        var freshPoToken = null;
        if (currentState.mintPoToken) {
          try {
            // The segment timeout/cancellation aborts this wait as well.
            freshPoToken = await abortable(currentState.mintPoToken(), currentState.abortController.signal);
          } catch (e) {
            if (currentState.abortController.signal.aborted) throw abortedRequestError(operationInputs, currentState);
            console.warn('[SabrScheme] PO token re-mint failed', e);
          }
        }
        if (currentState.abortController.signal.aborted) throw abortedRequestError(operationInputs, currentState);
        if (freshPoToken) {
          var freshPoTokenBytes = utils.base64ToU8(freshPoToken);
          currentState.abrRequest.streamerContext.poToken = freshPoTokenBytes;
          // Later segment requests of this stream start with the replacement token.
          currentState.sabrStreamState.poToken = freshPoTokenBytes;
        }
      }

      if (redirected) {
        currentState.redirectRetries += 1;
        if (currentState.redirectRetries > MAX_REDIRECTS_PER_REQUEST) {
          console.warn('[SabrScheme] Too many SABR redirects, reloading the player');
          requestPlayerReload(currentState);
          throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
        }
      }

      if (shouldRetryDueToNextRequestPolicy) {
        currentState.cumulativeRetryDueToNextRequestPolicy += 1;
      }

      var prepared = prepareSabrContexts(currentState.sabrStreamState);
      currentState.abrRequest.streamerContext.sabrContexts = prepared.sabrContexts;
      currentState.abrRequest.streamerContext.unsentSabrContexts = prepared.unsentSabrContexts;

      var body;
      try {
        body = VideoPlaybackAbrRequest.encode(currentState.abrRequest).finish();
      } catch (e) {
        console.error('Invalid VideoPlaybackAbrRequest data', currentState.abrRequest);
        throw e;
      }

      currentState.requestInit = {
        body: body,
        method: 'POST',
        headers: {
          'content-type': 'application/x-protobuf',
          'accept-encoding': 'identity',
          'accept': 'application/vnd.yt-ump'
        },
        signal: currentState.abortController.signal
      };
      currentState.abortStatus.timedOut = false;
      currentState.abortStatus.finished = false;
      return doRequest(operationInputs, currentState);
    } else if (error) {
      throw createRecoverableNetworkError(ShakaError.Code.HTTP_ERROR, operationInputs.uri, new Error(error), operationInputs.requestType);
    } else if (responseDataChunks.length > 0 && !segmentComplete) {
      throw createRecoverableNetworkError(
        ShakaError.Code.HTTP_ERROR,
        operationInputs.uri,
        new Error('Incomplete segment, missing MEDIA_END part'),
        operationInputs.requestType
      );
    } else if (response.status === 200) {
      throw createRecoverableNetworkError(
        ShakaError.Code.HTTP_ERROR,
        operationInputs.uri,
        new Error('Empty response, this should not happen'),
        operationInputs.requestType
      );
    } else {
      var severity = response.status === 401 || response.status === 403
        ? ShakaError.Severity.CRITICAL
        : ShakaError.Severity.RECOVERABLE;
      throw new ShakaError(
        severity,
        ShakaError.Category.NETWORK,
        ShakaError.Code.BAD_HTTP_STATUS,
        operationInputs.uri,
        response.status,
        '',
        {},
        operationInputs.requestType,
        operationInputs.uri
      );
    }
  }

  function setupSabrScheme(sabrData, getPlayer, getManifest, getWidth, getHeight, mintPoToken) {
    var ShakaAbortableOperation = shaka().util.AbortableOperation;
    var ShakaError = shaka().util.Error;
    var protos = gv().protos;
    var utils = gv().utils;
    var base64ToU8 = utils.base64ToU8;
    var VideoPlaybackAbrRequest = protos.VideoPlaybackAbrRequest;
    var EventEmitterLike = utils.EventEmitterLike;

    var eventEmitter = new EventEmitterLike();
    var initDataCache = new Map();

    var videoPlaybackUstreamerConfig = base64ToU8(sabrData.ustreamerConfig);
    var clientInfo = deepCopy(sabrData.clientInfo);

    var sabrStreamState = {
      sabrUrl: sabrData.url,
      // Current PO token of this stream (replaced when the server asks to re-attest).
      poToken: base64ToU8(sabrData.poToken),
      activeSabrContextTypes: new Set(),
      sabrContexts: new Map(),
      nextRequestPolicy: undefined,
      playerReloadRequested: false,
      requestNumber: 0
    };

    shaka().net.NetworkingEngine.registerScheme('sabr', function (uri, request, requestType, _progressUpdated, headersReceived, _config) {
      var player = getPlayer();
      if (player == null) {
        return new ShakaAbortableOperation(Promise.resolve());
      }
      var isAudioOnly = player.isAudioOnly();

      var url = new URL(request.uris[0]);
      var isInit = url.searchParams.has('init');
      var formatIdString = url.searchParams.get('formatId');

      if (isInit && initDataCache.has(formatIdString)) {
        return createCacheResponse(ShakaAbortableOperation, uri, request, initDataCache.get(formatIdString));
      }

      var variantTracks = player.getVariantTracks();
      var activeVariant = null;
      for (var i = 0; i < variantTracks.length; i++) {
        if (variantTracks[i].active) { activeVariant = variantTracks[i]; break; }
      }

      var streamIsAudio = url.pathname === 'audio';
      var streamIsVideo = url.pathname === 'video';

      var audioFormatId;
      var videoFormatId;

      // The companion format of the other media type comes from the active variant
      // when there is one. Before that (e.g. the init request, which can run before
      // shaka publishes any track) use the published tracks or, failing that, the
      // companion format the manifest parser put in the URL.
      var urlVideoFormatId = url.searchParams.get('videoFormatId');
      var urlAudioFormatId = url.searchParams.get('audioFormatId');

      if (streamIsAudio) {
        audioFormatId = formatIdFromString(formatIdString);
        var companionVideoTrack = isAudioOnly ? null : (activeVariant || variantTracks[0]);
        var videoIdString = companionVideoTrack && companionVideoTrack.originalVideoId
          ? companionVideoTrack.originalVideoId
          : urlVideoFormatId;
        if (videoIdString) videoFormatId = formatIdFromString(videoIdString);
      } else if (streamIsVideo) {
        videoFormatId = formatIdFromString(formatIdString);
        var audioIdString = urlAudioFormatId;
        if (activeVariant && activeVariant.originalAudioId) {
          audioIdString = activeVariant.originalAudioId;
        } else {
          var candidates = variantTracks.filter(function (track) {
            return track.originalAudioId && track.audioRoles.indexOf('main') !== -1;
          });
          if (candidates.length === 0) {
            candidates = variantTracks.filter(function (track) { return !!track.originalAudioId; });
          }
          if (candidates.length > 0) {
            var probableAudioFormat = candidates.reduce(function (previous, current) {
              return current.audioBandwidth >= previous.audioBandwidth ? current : previous;
            });
            audioIdString = probableAudioFormat.originalAudioId;
          }
        }
        if (audioIdString) audioFormatId = formatIdFromString(audioIdString);
      }

      var bufferedRanges = [];
      if (!isInit && activeVariant) {
        fillBufferedRanges(player, getManifest(), isAudioOnly, streamIsVideo, streamIsAudio, bufferedRanges, activeVariant);
      }

      var playerTimeMs = '0';
      if (url.searchParams.has('startTimeMs')) {
        playerTimeMs = url.searchParams.get('startTimeMs');
      }

      var drcEnabled = url.searchParams.has('drc') || !!(activeVariant && activeVariant.audioRoles.indexOf('drc') !== -1);
      var enableVoiceBoost = url.searchParams.has('vb') || !!(activeVariant && activeVariant.audioRoles.indexOf('voice-boost') !== -1);
      var resolution = streamIsVideo ? parseInt(url.searchParams.get('resolution'), 10) : undefined;

      var prepared = prepareSabrContexts(sabrStreamState);

      var requestData = {
        clientAbrState: {
          bandwidthEstimate: String(Math.round(player.getStats().estimatedBandwidth)),
          timeSinceLastManualFormatSelectionMs: streamIsVideo ? '0' : undefined,
          stickyResolution: resolution,
          lastManualSelectedResolution: resolution,
          playbackRate: player.getPlaybackRate(),
          enabledTrackTypesBitfield: streamIsAudio ? 1 : 0,
          drcEnabled: drcEnabled,
          enableVoiceBoost: enableVoiceBoost,
          playerTimeMs: playerTimeMs,
          clientViewportWidth: getWidth(),
          clientViewportHeight: getHeight(),
          clientViewportIsFlexible: false
        },
        selectedAudioFormatIds: audioFormatId ? [audioFormatId] : [],
        selectedVideoFormatIds: videoFormatId ? [videoFormatId] : [],
        selectedCaptionFormatIds: [],
        initializationFormatIds: isInit ? [] : [audioFormatId, videoFormatId].filter(Boolean),
        bufferedRanges: bufferedRanges,
        streamerContext: {
          poToken: sabrStreamState.poToken,
          clientInfo: clientInfo,
          sabrContexts: prepared.sabrContexts,
          unsentSabrContexts: prepared.unsentSabrContexts,
          playbackCookie: sabrStreamState.nextRequestPolicy?.playbackCookie
        },
        ssapPlaybackInfos: [],
        field1000: [],
        videoPlaybackUstreamerConfig: videoPlaybackUstreamerConfig
      };

      var body;
      try {
        body = VideoPlaybackAbrRequest.encode(requestData).finish();
      } catch (e) {
        console.error('Invalid VideoPlaybackAbrRequest data', requestData);
        throw e;
      }

      var sequenceNumber = parseInt(url.searchParams.get('sq'), 10);

      var opInputs = {
        uri: uri,
        request: request,
        requestType: requestType,
        headersReceived: headersReceived,
        formatIdString: formatIdString,
        isInit: isInit,
        sequenceNumber: isNaN(sequenceNumber) ? undefined : sequenceNumber
      };

      var abortController = new AbortController();

      var init = {
        body: body,
        method: 'POST',
        headers: {
          'content-type': 'application/x-protobuf',
          'accept-encoding': 'identity',
          'accept': 'application/vnd.yt-ump'
        },
        signal: abortController.signal
      };

      var abortStatus = { cancelled: false, timedOut: false, finished: false };
      var timeoutMs = request.retryParameters.timeout;
      var timeoutController = null;
      if (timeoutMs) {
        timeoutController = createTimeoutController(function () {
          abortStatus.timedOut = true;
          abortController.abort();
        }, timeoutMs);
      }

      var currentState = {
        initDataCache: initDataCache,
        abrRequest: requestData,
        requestInit: init,
        abortStatus: abortStatus,
        abortController: abortController,
        sabrStreamState: sabrStreamState,
        timeoutController: timeoutController,
        eventEmitter: eventEmitter,
        mintPoToken: mintPoToken,
        attestationRetries: 0,
        redirectRetries: 0,
        cumulativeBackOffTimeMs: 0,
        cumulativeBackOffRequested: 0,
        cumulativeRetryDueToNextRequestPolicy: 0
      };

      var pendingRequest = doRequest(opInputs, currentState);

      var op = new ShakaAbortableOperation(pendingRequest, function () {
        abortStatus.cancelled = true;
        abortController.abort();
        return Promise.resolve();
      });

      if (timeoutController) {
        op.finally(function () {
          timeoutController.clearTimeout();
        });
      }

      return op;
    });

    function cleanup() {
      shaka().net.NetworkingEngine.unregisterScheme('sabr');
      initDataCache.clear();
    }

    return {
      onBackoffRequested: function (callback) {
        eventEmitter.on('backoff-requested', callback);
      },
      onReloadOnce: function (callback) {
        eventEmitter.once('reload', callback);
      },
      cleanup: cleanup
    };
  }

  window.setupSabrScheme = setupSabrScheme;
})();