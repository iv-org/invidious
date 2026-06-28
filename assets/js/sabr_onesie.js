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

  function gv() { return window.googlevideo; }

  // Concatenate a UMP part's chunks into a single Uint8Array.
  function partBytes(part) {
    var chunks = part.data.chunks;
    if (chunks.length === 1) return chunks[0];
    return gv().utils.concatenateChunks(chunks);
  }

  // Ensure we have a googlevideo redirector base (e.g. https://rrX---snXXX.googlevideo.com).
  // Reuses the value preloaded into localStorage by SABRPlayer.initInnertube.
  async function getRedirectorBase() {
    var stored = null;
    try { stored = localStorage.getItem(SABRHelpers.REDIRECTOR_STORAGE_KEY); } catch (e) {}
    if (!stored || !stored.startsWith('https://')) {
      var resp = await SABRHelpers.fetchWithProxy(
        'https://redirector.googlevideo.com/initplayback?source=youtube&itag=0&pvi=0&pai=0&owc=yes&cmo:sensitive_content=yes&alr=yes&id=' + Math.round(Math.random() * 1e5),
        { method: 'GET' }
      );
      stored = (await resp.text()).trim();
      if (stored.startsWith('https://')) {
        try { localStorage.setItem(SABRHelpers.REDIRECTOR_STORAGE_KEY, stored); } catch (e) {}
      }
    }
    if (!stored.startsWith('https://')) throw new Error('Invalid redirector response');
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
      body: prepared.body
    });
    var buffer = new Uint8Array(await resp.arrayBuffer());

    // Parse the UMP stream: collect ONESIE_HEADER parts and attach their data.
    var onesie = [];
    new ump.UmpReader(new ump.CompositeBuffer([buffer])).read(function (part) {
      if (part.type === protos.UMPPartId.ONESIE_HEADER) {
        onesie.push(protos.OnesieHeader.decode(partBytes(part)));
      } else if (part.type === protos.UMPPartId.ONESIE_DATA) {
        if (onesie.length) onesie[onesie.length - 1].data = partBytes(part);
      } else if (part.type === protos.UMPPartId.SABR_ERROR) {
        try { console.error('[SABROnesie] SABR_ERROR', protos.SabrError.decode(partBytes(part))); } catch (e) {}
      }
    });

    var header = null;
    for (var i = 0; i < onesie.length; i++) {
      if (onesie[i].type === protos.OnesieHeaderType.ONESIE_PLAYER_RESPONSE) { header = onesie[i]; break; }
    }
    if (!header) throw new Error('Onesie player response not found');
    if (!header.cryptoParams) throw new Error('Onesie crypto params not found');

    var responseData = header.data;

    // Decompress (gzip) if requested.
    if (responseData && header.cryptoParams.compressionType === protos.CompressionType.GZIP) {
      var ds = new DecompressionStream('gzip');
      var stream = new Blob([responseData]).stream().pipeThrough(ds);
      responseData = new Uint8Array(await new Response(stream).arrayBuffer());
    }

    // Decrypt only if the response was encrypted (skipResponseEncryption=true means it usually isn't).
    var iv = header.cryptoParams.iv;
    var hmac = header.cryptoParams.hmac;
    var decrypted = (hmac && hmac.length && iv && iv.length)
      ? await SABRHelpers.decryptResponse(iv, hmac, responseData, clientConfig.clientKeyData)
      : responseData;

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
})();
