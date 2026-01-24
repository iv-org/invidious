/**
 * SABR Shaka Player Adapter
 * Ported from Kira project (https://github.com/LuanRT/kira)
 * 
 * This module provides the ShakaPlayerAdapter class that implements
 * the SabrPlayerAdapter interface for use with the SABR streaming adapter.
 */

'use strict';

var ShakaPlayerAdapter = (function() {
    /**
     * Convert object to Map
     * @param {Object} object
     * @returns {Map}
     */
    function asMap(object) {
        var map = new Map();
        for (var key in object) {
            if (Object.prototype.hasOwnProperty.call(object, key)) {
                map.set(key, object[key]);
            }
        }
        return map;
    }

    /**
     * Convert Headers to plain object
     * @param {Headers} headers
     * @returns {Object}
     */
    function headersToGenericObject(headers) {
        var headersObj = {};
        headers.forEach(function(value, key) {
            headersObj[key.trim()] = value;
        });
        return headersObj;
    }

    /**
     * Create a Shaka response object
     * @param {Object} headers
     * @param {BufferSource} data
     * @param {number} status
     * @param {string} uri
     * @param {string} responseURL
     * @param {Object} request
     * @param {number} requestType
     * @returns {Object}
     */
    function makeResponse(headers, data, status, uri, responseURL, request, requestType) {
        if (status >= 200 && status <= 299 && status !== 202) {
            return {
                uri: responseURL || uri,
                originalUri: uri,
                data: data,
                status: status,
                headers: headers,
                originalRequest: request,
                fromCache: !!headers['x-shaka-from-cache']
            };
        }

        var responseText = null;
        try {
            responseText = shaka.util.StringUtils.fromBytesAutoDetect(data);
        } catch (e) { /* no-op */ }

        var severity = (status === 401 || status === 403)
            ? shaka.util.Error.Severity.CRITICAL
            : shaka.util.Error.Severity.RECOVERABLE;

        throw new shaka.util.Error(
            severity,
            shaka.util.Error.Category.NETWORK,
            shaka.util.Error.Code.BAD_HTTP_STATUS,
            uri,
            status,
            responseText,
            headers,
            requestType,
            responseURL || uri
        );
    }

    /**
     * Create a recoverable Shaka error
     * @param {string} message
     * @param {Object} info
     * @returns {shaka.util.Error}
     */
    function createRecoverableError(message, info) {
        return new shaka.util.Error(
            shaka.util.Error.Severity.RECOVERABLE,
            shaka.util.Error.Category.NETWORK,
            shaka.util.Error.Code.HTTP_ERROR,
            message,
            { info: info }
        );
    }

    /**
     * Check if URL is a Google Video URL
     * @param {string} url
     * @returns {boolean}
     */
    function isGoogleVideoURL(url) {
        try {
            var urlObj = new URL(url);
            return urlObj.hostname.endsWith('.googlevideo.com') || 
                   urlObj.hostname.endsWith('.youtube.com') ||
                   urlObj.hostname.includes('googlevideo');
        } catch (e) {
            return false;
        }
    }

    /**
     * ShakaPlayerAdapter class implementing SabrPlayerAdapter interface
     */
    function ShakaPlayerAdapter() {
        this.player = null;
        this.requestMetadataManager = null;
        this.cacheManager = null;
        this.abortController = null;
        this.requestFilter = null;
        this.responseFilter = null;
    }

    /**
     * Initialize the adapter with a Shaka player instance
     * @param {shaka.Player} player
     * @param {RequestMetadataManager} requestMetadataManager
     * @param {CacheManager} cacheManager
     */
    ShakaPlayerAdapter.prototype.initialize = function(player, requestMetadataManager, cacheManager) {
        console.log('[ShakaPlayerAdapter] initialize() called', { player: !!player, requestMetadataManager: !!requestMetadataManager, cacheManager: !!cacheManager });
        var self = this;
        this.player = player;
        this.requestMetadataManager = requestMetadataManager;
        this.cacheManager = cacheManager;

        var networkingEngine = shaka.net.NetworkingEngine;
        var schemes = ['http', 'https'];
        console.log('[ShakaPlayerAdapter] Registering schemes:', schemes);

        if (!shaka.net.HttpFetchPlugin.isSupported()) {
            throw new Error('The Fetch API is not supported in this browser.');
        }

        schemes.forEach(function(scheme) {
            console.log('[ShakaPlayerAdapter] Registering scheme:', scheme);
            networkingEngine.registerScheme(
                scheme, 
                self.parseRequest.bind(self),
                networkingEngine.PluginPriority.PREFERRED
            );
        });
        console.log('[ShakaPlayerAdapter] Initialization complete');
    };

    /**
     * Parse and handle a network request
     */
    ShakaPlayerAdapter.prototype.parseRequest = function(
        uri, request, requestType, progressUpdated, headersReceived, config
    ) {
        var self = this;
        var headers = new Headers();
        asMap(request.headers).forEach(function(value, key) {
            headers.append(key, value);
        });

        var controller = new AbortController();
        this.abortController = controller;

        var init = {
            body: request.body || undefined,
            headers: headers,
            method: request.method,
            signal: this.abortController.signal,
            credentials: request.allowCrossSiteCredentials ? 'include' : undefined
        };

        var abortStatus = { canceled: false, timedOut: false };
        var minBytes = config.minBytesForProgressEvents || 0;

        var pendingRequest = this.doRequest(
            uri, request, requestType, init, controller, 
            abortStatus, progressUpdated, headersReceived, minBytes
        );

        var operation = new shaka.util.AbortableOperation(
            pendingRequest,
            function() {
                abortStatus.canceled = true;
                controller.abort();
                return Promise.resolve();
            }
        );

        var timeoutMs = request.retryParameters.timeout;
        if (timeoutMs) {
            var timer = new shaka.util.Timer(function() {
                abortStatus.timedOut = true;
                controller.abort();
                console.warn('[ShakaPlayerAdapter]', 'Request aborted due to timeout:', uri, requestType);
            });
            timer.tickAfter(timeoutMs / 1000);
            operation.finally(function() { timer.stop(); });
        }

        return operation;
    };

    /**
     * Handle cached request
     */
    ShakaPlayerAdapter.prototype.handleCachedRequest = async function(
        requestMetadata, uri, request, progressUpdated, headersReceived, requestType
    ) {
        if (!requestMetadata.byteRange || !this.cacheManager) {
            return null;
        }

        // Check if FormatKeyUtils is available
        if (typeof FormatKeyUtils === 'undefined' || !FormatKeyUtils.createSegmentCacheKeyFromMetadata) {
            return null;
        }

        var segmentKey = FormatKeyUtils.createSegmentCacheKeyFromMetadata(requestMetadata);

        var arrayBuffer = requestMetadata.isInit 
            ? this.cacheManager.getInitSegment(segmentKey)?.buffer
            : this.cacheManager.getSegment(segmentKey)?.buffer;

        if (!arrayBuffer) {
            return null;
        }

        if (requestMetadata.isInit) {
            arrayBuffer = arrayBuffer.slice(
                requestMetadata.byteRange.start,
                requestMetadata.byteRange.end + 1
            );
        }

        var headers = {
            'content-type': requestMetadata.format?.mimeType?.split(';')[0] || '',
            'content-length': arrayBuffer.byteLength.toString(),
            'x-shaka-from-cache': 'true'
        };

        headersReceived(headers);
        progressUpdated(0, arrayBuffer.byteLength, 0);

        return makeResponse(headers, arrayBuffer, 200, uri, uri, request, requestType);
    };

    /**
     * Handle UMP response (SABR streaming format)
     */
    ShakaPlayerAdapter.prototype.handleUmpResponse = async function(
        response, requestMetadata, uri, request, requestType,
        progressUpdated, abortController, minBytes
    ) {
        var self = this;
        var lastTime = Date.now();

        // Check if SabrUmpProcessor is available
        if (typeof SabrUmpProcessor === 'undefined') {
            console.warn('[ShakaPlayerAdapter]', 'SabrUmpProcessor not available, falling back to normal handling');
            var arrayBuffer = await response.arrayBuffer();
            return this.createShakaResponse({ uri: uri, request: request, requestType: requestType, response: response, arrayBuffer: arrayBuffer });
        }

        var sabrUmpReader = new SabrUmpProcessor(requestMetadata, this.cacheManager);

        function checkResultIntegrity(result) {
            if (!result.data && ((!!requestMetadata.error || requestMetadata.streamInfo?.streamProtectionStatus?.status === 3) && !requestMetadata.streamInfo?.sabrContextUpdate)) {
                throw createRecoverableError('Server streaming error', requestMetadata);
            }
        }

        function shouldReturnEmptyResponse() {
            return requestMetadata.isSABR && (requestMetadata.streamInfo?.redirect || requestMetadata.streamInfo?.sabrContextUpdate);
        }

        // If response body is not a ReadableStream, handle whole response
        if (!response.body) {
            var arrayBuffer = await response.arrayBuffer();
            var currentTime = Date.now();

            progressUpdated(currentTime - lastTime, arrayBuffer.byteLength, 0);

            var result = await sabrUmpReader.processChunk(new Uint8Array(arrayBuffer));

            if (result) {
                checkResultIntegrity(result);
                return this.createShakaResponse({ uri: uri, request: request, requestType: requestType, response: response, arrayBuffer: result.data });
            }

            if (shouldReturnEmptyResponse()) {
                return this.createShakaResponse({ uri: uri, request: request, requestType: requestType, response: response, arrayBuffer: undefined });
            }

            throw createRecoverableError('Empty response with no redirect information', requestMetadata);
        }

        // Stream processing with ReadableStream
        var reader = response.body.getReader();
        var loaded = 0;
        var lastLoaded = 0;
        var contentLength;

        while (!abortController.signal.aborted) {
            var readObj;
            try {
                readObj = await reader.read();
            } catch (e) {
                break;
            }

            var value = readObj.value;
            var done = readObj.done;

            if (done) {
                if (shouldReturnEmptyResponse()) {
                    return this.createShakaResponse({ uri: uri, request: request, requestType: requestType, response: response, arrayBuffer: undefined });
                }
                throw createRecoverableError('Empty response with no redirect information', requestMetadata);
            }

            var result = await sabrUmpReader.processChunk(value);
            var segmentInfo = sabrUmpReader.getSegmentInfo();

            if (segmentInfo) {
                if (!contentLength) {
                    contentLength = segmentInfo.mediaHeader.contentLength;
                }
                loaded += segmentInfo.lastChunkSize || 0;
                segmentInfo.lastChunkSize = 0;
            }

            var currentTime = Date.now();
            var chunkSize = loaded - lastLoaded;

            if ((currentTime - lastTime > 100 && chunkSize >= minBytes) || result) {
                if (result) checkResultIntegrity(result);
                if (contentLength) {
                    var numBytesRemaining = result ? 0 : parseInt(contentLength) - loaded;
                    try {
                        progressUpdated(currentTime - lastTime, chunkSize, numBytesRemaining);
                    } catch (e) { /* no-op */ }
                    finally {
                        lastLoaded = loaded;
                        lastTime = currentTime;
                    }
                }
            }

            if (result) {
                abortController.abort();
                return this.createShakaResponse({ uri: uri, request: request, requestType: requestType, response: response, arrayBuffer: result.data });
            }
        }

        throw createRecoverableError('UMP stream processing was aborted but did not produce a result.', requestMetadata);
    };

    /**
     * Perform the network request
     */
    ShakaPlayerAdapter.prototype.doRequest = async function(
        uri, request, requestType, init, abortController,
        abortStatus, progressUpdated, headersReceived, minBytes
    ) {
        var self = this;

        try {
            console.log('[ShakaPlayerAdapter] doRequest called:', { uri: uri, requestType: requestType });
            
            // Convert sabr:// URLs to HTTP URLs before processing
            if (uri.startsWith('sabr://')) {
                // sabr:// URLs should have been converted by the request interceptor
                // If we reach here, the interceptor wasn't set up properly
                console.error('[ShakaPlayerAdapter] *** sabr:// URL reached doRequest without being converted:', uri);
                console.error('[ShakaPlayerAdapter] This means the request interceptor is not working!');
                // Try to handle it anyway - this shouldn't normally happen
                return makeResponse({}, new ArrayBuffer(0), 200, uri, uri, request, requestType);
            }

            var requestMetadata = this.requestMetadataManager?.getRequestMetadata(uri);

            // Check cache first
            if (requestMetadata) {
                var cachedResponse = await this.handleCachedRequest(
                    requestMetadata, uri, request, progressUpdated, headersReceived, requestType
                );
                if (cachedResponse) {
                    return cachedResponse;
                }
            }

            // Proxy Google Video URLs
            var fetchUrl = uri;
            if (isGoogleVideoURL(uri)) {
                // Ensure required headers are present for googlevideo requests
                var headersForProxy = init.headers;
                
                // Debug: log initial headers
                console.log('[ShakaPlayerAdapter] Initial init.headers:', init.headers ? 'exists' : 'null', 
                    'method:', init.method);
                if (init.headers) {
                    var initHeadersDebug = [];
                    init.headers.forEach(function(v, k) { initHeadersDebug.push(k); });
                    console.log('[ShakaPlayerAdapter] Init headers keys:', initHeadersDebug);
                }
                
                // For SABR requests (POST to videoplayback), ensure we have proper headers
                if (!headersForProxy || headersForProxy.entries().next().done) {
                    headersForProxy = new Headers();
                }
                
                // Always add User-Agent for googlevideo requests to avoid 403
                // Use the browser's actual User-Agent
                if (!headersForProxy.has('user-agent')) {
                    headersForProxy.set('user-agent', navigator.userAgent);
                }
                
                // For POST requests (SABR), add additional required headers
                if (init.method === 'POST') {
                    console.log('[ShakaPlayerAdapter] POST request detected, adding content-type header');
                    headersForProxy.set('content-type', 'application/x-protobuf');
                    if (!headersForProxy.has('origin')) {
                        headersForProxy.set('origin', 'https://www.youtube.com');
                    }
                    if (!headersForProxy.has('referer')) {
                        headersForProxy.set('referer', 'https://www.youtube.com/');
                    }
                }
                
                // Debug: log the headers being sent
                var debugHeaders = [];
                headersForProxy.forEach(function(v, k) { debugHeaders.push([k, v.substring(0, 50)]); });
                console.log('[ShakaPlayerAdapter] Headers for proxy:', debugHeaders);
                
                fetchUrl = SABRHelpers.proxyUrl(uri, headersForProxy).toString();
                // Set Content-Type on the fetch request for POST (needed for the proxy to know the body type)
                // Other headers are passed via __headers param and will be forwarded by the proxy
                init.headers = new Headers();
                if (init.method === 'POST') {
                    init.headers.set('Content-Type', 'application/x-protobuf');
                }
            }

            var response = await fetch(fetchUrl, init);
            
            // Debug log for POST requests
            if (init.method === 'POST' && init.body) {
                var bodySize = init.body instanceof ArrayBuffer ? init.body.byteLength : 
                               (init.body instanceof Uint8Array ? init.body.byteLength : 0);
                console.log('[ShakaPlayerAdapter] POST request sent:', { 
                    url: fetchUrl.substring(0, 100) + '...', 
                    bodySize: bodySize + ' bytes',
                    status: response.status
                });
            }
            
            headersReceived(headersToGenericObject(response.headers));

            // Handle UMP response
            if (requestMetadata && init.method !== 'HEAD' && response.headers.get('content-type') === 'application/vnd.yt-ump') {
                return this.handleUmpResponse(
                    response, requestMetadata, uri, request, requestType,
                    progressUpdated, abortController, minBytes
                );
            }

            // Handle normal response
            var lastTime = Date.now();
            var arrayBuffer = await response.arrayBuffer();
            var currentTime = Date.now();

            progressUpdated(currentTime - lastTime, arrayBuffer.byteLength, 0);

            return this.createShakaResponse({
                uri: uri,
                request: request,
                requestType: requestType,
                response: response,
                arrayBuffer: arrayBuffer
            });
        } catch (error) {
            if (abortStatus.canceled) {
                throw new shaka.util.Error(
                    shaka.util.Error.Severity.RECOVERABLE,
                    shaka.util.Error.Category.NETWORK,
                    shaka.util.Error.Code.OPERATION_ABORTED,
                    uri, requestType
                );
            } else if (abortStatus.timedOut) {
                throw new shaka.util.Error(
                    shaka.util.Error.Severity.RECOVERABLE,
                    shaka.util.Error.Category.NETWORK,
                    shaka.util.Error.Code.TIMEOUT,
                    uri, requestType
                );
            }
            throw new shaka.util.Error(
                shaka.util.Error.Severity.RECOVERABLE,
                shaka.util.Error.Category.NETWORK,
                shaka.util.Error.Code.HTTP_ERROR,
                uri, error, requestType
            );
        }
    };

    /**
     * Check that player is initialized
     */
    ShakaPlayerAdapter.prototype.checkPlayerStatus = function() {
        if (!this.player) {
            throw new Error('Player not initialized');
        }
    };

    /**
     * Get current playback time
     */
    ShakaPlayerAdapter.prototype.getPlayerTime = function() {
        this.checkPlayerStatus();
        var mediaElement = this.player.getMediaElement();
        return mediaElement ? mediaElement.currentTime : 0;
    };

    /**
     * Get current playback rate
     */
    ShakaPlayerAdapter.prototype.getPlaybackRate = function() {
        this.checkPlayerStatus();
        return this.player.getPlaybackRate();
    };

    /**
     * Get bandwidth estimate
     */
    ShakaPlayerAdapter.prototype.getBandwidthEstimate = function() {
        this.checkPlayerStatus();
        return this.player.getStats().estimatedBandwidth;
    };

    /**
     * Get active track formats
     */
    ShakaPlayerAdapter.prototype.getActiveTrackFormats = function(activeFormat, sabrFormats) {
        this.checkPlayerStatus();

        // Check if FormatKeyUtils is available
        if (typeof FormatKeyUtils === 'undefined' || !FormatKeyUtils.getUniqueFormatId) {
            return { videoFormat: undefined, audioFormat: undefined };
        }

        var activeVariant = this.player.getVariantTracks().find(function(track) {
            return FormatKeyUtils.getUniqueFormatId(activeFormat) === (activeFormat.width ? track.originalVideoId : track.originalAudioId);
        });

        if (!activeVariant) {
            return { videoFormat: undefined, audioFormat: undefined };
        }

        var formatMap = new Map(sabrFormats.map(function(format) {
            return [FormatKeyUtils.getUniqueFormatId(format), format];
        }));

        return {
            videoFormat: activeVariant.originalVideoId ? formatMap.get(activeVariant.originalVideoId) : undefined,
            audioFormat: activeVariant.originalAudioId ? formatMap.get(activeVariant.originalAudioId) : undefined
        };
    };

    /**
     * Register request interceptor
     */
    ShakaPlayerAdapter.prototype.registerRequestInterceptor = function(interceptor) {
        console.log('[ShakaPlayerAdapter] registerRequestInterceptor() called');
        var self = this;
        this.checkPlayerStatus();

        var networkingEngine = this.player.getNetworkingEngine();
        if (!networkingEngine) {
            console.warn('[ShakaPlayerAdapter] No networking engine available');
            return;
        }
        console.log('[ShakaPlayerAdapter] Got networking engine, registering filter');

        this.requestFilter = async function(type, request, context) {
            console.log('[ShakaPlayerAdapter] Request filter called:', { type: type, uri: request.uris[0] });
            
            // Check if this is a SEGMENT request that needs processing
            // Process sabr:// URLs (need conversion) and googlevideo URLs (already converted)
            var uri = request.uris[0];
            var isSabrUrl = uri.startsWith('sabr://');
            var isGoogleVideo = isGoogleVideoURL(uri);
            
            if (type !== shaka.net.NetworkingEngine.RequestType.SEGMENT || (!isSabrUrl && !isGoogleVideo)) {
                console.log('[ShakaPlayerAdapter] Skipping request (not segment or not sabr/googlevideo):', uri);
                return;
            }

            console.log('[ShakaPlayerAdapter] Calling interceptor for URL:', request.uris[0]);
            try {
                var modifiedRequest = await interceptor({
                    headers: request.headers,
                    url: request.uris[0],
                    method: request.method,
                    segment: {
                        getStartTime: function() { return context?.segment?.getStartTime() ?? null; },
                        isInit: function() { return !context?.segment; }
                    },
                    body: request.body
                });

                console.log('[ShakaPlayerAdapter] Interceptor returned:', modifiedRequest);

                if (modifiedRequest) {
                    console.log('[ShakaPlayerAdapter] Request modified:', { oldUrl: request.uris[0], newUrl: modifiedRequest.url });
                    request.uris = modifiedRequest.url ? [modifiedRequest.url] : request.uris;
                    request.method = modifiedRequest.method || request.method;
                    request.headers = modifiedRequest.headers || request.headers;
                    request.body = modifiedRequest.body || request.body;
                } else {
                    console.warn('[ShakaPlayerAdapter] Interceptor returned null/undefined for:', request.uris[0]);
                }
            } catch (error) {
                console.error('[ShakaPlayerAdapter] Interceptor error:', error);
                throw error;
            }
        };

        networkingEngine.registerRequestFilter(this.requestFilter);
        console.log('[ShakaPlayerAdapter] Request filter registered');
    };

    /**
     * Register response interceptor
     */
    ShakaPlayerAdapter.prototype.registerResponseInterceptor = function(interceptor) {
        var self = this;
        this.checkPlayerStatus();

        var networkingEngine = this.player.getNetworkingEngine();
        if (!networkingEngine) return;

        this.responseFilter = async function(type, response, context) {
            if (type !== shaka.net.NetworkingEngine.RequestType.SEGMENT || !isGoogleVideoURL(response.uri)) return;

            var modifiedResponse = await interceptor({
                url: response.originalRequest.uris[0],
                method: response.originalRequest.method,
                headers: response.headers,
                data: response.data,
                makeRequest: async function(url, headers) {
                    var retryParameters = self.player.getConfiguration().streaming.retryParameters;
                    var redirectRequest = shaka.net.NetworkingEngine.makeRequest([url], retryParameters);
                    Object.assign(redirectRequest.headers, headers);

                    var requestOperation = networkingEngine.request(type, redirectRequest, context);
                    var redirectResponse = await requestOperation.promise;

                    return {
                        url: redirectResponse.uri,
                        method: redirectResponse.originalRequest.method,
                        headers: redirectResponse.headers,
                        data: redirectResponse.data
                    };
                }
            });

            if (modifiedResponse) {
                response.data = modifiedResponse.data ?? response.data;
                Object.assign(response.headers, modifiedResponse.headers);
            }
        };

        networkingEngine.registerResponseFilter(this.responseFilter);
    };

    /**
     * Create a Shaka response object
     */
    ShakaPlayerAdapter.prototype.createShakaResponse = function(args) {
        return makeResponse(
            headersToGenericObject(args.response.headers),
            args.arrayBuffer || new ArrayBuffer(0),
            args.response.status,
            args.uri,
            args.response.url,
            args.request,
            args.requestType
        );
    };

    /**
     * Dispose of the adapter
     */
    ShakaPlayerAdapter.prototype.dispose = function() {
        if (this.abortController) {
            this.abortController.abort();
            this.abortController = null;
        }

        if (this.player) {
            var networkingEngine = this.player.getNetworkingEngine();

            if (networkingEngine) {
                if (this.requestFilter) {
                    networkingEngine.unregisterRequestFilter(this.requestFilter);
                }
                if (this.responseFilter) {
                    networkingEngine.unregisterResponseFilter(this.responseFilter);
                }
            }

            shaka.net.NetworkingEngine.unregisterScheme('http');
            shaka.net.NetworkingEngine.unregisterScheme('https');

            this.player = null;
        }
    };

    return ShakaPlayerAdapter;
})();

// Export for use
window.ShakaPlayerAdapter = ShakaPlayerAdapter;
