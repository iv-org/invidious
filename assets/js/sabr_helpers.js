/**
 * SABR Helpers - Utility functions for SABR streaming
 * Ported from Kira project (https://github.com/LuanRT/kira)
 */

'use strict';

window.SABRHelpers = (function () {
    // Proxy configuration - uses Invidious proxy endpoint
    var SABR_PROXY_PROTOCOL = window.location.protocol.replace(':', '');
    var SABR_PROXY_HOST = window.location.hostname;
    var SABR_PROXY_PORT = window.location.port || (SABR_PROXY_PROTOCOL === 'https' ? '443' : '80');

    var REDIRECTOR_STORAGE_KEY = 'googlevideo_redirector';
    var CLIENT_CONFIG_STORAGE_KEY = 'yt_client_config';

    // Query parameters the /proxy route reserves for itself.
    var RESERVED_PROXY_PARAMS = ['__host', '__path', '__headers'];

    // User-Agent sent to YouTube for every proxied request (the same one the
    // Invidious backend uses, rendered by the server in player.ecr). It is put
    // in __headers for the proxy, and on the fetch itself too (only Firefox
    // honours a custom User-Agent on fetch; Chrome silently keeps its own).
    // A client-specific User-Agent set by youtubei.js (e.g. VISIONOS) is kept.
    var FALLBACK_USER_AGENT = 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/149.0.0.0 Safari/537.36';

    function getUserAgent() {
        var container = document.getElementById('sabr-player-container');
        return (container && container.dataset.userAgent) || FALLBACK_USER_AGENT;
    }

    // Returns a copy of `headers` (Headers or plain object) with a User-Agent.
    function withUserAgent(headers) {
        var result = new Headers(headers || undefined);
        if (!result.has('user-agent')) result.set('user-agent', getUserAgent());
        return result;
    }

    /**
     * Get proxy configuration
     */
    function getProxyConfig() {
        return {
            PROXY_PROTOCOL: SABR_PROXY_PROTOCOL,
            PROXY_HOST: SABR_PROXY_HOST,
            PROXY_PORT: SABR_PROXY_PORT
        };
    }

    /**
     * Encrypt a request using AES-CTR and HMAC-SHA256
     * @param {Uint8Array} clientKey - 32-byte client key
     * @param {Uint8Array} data - Data to encrypt
     * @returns {Promise<{encrypted: Uint8Array, hmac: Uint8Array, iv: Uint8Array}>}
     */
    async function encryptRequest(clientKey, data) {
        if (clientKey.length !== 32)
            throw new Error('Invalid client key length');

        var aesKeyData = clientKey.slice(0, 16);
        var hmacKeyData = clientKey.slice(16, 32);

        var iv = window.crypto.getRandomValues(new Uint8Array(16));

        var aesKey = await window.crypto.subtle.importKey(
            'raw',
            aesKeyData,
            { name: 'AES-CTR', length: 128 },
            false,
            ['encrypt']
        );

        var encrypted = new Uint8Array(await window.crypto.subtle.encrypt(
            { name: 'AES-CTR', counter: iv, length: 128 },
            aesKey,
            data
        ));

        var hmacKey = await window.crypto.subtle.importKey(
            'raw',
            hmacKeyData,
            { name: 'HMAC', hash: { name: 'SHA-256' } },
            false,
            ['sign']
        );

        // Concatenate encrypted and iv for HMAC
        var dataToSign = new Uint8Array(encrypted.length + iv.length);
        dataToSign.set(encrypted, 0);
        dataToSign.set(iv, encrypted.length);

        var hmac = new Uint8Array(await window.crypto.subtle.sign(
            'HMAC',
            hmacKey,
            dataToSign
        ));

        return { encrypted: encrypted, hmac: hmac, iv: iv };
    }

    /**
     * Decrypt an (optionally) encrypted Onesie response with AES-CTR and verify
     * its HMAC-SHA256. Mirrors googlevideo/examples/onesie-request/utils.ts.
     * @param {Uint8Array} iv
     * @param {Uint8Array} hmac
     * @param {Uint8Array} data
     * @param {Uint8Array} clientKeyData - 32-byte client key (16B AES + 16B HMAC)
     * @returns {Promise<Uint8Array>}
     */
    async function decryptResponse(iv, hmac, data, clientKeyData) {
        if (!iv || !hmac || !data || !clientKeyData) {
            throw new Error('Invalid input to decryptResponse');
        }

        var aesKey = await window.crypto.subtle.importKey(
            'raw',
            clientKeyData.slice(0, 16),
            { name: 'AES-CTR', length: 128 },
            false,
            ['decrypt']
        );

        var decryptedData = new Uint8Array(await window.crypto.subtle.decrypt(
            { name: 'AES-CTR', counter: iv, length: 128 },
            aesKey,
            data
        ));

        var hmacKey = await window.crypto.subtle.importKey(
            'raw',
            clientKeyData.slice(16, 32),
            { name: 'HMAC', hash: { name: 'SHA-256' } },
            false,
            ['verify']
        );

        var dataToVerify = new Uint8Array(data.length + iv.length);
        dataToVerify.set(data, 0);
        dataToVerify.set(iv, data.length);

        var isValid = await window.crypto.subtle.verify('HMAC', hmacKey, hmac, dataToVerify);
        if (!isValid) {
            throw new Error('HMAC verification failed');
        }

        return decryptedData;
    }

    /**
     * Check if Onesie client config is still valid
     * @param {Object} config - Client config object
     * @returns {boolean}
     */
    function isConfigValid(config) {
        if (!config.timestamp || !config.keyExpiresInSeconds) {
            return false;
        }

        var currentTime = Date.now();
        var expirationTime = config.timestamp + (config.keyExpiresInSeconds * 1000);
        return currentTime < expirationTime;
    }

    /**
     * Load cached client config from localStorage
     * @returns {Object|null}
     */
    function loadCachedClientConfig() {
        try {
            var cachedData = localStorage.getItem(CLIENT_CONFIG_STORAGE_KEY);
            if (!cachedData) return null;

            var parsed = JSON.parse(cachedData);

            if (!isConfigValid(parsed)) {
                localStorage.removeItem(CLIENT_CONFIG_STORAGE_KEY);
                return null;
            }

            return {
                clientKeyData: new Uint8Array(Object.values(parsed.clientKeyData)),
                encryptedClientKey: new Uint8Array(Object.values(parsed.encryptedClientKey)),
                onesieUstreamerConfig: new Uint8Array(Object.values(parsed.onesieUstreamerConfig)),
                baseUrl: parsed.baseUrl,
                keyExpiresInSeconds: parsed.keyExpiresInSeconds,
                timestamp: parsed.timestamp
            };
        } catch (error) {
            console.error('[SABR]', 'Failed to load cached client config', error);
            localStorage.removeItem(CLIENT_CONFIG_STORAGE_KEY);
            return null;
        }
    }

    /**
     * Save client config to localStorage
     * @param {Object} config - Client config to save
     */
    function saveCachedClientConfig(config) {
        try {
            config.timestamp = Date.now();
            localStorage.setItem(CLIENT_CONFIG_STORAGE_KEY, JSON.stringify({
                clientKeyData: Array.from(config.clientKeyData),
                encryptedClientKey: Array.from(config.encryptedClientKey),
                onesieUstreamerConfig: Array.from(config.onesieUstreamerConfig),
                baseUrl: config.baseUrl,
                keyExpiresInSeconds: config.keyExpiresInSeconds,
                timestamp: config.timestamp
            }));
        } catch (error) {
            console.error('[SABR]', 'Failed to save client config', error);
        }
    }

    /**
     * Convert object to Map
     * @param {Object} object
     * @returns {Map}
     */
    function asMap(object) {
        var map = new Map();
        for (var key of Object.keys(object)) {
            map.set(key, object[key]);
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
     * @param {Object} headers - Response headers
     * @param {BufferSource} data - Response data
     * @param {number} status - HTTP status code
     * @param {string} uri - Original URI
     * @param {string} responseURL - Final response URL
     * @param {Object} request - Original request
     * @param {number} requestType - Request type
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
     * @param {string} message - Error message
     * @param {Object} info - Additional info
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
     * Rewrite a URL so it goes through the Invidious /proxy route. This is the
     * single implementation of the proxy URL contract:
     *   https://host/path?q  ->  /proxy/path?q&__host=host[&__headers=[[name,value],...]]
     * @param {string|URL} url - URL to proxy
     * @param {Headers|Object} [headers] - Headers the proxy should send upstream
     * @returns {URL}
     */
    function proxyUrl(url, headers) {
        var config = getProxyConfig();
        var urlObj = new URL(url.toString());
        var newUrl = new URL(urlObj.toString());

        // Never let the upstream query override the proxy's own parameters.
        RESERVED_PROXY_PARAMS.forEach(function (name) { newUrl.searchParams.delete(name); });

        var headersArray = [];
        withUserAgent(headers).forEach(function (value, key) {
            headersArray.push([key, value]);
        });
        newUrl.searchParams.set('__headers', JSON.stringify(headersArray));

        newUrl.searchParams.set('__host', urlObj.host);
        newUrl.host = config.PROXY_HOST;
        newUrl.port = config.PROXY_PORT;
        newUrl.protocol = config.PROXY_PROTOCOL + ':';
        newUrl.pathname = '/proxy' + urlObj.pathname;

        return newUrl;
    }

    /**
     * Fetch through proxy. The request headers, including the forced User-Agent, are
     * serialized into __headers for the proxy to send upstream.
     * @param {string|URL|Request} input - URL to fetch
     * @param {RequestInit} init - Fetch init options
     * @returns {Promise<Response>}
     */
    async function fetchWithProxy(input, init) {
        var url = typeof input === 'string' ? new URL(input) : (input instanceof URL ? input : new URL(input.url));
        var headers = withUserAgent(init?.headers || (input instanceof Request ? input.headers : undefined));
        var requestInit = Object.assign({}, init, { headers: headers });

        var newUrl = proxyUrl(url, headers);
        var request = new Request(newUrl, input instanceof Request ? input : undefined);

        return fetch(request, requestInit);
    }

    /**
     * Check if URL is a Google Video / YouTube URL (suffix-anchored host match).
     * @param {string|URL} url
     * @returns {boolean}
     */
    function isGoogleVideoURL(url) {
        try {
            var hostname = new URL(url.toString()).hostname;
            return hostname === 'googlevideo.com' || hostname.endsWith('.googlevideo.com') ||
                   hostname === 'youtube.com' || hostname.endsWith('.youtube.com');
        } catch (e) {
            return false;
        }
    }

    /**
     * Generate a random string
     * @param {number} length
     * @returns {string}
     */
    function generateRandomString(length) {
        var chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
        var result = '';
        for (var i = 0; i < length; i++) {
            result += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return result;
    }

    // Export for use in other modules
    return {
        getProxyConfig: getProxyConfig,
        encryptRequest: encryptRequest,
        decryptResponse: decryptResponse,
        isConfigValid: isConfigValid,
        loadCachedClientConfig: loadCachedClientConfig,
        saveCachedClientConfig: saveCachedClientConfig,
        asMap: asMap,
        headersToGenericObject: headersToGenericObject,
        makeResponse: makeResponse,
        createRecoverableError: createRecoverableError,
        proxyUrl: proxyUrl,
        fetchWithProxy: fetchWithProxy,
        isGoogleVideoURL: isGoogleVideoURL,
        generateRandomString: generateRandomString,
        REDIRECTOR_STORAGE_KEY: REDIRECTOR_STORAGE_KEY,
        CLIENT_CONFIG_STORAGE_KEY: CLIENT_CONFIG_STORAGE_KEY
    };
})();
