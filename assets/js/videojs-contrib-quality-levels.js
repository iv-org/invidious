/*! @name videojs-contrib-quality-levels @version 2.0.7 @license Apache-2.0 */
(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('video.js'), require('global/document')) :
  typeof define === 'function' && define.amd ? define(['video.js', 'global/document'], factory) :
  (global.videojsContribQualityLevels = factory(global.videojs,global.document));
}(this, (function (videojs,document) { 'use strict';

  videojs = videojs && videojs.hasOwnProperty('default') ? videojs['default'] : videojs;
  document = document && document.hasOwnProperty('default') ? document['default'] : document;

  var classCallCheck = function (instance, Constructor) {
    if (!(instance instanceof Constructor)) {
      throw new TypeError("Cannot call a class as a function");
    }
  };

  var inherits = function (subClass, superClass) {
    if (typeof superClass !== "function" && superClass !== null) {
      throw new TypeError("Super expression must either be null or a function, not " + typeof superClass);
    }

    subClass.prototype = Object.create(superClass && superClass.prototype, {
      constructor: {
        value: subClass,
        enumerable: false,
        writable: true,
        configurable: true
      }
    });
    if (superClass) Object.setPrototypeOf ? Object.setPrototypeOf(subClass, superClass) : subClass.__proto__ = superClass;
  };

  var possibleConstructorReturn = function (self, call) {
    if (!self) {
      throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
    }

    return call && (typeof call === "object" || typeof call === "function") ? call : self;
  };

  /**
   * A single QualityLevel.
   *
   * interface QualityLevel {
   *   readonly attribute DOMString id;
   *            attribute DOMString label;
   *   readonly attribute long width;
   *   readonly attribute long height;
   *   readonly attribute long bitrate;
   *            attribute boolean enabled;
   * };
   *
   * @class QualityLevel
   */

  var QualityLevel =

  /**
   * Creates a QualityLevel
   *
   * @param {Representation|Object} representation The representation of the quality level
   * @param {string}   representation.id        Unique id of the QualityLevel
   * @param {number=}  representation.width     Resolution width of the QualityLevel
   * @param {number=}  representation.height    Resolution height of the QualityLevel
   * @param {number}   representation.bandwidth Bitrate of the QualityLevel
   * @param {Function} representation.enabled   Callback to enable/disable QualityLevel
   */
  function QualityLevel(representation) {
    classCallCheck(this, QualityLevel);


    var level = this; // eslint-disable-line

    if (videojs.browser.IS_IE8) {
      level = document.createElement('custom');
      for (var prop in QualityLevel.prototype) {
        if (prop !== 'constructor') {
          level[prop] = QualityLevel.prototype[prop];
        }
      }
    }

    level.id = representation.id;
    level.label = level.id;
    level.width = representation.width;
    level.height = representation.height;
    level.bitrate = representation.bandwidth;
    level.enabled_ = representation.enabled;

    Object.defineProperty(level, 'enabled', {
      /**
       * Get whether the QualityLevel is enabled.
       *
       * @return {boolean} True if the QualityLevel is enabled.
       */
      get: function get$$1() {
        return level.enabled_();
      },


      /**
       * Enable or disable the QualityLevel.
       *
       * @param {boolean} enable true to enable QualityLevel, false to disable.
       */
      set: function set$$1(enable) {
        level.enabled_(enable);
      }
    });

    return level;
  };

  /**
   * A list of QualityLevels.
   *
   * interface QualityLevelList : EventTarget {
   *   getter QualityLevel (unsigned long index);
   *   readonly attribute unsigned long length;
   *   readonly attribute long selectedIndex;
   *
   *   void addQualityLevel(QualityLevel qualityLevel)
   *   void removeQualityLevel(QualityLevel remove)
   *   QualityLevel? getQualityLevelById(DOMString id);
   *
   *   attribute EventHandler onchange;
   *   attribute EventHandler onaddqualitylevel;
   *   attribute EventHandler onremovequalitylevel;
   * };
   *
   * @extends videojs.EventTarget
   * @class QualityLevelList
   */

  var QualityLevelList = function (_videojs$EventTarget) {
    inherits(QualityLevelList, _videojs$EventTarget);

    function QualityLevelList() {
      var _ret;

      classCallCheck(this, QualityLevelList);

      var _this = possibleConstructorReturn(this, _videojs$EventTarget.call(this));

      var list = _this; // eslint-disable-line

      if (videojs.browser.IS_IE8) {
        list = document.createElement('custom');
        for (var prop in QualityLevelList.prototype) {
          if (prop !== 'constructor') {
            list[prop] = QualityLevelList.prototype[prop];
          }
        }
      }

      list.levels_ = [];
      list.selectedIndex_ = -1;

      /**
       * Get the index of the currently selected QualityLevel.
       *
       * @returns {number} The index of the selected QualityLevel. -1 if none selected.
       * @readonly
       */
      Object.defineProperty(list, 'selectedIndex', {
        get: function get$$1() {
          return list.selectedIndex_;
        }
      });

      /**
       * Get the length of the list of QualityLevels.
       *
       * @returns {number} The length of the list.
       * @readonly
       */
      Object.defineProperty(list, 'length', {
        get: function get$$1() {
          return list.levels_.length;
        }
      });

      return _ret = list, possibleConstructorReturn(_this, _ret);
    }

    /**
     * Adds a quality level to the list.
     *
     * @param {Representation|Object} representation The representation of the quality level
     * @param {string}   representation.id        Unique id of the QualityLevel
     * @param {number=}  representation.width     Resolution width of the QualityLevel
     * @param {number=}  representation.height    Resolution height of the QualityLevel
     * @param {number}   representation.bandwidth Bitrate of the QualityLevel
     * @param {Function} representation.enabled   Callback to enable/disable QualityLevel
     * @return {QualityLevel} the QualityLevel added to the list
     * @method addQualityLevel
     */


    QualityLevelList.prototype.addQualityLevel = function addQualityLevel(representation) {
      var qualityLevel = this.getQualityLevelById(representation.id);

      // Do not add duplicate quality levels
      if (qualityLevel) {
        return qualityLevel;
      }

      var index = this.levels_.length;

      qualityLevel = new QualityLevel(representation);

      if (!('' + index in this)) {
        Object.defineProperty(this, index, {
          get: function get$$1() {
            return this.levels_[index];
          }
        });
      }

      this.levels_.push(qualityLevel);

      this.trigger({
        qualityLevel: qualityLevel,
        type: 'addqualitylevel'
      });

      return qualityLevel;
    };

    /**
     * Removes a quality level from the list.
     *
     * @param {QualityLevel} remove QualityLevel to remove to the list.
     * @return {QualityLevel|null} the QualityLevel removed or null if nothing removed
     * @method removeQualityLevel
     */


    QualityLevelList.prototype.removeQualityLevel = function removeQualityLevel(qualityLevel) {
      var removed = null;

      for (var i = 0, l = this.length; i < l; i++) {
        if (this[i] === qualityLevel) {
          removed = this.levels_.splice(i, 1)[0];

          if (this.selectedIndex_ === i) {
            this.selectedIndex_ = -1;
          } else if (this.selectedIndex_ > i) {
            this.selectedIndex_--;
          }
          break;
        }
      }

      if (removed) {
        this.trigger({
          qualityLevel: qualityLevel,
          type: 'removequalitylevel'
        });
      }

      return removed;
    };

    /**
     * Searches for a QualityLevel with the given id.
     *
     * @param {string} id The id of the QualityLevel to find.
     * @return {QualityLevel|null} The QualityLevel with id, or null if not found.
     * @method getQualityLevelById
     */


    QualityLevelList.prototype.getQualityLevelById = function getQualityLevelById(id) {
      for (var i = 0, l = this.length; i < l; i++) {
        var level = this[i];

        if (level.id === id) {
          return level;
        }
      }
      return null;
    };

    /**
     * Resets the list of QualityLevels to empty
     *
     * @method dispose
     */


    QualityLevelList.prototype.dispose = function dispose() {
      this.selectedIndex_ = -1;
      this.levels_.length = 0;
    };

    return QualityLevelList;
  }(videojs.EventTarget);

  /**
   * change - The selected QualityLevel has changed.
   * addqualitylevel - A QualityLevel has been added to the QualityLevelList.
   * removequalitylevel - A QualityLevel has been removed from the QualityLevelList.
   */


  QualityLevelList.prototype.allowedEvents_ = {
    change: 'change',
    addqualitylevel: 'addqualitylevel',
    removequalitylevel: 'removequalitylevel'
  };

  // emulate attribute EventHandler support to allow for feature detection
  for (var event in QualityLevelList.prototype.allowedEvents_) {
    QualityLevelList.prototype['on' + event] = null;
  }

  // vjs 5/6 support
  var registerPlugin = videojs.registerPlugin || videojs.plugin;

  /**
   * Initialization function for the qualityLevels plugin. Sets up the QualityLevelList and
   * event handlers.
   *
   * @param {Player} player Player object.
   * @param {Object} options Plugin options object.
   * @function initPlugin
   */
  var initPlugin = function initPlugin(player, options) {
    var originalPluginFn = player.qualityLevels;

    var qualityLevelList = new QualityLevelList();

    var disposeHandler = function disposeHandler() {
      qualityLevelList.dispose();
      player.qualityLevels = originalPluginFn;
      player.off('dispose', disposeHandler);
    };

    player.on('dispose', disposeHandler);

    player.qualityLevels = function () {
      return qualityLevelList;
    };
    player.qualityLevels.VERSION = '__VERSION__';

    return qualityLevelList;
  };

  /**
   * A video.js plugin.
   *
   * In the plugin function, the value of `this` is a video.js `Player`
   * instance. You cannot rely on the player being in a "ready" state here,
   * depending on how the plugin is invoked. This may or may not be important
   * to you; if not, remove the wait for "ready"!
   *
   * @param {Object} options Plugin options object
   * @function qualityLevels
   */
  var qualityLevels = function qualityLevels(options) {
    return initPlugin(this, videojs.mergeOptions({}, options));
  };

  // Register the plugin with video.js.
  registerPlugin('qualityLevels', qualityLevels);

  // Include the version number.
  qualityLevels.VERSION = '__VERSION__';

  return qualityLevels;

})));
