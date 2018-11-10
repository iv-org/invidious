/*! videojs-contrib-dash - v2.8.2 - 2017-04-26
 * Copyright (c) 2017 Brightcove  */
(function e(t,n,r){function s(o,u){if(!n[o]){if(!t[o]){var a=typeof require=="function"&&require;if(!u&&a)return a(o,!0);if(i)return i(o,!0);var f=new Error("Cannot find module '"+o+"'");throw f.code="MODULE_NOT_FOUND",f}var l=n[o]={exports:{}};t[o][0].call(l.exports,function(e){var n=t[o][1][e];return s(n?n:e)},l,l.exports,e,t,n,r)}return n[o].exports}var i=typeof require=="function"&&require;for(var o=0;o<r.length;o++)s(r[o]);return s})({1:[function(require,module,exports){
(function (global){
'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});
exports.default = setupAudioTracks;

var _dashjs = (typeof window !== "undefined" ? window['dashjs'] : typeof global !== "undefined" ? global['dashjs'] : null);

var _dashjs2 = _interopRequireDefault(_dashjs);

var _video = (typeof window !== "undefined" ? window['videojs'] : typeof global !== "undefined" ? global['videojs'] : null);

var _video2 = _interopRequireDefault(_video);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

/*
 * Setup audio tracks. Take the tracks from dash and add the tracks to videojs. Listen for when
 * videojs changes tracks and apply that to the dash player because videojs doesn't do this
 * natively.
 *
 * @private
 * @param {videojs} player the videojs player instance
 * @param {videojs.tech} tech the videojs tech being used
 */
function handlePlaybackMetadataLoaded(player, tech) {
  var mediaPlayer = player.dash.mediaPlayer;

  var dashAudioTracks = mediaPlayer.getTracksFor('audio');
  var videojsAudioTracks = player.audioTracks();

  function generateIdFromTrackIndex(index) {
    return 'dash-audio-' + index;
  }

  function findDashAudioTrack(dashAudioTracks, videojsAudioTrack) {
    return dashAudioTracks.find(function (_ref) {
      var index = _ref.index;
      return generateIdFromTrackIndex(index) === videojsAudioTrack.id;
    });
  }

  // Safari creates a single native `AudioTrack` (not `videojs.AudioTrack`) when loading. Clear all
  // automatically generated audio tracks so we can create them all ourself.
  if (videojsAudioTracks.length) {
    tech.clearTracks(['audio']);
  }

  var currentAudioTrack = mediaPlayer.getCurrentTrackFor('audio');

  dashAudioTracks.forEach(function (dashTrack) {
    var label = dashTrack.lang;

    if (dashTrack.roles && dashTrack.roles.length) {
      label += ' (' + dashTrack.roles.join(', ') + ')';
    }

    // Add the track to the player's audio track list.
    videojsAudioTracks.addTrack(new _video2.default.AudioTrack({
      enabled: dashTrack === currentAudioTrack,
      id: generateIdFromTrackIndex(dashTrack.index),
      kind: dashTrack.kind || 'main',
      label: label,
      language: dashTrack.lang
    }));
  });

  videojsAudioTracks.addEventListener('change', function () {
    for (var i = 0; i < videojsAudioTracks.length; i++) {
      var track = videojsAudioTracks[i];

      if (track.enabled) {
        // Find the audio track we just selected by the id
        var dashAudioTrack = findDashAudioTrack(dashAudioTracks, track);

        // Set is as the current track
        mediaPlayer.setCurrentTrack(dashAudioTrack);

        // Stop looping
        continue;
      }
    }
  });
}

/*
 * Call `handlePlaybackMetadataLoaded` when `mediaPlayer` emits
 * `dashjs.MediaPlayer.events.PLAYBACK_METADATA_LOADED`.
 */
function setupAudioTracks(player, tech) {
  // When `dashjs` finishes loading metadata, create audio tracks for `video.js`.
  player.dash.mediaPlayer.on(_dashjs2.default.MediaPlayer.events.PLAYBACK_METADATA_LOADED, handlePlaybackMetadataLoaded.bind(null, player, tech));
}

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{}],2:[function(require,module,exports){
(function (global){
'use strict';

Object.defineProperty(exports, "__esModule", {
  value: true
});

var _createClass = function () { function defineProperties(target, props) { for (var i = 0; i < props.length; i++) { var descriptor = props[i]; descriptor.enumerable = descriptor.enumerable || false; descriptor.configurable = true; if ("value" in descriptor) descriptor.writable = true; Object.defineProperty(target, descriptor.key, descriptor); } } return function (Constructor, protoProps, staticProps) { if (protoProps) defineProperties(Constructor.prototype, protoProps); if (staticProps) defineProperties(Constructor, staticProps); return Constructor; }; }();

var _window = require('global/window');

var _window2 = _interopRequireDefault(_window);

var _video = (typeof window !== "undefined" ? window['videojs'] : typeof global !== "undefined" ? global['videojs'] : null);

var _video2 = _interopRequireDefault(_video);

var _dashjs = (typeof window !== "undefined" ? window['dashjs'] : typeof global !== "undefined" ? global['dashjs'] : null);

var _dashjs2 = _interopRequireDefault(_dashjs);

var _setupAudioTracks = require('./setup-audio-tracks');

var _setupAudioTracks2 = _interopRequireDefault(_setupAudioTracks);

function _interopRequireDefault(obj) { return obj && obj.__esModule ? obj : { default: obj }; }

function _toConsumableArray(arr) { if (Array.isArray(arr)) { for (var i = 0, arr2 = Array(arr.length); i < arr.length; i++) { arr2[i] = arr[i]; } return arr2; } else { return Array.from(arr); } }

function _classCallCheck(instance, Constructor) { if (!(instance instanceof Constructor)) { throw new TypeError("Cannot call a class as a function"); } }

var isArray = function isArray(a) {
  return Object.prototype.toString.call(a) === '[object Array]';
};

/**
 * videojs-contrib-dash
 *
 * Use Dash.js to playback DASH content inside of Video.js via a SourceHandler
 */

var Html5DashJS = function () {
  function Html5DashJS(source, tech, options) {
    var _this = this;

    _classCallCheck(this, Html5DashJS);

    // Get options from tech if not provided for backwards compatibility
    options = options || tech.options_;

    this.player = (0, _video2.default)(options.playerId);
    this.player.dash = this.player.dash || {};

    this.tech_ = tech;
    this.el_ = tech.el();
    this.elParent_ = this.el_.parentNode;

    // Do nothing if the src is falsey
    if (!source.src) {
      return;
    }

    // While the manifest is loading and Dash.js has not finished initializing
    // we must defer events and functions calls with isReady_ and then `triggerReady`
    // again later once everything is setup
    tech.isReady_ = false;

    if (Html5DashJS.updateSourceData) {
      _video2.default.log.warn('updateSourceData has been deprecated.' + ' Please switch to using hook("updatesource", callback).');
      source = Html5DashJS.updateSourceData(source);
    }

    // call updatesource hooks
    Html5DashJS.hooks('updatesource').forEach(function (hook) {
      source = hook(source);
    });

    var manifestSource = source.src;
    this.keySystemOptions_ = Html5DashJS.buildDashJSProtData(source.keySystemOptions);

    this.player.dash.mediaPlayer = _dashjs2.default.MediaPlayer().create();

    this.mediaPlayer_ = this.player.dash.mediaPlayer;

    // Log MedaPlayer messages through video.js
    if (Html5DashJS.useVideoJSDebug) {
      _video2.default.log.warn('useVideoJSDebug has been deprecated.' + ' Please switch to using hook("beforeinitialize", callback).');
      Html5DashJS.useVideoJSDebug(this.mediaPlayer_);
    }

    if (Html5DashJS.beforeInitialize) {
      _video2.default.log.warn('beforeInitialize has been deprecated.' + ' Please switch to using hook("beforeinitialize", callback).');
      Html5DashJS.beforeInitialize(this.player, this.mediaPlayer_);
    }

    Html5DashJS.hooks('beforeinitialize').forEach(function (hook) {
      hook(_this.player, _this.mediaPlayer_);
    });

    // Must run controller before these two lines or else there is no
    // element to bind to.
    this.mediaPlayer_.initialize();

    // Apply all dash options that are set
    if (options.dash) {
      Object.keys(options.dash).forEach(function (key) {
        var _mediaPlayer_;

        var dashOptionsKey = 'set' + key.charAt(0).toUpperCase() + key.slice(1);
        var value = options.dash[key];

        if (_this.mediaPlayer_.hasOwnProperty(dashOptionsKey)) {
          // Providing a key without `set` prefix is now deprecated.
          _video2.default.log.warn('Using dash options in videojs-contrib-dash without the set prefix ' + ('has been deprecated. Change \'' + key + '\' to \'' + dashOptionsKey + '\''));

          // Set key so it will still work
          key = dashOptionsKey;
        }

        if (!_this.mediaPlayer_.hasOwnProperty(key)) {
          _video2.default.log.warn('Warning: dash configuration option unrecognized: ' + key);

          return;
        }

        // Guarantee `value` is an array
        if (!isArray(value)) {
          value = [value];
        }

        (_mediaPlayer_ = _this.mediaPlayer_)[key].apply(_mediaPlayer_, _toConsumableArray(value));
      });
    }

    this.mediaPlayer_.attachView(this.el_);

    // Dash.js autoplays by default, video.js will handle autoplay
    this.mediaPlayer_.setAutoPlay(false);

    // Setup audio tracks
    _setupAudioTracks2.default.call(null, this.player, tech);

    // Attach the source with any protection data
    this.mediaPlayer_.setProtectionData(this.keySystemOptions_);
    this.mediaPlayer_.attachSource(manifestSource);

    this.tech_.triggerReady();
  }

  /*
   * Iterate over the `keySystemOptions` array and convert each object into
   * the type of object Dash.js expects in the `protData` argument.
   *
   * Also rename 'licenseUrl' property in the options to an 'serverURL' property
   */


  _createClass(Html5DashJS, [{
    key: 'dispose',
    value: function dispose() {
      if (this.mediaPlayer_) {
        this.mediaPlayer_.reset();
      }

      if (this.player.dash) {
        delete this.player.dash;
      }
    }
  }, {
    key: 'duration',
    value: function duration() {
      var duration = this.el_.duration;
      if (duration === Number.MAX_VALUE) {
        return Infinity;
      }
      return duration;
    }

    /**
     * Get a list of hooks for a specific lifecycle
     *
     * @param {string} type the lifecycle to get hooks from
     * @param {Function=|Function[]=} hook Optionally add a hook tothe lifecycle
     * @return {Array} an array of hooks or epty if none
     * @method hooks
     */

  }], [{
    key: 'buildDashJSProtData',
    value: function buildDashJSProtData(keySystemOptions) {
      var output = {};

      if (!keySystemOptions || !isArray(keySystemOptions)) {
        return null;
      }

      for (var i = 0; i < keySystemOptions.length; i++) {
        var keySystem = keySystemOptions[i];
        var options = _video2.default.mergeOptions({}, keySystem.options);

        if (options.licenseUrl) {
          options.serverURL = options.licenseUrl;
          delete options.licenseUrl;
        }

        output[keySystem.name] = options;
      }

      return output;
    }
  }, {
    key: 'hooks',
    value: function hooks(type, hook) {
      Html5DashJS.hooks_[type] = Html5DashJS.hooks_[type] || [];

      if (hook) {
        Html5DashJS.hooks_[type] = Html5DashJS.hooks_[type].concat(hook);
      }

      return Html5DashJS.hooks_[type];
    }

    /**
     * Add a function hook to a specific dash lifecycle
     *
     * @param {string} type the lifecycle to hook the function to
     * @param {Function|Function[]} hook the function or array of functions to attach
     * @method hook
     */

  }, {
    key: 'hook',
    value: function hook(type, _hook) {
      Html5DashJS.hooks(type, _hook);
    }

    /**
     * Remove a hook from a specific dash lifecycle.
     *
     * @param {string} type the lifecycle that the function hooked to
     * @param {Function} hook The hooked function to remove
     * @return {boolean} True if the function was removed, false if not found
     * @method removeHook
     */

  }, {
    key: 'removeHook',
    value: function removeHook(type, hook) {
      var index = Html5DashJS.hooks(type).indexOf(hook);

      if (index === -1) {
        return false;
      }

      Html5DashJS.hooks_[type] = Html5DashJS.hooks_[type].slice();
      Html5DashJS.hooks_[type].splice(index, 1);

      return true;
    }
  }]);

  return Html5DashJS;
}();

Html5DashJS.hooks_ = {};

var canHandleKeySystems = function canHandleKeySystems(source) {
  // copy the source
  source = JSON.parse(JSON.stringify(source));

  if (Html5DashJS.updateSourceData) {
    _video2.default.log.warn('updateSourceData has been deprecated.' + ' Please switch to using hook("updatesource", callback).');
    source = Html5DashJS.updateSourceData(source);
  }

  // call updatesource hooks
  Html5DashJS.hooks('updatesource').forEach(function (hook) {
    source = hook(source);
  });

  var videoEl = document.createElement('video');
  if (source.keySystemOptions && !(navigator.requestMediaKeySystemAccess ||
  // IE11 Win 8.1
  videoEl.msSetMediaKeys)) {
    return false;
  }

  return true;
};

_video2.default.DashSourceHandler = function () {
  return {
    canHandleSource: function canHandleSource(source) {
      var dashExtRE = /\.mpd/i;

      if (!canHandleKeySystems(source)) {
        return '';
      }

      if (_video2.default.DashSourceHandler.canPlayType(source.type)) {
        return 'probably';
      } else if (dashExtRE.test(source.src)) {
        return 'maybe';
      } else {
        return '';
      }
    },

    handleSource: function handleSource(source, tech, options) {
      return new Html5DashJS(source, tech, options);
    },

    canPlayType: function canPlayType(type) {
      return _video2.default.DashSourceHandler.canPlayType(type);
    }
  };
};

_video2.default.DashSourceHandler.canPlayType = function (type) {
  var dashTypeRE = /^application\/dash\+xml/i;
  if (dashTypeRE.test(type)) {
    return 'probably';
  }

  return '';
};

// Only add the SourceHandler if the browser supports MediaSourceExtensions
if (!!_window2.default.MediaSource) {
  _video2.default.getTech('Html5').registerSourceHandler(_video2.default.DashSourceHandler(), 0);
}

_video2.default.Html5DashJS = Html5DashJS;
exports.default = Html5DashJS;

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{"./setup-audio-tracks":1,"global/window":3}],3:[function(require,module,exports){
(function (global){
var win;

if (typeof window !== "undefined") {
    win = window;
} else if (typeof global !== "undefined") {
    win = global;
} else if (typeof self !== "undefined"){
    win = self;
} else {
    win = {};
}

module.exports = win;

}).call(this,typeof global !== "undefined" ? global : typeof self !== "undefined" ? self : typeof window !== "undefined" ? window : {})
},{}]},{},[2]);
