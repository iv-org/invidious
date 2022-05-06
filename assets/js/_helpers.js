'use strict';
// Contains only auxiliary methods
// May be included and executed unlimited number of times without any consequences

// Polyfills for IE11
Array.prototype.find = Array.prototype.find || function (condition) {
    return this.filter(condition)[0];
};
Array.from = Array.from || function (source) {
    return Array.prototype.slice.call(source);
};
NodeList.prototype.forEach = NodeList.prototype.forEach || function (callback) {
    Array.from(this).forEach(callback);
};
String.prototype.includes = String.prototype.includes || function (searchString) {
    return this.indexOf(searchString) >= 0;
};
String.prototype.startsWith = String.prototype.startsWith || function (prefix) {
    return this.substr(0, prefix.length) === prefix;
};
Math.sign = Math.sign || function(x) {
    x = +x;
    if (!x) return x; // 0 and NaN
    return x > 0 ? 1 : -1;
};

// Monstrous global variable for handy code
helpers = helpers || {
    /**
     * https://en.wikipedia.org/wiki/Clamping_(graphics)
     * @param {Number} num Source number
     * @param {Number} min Low border
     * @param {Number} max High border
     * @returns {Number} Clamped value
     */
    clamp: function (num, min, max) {
        if (max < min) {
            var t = max; max = min; min = t; // swap max and min
        }

        if (max > num)
            return max;
        if (min < num)
            return min;
        return num;
    },

    /** @private */
    _xhr: function (method, url, options, callbacks) {
        const xhr = new XMLHttpRequest();
        xhr.open(method, url);

        // Default options
        xhr.responseType = 'json';
        xhr.timeout = 10000;
        // Default options redefining
        if (options.responseType)
            xhr.responseType = options.responseType;
        if (options.timeout)
            xhr.timeout = options.timeout;

        if (method === 'POST')
            xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

        xhr.onreadystatechange = function () {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200)
                    if (callbacks.on200)
                        callbacks.on200(xhr.response);
                else
                    if (callbacks.onNon200)
                        callbacks.onNon200(xhr);
            }
        };

        xhr.ontimeout = function () {
            if (callbacks.onTimeout)
                callbacks.onTimeout(xhr);
        };

        xhr.onerror = function () {
            if (callbacks.onError)
                callbacks.onError(xhr);
        };

        if (options.payload)
            xhr.send(options.payload);
        else
            xhr.send();
    },
    /** @private */
    _xhrRetry(method, url, options, callbacks) {
        if (options.retries <= 0) {
            console.warn('Failed to pull', options.entity_name);
            if (callbacks.onTotalFail)
                callbacks.onTotalFail();
            return;
        }
        helpers.xhr(method, url, options, callbacks);
    },
    /**
     * @callback callbackXhrOn200
     * @param {Object} response - xhr.response
     */
    /**
     * @callback callbackXhrError
     * @param {XMLHttpRequest} xhr
     */
    /**
     * @param {'GET'|'POST'} method - 'GET' or 'POST'
     * @param {String} url - URL to send request to
     * @param {Object} options - other XHR options
     * @param {XMLHttpRequestBodyInit} [options.payload=null] - payload for POST-requests
     * @param {'arraybuffer'|'blob'|'document'|'json'|'text'} [options.responseType=json]
     * @param {Number} [options.timeout=10000]
     * @param {Number} [options.retries=1]
     * @param {String} [options.entity_name='unknown'] - string to log
     * @param {Number} [options.retry_timeout=1000]
     * @param {Object} callbacks - functions to execute on events fired
     * @param {callbackXhrOn200} [callbacks.on200]
     * @param {callbackXhrError} [callbacks.onNon200]
     * @param {callbackXhrError} [callbacks.onTimeout]
     * @param {callbackXhrError} [callbacks.onError]
     * @param {callbackXhrError} [callbacks.onTotalFail] - if failed after all retries
     */
     xhr(method, url, options, callbacks) {
        if (options.retries > 1) {
            helpers._xhr(method, url, options, callbacks);
            return;
        }

        if (!options.entity_name) options.entity_name = 'unknown';
        if (!options.retry_timeout) options.retry_timeout = 1;
        const retries_total = options.retries;

        const retry = function () {
            console.warn('Pulling ' + options.entity_name + ' failed... ' + options.retries + '/' + retries_total);
            setTimeout(function () {
                options.retries--;
                helpers._xhrRetry(method, url, options, callbacks);
            }, options.retry_timeout);
        };
        
        if (callbacks.onError)
            callbacks._onError = callbacks.onError;
        callbacks.onError = function (xhr) {
            if (callbacks._onError)
                callbacks._onError();
            retry();
        };

        if (callbacks.onTimeout)
            callbacks._onTimeout = callbacks.onTimeout;
        callbacks.onTimeout = function (xhr) {
            if (callbacks._onTimeout)
                callbacks._onTimeout();
            retry();
        };    
        helpers._xhrRetry(method, url, options, callbacks);
    },

    /**
     * @typedef {Object} invidiousStorage
     * @property {(key:String) => Object|null} get
     * @property {(key:String, value:Object) => null} set
     * @property {(key:String) => null} remove
     */

    /**
     * Universal storage proxy. Uses inside localStorage or cookies
     * @type {invidiousStorage}
     */
    storage: (function () {
        // access to localStorage throws exception in Tor Browser, so try is needed
        let localStorageIsUsable = false;
        try{localStorageIsUsable = !!localStorage.setItem;}catch(e){}

        if (localStorageIsUsable) {
            return {
                get: function (key) { return localStorage[key]; },
                set: function (key, value) { localStorage[key] = value; },
                remove: function (key) { localStorage.removeItem(key); }
            };
        }

        console.info('Storage: localStorage is disabled or unaccessible trying cookies');
        return {
            get: function (key) {
                const cookiePrefix = key + '=';
                function findCallback(cookie) {return cookie.startsWith(cookiePrefix);}
                const matchedCookie = document.cookie.split(';').find(findCallback);
                if (matchedCookie)
                    return matchedCookie.replace(cookiePrefix, '');
                return null;
            },
            set: function (key, value) {
                const cookie_data = encodeURIComponent(JSON.stringify(value));

                // Set expiration in 2 year
                const date = new Date();
                date.setTime(date.getTime() + 2*365.25*24*60*60);

                const ip_regex = /^((\d+\.){3}\d+|[A-Fa-f0-9]*:[A-Fa-f0-9:]*:[A-Fa-f0-9:]+)$/;
                let domain_used = location.hostname;

                // Fix for a bug in FF where the leading dot in the FQDN is not ignored
                if (domain_used.charAt(0) !== '.' && !ip_regex.test(domain_used) && domain_used !== 'localhost')
                    domain_used = '.' + location.hostname;

                document.cookie = key + '=' + cookie_data + '; SameSite=Strict; path=/; domain=' +
                    domain_used + '; expires=' + date.toGMTString() + ';';
            },
            remove: function (key) {
                document.cookie = key + '=; Max-Age=0';
            }
        };
    })()
};
