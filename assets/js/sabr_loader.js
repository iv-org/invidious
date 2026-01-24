/**
 * SABR Loader - ES module loader for SABR dependencies
 * 
 * All dependencies are ES modules:
 * - youtubei.js: Provides Innertube for YouTube API access
 * - googlevideo: Provides SABR streaming adapter
 * - bgutils-js: Provides BotGuard utilities
 */

// Import all ES modules
import Innertube from '/js/sabr/youtubei.js/youtubei.bundle.min.js';
import { Platform } from '/js/sabr/youtubei.js/youtubei.bundle.min.js';
import { Constants } from '/js/sabr/youtubei.js/youtubei.bundle.min.js';
import * as googlevideo from '/js/sabr/googlevideo/googlevideo.bundle.min.js';
import { BG } from '/js/sabr/bgutils-js/bgutils.bundle.min.js';

// Expose all SABR-related functions to window
window.Innertube = Innertube;
window.Platform = Platform;
window.Constants = Constants;
window.SabrStreamingAdapter = googlevideo.SabrStreamingAdapter;
window.SabrUmpProcessor = googlevideo.SabrUmpProcessor;
window.buildSabrFormat = googlevideo.buildSabrFormat;
window.FormatKeyUtils = googlevideo.FormatKeyUtils;
window.UmpUtils = googlevideo.UmpUtils;
window.SABR_CONSTANTS = googlevideo.SABR_CONSTANTS;
window.isGoogleVideoURL = googlevideo.isGoogleVideoURL;
window.BG = BG;

// Signal that all SABR libraries are loaded and ready
console.info('[SABR Loader]', 'All SABR libraries loaded');
window.dispatchEvent(new Event('sabr-libs-loaded'));
