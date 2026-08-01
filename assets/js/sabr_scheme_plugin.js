// Port of FreeTube's SabrSchemePlugin.js
// Registers the 'sabr' networking scheme with Shaka.
// Reads shaka from window.shaka, googlevideo symbols from window.googlevideo.
// Invidious is browser-sandboxed, so outbound fetches are routed through
// SABRHelpers.fetchWithProxy (the Crystal /proxy route) instead of hitting
// googlevideo directly.
// Fixes the latent SABR_REDIRECT bug (write sabrStreamState.sabrUrl, not currentState.sabrUrl).
// Exports window.setupSabrScheme.

'use strict';

(function () {
  // Lazily resolve dependencies at call time so load order is flexible.
  function shaka() { return window.shaka; }
  function gv() { return window.googlevideo; }

  function deepCopy(obj) {
    return JSON.parse(JSON.stringify(obj));
  }


  function formatIdFromString(str) {
    var parts = str.split('-');
    return {
      itag: parseInt(parts[0], 10),
      lastModified: parts[1],
      xtags: parts[2]
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

    var activeManifestVariant;
    if (audioFormatsActive) {
      activeManifestVariant = manifest.variants.find(function (variant) {
        return variant.audio.originalId === activeVariant.originalAudioId;
      });
    } else {
      activeManifestVariant = manifest.variants.find(function (variant) {
        return variant.audio.originalId === activeVariant.originalAudioId &&
          variant.video.originalId === activeVariant.originalVideoId;
      });
    }

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
          videoSegmentIndex = activeManifestVariant.video.segmentIndex;
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
    return new ShakaError(ShakaError.Severity.RECOVERABLE, ShakaError.Category.NETWORK, code, args);
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

  function decodePart(part, decoder) {
    if (!part.data.chunks.length) return undefined;
    try {
      var concatenateChunks = gv().utils.concatenateChunks;
      var chunk = part.data.chunks.length === 1 ? part.data.chunks[0] : concatenateChunks(part.data.chunks);
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
    var CompositeBuffer = ump.CompositeBuffer;
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
    var PlaybackCookie = protos.PlaybackCookie;
    var ReloadPlaybackContext = protos.ReloadPlaybackContext;

    var response;
    var chunkedDataBuffer = null;
    var responseDataChunks = [];
    var segmentComplete = false;
    var shouldRetry = false;
    var shouldRetryDueToNextRequestPolicy = false;
    var invalidPoToken = false;
    var error;

    if (currentState.sabrStreamState.playerReloadRequested) {
      throw createRecoverableNetworkError(ShakaError.Code.OPERATION_ABORTED, operationInputs.uri, operationInputs.requestType);
    }

    // --- TEMP SEEK DIAGNOSTICS (toggle: window.SABR_DEBUG = true) ---
    var _dbg = (typeof window !== 'undefined' && window.SABR_DEBUG);
    var _dbgHeaders = [];
    var _dbgPartTypes = {};
    if (_dbg) {
      try {
        console.log('[SABR_DBG] REQ', JSON.stringify({
          uri: operationInputs.uri,
          isInit: operationInputs.isInit,
          sq: operationInputs.sequenceNumber,
          playerTimeMs: currentState.abrRequest.clientAbrState.playerTimeMs,
          bufRanges: (currentState.abrRequest.bufferedRanges || []).length,
          rn: currentState.sabrStreamState.requestNumber,
          ctxStored: currentState.sabrStreamState.sabrContexts.size,
          ctxActive: Array.from(currentState.sabrStreamState.activeSabrContextTypes),
          ctxSent: (currentState.abrRequest.streamerContext.sabrContexts || []).length,
          sabrHost: (new URL(currentState.sabrStreamState.sabrUrl)).host
        }));
      } catch (e) {}
    }

    try {
      var shouldReloadDueToBackoffLoop = false;
      if ((currentState.sabrStreamState.nextRequestPolicy?.backoffTimeMs || 0) > 0) {
        var currentBackoffTimeMs = currentState.sabrStreamState.nextRequestPolicy.backoffTimeMs;
        currentState.eventEmitter.emit('backoff-requested', { backoffMs: currentBackoffTimeMs });
        await new Promise(function (resolve, reject) {
          setTimeout(resolve, currentBackoffTimeMs);
          currentState.abortController.signal.addEventListener('abort', reject);
        });
        currentState.timeoutController?.resetTimeoutOnce();

        currentState.cumulativeBackOffTimeMs += currentState.sabrStreamState.nextRequestPolicy.backoffTimeMs;
        currentState.cumulativeBackOffRequested += 1;
        var timeoutMs = operationInputs.request.retryParameters.timeout;
        if (currentState.cumulativeBackOffRequested >= 3 || (timeoutMs > 0 && timeoutMs <= (currentState.cumulativeBackOffTimeMs + currentBackoffTimeMs))) {
          shouldReloadDueToBackoffLoop = true;
        }
      }
      if (shouldReloadDueToBackoffLoop || currentState.cumulativeRetryDueToNextRequestPolicy >= 100) {
        currentState.sabrStreamState.playerReloadRequested = true;
        if (!currentState.abortController.signal.aborted) {
          currentState.abortController.abort();
          currentState.eventEmitter.emit('reload');
        }
      }

      var sabrURL = new URL(currentState.sabrStreamState.sabrUrl);
      sabrURL.searchParams.set('rn', String(currentState.sabrStreamState.requestNumber++));
      // Stream through the Invidious proxy (CSP + CORS), honoring requestInit headers/body.
      response = await proxyFetch(sabrURL.toString(), currentState.requestInit);

      operationInputs.headersReceived({});

      var fmtId = formatIdFromString(operationInputs.formatIdString);
      var itag = fmtId.itag;
      var lastModified = fmtId.lastModified;
      var xtags = fmtId.xtags;
      var mediaHeaderId;

      var reader = response.body.getReader();
      var readObj = await reader.read();

      while (!readObj.done && !currentState.abortStatus.finished) {
        if (chunkedDataBuffer) {
          chunkedDataBuffer.append(readObj.value);
        } else {
          chunkedDataBuffer = new CompositeBuffer([readObj.value]);
        }

        var remainingData = new UmpReader(chunkedDataBuffer).read(function (part) {
          if (_dbg) { _dbgPartTypes[part.type] = (_dbgPartTypes[part.type] || 0) + 1; }
          switch (part.type) {
            case UMPPartId.STREAM_PROTECTION_STATUS: {
              var streamProtectionStatus = decodePart(part, StreamProtectionStatus);
              if (streamProtectionStatus && streamProtectionStatus.status === 3) {
                invalidPoToken = true;
                if (streamProtectionStatus.maxRetries) {
                  currentState.attestationMaxRetries = streamProtectionStatus.maxRetries;
                }
              }
              break;
            }
            case UMPPartId.SABR_ERROR: {
              var sabrError = decodePart(part, SabrError);
              if (!sabrError) break;
              error = 'SABR Error: type: ' + sabrError.type + ', code: ' + sabrError.code;
              break;
            }
            case UMPPartId.SABR_REDIRECT: {
              var sabrRedirect = decodePart(part, SabrRedirect);
              if (!sabrRedirect) break;
              // Match FreeTube EXACTLY: it writes currentState.sabrUrl (a field that does
              // NOT exist on currentState), so the redirect URL is effectively ignored and
              // every request keeps POSTing to the ORIGINAL server_abr_streaming_url
              // (sabrStreamState.sabrUrl). Earlier we "fixed" this to follow the redirect,
              // which pins the session to a specific CDN host (rrN---snXXX) that maintains a
              // sequential cursor and returns 0 media when the client jumps/seeks. Following
              // the redirect breaks seeking; ignoring it (as FreeTube does) keeps seeks working.
              currentState.sabrUrl = sabrRedirect.url;
              shouldRetry = true;
              break;
            }
            case UMPPartId.MEDIA_HEADER: {
              if (mediaHeaderId === undefined) {
                var mediaHeader = decodePart(part, MediaHeader);
                if (!mediaHeader) break;
                if (_dbg) {
                  try {
                    _dbgHeaders.push({ itag: mediaHeader.formatId.itag, seq: mediaHeader.sequenceNumber, isInitSeg: !!mediaHeader.isInitSeg, start: mediaHeader.startMs, want: operationInputs.sequenceNumber });
                  } catch (e) {}
                }
                if (
                  mediaHeader.formatId.itag === itag &&
                  mediaHeader.formatId.lastModified === lastModified &&
                  mediaHeader.formatId.xtags === xtags
                ) {
                  if (operationInputs.isInit && mediaHeader.isInitSeg) {
                    mediaHeaderId = mediaHeader.headerId;
                  } else if (!operationInputs.isInit && mediaHeader.sequenceNumber === operationInputs.sequenceNumber) {
                    mediaHeaderId = mediaHeader.headerId;
                  }
                }
              }
              break;
            }
            case UMPPartId.MEDIA: {
              if (mediaHeaderId === part.data.getUint8(0)) {
                var split = part.data.split(1);
                var remaining = split.remainingBuffer;
                for (var k = 0; k < remaining.chunks.length; k++) {
                  responseDataChunks.push(remaining.chunks[k]);
                }
              }
              break;
            }
            case UMPPartId.MEDIA_END: {
              if (mediaHeaderId === part.data.getUint8(0)) {
                segmentComplete = true;
                currentState.abortStatus.finished = true;
                currentState.abortController.abort();
              }
              break;
            }
            case UMPPartId.NEXT_REQUEST_POLICY: {
              var nextRequestPolicy = decodePart(part, NextRequestPolicy);
              shouldRetry = true;
              shouldRetryDueToNextRequestPolicy = true;
              currentState.sabrStreamState.nextRequestPolicy = nextRequestPolicy;
              currentState.abrRequest.streamerContext.playbackCookie = nextRequestPolicy?.playbackCookie ? PlaybackCookie.encode(nextRequestPolicy.playbackCookie).finish() : undefined;
              currentState.abrRequest.streamerContext.backoffTimeMs = nextRequestPolicy?.backoffTimeMs;
              break;
            }
            case UMPPartId.FORMAT_INITIALIZATION_METADATA: {
              break;
            }
            case UMPPartId.SABR_CONTEXT_UPDATE: {
              var sabrContextUpdate = decodePart(part, SabrContextUpdate);
              if (_dbg) { try { console.log('[SABR_DBG] CTX_UPDATE', JSON.stringify({ decoded: !!sabrContextUpdate, type: sabrContextUpdate ? sabrContextUpdate.type : null, valueLen: sabrContextUpdate && sabrContextUpdate.value ? sabrContextUpdate.value.length : 0, sendByDefault: sabrContextUpdate ? sabrContextUpdate.sendByDefault : null, writePolicy: sabrContextUpdate ? sabrContextUpdate.writePolicy : null })); } catch (e) {} }
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
              var sabrContextSendingPolicy = decodePart(part, SabrContextSendingPolicy);
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
              var reloadPlaybackContext = decodePart(part, ReloadPlaybackContext);
              if (!reloadPlaybackContext) break;
              currentState.sabrStreamState.playerReloadRequested = true;
              if (!currentState.abortController.signal.aborted) {
                currentState.abortController.abort();
                currentState.eventEmitter.emit('reload');
              }
              break;
            }
            default: {
              break;
            }
          }
        });

        if (!currentState.abortStatus.finished) {
          if (remainingData) {
            chunkedDataBuffer = remainingData.data;
          } else {
            chunkedDataBuffer = null;
          }
          readObj = await reader.read();
        }
      }
    } catch (err) {
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


    if (_dbg) {
      try {
        console.log('[SABR_DBG] RESP', JSON.stringify({
          sq: operationInputs.sequenceNumber,
          isInit: operationInputs.isInit,
          mediaBytes: responseDataChunks.reduce(function (n, c) { return n + (c.length || c.byteLength || 0); }, 0),
          segmentComplete: segmentComplete,
          shouldRetry: shouldRetry,
          retryNextPolicy: shouldRetryDueToNextRequestPolicy,
          invalidPoToken: invalidPoToken,
          backoffMs: currentState.sabrStreamState.nextRequestPolicy ? currentState.sabrStreamState.nextRequestPolicy.backoffTimeMs : undefined,
          reload: currentState.sabrStreamState.playerReloadRequested,
          error: error,
          httpStatus: response ? response.status : undefined,
          headersSeen: _dbgHeaders,
          partTypes: _dbgPartTypes,
          CTX_UPDATE_ID: UMPPartId.SABR_CONTEXT_UPDATE,
          CTX_SENDING_ID: UMPPartId.SABR_CONTEXT_SENDING_POLICY
        }));
      } catch (e) {}
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
        try {
          freshPoToken = currentState.mintPoToken ? await currentState.mintPoToken() : null;
        } catch (e) {
          console.warn('[SabrScheme] PO token re-mint failed', e);
        }
        if (freshPoToken) {
          currentState.abrRequest.streamerContext.poToken = utils.base64ToU8(freshPoToken);
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
    var PlaybackCookie = protos.PlaybackCookie;
    var EventEmitterLike = utils.EventEmitterLike;

    var eventEmitter = new EventEmitterLike();
    var initDataCache = new Map();

    var poToken = base64ToU8(sabrData.poToken);
    var videoPlaybackUstreamerConfig = base64ToU8(sabrData.ustreamerConfig);
    var clientInfo = deepCopy(sabrData.clientInfo);

    var sabrStreamState = {
      sabrUrl: sabrData.url,
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

      if (streamIsAudio) {
        audioFormatId = formatIdFromString(formatIdString);
        if (isAudioOnly) {
          videoFormatId = formatIdFromString(url.searchParams.get('videoFormatId'));
        } else {
          videoFormatId = formatIdFromString((activeVariant || variantTracks[0]).originalVideoId);
        }
      } else if (streamIsVideo) {
        videoFormatId = formatIdFromString(formatIdString);
        if (activeVariant) {
          audioFormatId = formatIdFromString(activeVariant.originalAudioId);
        } else {
          var candidates = variantTracks.filter(function (track) {
            return track.audioRoles.indexOf('main') !== -1;
          });
          var probableAudioFormat = candidates.reduce(function (previous, current) {
            return current.audioBandwidth >= previous.audioBandwidth ? current : previous;
          }, candidates[0]);
          audioFormatId = formatIdFromString(probableAudioFormat.originalAudioId);
        }
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
      var enableVoiceBoost = url.searchParams.has('vb') || !!(activeVariant && activeVariant.audioRoles.indexOf('vb') !== -1);
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
        preferredAudioFormatIds: [audioFormatId],
        preferredVideoFormatIds: [videoFormatId],
        preferredSubtitleFormatIds: [],
        selectedFormatIds: isInit ? [] : [audioFormatId, videoFormatId],
        bufferedRanges: bufferedRanges,
        streamerContext: {
          poToken: poToken,
          clientInfo: clientInfo,
          sabrContexts: prepared.sabrContexts,
          unsentSabrContexts: prepared.unsentSabrContexts,
          playbackCookie: sabrStreamState.nextRequestPolicy?.playbackCookie ? PlaybackCookie.encode(sabrStreamState.nextRequestPolicy.playbackCookie).finish() : undefined
        },
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