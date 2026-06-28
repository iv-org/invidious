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
 */

import Innertube, { Platform, Constants } from '/js/sabr/youtubei.js/youtubei.bundle.min.js';
import { googlevideo } from '/js/sabr/googlevideo/googlevideo.bundle.min.js';
import { BG } from '/js/sabr/bgutils-js/bgutils.bundle.min.js';

// youtubei.js
window.Innertube = Innertube;
window.Platform = Platform;
window.Constants = Constants;

// googlevideo namespace (utils, ump, protos) for the SABR scheme plugin + manifest parser
window.googlevideo = googlevideo;

// BotGuard
window.BG = BG;

console.info('[SABR Loader]', 'All SABR libraries loaded');
window.dispatchEvent(new Event('sabr-libs-loaded'));