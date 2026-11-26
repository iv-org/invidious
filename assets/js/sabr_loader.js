/**
 * SABR Loader - ES module loader for SABR dependencies
 *
 * All dependencies are ES modules:
 * - youtubei.js: Provides Innertube for YouTube API access
 * - googlevideo: Provides SABR protos, UMP reader/writer and utils
 * - bgutils-js: Provides BotGuard utilities
 *
 * Exposes everything needed by sabr_scheme_plugin.js / sabr_manifest_parser.js
 * onto window.googlevideo so the plain-script plugin can read them at call time.
 *
 * Dispatches 'sabr-libs-loaded', or 'sabr-libs-failed' (detail: the error) when an
 * import fails, so sabr_init.js can show the DASH fallback instead of waiting forever.
 * The result is also kept in window.SABR_LIBS_STATE ('loaded' | 'failed').
 */

// Static assets are cached for a long time: pass this module's own `?v=<commit>`
// on, so a new Invidious version doesn't keep serving cached library files.
var assetVersion = new URL(import.meta.url).search;

Promise.all([
  // youtubei.js and bgutils-js are downloaded from npm at build time,
  // googlevideo is bundled with `npm run bundle-sabr`.
  import('/js/sabr/youtubei.js/browser.js' + assetVersion),
  import('/js/sabr/googlevideo/googlevideo.bundle.min.js' + assetVersion),
  import('/js/sabr/bgutils-js/bgutils.js' + assetVersion)
]).then(function (modules) {
  var youtubei = modules[0];

  // youtubei.js
  window.Innertube = youtubei.default;
  window.Platform = youtubei.Platform;
  window.Constants = youtubei.Constants;
  // YT.VideoInfo: build a VideoInfo from a raw player response fetched via the
  // onesie path (sabr_onesie.js) instead of innertube.getInfo().
  window.YT = youtubei.YT;

  // googlevideo namespace (utils, ump, protos) for the SABR scheme plugin + manifest parser
  window.googlevideo = modules[1].googlevideo;

  // BotGuard
  window.BG = modules[2].BG;

  console.info('[SABR Loader]', 'All SABR libraries loaded');
  window.SABR_LIBS_STATE = 'loaded';
  window.dispatchEvent(new Event('sabr-libs-loaded'));
}).catch(function (error) {
  console.error('[SABR Loader]', 'Failed to load the SABR libraries', error);
  window.SABR_LIBS_STATE = 'failed';
  window.SABR_LIBS_ERROR = error;
  window.dispatchEvent(new CustomEvent('sabr-libs-failed', { detail: error }));
});
