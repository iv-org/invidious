/**
 * BotGuard Service - PoToken generation for SABR streaming
 * Ported from Kira project (https://github.com/LuanRT/kira)
 * 
 * This module handles:
 * - BotGuard challenge fetching and processing
 * - Integrity token generation
 * - WebPO minter creation for content-bound tokens
 * - Cold start token generation for quick fallback
 */

'use strict';

var BotguardService = (function() {
    var WAA_REQUEST_KEY = 'O43z0dpjhgX20SCx4KAo';
    // Use the API key from bgutils-js/Kira which has access to Web Anti-Abuse API
    var GOOG_API_KEY = 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
    
    var botguardClient = null;
    var initializationPromise = null;
    var integrityTokenBasedMinter = null;
    var bgChallenge = null;

    /**
     * Build URL for BotGuard API calls (using YouTube endpoint, not googleapis.com)
     * @param {string} action - 'Create' or 'GenerateIT'
     * @param {boolean} useTrustedEnv
     * @returns {string}
     */
    function buildURL(action, useTrustedEnv) {
        // Use YouTube's endpoint instead of googleapis.com to avoid CORS issues
        var baseUrl = 'https://www.youtube.com/api/jnn/v1/';
        return baseUrl + action;
    }

    /**
     * Fetch with proxy support for CORS compliance
     * All external URLs must go through the Invidious proxy to avoid CORS issues
     * @param {string} url - URL to fetch
     * @param {Object} options - Fetch options
     * @returns {Promise<Response>}
     */
    async function fetchWithProxy(url, options) {
        var parsedUrl = new URL(url);
        var host = parsedUrl.host;
        
        // Build proxy URL with __host and __path parameters
        // We use __path instead of putting the path in the URL to avoid issues with special chars like $
        var proxyUrl = new URL('/proxy', window.location.origin);
        proxyUrl.searchParams.set('__host', host);
        proxyUrl.searchParams.set('__path', parsedUrl.pathname);
        
        // Copy original query parameters
        parsedUrl.searchParams.forEach(function(value, key) {
            proxyUrl.searchParams.set(key, value);
        });
        
        // Pass custom headers through __headers parameter
        if (options && options.headers) {
            var headersArray = [];
            for (var key in options.headers) {
                if (options.headers.hasOwnProperty(key)) {
                    headersArray.push([key, options.headers[key]]);
                }
            }
            proxyUrl.searchParams.set('__headers', JSON.stringify(headersArray));
        }
        
        // Make the proxied request (headers are passed through __headers param)
        return fetch(proxyUrl.toString(), {
            method: options?.method || 'GET',
            body: options?.body
        });
    }

    /**
     * Initialize the BotGuard client
     * @returns {Promise<Object|undefined>}
     */
    async function init() {
        if (initializationPromise) {
            return await initializationPromise;
        }
        return setup();
    }

    /**
     * Internal setup function
     * @returns {Promise<Object|undefined>}
     */
    async function setup() {
        if (initializationPromise) {
            return await initializationPromise;
        }

        initializationPromise = _initBotguard();

        try {
            botguardClient = await initializationPromise;
            return botguardClient;
        } finally {
            initializationPromise = null;
        }
    }

    /**
     * Internal BotGuard initialization
     * @returns {Promise<Object|undefined>}
     */
    async function _initBotguard() {
        // Check if BG (bgutils-js) is available
        if (typeof BG === 'undefined') {
            console.error('[BotguardService]', 'bgutils-js not loaded');
            return undefined;
        }

        try {
            // First call (Create) uses direct fetch - no proxy needed
            var challengeResponse = await fetch(buildURL('Create', true), {
                method: 'POST',
                headers: {
                    'content-type': 'application/json+protobuf',
                    'x-goog-api-key': GOOG_API_KEY,
                    'x-user-agent': 'grpc-web-javascript/0.1'
                },
                body: JSON.stringify([WAA_REQUEST_KEY])
            });

            var challengeResponseData = await challengeResponse.json();
            bgChallenge = BG.Challenge.parseChallengeData(challengeResponseData);

            if (!bgChallenge) {
                console.error('[BotguardService]', 'Failed to parse challenge data');
                return undefined;
            }

            var interpreterJavascript = bgChallenge.interpreterJavascript?.privateDoNotAccessOrElseSafeScriptWrappedValue;

            if (!interpreterJavascript) {
                console.error('[BotguardService]', 'Could not get interpreter javascript. Interpreter Hash:', bgChallenge.interpreterHash);
                return undefined;
            }

            // Inject the interpreter script if not already present
            if (!document.getElementById(bgChallenge.interpreterHash)) {
                var script = document.createElement('script');
                script.type = 'text/javascript';
                script.id = bgChallenge.interpreterHash;
                script.textContent = interpreterJavascript;
                document.head.appendChild(script);
            }

            // Create the BotGuard client
            botguardClient = await BG.BotGuardClient.create({
                globalObj: globalThis,
                globalName: bgChallenge.globalName,
                program: bgChallenge.program
            });

            // Generate integrity token and create WebPO minter
            if (bgChallenge) {
                var webPoSignalOutput = [];
                var botguardResponse = await botguardClient.snapshot({ webPoSignalOutput: webPoSignalOutput });

                var integrityTokenResponse = await fetchWithProxy(buildURL('GenerateIT', true), {
                    method: 'POST',
                    headers: {
                        'content-type': 'application/json+protobuf',
                        'x-goog-api-key': GOOG_API_KEY,
                        'x-user-agent': 'grpc-web-javascript/0.1'
                    },
                    body: JSON.stringify([WAA_REQUEST_KEY, botguardResponse])
                });

                var integrityTokenResponseData = await integrityTokenResponse.json();
                var integrityToken = integrityTokenResponseData[0];

                if (!integrityToken) {
                    console.error('[BotguardService]', 'Could not get integrity token. Interpreter Hash:', bgChallenge.interpreterHash);
                    return botguardClient;
                }

                integrityTokenBasedMinter = await BG.WebPoMinter.create({ integrityToken: integrityToken }, webPoSignalOutput);
            }

            return botguardClient;
        } catch (error) {
            console.error('[BotguardService]', 'Error initializing BotGuard:', error);
            return undefined;
        }
    }

    /**
     * Mint a cold start token (quick fallback)
     * @param {string} contentBinding - Content binding (usually video ID)
     * @returns {string}
     */
    function mintColdStartToken(contentBinding) {
        if (typeof BG === 'undefined') {
            console.error('[BotguardService]', 'bgutils-js not loaded');
            return '';
        }
        return BG.PoToken.generateColdStartToken(contentBinding);
    }

    /**
     * Check if BotGuard is fully initialized
     * @returns {boolean}
     */
    function isInitialized() {
        return !!botguardClient && !!integrityTokenBasedMinter;
    }

    /**
     * Mint a WebPO token for content binding
     * @param {string} contentBinding - Content binding (usually video ID)
     * @returns {Promise<string>}
     */
    async function mintWebPoToken(contentBinding) {
        if (!integrityTokenBasedMinter) {
            throw new Error('WebPO minter not initialized');
        }
        return await integrityTokenBasedMinter.mintAsWebsafeString(contentBinding);
    }

    /**
     * Dispose of the BotGuard client
     */
    function dispose() {
        if (botguardClient && bgChallenge) {
            try {
                botguardClient.shutdown();
            } catch (e) {
                // Ignore shutdown errors
            }
            botguardClient = null;
            integrityTokenBasedMinter = null;

            var script = document.getElementById(bgChallenge.interpreterHash);
            if (script) {
                script.remove();
            }
            bgChallenge = null;
        }
    }

    /**
     * Reinitialize BotGuard
     * @returns {Promise<Object|undefined>}
     */
    async function reinit() {
        if (initializationPromise) {
            return initializationPromise;
        }
        dispose();
        return setup();
    }

    return {
        init: init,
        mintColdStartToken: mintColdStartToken,
        mintWebPoToken: mintWebPoToken,
        isInitialized: isInitialized,
        dispose: dispose,
        reinit: reinit
    };
})();

// Export for use in other modules
window.BotguardService = BotguardService;
