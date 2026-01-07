/**
 * SABR Helpers - Utility functions for SABR streaming
 * Ported from Kira project (https://github.com/LuanRT/kira)
 */

'use strict';

// Proxy configuration - uses Invidious proxy endpoint
var SABR_PROXY_PROTOCOL = window.location.protocol.replace(':', '');
var SABR_PROXY_HOST = window.location.hostname;
var SABR_PROXY_PORT = window.location.port || (SABR_PROXY_PROTOCOL === 'https' ? '443' : '80');

var REDIRECTOR_STORAGE_KEY = 'googlevideo_redirector';
var CLIENT_CONFIG_STORAGE_KEY = 'yt_client_config';

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
 * Proxy a URL through Invidious proxy
 * @param {string|URL} url - URL to proxy
 * @param {Headers|Object} headers - Additional headers
 * @returns {URL}
 */
function proxyUrl(url, headers) {
    var config = getProxyConfig();
    var urlObj = typeof url === 'string' ? new URL(url) : new URL(url.toString());
    var newUrl = new URL(urlObj.toString());
    
    if (headers) {
        var headersArray = [];
        if (headers instanceof Headers) {
            headers.forEach(function(value, key) {
                headersArray.push([key, value]);
            });
        } else {
            for (var key in headers) {
                headersArray.push([key, headers[key]]);
            }
        }
        newUrl.searchParams.set('__headers', JSON.stringify(headersArray));
    }
    
    newUrl.searchParams.set('__host', urlObj.host);
    newUrl.host = config.PROXY_HOST;
    newUrl.port = config.PROXY_PORT;
    newUrl.protocol = config.PROXY_PROTOCOL + ':';
    newUrl.pathname = '/proxy' + urlObj.pathname;
    
    return newUrl;
}

/**
 * Fetch through proxy
 * @param {string|URL} input - URL to fetch
 * @param {RequestInit} init - Fetch init options
 * @returns {Promise<Response>}
 */
async function fetchWithProxy(input, init) {
    var url = typeof input === 'string' ? new URL(input) : (input instanceof URL ? input : new URL(input.url));
    var headers = new Headers(init?.headers || (input instanceof Request ? input.headers : undefined));
    var requestInit = Object.assign({}, init, { headers: headers });

    var config = getProxyConfig();

    var newUrl = new URL(url.toString());
    newUrl.searchParams.set('__headers', JSON.stringify(Array.from(headers.entries())));
    newUrl.searchParams.set('__host', url.host);
    newUrl.host = config.PROXY_HOST;
    newUrl.port = config.PROXY_PORT;
    newUrl.protocol = config.PROXY_PROTOCOL + ':';
    newUrl.pathname = '/proxy' + url.pathname;

    var request = new Request(newUrl, input instanceof Request ? input : undefined);
    headers.delete('user-agent');

    return fetch(request, requestInit);
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
window.SABRHelpers = {
    getProxyConfig: getProxyConfig,
    encryptRequest: encryptRequest,
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
