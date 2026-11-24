/**
 * SABR Onesie - fetch the YouTube player response through an encrypted Onesie
 * request (WEB client), instead of a plain /youtubei/v1/player call.
 *
 * Why: a normal player request is bound to the IP that made it, so the
 * server_abr_streaming_url it returns only works from that same IP. An Onesie
 * request is proxied by YouTube's "trusted bandaid", so the player response
 * (and the SABR streaming URL within it) is not tied to our proxy's egress IP.
 * Subsequent media is still pulled with SABR (see sabr_scheme_plugin.js) - this
 * module only replaces how the player response itself is obtained.
 *
 * Adapted from googlevideo/examples/onesie-request/main.ts and the WEB-client
 * variant in invidious-secret-companion (override/onesiePlayerReq.ts).
 *
 * Reads googlevideo protos/ump/utils from window.googlevideo, crypto helpers
 * from window.SABRHelpers, and Constants from window.Constants.
 * Exposes window.fetchOnesiePlayerResponse(innertube, videoId, poToken, clientConfig).
 */

'use strict';

(function () {
  // Public WEB player API key used for the inner player request.
  var PLAYER_API_KEY = 'AIzaSyDCU8hByM-4DrUqRUYnGn-3llEO78bcxq8';

  // Onesie is on the player-load path, so never let a stalled request block it.
  var REQUEST_TIMEOUT_MS = 15000;

  function gv() { return window.googlevideo; }

  function timeoutSignal(ms) {
    return (typeof AbortSignal !== 'undefined' && AbortSignal.timeout) ? AbortSignal.timeout(ms) : undefined;
  }

  // Concatenate a UMP part's chunks (googlevideo/ump CompositeBuffer) into a single Uint8Array.
  function partBytes(data) {
    var chunks = data.chunks;
    if (chunks.length === 1) return chunks[0];
    return gv().utils.concatenateChunks(chunks);
  }

  // Ensure we have a googlevideo redirector base (e.g. https://rrX---snXXX.googlevideo.com).
  // Reuses the value preloaded into localStorage by SABRPlayer.initInnertube.
  // Fetch the redirector URL and cache it (trimmed) in localStorage. Returns '' on failure.
  async function fetchRedirectorUrl() {
    var resp = await SABRHelpers.fetchWithProxy(
      'https://redirector.googlevideo.com/initplayback?source=youtube&itag=0&pvi=0&pai=0&owc=yes&cmo:sensitive_content=yes&alr=yes&id=' + Math.round(Math.random() * 1e5),
      { method: 'GET', signal: timeoutSignal(REQUEST_TIMEOUT_MS) }
    );
    if (!resp.ok) return '';
    var url = (await resp.text()).trim();
    if (url.indexOf('https://') !== 0) return '';
    try { localStorage.setItem(SABRHelpers.REDIRECTOR_STORAGE_KEY, url); } catch (e) {}
    return url;
  }

  async function getRedirectorBase() {
    var stored = null;
    try { stored = (localStorage.getItem(SABRHelpers.REDIRECTOR_STORAGE_KEY) || '').trim(); } catch (e) {}
    if (!stored || stored.indexOf('https://') !== 0) {
      stored = await fetchRedirectorUrl();
    }
    if (!stored) throw new Error('Invalid redirector response');
    return stored.split('/initplayback')[0];
  }

  // Build the encrypted Onesie request body + the hex-encoded video id.
  async function prepareOnesieRequest(innertube, videoId, poToken, clientConfig) {
    var protos = gv().protos;
    var base64ToU8 = gv().utils.base64ToU8;

    // Shallow clone of the session context, deep-copying only `client` since
    // that's all we mutate (force WEB client - matches the secret-companion).
    var ctx = Object.assign({}, innertube.session.context);
    ctx.client = Object.assign({}, innertube.session.context.client, {
      clientName: Constants.CLIENTS.WEB.NAME,
      clientVersion: Constants.CLIENTS.WEB.VERSION
    });

    var playerRequestJson = {
      context: ctx,
      playbackContext: {
        contentPlaybackContext: {
          vis: 0,
          splay: false,
          lactMilliseconds: '-1',
          signatureTimestamp: innertube.session.player && innertube.session.player.signature_timestamp
        }
      },
      videoId: videoId,
      racyCheckOk: true,
      contentCheckOk: true
    };

    if (poToken) {
      playerRequestJson.serviceIntegrityDimensions = { poToken: poToken };
    }

    var headers = [
      { name: 'Content-Type', value: 'application/json' },
      { name: 'User-Agent', value: ctx.client.userAgent },
      { name: 'X-Goog-Visitor-Id', value: ctx.client.visitorData }
    ];

    var onesieInnertubeRequest = protos.OnesieInnertubeRequest.encode({
      url: 'https://youtubei.googleapis.com/youtubei/v1/player?key=' + PLAYER_API_KEY,
      headers: headers,
      body: JSON.stringify(playerRequestJson),
      proxiedByTrustedBandaid: true,
      skipResponseEncryption: true
    }).finish();

    var enc = await SABRHelpers.encryptRequest(clientConfig.clientKeyData, onesieInnertubeRequest);

    var body = protos.OnesieRequest.encode({
      urls: [],
      innertubeRequest: {
        enableCompression: true,
        encryptedClientKey: clientConfig.encryptedClientKey,
        enableAdPlacementsPreroll: false,
        encryptedOnesieInnertubeRequest: enc.encrypted,
        hmac: enc.hmac,
        iv: enc.iv,
        useJsonformatterToParsePlayerResponse: false,
        serializeResponseAsJson: true
      },
      streamerContext: {
        sabrContexts: [],
        unsentSabrContexts: [],
        poToken: poToken ? base64ToU8(poToken) : undefined,
        playbackCookie: undefined,
        clientInfo: {
          clientName: parseInt(Constants.CLIENT_NAME_IDS[Constants.CLIENTS.WEB.NAME], 10),
          clientVersion: Constants.CLIENTS.WEB.VERSION
        }
      },
      bufferedRanges: [],
      onesieUstreamerConfig: clientConfig.onesieUstreamerConfig
    }).finish();

    // The `id` query param is the hex of the (base64-decoded) video id.
    var videoIdBytes = base64ToU8(videoId);
    var hex = [];
    for (var i = 0; i < videoIdBytes.length; i++) {
      hex.push(videoIdBytes[i].toString(16).padStart(2, '0'));
    }

    return { body: body, encodedVideoId: hex.join('') };
  }

  /**
   * Fetch and decode the player response JSON via Onesie.
   * @returns {Promise<Object>} the raw /player response JSON
   */
  async function fetchOnesiePlayerResponse(innertube, videoId, poToken, clientConfig) {
    if (!clientConfig) throw new Error('Onesie client config not available');
    var protos = gv().protos;
    var ump = gv().ump;

    var base = await getRedirectorBase();
    var prepared = await prepareOnesieRequest(innertube, videoId, poToken, clientConfig);

    var url = base + clientConfig.baseUrl +
      '&id=' + prepared.encodedVideoId +
      '&cmo:sensitive_content=yes' +
      '&opr=1' +   // Onesie Playback Request
      '&osts=0' +  // Onesie Start Time Seconds
      '&por=1' +
      '&rn=0';

    var resp = await SABRHelpers.fetchWithProxy(url, {
      method: 'POST',
      headers: { 'accept': '*/*', 'content-type': 'application/octet-stream' },
      body: prepared.body,
      signal: timeoutSignal(REQUEST_TIMEOUT_MS)
    });
    if (!resp.ok || !resp.body) throw new Error('Onesie request failed with HTTP status ' + resp.status);
    // Parse the UMP stream, keeping the ONESIE_DATA that follows the player-response header.
    var lastHeader = null;
    var header = null;
    var responseData = null;
    var umpReader = new ump.UmpReader({
      onPart: function (partType, data) {
        if (partType === protos.UMPPartId.ONESIE_HEADER) {
          lastHeader = protos.OnesieHeader.decode(partBytes(data));
        } else if (partType === protos.UMPPartId.ONESIE_DATA) {
          if (lastHeader && lastHeader.type === protos.OnesieHeaderType.ONESIE_PLAYER_RESPONSE) {
            header = lastHeader;
            responseData = partBytes(data);
          }
          lastHeader = null;
        } else if (partType === protos.UMPPartId.SABR_ERROR) {
          try { console.error('[SABROnesie] SABR_ERROR', protos.SabrError.decode(partBytes(data))); } catch (e) {}
        }
      }
    });

    var reader = resp.body.getReader();
    while (true) {
      var chunk = await reader.read();
      if (chunk.done) break;
      await umpReader.feed(chunk.value);
    }

    if (!header || !responseData) throw new Error('Onesie player response not found');

    // skipResponseEncryption is set, so the response normally comes back in the clear;
    // decrypt only if crypto params are actually present, then gunzip.
    var cryptoParams = header.cryptoParams || {};
    var iv = cryptoParams.iv;
    var hmac = cryptoParams.hmac;
    var decrypted = (hmac && hmac.length && iv && iv.length)
      ? await SABRHelpers.decryptResponse(iv, hmac, responseData, clientConfig.clientKeyData)
      : responseData;

    if (decrypted && cryptoParams.compressionType === protos.CompressionType.GZIP) {
      var ds = new DecompressionStream('gzip');
      var stream = new Blob([decrypted]).stream().pipeThrough(ds);
      decrypted = new Uint8Array(await new Response(stream).arrayBuffer());
    }

    var innerResponse = protos.OnesieInnertubeResponse.decode(decrypted);
    if (innerResponse.onesieProxyStatus !== protos.OnesieProxyStatus.OK) {
      throw new Error('Onesie proxy status not OK (' + innerResponse.onesieProxyStatus + ')');
    }
    if (innerResponse.httpStatus !== 200) {
      throw new Error('Onesie player HTTP status ' + innerResponse.httpStatus);
    }

    return JSON.parse(new TextDecoder().decode(innerResponse.body));
  }

  window.fetchOnesiePlayerResponse = fetchOnesiePlayerResponse;
  window.fetchSabrRedirectorUrl = fetchRedirectorUrl;
})();
