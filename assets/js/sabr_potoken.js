/**
 * BotGuard Service - PoToken generation for SABR streaming
 * Ported from googlevideo's examples/sabr-shaka-example/src/BotguardService.ts
 * (bgutils-js 4 API: BotGuardClient, parseChallengeData, WebPoMinter, createColdStartToken).
 * 
 * This module handles:
 * - BotGuard challenge fetching and processing
 * - Integrity token generation
 * - WebPO minter creation for content-bound tokens
 * - Cold start token generation for quick fallback
 */

'use strict';

var BotguardService = (function() {
    // WEB WAA request key (same as googlevideo's example and bgutils-js).
    var WAA_REQUEST_KEY = 'O43z0dpjhgX20SCx4KAo';
    // Web Anti-Abuse API key, exported by bgutils-js.
    function googApiKey() {
        return (typeof BG !== 'undefined' && BG.GOOG_API_KEY) || 'AIzaSyDyT5W0Jh49F30Pqqtyfdf7pDLFKLJoAnw';
    }
    
    var JNN_BASE_URL = 'https://www.youtube.com/api/jnn/v1/';

    // State published only by a setup attempt that completed and was not disposed.
    var botguardClient = null;
    var integrityTokenBasedMinter = null;
    var bgChallenge = null;
    var initializationPromise = null;
    // Bumped by dispose(): a setup attempt started under an older generation must
    // not publish its client/minter (it shuts its own client down instead).
    var generation = 0;

    /**
     * Call the BotGuard (WAA) API through the Invidious proxy. YouTube's own
     * endpoint is used instead of jnn-pa.googleapis.com.
     * @param {string} action - 'Create' or 'GenerateIT'
     * @param {Array} payload
     * @returns {Promise<Response>}
     */
    function fetchJnn(action, payload) {
        return SABRHelpers.fetchWithProxy(JNN_BASE_URL + action, {
            method: 'POST',
            headers: {
                'content-type': 'application/json+protobuf',
                'x-goog-api-key': googApiKey(),
                'x-user-agent': 'grpc-web-javascript/0.1'
            },
            body: JSON.stringify(payload)
        });
    }

    /**
     * Run the BotGuard interpreter in the global scope, like a classic script.
     * Trust boundary: this is YouTube-supplied code and it runs with the page's
     * privileges. It is only used on the WEB/Onesie debug path
     * (window.SABR_PLAYER_CLIENT = 'WEB'). Indirect eval keeps it out of inline
     * <script> tags, so the CSP needs 'unsafe-eval' but not 'unsafe-inline'.
     * @param {string} code
     */
    function runInterpreter(code) {
        (0, eval)(code);
    }

    function disposedError() {
        var err = new Error('BotGuard was disposed during initialization');
        err.disposed = true;
        return err;
    }

    /**
     * One BotGuard initialization attempt. Resolves with the acquired resources,
     * or releases them and rejects.
     * @param {number} gen - generation the attempt belongs to
     * @returns {Promise<{client: Object, minter: Object, challenge: Object}>}
     */
    async function attemptInit(gen) {
        function checkCurrent() {
            if (gen !== generation) throw disposedError();
        }

        var client = null;
        try {
            var challengeResponse = await fetchJnn('Create', [WAA_REQUEST_KEY]);
            var challenge = BG.parseChallengeData(await challengeResponse.json());
            if (!challenge) throw new Error('Failed to parse challenge data (Create)');

            var interpreterJavascript = challenge.interpreterJavascript &&
                challenge.interpreterJavascript.privateDoNotAccessOrElseSafeScriptWrappedValue;
            if (!interpreterJavascript) {
                throw new Error('Could not get interpreter javascript. Interpreter Hash: ' + challenge.interpreterHash);
            }

            checkCurrent();
            runInterpreter(interpreterJavascript);

            client = await BG.BotGuardClient.create({
                globalObject: globalThis,
                globalName: challenge.globalName,
                program: challenge.program
            });
            checkCurrent();

            // Generate the integrity token and create the WebPO minter.
            var webPoSignalOutput = [];
            var botguardResponse = await client.snapshot({ webPoSignalOutput: webPoSignalOutput });
            checkCurrent();

            var integrityTokenResponse = await fetchJnn('GenerateIT', [WAA_REQUEST_KEY, botguardResponse]);
            var integrityTokenResponseData = await integrityTokenResponse.json();
            var integrityToken = Array.isArray(integrityTokenResponseData) ? integrityTokenResponseData[0] : undefined;
            if (!integrityToken) {
                throw new Error('Could not get integrity token. Interpreter Hash: ' + challenge.interpreterHash);
            }

            var minter = await BG.WebPoMinter.create({ integrityToken: integrityToken }, webPoSignalOutput);
            checkCurrent();

            return { client: client, minter: minter, challenge: challenge };
        } catch (error) {
            if (client) {
                try { client.shutdown(); } catch (e) { /* ignore */ }
            }
            throw error;
        }
    }

    /**
     * Start (or join) an initialization attempt.
     * @returns {Promise<Object|undefined>} the BotGuard client, or undefined on failure
     */
    function setup() {
        if (initializationPromise) return initializationPromise;

        if (typeof BG === 'undefined') {
            console.error('[BotguardService]', 'bgutils-js not loaded');
            return Promise.resolve(undefined);
        }

        var gen = generation;
        var promise = attemptInit(gen).then(function (result) {
            // dispose() may have run after attemptInit's last check: never publish
            // a stale attempt, release its client instead.
            if (gen !== generation) {
                try { result.client.shutdown(); } catch (e) { /* ignore */ }
                return undefined;
            }
            botguardClient = result.client;
            integrityTokenBasedMinter = result.minter;
            bgChallenge = result.challenge;
            return botguardClient;
        }, function (error) {
            if (!error.disposed) console.error('[BotguardService]', 'Error initializing BotGuard:', error);
            return undefined;
        });
        initializationPromise = promise;
        promise.finally(function () {
            if (initializationPromise === promise) initializationPromise = null;
        });
        return promise;
    }

    /**
     * Initialize the BotGuard client (no-op when it is already initialized).
     * @returns {Promise<Object|undefined>}
     */
    async function init() {
        if (isInitialized()) return botguardClient;
        return setup();
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
        return BG.createColdStartToken(contentBinding);
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
     * Dispose of the BotGuard client. Also invalidates a pending initialization:
     * it will release its own resources instead of publishing them.
     */
    function dispose() {
        generation++;
        initializationPromise = null;
        if (botguardClient) {
            try {
                botguardClient.shutdown();
            } catch (e) {
                // Ignore shutdown errors
            }
        }
        botguardClient = null;
        integrityTokenBasedMinter = null;
        bgChallenge = null;
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
