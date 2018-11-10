/**
 * @license
 * Video.js 6.12.1 <http://videojs.com/>
 * Copyright Brightcove, Inc. <https://www.brightcove.com/>
 * Available under Apache License Version 2.0
 * <https://github.com/videojs/video.js/blob/master/LICENSE>
 *
 * Includes vtt.js <https://github.com/mozilla/vtt.js>
 * Available under Apache License Version 2.0
 * <https://github.com/mozilla/vtt.js/blob/master/LICENSE>
 */

(function (global, factory) {
	typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory() :
	typeof define === 'function' && define.amd ? define(factory) :
	(global.videojs = factory());
}(this, (function () {

var version = "6.12.1";

var commonjsGlobal = typeof window !== 'undefined' ? window : typeof global !== 'undefined' ? global : typeof self !== 'undefined' ? self : {};





function createCommonjsModule(fn, module) {
	return module = { exports: {} }, fn(module, module.exports), module.exports;
}

var win;

if (typeof window !== "undefined") {
    win = window;
} else if (typeof commonjsGlobal !== "undefined") {
    win = commonjsGlobal;
} else if (typeof self !== "undefined"){
    win = self;
} else {
    win = {};
}

var window_1 = win;

var empty = {};


var empty$1 = (Object.freeze || Object)({
	'default': empty
});

var minDoc = ( empty$1 && empty ) || empty$1;

var topLevel = typeof commonjsGlobal !== 'undefined' ? commonjsGlobal :
    typeof window !== 'undefined' ? window : {};


var doccy;

if (typeof document !== 'undefined') {
    doccy = document;
} else {
    doccy = topLevel['__GLOBAL_DOCUMENT_CACHE@4'];

    if (!doccy) {
        doccy = topLevel['__GLOBAL_DOCUMENT_CACHE@4'] = minDoc;
    }
}

var document_1 = doccy;

/**
 * @file browser.js
 * @module browser
 */
var USER_AGENT = window_1.navigator && window_1.navigator.userAgent || '';
var webkitVersionMap = /AppleWebKit\/([\d.]+)/i.exec(USER_AGENT);
var appleWebkitVersion = webkitVersionMap ? parseFloat(webkitVersionMap.pop()) : null;

/*
 * Device is an iPhone
 *
 * @type {Boolean}
 * @constant
 * @private
 */
var IS_IPAD = /iPad/i.test(USER_AGENT);

// The Facebook app's UIWebView identifies as both an iPhone and iPad, so
// to identify iPhones, we need to exclude iPads.
// http://artsy.github.io/blog/2012/10/18/the-perils-of-ios-user-agent-sniffing/
var IS_IPHONE = /iPhone/i.test(USER_AGENT) && !IS_IPAD;
var IS_IPOD = /iPod/i.test(USER_AGENT);
var IS_IOS = IS_IPHONE || IS_IPAD || IS_IPOD;

var IOS_VERSION = function () {
  var match = USER_AGENT.match(/OS (\d+)_/i);

  if (match && match[1]) {
    return match[1];
  }
  return null;
}();

var IS_ANDROID = /Android/i.test(USER_AGENT);
var ANDROID_VERSION = function () {
  // This matches Android Major.Minor.Patch versions
  // ANDROID_VERSION is Major.Minor as a Number, if Minor isn't available, then only Major is returned
  var match = USER_AGENT.match(/Android (\d+)(?:\.(\d+))?(?:\.(\d+))*/i);

  if (!match) {
    return null;
  }

  var major = match[1] && parseFloat(match[1]);
  var minor = match[2] && parseFloat(match[2]);

  if (major && minor) {
    return parseFloat(match[1] + '.' + match[2]);
  } else if (major) {
    return major;
  }
  return null;
}();

// Old Android is defined as Version older than 2.3, and requiring a webkit version of the android browser
var IS_OLD_ANDROID = IS_ANDROID && /webkit/i.test(USER_AGENT) && ANDROID_VERSION < 2.3;
var IS_NATIVE_ANDROID = IS_ANDROID && ANDROID_VERSION < 5 && appleWebkitVersion < 537;

var IS_FIREFOX = /Firefox/i.test(USER_AGENT);
var IS_EDGE = /Edge/i.test(USER_AGENT);
var IS_CHROME = !IS_EDGE && (/Chrome/i.test(USER_AGENT) || /CriOS/i.test(USER_AGENT));
var CHROME_VERSION = function () {
  var match = USER_AGENT.match(/(Chrome|CriOS)\/(\d+)/);

  if (match && match[2]) {
    return parseFloat(match[2]);
  }
  return null;
}();
var IS_IE8 = /MSIE\s8\.0/.test(USER_AGENT);
var IE_VERSION = function () {
  var result = /MSIE\s(\d+)\.\d/.exec(USER_AGENT);
  var version = result && parseFloat(result[1]);

  if (!version && /Trident\/7.0/i.test(USER_AGENT) && /rv:11.0/.test(USER_AGENT)) {
    // IE 11 has a different user agent string than other IE versions
    version = 11.0;
  }

  return version;
}();

var IS_SAFARI = /Safari/i.test(USER_AGENT) && !IS_CHROME && !IS_ANDROID && !IS_EDGE;
var IS_ANY_SAFARI = (IS_SAFARI || IS_IOS) && !IS_CHROME;

var TOUCH_ENABLED = isReal() && ('ontouchstart' in window_1 || window_1.navigator.maxTouchPoints || window_1.DocumentTouch && window_1.document instanceof window_1.DocumentTouch);

var BACKGROUND_SIZE_SUPPORTED = isReal() && 'backgroundSize' in window_1.document.createElement('video').style;

var browser = (Object.freeze || Object)({
	IS_IPAD: IS_IPAD,
	IS_IPHONE: IS_IPHONE,
	IS_IPOD: IS_IPOD,
	IS_IOS: IS_IOS,
	IOS_VERSION: IOS_VERSION,
	IS_ANDROID: IS_ANDROID,
	ANDROID_VERSION: ANDROID_VERSION,
	IS_OLD_ANDROID: IS_OLD_ANDROID,
	IS_NATIVE_ANDROID: IS_NATIVE_ANDROID,
	IS_FIREFOX: IS_FIREFOX,
	IS_EDGE: IS_EDGE,
	IS_CHROME: IS_CHROME,
	CHROME_VERSION: CHROME_VERSION,
	IS_IE8: IS_IE8,
	IE_VERSION: IE_VERSION,
	IS_SAFARI: IS_SAFARI,
	IS_ANY_SAFARI: IS_ANY_SAFARI,
	TOUCH_ENABLED: TOUCH_ENABLED,
	BACKGROUND_SIZE_SUPPORTED: BACKGROUND_SIZE_SUPPORTED
});

var _typeof = typeof Symbol === "function" && typeof Symbol.iterator === "symbol" ? function (obj) {
  return typeof obj;
} : function (obj) {
  return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj;
};











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











var taggedTemplateLiteralLoose = function (strings, raw) {
  strings.raw = raw;
  return strings;
};

/**
 * @file obj.js
 * @module obj
 */

/**
 * @callback obj:EachCallback
 *
 * @param {Mixed} value
 *        The current key for the object that is being iterated over.
 *
 * @param {string} key
 *        The current key-value for object that is being iterated over
 */

/**
 * @callback obj:ReduceCallback
 *
 * @param {Mixed} accum
 *        The value that is accumulating over the reduce loop.
 *
 * @param {Mixed} value
 *        The current key for the object that is being iterated over.
 *
 * @param {string} key
 *        The current key-value for object that is being iterated over
 *
 * @return {Mixed}
 *         The new accumulated value.
 */
var toString = Object.prototype.toString;

/**
 * Get the keys of an Object
 *
 * @param {Object}
 *        The Object to get the keys from
 *
 * @return {string[]}
 *         An array of the keys from the object. Returns an empty array if the
 *         object passed in was invalid or had no keys.
 *
 * @private
 */
var keys = function keys(object) {
  return isObject(object) ? Object.keys(object) : [];
};

/**
 * Array-like iteration for objects.
 *
 * @param {Object} object
 *        The object to iterate over
 *
 * @param {obj:EachCallback} fn
 *        The callback function which is called for each key in the object.
 */
function each(object, fn) {
  keys(object).forEach(function (key) {
    return fn(object[key], key);
  });
}

/**
 * Array-like reduce for objects.
 *
 * @param {Object} object
 *        The Object that you want to reduce.
 *
 * @param {Function} fn
 *         A callback function which is called for each key in the object. It
 *         receives the accumulated value and the per-iteration value and key
 *         as arguments.
 *
 * @param {Mixed} [initial = 0]
 *        Starting value
 *
 * @return {Mixed}
 *         The final accumulated value.
 */
function reduce(object, fn) {
  var initial = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 0;

  return keys(object).reduce(function (accum, key) {
    return fn(accum, object[key], key);
  }, initial);
}

/**
 * Object.assign-style object shallow merge/extend.
 *
 * @param  {Object} target
 * @param  {Object} ...sources
 * @return {Object}
 */
function assign(target) {
  for (var _len = arguments.length, sources = Array(_len > 1 ? _len - 1 : 0), _key = 1; _key < _len; _key++) {
    sources[_key - 1] = arguments[_key];
  }

  if (Object.assign) {
    return Object.assign.apply(Object, [target].concat(sources));
  }

  sources.forEach(function (source) {
    if (!source) {
      return;
    }

    each(source, function (value, key) {
      target[key] = value;
    });
  });

  return target;
}

/**
 * Returns whether a value is an object of any kind - including DOM nodes,
 * arrays, regular expressions, etc. Not functions, though.
 *
 * This avoids the gotcha where using `typeof` on a `null` value
 * results in `'object'`.
 *
 * @param  {Object} value
 * @return {Boolean}
 */
function isObject(value) {
  return !!value && (typeof value === 'undefined' ? 'undefined' : _typeof(value)) === 'object';
}

/**
 * Returns whether an object appears to be a "plain" object - that is, a
 * direct instance of `Object`.
 *
 * @param  {Object} value
 * @return {Boolean}
 */
function isPlain(value) {
  return isObject(value) && toString.call(value) === '[object Object]' && value.constructor === Object;
}

/**
 * @file log.js
 * @module log
 */
var log = void 0;

// This is the private tracking variable for logging level.
var level = 'info';

// This is the private tracking variable for the logging history.
var history = [];

/**
 * Log messages to the console and history based on the type of message
 *
 * @private
 * @param  {string} type
 *         The name of the console method to use.
 *
 * @param  {Array} args
 *         The arguments to be passed to the matching console method.
 *
 * @param  {boolean} [stringify]
 *         By default, only old IEs should get console argument stringification,
 *         but this is exposed as a parameter to facilitate testing.
 */
var logByType = function logByType(type, args) {
  var stringify = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : !!IE_VERSION && IE_VERSION < 11;

  var lvl = log.levels[level];
  var lvlRegExp = new RegExp('^(' + lvl + ')$');

  if (type !== 'log') {

    // Add the type to the front of the message when it's not "log".
    args.unshift(type.toUpperCase() + ':');
  }

  // Add a clone of the args at this point to history.
  if (history) {
    history.push([].concat(args));
  }

  // Add console prefix after adding to history.
  args.unshift('VIDEOJS:');

  // If there's no console then don't try to output messages, but they will
  // still be stored in history.
  if (!window_1.console) {
    return;
  }

  // Was setting these once outside of this function, but containing them
  // in the function makes it easier to test cases where console doesn't exist
  // when the module is executed.
  var fn = window_1.console[type];

  if (!fn && type === 'debug') {
    // Certain browsers don't have support for console.debug. For those, we
    // should default to the closest comparable log.
    fn = window_1.console.info || window_1.console.log;
  }

  // Bail out if there's no console or if this type is not allowed by the
  // current logging level.
  if (!fn || !lvl || !lvlRegExp.test(type)) {
    return;
  }

  // IEs previous to 11 log objects uselessly as "[object Object]"; so, JSONify
  // objects and arrays for those less-capable browsers.
  if (stringify) {
    args = args.map(function (a) {
      if (isObject(a) || Array.isArray(a)) {
        try {
          return JSON.stringify(a);
        } catch (x) {
          return String(a);
        }
      }

      // Cast to string before joining, so we get null and undefined explicitly
      // included in output (as we would in a modern console).
      return String(a);
    }).join(' ');
  }

  // Old IE versions do not allow .apply() for console methods (they are
  // reported as objects rather than functions).
  if (!fn.apply) {
    fn(args);
  } else {
    fn[Array.isArray(args) ? 'apply' : 'call'](window_1.console, args);
  }
};

/**
 * Logs plain debug messages. Similar to `console.log`.
 *
 * @class
 * @param    {Mixed[]} args
 *           One or more messages or objects that should be logged.
 */
log = function log() {
  for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
    args[_key] = arguments[_key];
  }

  logByType('log', args);
};

/**
 * Enumeration of available logging levels, where the keys are the level names
 * and the values are `|`-separated strings containing logging methods allowed
 * in that logging level. These strings are used to create a regular expression
 * matching the function name being called.
 *
 * Levels provided by video.js are:
 *
 * - `off`: Matches no calls. Any value that can be cast to `false` will have
 *   this effect. The most restrictive.
 * - `all`: Matches only Video.js-provided functions (`debug`, `log`,
 *   `log.warn`, and `log.error`).
 * - `debug`: Matches `log.debug`, `log`, `log.warn`, and `log.error` calls.
 * - `info` (default): Matches `log`, `log.warn`, and `log.error` calls.
 * - `warn`: Matches `log.warn` and `log.error` calls.
 * - `error`: Matches only `log.error` calls.
 *
 * @type {Object}
 */
log.levels = {
  all: 'debug|log|warn|error',
  off: '',
  debug: 'debug|log|warn|error',
  info: 'log|warn|error',
  warn: 'warn|error',
  error: 'error',
  DEFAULT: level
};

/**
 * Get or set the current logging level. If a string matching a key from
 * {@link log.levels} is provided, acts as a setter. Regardless of argument,
 * returns the current logging level.
 *
 * @param  {string} [lvl]
 *         Pass to set a new logging level.
 *
 * @return {string}
 *         The current logging level.
 */
log.level = function (lvl) {
  if (typeof lvl === 'string') {
    if (!log.levels.hasOwnProperty(lvl)) {
      throw new Error('"' + lvl + '" in not a valid log level');
    }
    level = lvl;
  }
  return level;
};

/**
 * Returns an array containing everything that has been logged to the history.
 *
 * This array is a shallow clone of the internal history record. However, its
 * contents are _not_ cloned; so, mutating objects inside this array will
 * mutate them in history.
 *
 * @return {Array}
 */
log.history = function () {
  return history ? [].concat(history) : [];
};

/**
 * Clears the internal history tracking, but does not prevent further history
 * tracking.
 */
log.history.clear = function () {
  if (history) {
    history.length = 0;
  }
};

/**
 * Disable history tracking if it is currently enabled.
 */
log.history.disable = function () {
  if (history !== null) {
    history.length = 0;
    history = null;
  }
};

/**
 * Enable history tracking if it is currently disabled.
 */
log.history.enable = function () {
  if (history === null) {
    history = [];
  }
};

/**
 * Logs error messages. Similar to `console.error`.
 *
 * @param {Mixed[]} args
 *        One or more messages or objects that should be logged as an error
 */
log.error = function () {
  for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
    args[_key2] = arguments[_key2];
  }

  return logByType('error', args);
};

/**
 * Logs warning messages. Similar to `console.warn`.
 *
 * @param {Mixed[]} args
 *        One or more messages or objects that should be logged as a warning.
 */
log.warn = function () {
  for (var _len3 = arguments.length, args = Array(_len3), _key3 = 0; _key3 < _len3; _key3++) {
    args[_key3] = arguments[_key3];
  }

  return logByType('warn', args);
};

/**
 * Logs debug messages. Similar to `console.debug`, but may also act as a comparable
 * log if `console.debug` is not available
 *
 * @param {Mixed[]} args
 *        One or more messages or objects that should be logged as debug.
 */
log.debug = function () {
  for (var _len4 = arguments.length, args = Array(_len4), _key4 = 0; _key4 < _len4; _key4++) {
    args[_key4] = arguments[_key4];
  }

  return logByType('debug', args);
};

var log$1 = log;

function clean (s) {
  return s.replace(/\n\r?\s*/g, '')
}


var tsml = function tsml (sa) {
  var s = ''
    , i = 0;

  for (; i < arguments.length; i++)
    s += clean(sa[i]) + (arguments[i + 1] || '');

  return s
};

/**
 * @file computed-style.js
 * @module computed-style
 */
/**
 * A safe getComputedStyle with an IE8 fallback.
 *
 * This is needed because in Firefox, if the player is loaded in an iframe with
 * `display:none`, then `getComputedStyle` returns `null`, so, we do a null-check to
 * make sure  that the player doesn't break in these cases.
 *
 * @param {Element} el
 *        The element you want the computed style of
 *
 * @param {string} prop
 *        The property name you want
 *
 * @see https://bugzilla.mozilla.org/show_bug.cgi?id=548397
 *
 * @static
 * @const
 */
function computedStyle(el, prop) {
  if (!el || !prop) {
    return '';
  }

  if (typeof window_1.getComputedStyle === 'function') {
    var cs = window_1.getComputedStyle(el);

    return cs ? cs[prop] : '';
  }

  return el.currentStyle[prop] || '';
}

var _templateObject = taggedTemplateLiteralLoose(['Setting attributes in the second argument of createEl()\n                has been deprecated. Use the third argument instead.\n                createEl(type, properties, attributes). Attempting to set ', ' to ', '.'], ['Setting attributes in the second argument of createEl()\n                has been deprecated. Use the third argument instead.\n                createEl(type, properties, attributes). Attempting to set ', ' to ', '.']);

/**
 * @file dom.js
 * @module dom
 */
/**
 * Detect if a value is a string with any non-whitespace characters.
 *
 * @param {string} str
 *        The string to check
 *
 * @return {boolean}
 *         - True if the string is non-blank
 *         - False otherwise
 *
 */
function isNonBlankString(str) {
  return typeof str === 'string' && /\S/.test(str);
}

/**
 * Throws an error if the passed string has whitespace. This is used by
 * class methods to be relatively consistent with the classList API.
 *
 * @param {string} str
 *         The string to check for whitespace.
 *
 * @throws {Error}
 *         Throws an error if there is whitespace in the string.
 *
 */
function throwIfWhitespace(str) {
  if (/\s/.test(str)) {
    throw new Error('class has illegal whitespace characters');
  }
}

/**
 * Produce a regular expression for matching a className within an elements className.
 *
 * @param {string} className
 *         The className to generate the RegExp for.
 *
 * @return {RegExp}
 *         The RegExp that will check for a specific `className` in an elements
 *         className.
 */
function classRegExp(className) {
  return new RegExp('(^|\\s)' + className + '($|\\s)');
}

/**
 * Whether the current DOM interface appears to be real.
 *
 * @return {Boolean}
 */
function isReal() {
  return (

    // Both document and window will never be undefined thanks to `global`.
    document_1 === window_1.document &&

    // In IE < 9, DOM methods return "object" as their type, so all we can
    // confidently check is that it exists.
    typeof document_1.createElement !== 'undefined'
  );
}

/**
 * Determines, via duck typing, whether or not a value is a DOM element.
 *
 * @param {Mixed} value
 *        The thing to check
 *
 * @return {boolean}
 *         - True if it is a DOM element
 *         - False otherwise
 */
function isEl(value) {
  return isObject(value) && value.nodeType === 1;
}

/**
 * Determines if the current DOM is embedded in an iframe.
 *
 * @return {boolean}
 *
 */
function isInFrame() {

  // We need a try/catch here because Safari will throw errors when attempting
  // to get either `parent` or `self`
  try {
    return window_1.parent !== window_1.self;
  } catch (x) {
    return true;
  }
}

/**
 * Creates functions to query the DOM using a given method.
 *
 * @param {string} method
 *         The method to create the query with.
 *
 * @return {Function}
 *         The query method
 */
function createQuerier(method) {
  return function (selector, context) {
    if (!isNonBlankString(selector)) {
      return document_1[method](null);
    }
    if (isNonBlankString(context)) {
      context = document_1.querySelector(context);
    }

    var ctx = isEl(context) ? context : document_1;

    return ctx[method] && ctx[method](selector);
  };
}

/**
 * Creates an element and applies properties.
 *
 * @param {string} [tagName='div']
 *         Name of tag to be created.
 *
 * @param {Object} [properties={}]
 *         Element properties to be applied.
 *
 * @param {Object} [attributes={}]
 *         Element attributes to be applied.
 *
 * @param {String|Element|TextNode|Array|Function} [content]
 *         Contents for the element (see: {@link dom:normalizeContent})
 *
 * @return {Element}
 *         The element that was created.
 */
function createEl() {
  var tagName = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'div';
  var properties = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var attributes = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};
  var content = arguments[3];

  var el = document_1.createElement(tagName);

  Object.getOwnPropertyNames(properties).forEach(function (propName) {
    var val = properties[propName];

    // See #2176
    // We originally were accepting both properties and attributes in the
    // same object, but that doesn't work so well.
    if (propName.indexOf('aria-') !== -1 || propName === 'role' || propName === 'type') {
      log$1.warn(tsml(_templateObject, propName, val));
      el.setAttribute(propName, val);

      // Handle textContent since it's not supported everywhere and we have a
      // method for it.
    } else if (propName === 'textContent') {
      textContent(el, val);
    } else {
      el[propName] = val;
    }
  });

  Object.getOwnPropertyNames(attributes).forEach(function (attrName) {
    el.setAttribute(attrName, attributes[attrName]);
  });

  if (content) {
    appendContent(el, content);
  }

  return el;
}

/**
 * Injects text into an element, replacing any existing contents entirely.
 *
 * @param {Element} el
 *        The element to add text content into
 *
 * @param {string} text
 *        The text content to add.
 *
 * @return {Element}
 *         The element with added text content.
 */
function textContent(el, text) {
  if (typeof el.textContent === 'undefined') {
    el.innerText = text;
  } else {
    el.textContent = text;
  }
  return el;
}

/**
 * Insert an element as the first child node of another
 *
 * @param {Element} child
 *        Element to insert
 *
 * @param {Element} parent
 *        Element to insert child into
 */
function prependTo(child, parent) {
  if (parent.firstChild) {
    parent.insertBefore(child, parent.firstChild);
  } else {
    parent.appendChild(child);
  }
}

/**
 * Check if an element has a CSS class
 *
 * @param {Element} element
 *        Element to check
 *
 * @param {string} classToCheck
 *        Class name to check for
 *
 * @return {boolean}
 *         - True if the element had the class
 *         - False otherwise.
 *
 * @throws {Error}
 *         Throws an error if `classToCheck` has white space.
 */
function hasClass(element, classToCheck) {
  throwIfWhitespace(classToCheck);
  if (element.classList) {
    return element.classList.contains(classToCheck);
  }
  return classRegExp(classToCheck).test(element.className);
}

/**
 * Add a CSS class name to an element
 *
 * @param {Element} element
 *        Element to add class name to.
 *
 * @param {string} classToAdd
 *        Class name to add.
 *
 * @return {Element}
 *         The dom element with the added class name.
 */
function addClass(element, classToAdd) {
  if (element.classList) {
    element.classList.add(classToAdd);

    // Don't need to `throwIfWhitespace` here because `hasElClass` will do it
    // in the case of classList not being supported.
  } else if (!hasClass(element, classToAdd)) {
    element.className = (element.className + ' ' + classToAdd).trim();
  }

  return element;
}

/**
 * Remove a CSS class name from an element
 *
 * @param {Element} element
 *        Element to remove a class name from.
 *
 * @param {string} classToRemove
 *        Class name to remove
 *
 * @return {Element}
 *         The dom element with class name removed.
 */
function removeClass(element, classToRemove) {
  if (element.classList) {
    element.classList.remove(classToRemove);
  } else {
    throwIfWhitespace(classToRemove);
    element.className = element.className.split(/\s+/).filter(function (c) {
      return c !== classToRemove;
    }).join(' ');
  }

  return element;
}

/**
 * The callback definition for toggleElClass.
 *
 * @callback Dom~PredicateCallback
 * @param {Element} element
 *        The DOM element of the Component.
 *
 * @param {string} classToToggle
 *        The `className` that wants to be toggled
 *
 * @return {boolean|undefined}
 *         - If true the `classToToggle` will get added to `element`.
 *         - If false the `classToToggle` will get removed from `element`.
 *         - If undefined this callback will be ignored
 */

/**
 * Adds or removes a CSS class name on an element depending on an optional
 * condition or the presence/absence of the class name.
 *
 * @param {Element} element
 *        The element to toggle a class name on.
 *
 * @param {string} classToToggle
 *        The class that should be toggled
 *
 * @param {boolean|PredicateCallback} [predicate]
 *        See the return value for {@link Dom~PredicateCallback}
 *
 * @return {Element}
 *         The element with a class that has been toggled.
 */
function toggleClass(element, classToToggle, predicate) {

  // This CANNOT use `classList` internally because IE does not support the
  // second parameter to the `classList.toggle()` method! Which is fine because
  // `classList` will be used by the add/remove functions.
  var has = hasClass(element, classToToggle);

  if (typeof predicate === 'function') {
    predicate = predicate(element, classToToggle);
  }

  if (typeof predicate !== 'boolean') {
    predicate = !has;
  }

  // If the necessary class operation matches the current state of the
  // element, no action is required.
  if (predicate === has) {
    return;
  }

  if (predicate) {
    addClass(element, classToToggle);
  } else {
    removeClass(element, classToToggle);
  }

  return element;
}

/**
 * Apply attributes to an HTML element.
 *
 * @param {Element} el
 *        Element to add attributes to.
 *
 * @param {Object} [attributes]
 *        Attributes to be applied.
 */
function setAttributes(el, attributes) {
  Object.getOwnPropertyNames(attributes).forEach(function (attrName) {
    var attrValue = attributes[attrName];

    if (attrValue === null || typeof attrValue === 'undefined' || attrValue === false) {
      el.removeAttribute(attrName);
    } else {
      el.setAttribute(attrName, attrValue === true ? '' : attrValue);
    }
  });
}

/**
 * Get an element's attribute values, as defined on the HTML tag
 * Attributes are not the same as properties. They're defined on the tag
 * or with setAttribute (which shouldn't be used with HTML)
 * This will return true or false for boolean attributes.
 *
 * @param {Element} tag
 *        Element from which to get tag attributes.
 *
 * @return {Object}
 *         All attributes of the element.
 */
function getAttributes(tag) {
  var obj = {};

  // known boolean attributes
  // we can check for matching boolean properties, but older browsers
  // won't know about HTML5 boolean attributes that we still read from
  var knownBooleans = ',' + 'autoplay,controls,playsinline,loop,muted,default,defaultMuted' + ',';

  if (tag && tag.attributes && tag.attributes.length > 0) {
    var attrs = tag.attributes;

    for (var i = attrs.length - 1; i >= 0; i--) {
      var attrName = attrs[i].name;
      var attrVal = attrs[i].value;

      // check for known booleans
      // the matching element property will return a value for typeof
      if (typeof tag[attrName] === 'boolean' || knownBooleans.indexOf(',' + attrName + ',') !== -1) {
        // the value of an included boolean attribute is typically an empty
        // string ('') which would equal false if we just check for a false value.
        // we also don't want support bad code like autoplay='false'
        attrVal = attrVal !== null ? true : false;
      }

      obj[attrName] = attrVal;
    }
  }

  return obj;
}

/**
 * Get the value of an element's attribute
 *
 * @param {Element} el
 *        A DOM element
 *
 * @param {string} attribute
 *        Attribute to get the value of
 *
 * @return {string}
 *         value of the attribute
 */
function getAttribute(el, attribute) {
  return el.getAttribute(attribute);
}

/**
 * Set the value of an element's attribute
 *
 * @param {Element} el
 *        A DOM element
 *
 * @param {string} attribute
 *        Attribute to set
 *
 * @param {string} value
 *        Value to set the attribute to
 */
function setAttribute(el, attribute, value) {
  el.setAttribute(attribute, value);
}

/**
 * Remove an element's attribute
 *
 * @param {Element} el
 *        A DOM element
 *
 * @param {string} attribute
 *        Attribute to remove
 */
function removeAttribute(el, attribute) {
  el.removeAttribute(attribute);
}

/**
 * Attempt to block the ability to select text while dragging controls
 */
function blockTextSelection() {
  document_1.body.focus();
  document_1.onselectstart = function () {
    return false;
  };
}

/**
 * Turn off text selection blocking
 */
function unblockTextSelection() {
  document_1.onselectstart = function () {
    return true;
  };
}

/**
 * Identical to the native `getBoundingClientRect` function, but ensures that
 * the method is supported at all (it is in all browsers we claim to support)
 * and that the element is in the DOM before continuing.
 *
 * This wrapper function also shims properties which are not provided by some
 * older browsers (namely, IE8).
 *
 * Additionally, some browsers do not support adding properties to a
 * `ClientRect`/`DOMRect` object; so, we shallow-copy it with the standard
 * properties (except `x` and `y` which are not widely supported). This helps
 * avoid implementations where keys are non-enumerable.
 *
 * @param  {Element} el
 *         Element whose `ClientRect` we want to calculate.
 *
 * @return {Object|undefined}
 *         Always returns a plain
 */
function getBoundingClientRect(el) {
  if (el && el.getBoundingClientRect && el.parentNode) {
    var rect = el.getBoundingClientRect();
    var result = {};

    ['bottom', 'height', 'left', 'right', 'top', 'width'].forEach(function (k) {
      if (rect[k] !== undefined) {
        result[k] = rect[k];
      }
    });

    if (!result.height) {
      result.height = parseFloat(computedStyle(el, 'height'));
    }

    if (!result.width) {
      result.width = parseFloat(computedStyle(el, 'width'));
    }

    return result;
  }
}

/**
 * The postion of a DOM element on the page.
 *
 * @typedef {Object} module:dom~Position
 *
 * @property {number} left
 *           Pixels to the left
 *
 * @property {number} top
 *           Pixels on top
 */

/**
 * Offset Left.
 * getBoundingClientRect technique from
 * John Resig
 *
 * @see http://ejohn.org/blog/getboundingclientrect-is-awesome/
 *
 * @param {Element} el
 *        Element from which to get offset
 *
 * @return {module:dom~Position}
 *         The position of the element that was passed in.
 */
function findPosition(el) {
  var box = void 0;

  if (el.getBoundingClientRect && el.parentNode) {
    box = el.getBoundingClientRect();
  }

  if (!box) {
    return {
      left: 0,
      top: 0
    };
  }

  var docEl = document_1.documentElement;
  var body = document_1.body;

  var clientLeft = docEl.clientLeft || body.clientLeft || 0;
  var scrollLeft = window_1.pageXOffset || body.scrollLeft;
  var left = box.left + scrollLeft - clientLeft;

  var clientTop = docEl.clientTop || body.clientTop || 0;
  var scrollTop = window_1.pageYOffset || body.scrollTop;
  var top = box.top + scrollTop - clientTop;

  // Android sometimes returns slightly off decimal values, so need to round
  return {
    left: Math.round(left),
    top: Math.round(top)
  };
}

/**
 * x and y coordinates for a dom element or mouse pointer
 *
 * @typedef {Object} Dom~Coordinates
 *
 * @property {number} x
 *           x coordinate in pixels
 *
 * @property {number} y
 *           y coordinate in pixels
 */

/**
 * Get pointer position in element
 * Returns an object with x and y coordinates.
 * The base on the coordinates are the bottom left of the element.
 *
 * @param {Element} el
 *        Element on which to get the pointer position on
 *
 * @param {EventTarget~Event} event
 *        Event object
 *
 * @return {Dom~Coordinates}
 *         A Coordinates object corresponding to the mouse position.
 *
 */
function getPointerPosition(el, event) {
  var position = {};
  var box = findPosition(el);
  var boxW = el.offsetWidth;
  var boxH = el.offsetHeight;

  var boxY = box.top;
  var boxX = box.left;
  var pageY = event.pageY;
  var pageX = event.pageX;

  if (event.changedTouches) {
    pageX = event.changedTouches[0].pageX;
    pageY = event.changedTouches[0].pageY;
  }

  position.y = Math.max(0, Math.min(1, (boxY - pageY + boxH) / boxH));
  position.x = Math.max(0, Math.min(1, (pageX - boxX) / boxW));

  return position;
}

/**
 * Determines, via duck typing, whether or not a value is a text node.
 *
 * @param {Mixed} value
 *        Check if this value is a text node.
 *
 * @return {boolean}
 *         - True if it is a text node
 *         - False otherwise
 */
function isTextNode(value) {
  return isObject(value) && value.nodeType === 3;
}

/**
 * Empties the contents of an element.
 *
 * @param {Element} el
 *        The element to empty children from
 *
 * @return {Element}
 *         The element with no children
 */
function emptyEl(el) {
  while (el.firstChild) {
    el.removeChild(el.firstChild);
  }
  return el;
}

/**
 * Normalizes content for eventual insertion into the DOM.
 *
 * This allows a wide range of content definition methods, but protects
 * from falling into the trap of simply writing to `innerHTML`, which is
 * an XSS concern.
 *
 * The content for an element can be passed in multiple types and
 * combinations, whose behavior is as follows:
 *
 * @param {String|Element|TextNode|Array|Function} content
 *        - String: Normalized into a text node.
 *        - Element/TextNode: Passed through.
 *        - Array: A one-dimensional array of strings, elements, nodes, or functions
 *          (which return single strings, elements, or nodes).
 *        - Function: If the sole argument, is expected to produce a string, element,
 *          node, or array as defined above.
 *
 * @return {Array}
 *         All of the content that was passed in normalized.
 */
function normalizeContent(content) {

  // First, invoke content if it is a function. If it produces an array,
  // that needs to happen before normalization.
  if (typeof content === 'function') {
    content = content();
  }

  // Next up, normalize to an array, so one or many items can be normalized,
  // filtered, and returned.
  return (Array.isArray(content) ? content : [content]).map(function (value) {

    // First, invoke value if it is a function to produce a new value,
    // which will be subsequently normalized to a Node of some kind.
    if (typeof value === 'function') {
      value = value();
    }

    if (isEl(value) || isTextNode(value)) {
      return value;
    }

    if (typeof value === 'string' && /\S/.test(value)) {
      return document_1.createTextNode(value);
    }
  }).filter(function (value) {
    return value;
  });
}

/**
 * Normalizes and appends content to an element.
 *
 * @param {Element} el
 *        Element to append normalized content to.
 *
 *
 * @param {String|Element|TextNode|Array|Function} content
 *        See the `content` argument of {@link dom:normalizeContent}
 *
 * @return {Element}
 *         The element with appended normalized content.
 */
function appendContent(el, content) {
  normalizeContent(content).forEach(function (node) {
    return el.appendChild(node);
  });
  return el;
}

/**
 * Normalizes and inserts content into an element; this is identical to
 * `appendContent()`, except it empties the element first.
 *
 * @param {Element} el
 *        Element to insert normalized content into.
 *
 * @param {String|Element|TextNode|Array|Function} content
 *        See the `content` argument of {@link dom:normalizeContent}
 *
 * @return {Element}
 *         The element with inserted normalized content.
 *
 */
function insertContent(el, content) {
  return appendContent(emptyEl(el), content);
}

/**
 * Check if event was a single left click
 *
 * @param {EventTarget~Event} event
 *        Event object
 *
 * @return {boolean}
 *         - True if a left click
 *         - False if not a left click
 */
function isSingleLeftClick(event) {
  // Note: if you create something draggable, be sure to
  // call it on both `mousedown` and `mousemove` event,
  // otherwise `mousedown` should be enough for a button

  if (event.button === undefined && event.buttons === undefined) {
    // Why do we need `buttons` ?
    // Because, middle mouse sometimes have this:
    // e.button === 0 and e.buttons === 4
    // Furthermore, we want to prevent combination click, something like
    // HOLD middlemouse then left click, that would be
    // e.button === 0, e.buttons === 5
    // just `button` is not gonna work

    // Alright, then what this block does ?
    // this is for chrome `simulate mobile devices`
    // I want to support this as well

    return true;
  }

  if (event.button === 0 && event.buttons === undefined) {
    // Touch screen, sometimes on some specific device, `buttons`
    // doesn't have anything (safari on ios, blackberry...)

    return true;
  }

  if (IE_VERSION === 9) {
    // Ignore IE9

    return true;
  }

  if (event.button !== 0 || event.buttons !== 1) {
    // This is the reason we have those if else block above
    // if any special case we can catch and let it slide
    // we do it above, when get to here, this definitely
    // is-not-left-click

    return false;
  }

  return true;
}

/**
 * Finds a single DOM element matching `selector` within the optional
 * `context` of another DOM element (defaulting to `document`).
 *
 * @param {string} selector
 *        A valid CSS selector, which will be passed to `querySelector`.
 *
 * @param {Element|String} [context=document]
 *        A DOM element within which to query. Can also be a selector
 *        string in which case the first matching element will be used
 *        as context. If missing (or no element matches selector), falls
 *        back to `document`.
 *
 * @return {Element|null}
 *         The element that was found or null.
 */
var $ = createQuerier('querySelector');

/**
 * Finds a all DOM elements matching `selector` within the optional
 * `context` of another DOM element (defaulting to `document`).
 *
 * @param {string} selector
 *           A valid CSS selector, which will be passed to `querySelectorAll`.
 *
 * @param {Element|String} [context=document]
 *           A DOM element within which to query. Can also be a selector
 *           string in which case the first matching element will be used
 *           as context. If missing (or no element matches selector), falls
 *           back to `document`.
 *
 * @return {NodeList}
 *         A element list of elements that were found. Will be empty if none were found.
 *
 */
var $$ = createQuerier('querySelectorAll');



var Dom = (Object.freeze || Object)({
	isReal: isReal,
	isEl: isEl,
	isInFrame: isInFrame,
	createEl: createEl,
	textContent: textContent,
	prependTo: prependTo,
	hasClass: hasClass,
	addClass: addClass,
	removeClass: removeClass,
	toggleClass: toggleClass,
	setAttributes: setAttributes,
	getAttributes: getAttributes,
	getAttribute: getAttribute,
	setAttribute: setAttribute,
	removeAttribute: removeAttribute,
	blockTextSelection: blockTextSelection,
	unblockTextSelection: unblockTextSelection,
	getBoundingClientRect: getBoundingClientRect,
	findPosition: findPosition,
	getPointerPosition: getPointerPosition,
	isTextNode: isTextNode,
	emptyEl: emptyEl,
	normalizeContent: normalizeContent,
	appendContent: appendContent,
	insertContent: insertContent,
	isSingleLeftClick: isSingleLeftClick,
	$: $,
	$$: $$
});

/**
 * @file guid.js
 * @module guid
 */

/**
 * Unique ID for an element or function
 * @type {Number}
 */
var _guid = 1;

/**
 * Get a unique auto-incrementing ID by number that has not been returned before.
 *
 * @return {number}
 *         A new unique ID.
 */
function newGUID() {
  return _guid++;
}

/**
 * @file dom-data.js
 * @module dom-data
 */
/**
 * Element Data Store.
 *
 * Allows for binding data to an element without putting it directly on the
 * element. Ex. Event listeners are stored here.
 * (also from jsninja.com, slightly modified and updated for closure compiler)
 *
 * @type {Object}
 * @private
 */
var elData = {};

/*
 * Unique attribute name to store an element's guid in
 *
 * @type {String}
 * @constant
 * @private
 */
var elIdAttr = 'vdata' + new Date().getTime();

/**
 * Returns the cache object where data for an element is stored
 *
 * @param {Element} el
 *        Element to store data for.
 *
 * @return {Object}
 *         The cache object for that el that was passed in.
 */
function getData(el) {
  var id = el[elIdAttr];

  if (!id) {
    id = el[elIdAttr] = newGUID();
  }

  if (!elData[id]) {
    elData[id] = {};
  }

  return elData[id];
}

/**
 * Returns whether or not an element has cached data
 *
 * @param {Element} el
 *        Check if this element has cached data.
 *
 * @return {boolean}
 *         - True if the DOM element has cached data.
 *         - False otherwise.
 */
function hasData(el) {
  var id = el[elIdAttr];

  if (!id) {
    return false;
  }

  return !!Object.getOwnPropertyNames(elData[id]).length;
}

/**
 * Delete data for the element from the cache and the guid attr from getElementById
 *
 * @param {Element} el
 *        Remove cached data for this element.
 */
function removeData(el) {
  var id = el[elIdAttr];

  if (!id) {
    return;
  }

  // Remove all stored data
  delete elData[id];

  // Remove the elIdAttr property from the DOM node
  try {
    delete el[elIdAttr];
  } catch (e) {
    if (el.removeAttribute) {
      el.removeAttribute(elIdAttr);
    } else {
      // IE doesn't appear to support removeAttribute on the document element
      el[elIdAttr] = null;
    }
  }
}

/**
 * @file events.js. An Event System (John Resig - Secrets of a JS Ninja http://jsninja.com/)
 * (Original book version wasn't completely usable, so fixed some things and made Closure Compiler compatible)
 * This should work very similarly to jQuery's events, however it's based off the book version which isn't as
 * robust as jquery's, so there's probably some differences.
 *
 * @module events
 */

/**
 * Clean up the listener cache and dispatchers
 *
 * @param {Element|Object} elem
 *        Element to clean up
 *
 * @param {string} type
 *        Type of event to clean up
 */
function _cleanUpEvents(elem, type) {
  var data = getData(elem);

  // Remove the events of a particular type if there are none left
  if (data.handlers[type].length === 0) {
    delete data.handlers[type];
    // data.handlers[type] = null;
    // Setting to null was causing an error with data.handlers

    // Remove the meta-handler from the element
    if (elem.removeEventListener) {
      elem.removeEventListener(type, data.dispatcher, false);
    } else if (elem.detachEvent) {
      elem.detachEvent('on' + type, data.dispatcher);
    }
  }

  // Remove the events object if there are no types left
  if (Object.getOwnPropertyNames(data.handlers).length <= 0) {
    delete data.handlers;
    delete data.dispatcher;
    delete data.disabled;
  }

  // Finally remove the element data if there is no data left
  if (Object.getOwnPropertyNames(data).length === 0) {
    removeData(elem);
  }
}

/**
 * Loops through an array of event types and calls the requested method for each type.
 *
 * @param {Function} fn
 *        The event method we want to use.
 *
 * @param {Element|Object} elem
 *        Element or object to bind listeners to
 *
 * @param {string} type
 *        Type of event to bind to.
 *
 * @param {EventTarget~EventListener} callback
 *        Event listener.
 */
function _handleMultipleEvents(fn, elem, types, callback) {
  types.forEach(function (type) {
    // Call the event method for each one of the types
    fn(elem, type, callback);
  });
}

/**
 * Fix a native event to have standard property values
 *
 * @param {Object} event
 *        Event object to fix.
 *
 * @return {Object}
 *         Fixed event object.
 */
function fixEvent(event) {

  function returnTrue() {
    return true;
  }

  function returnFalse() {
    return false;
  }

  // Test if fixing up is needed
  // Used to check if !event.stopPropagation instead of isPropagationStopped
  // But native events return true for stopPropagation, but don't have
  // other expected methods like isPropagationStopped. Seems to be a problem
  // with the Javascript Ninja code. So we're just overriding all events now.
  if (!event || !event.isPropagationStopped) {
    var old = event || window_1.event;

    event = {};
    // Clone the old object so that we can modify the values event = {};
    // IE8 Doesn't like when you mess with native event properties
    // Firefox returns false for event.hasOwnProperty('type') and other props
    //  which makes copying more difficult.
    // TODO: Probably best to create a whitelist of event props
    for (var key in old) {
      // Safari 6.0.3 warns you if you try to copy deprecated layerX/Y
      // Chrome warns you if you try to copy deprecated keyboardEvent.keyLocation
      // and webkitMovementX/Y
      if (key !== 'layerX' && key !== 'layerY' && key !== 'keyLocation' && key !== 'webkitMovementX' && key !== 'webkitMovementY') {
        // Chrome 32+ warns if you try to copy deprecated returnValue, but
        // we still want to if preventDefault isn't supported (IE8).
        if (!(key === 'returnValue' && old.preventDefault)) {
          event[key] = old[key];
        }
      }
    }

    // The event occurred on this element
    if (!event.target) {
      event.target = event.srcElement || document_1;
    }

    // Handle which other element the event is related to
    if (!event.relatedTarget) {
      event.relatedTarget = event.fromElement === event.target ? event.toElement : event.fromElement;
    }

    // Stop the default browser action
    event.preventDefault = function () {
      if (old.preventDefault) {
        old.preventDefault();
      }
      event.returnValue = false;
      old.returnValue = false;
      event.defaultPrevented = true;
    };

    event.defaultPrevented = false;

    // Stop the event from bubbling
    event.stopPropagation = function () {
      if (old.stopPropagation) {
        old.stopPropagation();
      }
      event.cancelBubble = true;
      old.cancelBubble = true;
      event.isPropagationStopped = returnTrue;
    };

    event.isPropagationStopped = returnFalse;

    // Stop the event from bubbling and executing other handlers
    event.stopImmediatePropagation = function () {
      if (old.stopImmediatePropagation) {
        old.stopImmediatePropagation();
      }
      event.isImmediatePropagationStopped = returnTrue;
      event.stopPropagation();
    };

    event.isImmediatePropagationStopped = returnFalse;

    // Handle mouse position
    if (event.clientX !== null && event.clientX !== undefined) {
      var doc = document_1.documentElement;
      var body = document_1.body;

      event.pageX = event.clientX + (doc && doc.scrollLeft || body && body.scrollLeft || 0) - (doc && doc.clientLeft || body && body.clientLeft || 0);
      event.pageY = event.clientY + (doc && doc.scrollTop || body && body.scrollTop || 0) - (doc && doc.clientTop || body && body.clientTop || 0);
    }

    // Handle key presses
    event.which = event.charCode || event.keyCode;

    // Fix button for mouse clicks:
    // 0 == left; 1 == middle; 2 == right
    if (event.button !== null && event.button !== undefined) {

      // The following is disabled because it does not pass videojs-standard
      // and... yikes.
      /* eslint-disable */
      event.button = event.button & 1 ? 0 : event.button & 4 ? 1 : event.button & 2 ? 2 : 0;
      /* eslint-enable */
    }
  }

  // Returns fixed-up instance
  return event;
}

/**
 * Whether passive event listeners are supported
 */
var _supportsPassive = false;

(function () {
  try {
    var opts = Object.defineProperty({}, 'passive', {
      get: function get() {
        _supportsPassive = true;
      }
    });

    window_1.addEventListener('test', null, opts);
    window_1.removeEventListener('test', null, opts);
  } catch (e) {
    // disregard
  }
})();

/**
 * Touch events Chrome expects to be passive
 */
var passiveEvents = ['touchstart', 'touchmove'];

/**
 * Add an event listener to element
 * It stores the handler function in a separate cache object
 * and adds a generic handler to the element's event,
 * along with a unique id (guid) to the element.
 *
 * @param {Element|Object} elem
 *        Element or object to bind listeners to
 *
 * @param {string|string[]} type
 *        Type of event to bind to.
 *
 * @param {EventTarget~EventListener} fn
 *        Event listener.
 */
function on(elem, type, fn) {
  if (Array.isArray(type)) {
    return _handleMultipleEvents(on, elem, type, fn);
  }

  var data = getData(elem);

  // We need a place to store all our handler data
  if (!data.handlers) {
    data.handlers = {};
  }

  if (!data.handlers[type]) {
    data.handlers[type] = [];
  }

  if (!fn.guid) {
    fn.guid = newGUID();
  }

  data.handlers[type].push(fn);

  if (!data.dispatcher) {
    data.disabled = false;

    data.dispatcher = function (event, hash) {

      if (data.disabled) {
        return;
      }

      event = fixEvent(event);

      var handlers = data.handlers[event.type];

      if (handlers) {
        // Copy handlers so if handlers are added/removed during the process it doesn't throw everything off.
        var handlersCopy = handlers.slice(0);

        for (var m = 0, n = handlersCopy.length; m < n; m++) {
          if (event.isImmediatePropagationStopped()) {
            break;
          } else {
            try {
              handlersCopy[m].call(elem, event, hash);
            } catch (e) {
              log$1.error(e);
            }
          }
        }
      }
    };
  }

  if (data.handlers[type].length === 1) {
    if (elem.addEventListener) {
      var options = false;

      if (_supportsPassive && passiveEvents.indexOf(type) > -1) {
        options = { passive: true };
      }
      elem.addEventListener(type, data.dispatcher, options);
    } else if (elem.attachEvent) {
      elem.attachEvent('on' + type, data.dispatcher);
    }
  }
}

/**
 * Removes event listeners from an element
 *
 * @param {Element|Object} elem
 *        Object to remove listeners from.
 *
 * @param {string|string[]} [type]
 *        Type of listener to remove. Don't include to remove all events from element.
 *
 * @param {EventTarget~EventListener} [fn]
 *        Specific listener to remove. Don't include to remove listeners for an event
 *        type.
 */
function off(elem, type, fn) {
  // Don't want to add a cache object through getElData if not needed
  if (!hasData(elem)) {
    return;
  }

  var data = getData(elem);

  // If no events exist, nothing to unbind
  if (!data.handlers) {
    return;
  }

  if (Array.isArray(type)) {
    return _handleMultipleEvents(off, elem, type, fn);
  }

  // Utility function
  var removeType = function removeType(el, t) {
    data.handlers[t] = [];
    _cleanUpEvents(el, t);
  };

  // Are we removing all bound events?
  if (type === undefined) {
    for (var t in data.handlers) {
      if (Object.prototype.hasOwnProperty.call(data.handlers || {}, t)) {
        removeType(elem, t);
      }
    }
    return;
  }

  var handlers = data.handlers[type];

  // If no handlers exist, nothing to unbind
  if (!handlers) {
    return;
  }

  // If no listener was provided, remove all listeners for type
  if (!fn) {
    removeType(elem, type);
    return;
  }

  // We're only removing a single handler
  if (fn.guid) {
    for (var n = 0; n < handlers.length; n++) {
      if (handlers[n].guid === fn.guid) {
        handlers.splice(n--, 1);
      }
    }
  }

  _cleanUpEvents(elem, type);
}

/**
 * Trigger an event for an element
 *
 * @param {Element|Object} elem
 *        Element to trigger an event on
 *
 * @param {EventTarget~Event|string} event
 *        A string (the type) or an event object with a type attribute
 *
 * @param {Object} [hash]
 *        data hash to pass along with the event
 *
 * @return {boolean|undefined}
 *         - Returns the opposite of `defaultPrevented` if default was prevented
 *         - Otherwise returns undefined
 */
function trigger(elem, event, hash) {
  // Fetches element data and a reference to the parent (for bubbling).
  // Don't want to add a data object to cache for every parent,
  // so checking hasElData first.
  var elemData = hasData(elem) ? getData(elem) : {};
  var parent = elem.parentNode || elem.ownerDocument;
  // type = event.type || event,
  // handler;

  // If an event name was passed as a string, creates an event out of it
  if (typeof event === 'string') {
    event = { type: event, target: elem };
  } else if (!event.target) {
    event.target = elem;
  }

  // Normalizes the event properties.
  event = fixEvent(event);

  // If the passed element has a dispatcher, executes the established handlers.
  if (elemData.dispatcher) {
    elemData.dispatcher.call(elem, event, hash);
  }

  // Unless explicitly stopped or the event does not bubble (e.g. media events)
  // recursively calls this function to bubble the event up the DOM.
  if (parent && !event.isPropagationStopped() && event.bubbles === true) {
    trigger.call(null, parent, event, hash);

    // If at the top of the DOM, triggers the default action unless disabled.
  } else if (!parent && !event.defaultPrevented) {
    var targetData = getData(event.target);

    // Checks if the target has a default action for this event.
    if (event.target[event.type]) {
      // Temporarily disables event dispatching on the target as we have already executed the handler.
      targetData.disabled = true;
      // Executes the default action.
      if (typeof event.target[event.type] === 'function') {
        event.target[event.type]();
      }
      // Re-enables event dispatching.
      targetData.disabled = false;
    }
  }

  // Inform the triggerer if the default was prevented by returning false
  return !event.defaultPrevented;
}

/**
 * Trigger a listener only once for an event
 *
 * @param {Element|Object} elem
 *        Element or object to bind to.
 *
 * @param {string|string[]} type
 *        Name/type of event
 *
 * @param {Event~EventListener} fn
 *        Event Listener function
 */
function one(elem, type, fn) {
  if (Array.isArray(type)) {
    return _handleMultipleEvents(one, elem, type, fn);
  }
  var func = function func() {
    off(elem, type, func);
    fn.apply(this, arguments);
  };

  // copy the guid to the new function so it can removed using the original function's ID
  func.guid = fn.guid = fn.guid || newGUID();
  on(elem, type, func);
}

var Events = (Object.freeze || Object)({
	fixEvent: fixEvent,
	on: on,
	off: off,
	trigger: trigger,
	one: one
});

/**
 * @file setup.js - Functions for setting up a player without
 * user interaction based on the data-setup `attribute` of the video tag.
 *
 * @module setup
 */
var _windowLoaded = false;
var videojs$2 = void 0;

/**
 * Set up any tags that have a data-setup `attribute` when the player is started.
 */
var autoSetup = function autoSetup() {

  // Protect against breakage in non-browser environments and check global autoSetup option.
  if (!isReal() || videojs$2.options.autoSetup === false) {
    return;
  }

  // One day, when we stop supporting IE8, go back to this, but in the meantime...*hack hack hack*
  // var vids = Array.prototype.slice.call(document.getElementsByTagName('video'));
  // var audios = Array.prototype.slice.call(document.getElementsByTagName('audio'));
  // var mediaEls = vids.concat(audios);

  // Because IE8 doesn't support calling slice on a node list, we need to loop
  // through each list of elements to build up a new, combined list of elements.
  var vids = document_1.getElementsByTagName('video');
  var audios = document_1.getElementsByTagName('audio');
  var divs = document_1.getElementsByTagName('video-js');
  var mediaEls = [];

  if (vids && vids.length > 0) {
    for (var i = 0, e = vids.length; i < e; i++) {
      mediaEls.push(vids[i]);
    }
  }

  if (audios && audios.length > 0) {
    for (var _i = 0, _e = audios.length; _i < _e; _i++) {
      mediaEls.push(audios[_i]);
    }
  }

  if (divs && divs.length > 0) {
    for (var _i2 = 0, _e2 = divs.length; _i2 < _e2; _i2++) {
      mediaEls.push(divs[_i2]);
    }
  }

  // Check if any media elements exist
  if (mediaEls && mediaEls.length > 0) {

    for (var _i3 = 0, _e3 = mediaEls.length; _i3 < _e3; _i3++) {
      var mediaEl = mediaEls[_i3];

      // Check if element exists, has getAttribute func.
      // IE seems to consider typeof el.getAttribute == 'object' instead of
      // 'function' like expected, at least when loading the player immediately.
      if (mediaEl && mediaEl.getAttribute) {

        // Make sure this player hasn't already been set up.
        if (mediaEl.player === undefined) {
          var options = mediaEl.getAttribute('data-setup');

          // Check if data-setup attr exists.
          // We only auto-setup if they've added the data-setup attr.
          if (options !== null) {
            // Create new video.js instance.
            videojs$2(mediaEl);
          }
        }

        // If getAttribute isn't defined, we need to wait for the DOM.
      } else {
        autoSetupTimeout(1);
        break;
      }
    }

    // No videos were found, so keep looping unless page is finished loading.
  } else if (!_windowLoaded) {
    autoSetupTimeout(1);
  }
};

/**
 * Wait until the page is loaded before running autoSetup. This will be called in
 * autoSetup if `hasLoaded` returns false.
 *
 * @param {number} wait
 *        How long to wait in ms
 *
 * @param {module:videojs} [vjs]
 *        The videojs library function
 */
function autoSetupTimeout(wait, vjs) {
  if (vjs) {
    videojs$2 = vjs;
  }

  window_1.setTimeout(autoSetup, wait);
}

if (isReal() && document_1.readyState === 'complete') {
  _windowLoaded = true;
} else {
  /**
   * Listen for the load event on window, and set _windowLoaded to true.
   *
   * @listens load
   */
  one(window_1, 'load', function () {
    _windowLoaded = true;
  });
}

/**
 * @file stylesheet.js
 * @module stylesheet
 */
/**
 * Create a DOM syle element given a className for it.
 *
 * @param {string} className
 *        The className to add to the created style element.
 *
 * @return {Element}
 *         The element that was created.
 */
var createStyleElement = function createStyleElement(className) {
  var style = document_1.createElement('style');

  style.className = className;

  return style;
};

/**
 * Add text to a DOM element.
 *
 * @param {Element} el
 *        The Element to add text content to.
 *
 * @param {string} content
 *        The text to add to the element.
 */
var setTextContent = function setTextContent(el, content) {
  if (el.styleSheet) {
    el.styleSheet.cssText = content;
  } else {
    el.textContent = content;
  }
};

/**
 * @file fn.js
 * @module fn
 */
/**
 * Bind (a.k.a proxy or Context). A simple method for changing the context of a function
 * It also stores a unique id on the function so it can be easily removed from events.
 *
 * @param {Mixed} context
 *        The object to bind as scope.
 *
 * @param {Function} fn
 *        The function to be bound to a scope.
 *
 * @param {number} [uid]
 *        An optional unique ID for the function to be set
 *
 * @return {Function}
 *         The new function that will be bound into the context given
 */
var bind = function bind(context, fn, uid) {
  // Make sure the function has a unique ID
  if (!fn.guid) {
    fn.guid = newGUID();
  }

  // Create the new function that changes the context
  var bound = function bound() {
    return fn.apply(context, arguments);
  };

  // Allow for the ability to individualize this function
  // Needed in the case where multiple objects might share the same prototype
  // IF both items add an event listener with the same function, then you try to remove just one
  // it will remove both because they both have the same guid.
  // when using this, you need to use the bind method when you remove the listener as well.
  // currently used in text tracks
  bound.guid = uid ? uid + '_' + fn.guid : fn.guid;

  return bound;
};

/**
 * Wraps the given function, `fn`, with a new function that only invokes `fn`
 * at most once per every `wait` milliseconds.
 *
 * @param  {Function} fn
 *         The function to be throttled.
 *
 * @param  {Number}   wait
 *         The number of milliseconds by which to throttle.
 *
 * @return {Function}
 */
var throttle = function throttle(fn, wait) {
  var last = Date.now();

  var throttled = function throttled() {
    var now = Date.now();

    if (now - last >= wait) {
      fn.apply(undefined, arguments);
      last = now;
    }
  };

  return throttled;
};

/**
 * Creates a debounced function that delays invoking `func` until after `wait`
 * milliseconds have elapsed since the last time the debounced function was
 * invoked.
 *
 * Inspired by lodash and underscore implementations.
 *
 * @param  {Function} func
 *         The function to wrap with debounce behavior.
 *
 * @param  {number} wait
 *         The number of milliseconds to wait after the last invocation.
 *
 * @param  {boolean} [immediate]
 *         Whether or not to invoke the function immediately upon creation.
 *
 * @param  {Object} [context=window]
 *         The "context" in which the debounced function should debounce. For
 *         example, if this function should be tied to a Video.js player,
 *         the player can be passed here. Alternatively, defaults to the
 *         global `window` object.
 *
 * @return {Function}
 *         A debounced function.
 */
var debounce = function debounce(func, wait, immediate) {
  var context = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : window_1;

  var timeout = void 0;

  /* eslint-disable consistent-this */
  return function () {
    var self = this;
    var args = arguments;

    var _later = function later() {
      timeout = null;
      _later = null;
      if (!immediate) {
        func.apply(self, args);
      }
    };

    if (!timeout && immediate) {
      func.apply(self, args);
    }

    context.clearTimeout(timeout);
    timeout = context.setTimeout(_later, wait);
  };
  /* eslint-enable consistent-this */
};

/**
 * @file src/js/event-target.js
 */
/**
 * `EventTarget` is a class that can have the same API as the DOM `EventTarget`. It
 * adds shorthand functions that wrap around lengthy functions. For example:
 * the `on` function is a wrapper around `addEventListener`.
 *
 * @see [EventTarget Spec]{@link https://www.w3.org/TR/DOM-Level-2-Events/events.html#Events-EventTarget}
 * @class EventTarget
 */
var EventTarget = function EventTarget() {};

/**
 * A Custom DOM event.
 *
 * @typedef {Object} EventTarget~Event
 * @see [Properties]{@link https://developer.mozilla.org/en-US/docs/Web/API/CustomEvent}
 */

/**
 * All event listeners should follow the following format.
 *
 * @callback EventTarget~EventListener
 * @this {EventTarget}
 *
 * @param {EventTarget~Event} event
 *        the event that triggered this function
 *
 * @param {Object} [hash]
 *        hash of data sent during the event
 */

/**
 * An object containing event names as keys and booleans as values.
 *
 * > NOTE: If an event name is set to a true value here {@link EventTarget#trigger}
 *         will have extra functionality. See that function for more information.
 *
 * @property EventTarget.prototype.allowedEvents_
 * @private
 */
EventTarget.prototype.allowedEvents_ = {};

/**
 * Adds an `event listener` to an instance of an `EventTarget`. An `event listener` is a
 * function that will get called when an event with a certain name gets triggered.
 *
 * @param {string|string[]} type
 *        An event name or an array of event names.
 *
 * @param {EventTarget~EventListener} fn
 *        The function to call with `EventTarget`s
 */
EventTarget.prototype.on = function (type, fn) {
  // Remove the addEventListener alias before calling Events.on
  // so we don't get into an infinite type loop
  var ael = this.addEventListener;

  this.addEventListener = function () {};
  on(this, type, fn);
  this.addEventListener = ael;
};

/**
 * An alias of {@link EventTarget#on}. Allows `EventTarget` to mimic
 * the standard DOM API.
 *
 * @function
 * @see {@link EventTarget#on}
 */
EventTarget.prototype.addEventListener = EventTarget.prototype.on;

/**
 * Removes an `event listener` for a specific event from an instance of `EventTarget`.
 * This makes it so that the `event listener` will no longer get called when the
 * named event happens.
 *
 * @param {string|string[]} type
 *        An event name or an array of event names.
 *
 * @param {EventTarget~EventListener} fn
 *        The function to remove.
 */
EventTarget.prototype.off = function (type, fn) {
  off(this, type, fn);
};

/**
 * An alias of {@link EventTarget#off}. Allows `EventTarget` to mimic
 * the standard DOM API.
 *
 * @function
 * @see {@link EventTarget#off}
 */
EventTarget.prototype.removeEventListener = EventTarget.prototype.off;

/**
 * This function will add an `event listener` that gets triggered only once. After the
 * first trigger it will get removed. This is like adding an `event listener`
 * with {@link EventTarget#on} that calls {@link EventTarget#off} on itself.
 *
 * @param {string|string[]} type
 *        An event name or an array of event names.
 *
 * @param {EventTarget~EventListener} fn
 *        The function to be called once for each event name.
 */
EventTarget.prototype.one = function (type, fn) {
  // Remove the addEventListener alialing Events.on
  // so we don't get into an infinite type loop
  var ael = this.addEventListener;

  this.addEventListener = function () {};
  one(this, type, fn);
  this.addEventListener = ael;
};

/**
 * This function causes an event to happen. This will then cause any `event listeners`
 * that are waiting for that event, to get called. If there are no `event listeners`
 * for an event then nothing will happen.
 *
 * If the name of the `Event` that is being triggered is in `EventTarget.allowedEvents_`.
 * Trigger will also call the `on` + `uppercaseEventName` function.
 *
 * Example:
 * 'click' is in `EventTarget.allowedEvents_`, so, trigger will attempt to call
 * `onClick` if it exists.
 *
 * @param {string|EventTarget~Event|Object} event
 *        The name of the event, an `Event`, or an object with a key of type set to
 *        an event name.
 */
EventTarget.prototype.trigger = function (event) {
  var type = event.type || event;

  if (typeof event === 'string') {
    event = { type: type };
  }
  event = fixEvent(event);

  if (this.allowedEvents_[type] && this['on' + type]) {
    this['on' + type](event);
  }

  trigger(this, event);
};

/**
 * An alias of {@link EventTarget#trigger}. Allows `EventTarget` to mimic
 * the standard DOM API.
 *
 * @function
 * @see {@link EventTarget#trigger}
 */
EventTarget.prototype.dispatchEvent = EventTarget.prototype.trigger;

/**
 * @file mixins/evented.js
 * @module evented
 */
/**
 * Returns whether or not an object has had the evented mixin applied.
 *
 * @param  {Object} object
 *         An object to test.
 *
 * @return {boolean}
 *         Whether or not the object appears to be evented.
 */
var isEvented = function isEvented(object) {
  return object instanceof EventTarget || !!object.eventBusEl_ && ['on', 'one', 'off', 'trigger'].every(function (k) {
    return typeof object[k] === 'function';
  });
};

/**
 * Whether a value is a valid event type - non-empty string or array.
 *
 * @private
 * @param  {string|Array} type
 *         The type value to test.
 *
 * @return {boolean}
 *         Whether or not the type is a valid event type.
 */
var isValidEventType = function isValidEventType(type) {
  return (
    // The regex here verifies that the `type` contains at least one non-
    // whitespace character.
    typeof type === 'string' && /\S/.test(type) || Array.isArray(type) && !!type.length
  );
};

/**
 * Validates a value to determine if it is a valid event target. Throws if not.
 *
 * @private
 * @throws {Error}
 *         If the target does not appear to be a valid event target.
 *
 * @param  {Object} target
 *         The object to test.
 */
var validateTarget = function validateTarget(target) {
  if (!target.nodeName && !isEvented(target)) {
    throw new Error('Invalid target; must be a DOM node or evented object.');
  }
};

/**
 * Validates a value to determine if it is a valid event target. Throws if not.
 *
 * @private
 * @throws {Error}
 *         If the type does not appear to be a valid event type.
 *
 * @param  {string|Array} type
 *         The type to test.
 */
var validateEventType = function validateEventType(type) {
  if (!isValidEventType(type)) {
    throw new Error('Invalid event type; must be a non-empty string or array.');
  }
};

/**
 * Validates a value to determine if it is a valid listener. Throws if not.
 *
 * @private
 * @throws {Error}
 *         If the listener is not a function.
 *
 * @param  {Function} listener
 *         The listener to test.
 */
var validateListener = function validateListener(listener) {
  if (typeof listener !== 'function') {
    throw new Error('Invalid listener; must be a function.');
  }
};

/**
 * Takes an array of arguments given to `on()` or `one()`, validates them, and
 * normalizes them into an object.
 *
 * @private
 * @param  {Object} self
 *         The evented object on which `on()` or `one()` was called. This
 *         object will be bound as the `this` value for the listener.
 *
 * @param  {Array} args
 *         An array of arguments passed to `on()` or `one()`.
 *
 * @return {Object}
 *         An object containing useful values for `on()` or `one()` calls.
 */
var normalizeListenArgs = function normalizeListenArgs(self, args) {

  // If the number of arguments is less than 3, the target is always the
  // evented object itself.
  var isTargetingSelf = args.length < 3 || args[0] === self || args[0] === self.eventBusEl_;
  var target = void 0;
  var type = void 0;
  var listener = void 0;

  if (isTargetingSelf) {
    target = self.eventBusEl_;

    // Deal with cases where we got 3 arguments, but we are still listening to
    // the evented object itself.
    if (args.length >= 3) {
      args.shift();
    }

    type = args[0];
    listener = args[1];
  } else {
    target = args[0];
    type = args[1];
    listener = args[2];
  }

  validateTarget(target);
  validateEventType(type);
  validateListener(listener);

  listener = bind(self, listener);

  return { isTargetingSelf: isTargetingSelf, target: target, type: type, listener: listener };
};

/**
 * Adds the listener to the event type(s) on the target, normalizing for
 * the type of target.
 *
 * @private
 * @param  {Element|Object} target
 *         A DOM node or evented object.
 *
 * @param  {string} method
 *         The event binding method to use ("on" or "one").
 *
 * @param  {string|Array} type
 *         One or more event type(s).
 *
 * @param  {Function} listener
 *         A listener function.
 */
var listen = function listen(target, method, type, listener) {
  validateTarget(target);

  if (target.nodeName) {
    Events[method](target, type, listener);
  } else {
    target[method](type, listener);
  }
};

/**
 * Contains methods that provide event capabilites to an object which is passed
 * to {@link module:evented|evented}.
 *
 * @mixin EventedMixin
 */
var EventedMixin = {

  /**
   * Add a listener to an event (or events) on this object or another evented
   * object.
   *
   * @param  {string|Array|Element|Object} targetOrType
   *         If this is a string or array, it represents the event type(s)
   *         that will trigger the listener.
   *
   *         Another evented object can be passed here instead, which will
   *         cause the listener to listen for events on _that_ object.
   *
   *         In either case, the listener's `this` value will be bound to
   *         this object.
   *
   * @param  {string|Array|Function} typeOrListener
   *         If the first argument was a string or array, this should be the
   *         listener function. Otherwise, this is a string or array of event
   *         type(s).
   *
   * @param  {Function} [listener]
   *         If the first argument was another evented object, this will be
   *         the listener function.
   */
  on: function on$$1() {
    var _this = this;

    for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }

    var _normalizeListenArgs = normalizeListenArgs(this, args),
        isTargetingSelf = _normalizeListenArgs.isTargetingSelf,
        target = _normalizeListenArgs.target,
        type = _normalizeListenArgs.type,
        listener = _normalizeListenArgs.listener;

    listen(target, 'on', type, listener);

    // If this object is listening to another evented object.
    if (!isTargetingSelf) {

      // If this object is disposed, remove the listener.
      var removeListenerOnDispose = function removeListenerOnDispose() {
        return _this.off(target, type, listener);
      };

      // Use the same function ID as the listener so we can remove it later it
      // using the ID of the original listener.
      removeListenerOnDispose.guid = listener.guid;

      // Add a listener to the target's dispose event as well. This ensures
      // that if the target is disposed BEFORE this object, we remove the
      // removal listener that was just added. Otherwise, we create a memory leak.
      var removeRemoverOnTargetDispose = function removeRemoverOnTargetDispose() {
        return _this.off('dispose', removeListenerOnDispose);
      };

      // Use the same function ID as the listener so we can remove it later
      // it using the ID of the original listener.
      removeRemoverOnTargetDispose.guid = listener.guid;

      listen(this, 'on', 'dispose', removeListenerOnDispose);
      listen(target, 'on', 'dispose', removeRemoverOnTargetDispose);
    }
  },


  /**
   * Add a listener to an event (or events) on this object or another evented
   * object. The listener will only be called once and then removed.
   *
   * @param  {string|Array|Element|Object} targetOrType
   *         If this is a string or array, it represents the event type(s)
   *         that will trigger the listener.
   *
   *         Another evented object can be passed here instead, which will
   *         cause the listener to listen for events on _that_ object.
   *
   *         In either case, the listener's `this` value will be bound to
   *         this object.
   *
   * @param  {string|Array|Function} typeOrListener
   *         If the first argument was a string or array, this should be the
   *         listener function. Otherwise, this is a string or array of event
   *         type(s).
   *
   * @param  {Function} [listener]
   *         If the first argument was another evented object, this will be
   *         the listener function.
   */
  one: function one$$1() {
    var _this2 = this;

    for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
      args[_key2] = arguments[_key2];
    }

    var _normalizeListenArgs2 = normalizeListenArgs(this, args),
        isTargetingSelf = _normalizeListenArgs2.isTargetingSelf,
        target = _normalizeListenArgs2.target,
        type = _normalizeListenArgs2.type,
        listener = _normalizeListenArgs2.listener;

    // Targeting this evented object.


    if (isTargetingSelf) {
      listen(target, 'one', type, listener);

      // Targeting another evented object.
    } else {
      var wrapper = function wrapper() {
        for (var _len3 = arguments.length, largs = Array(_len3), _key3 = 0; _key3 < _len3; _key3++) {
          largs[_key3] = arguments[_key3];
        }

        _this2.off(target, type, wrapper);
        listener.apply(null, largs);
      };

      // Use the same function ID as the listener so we can remove it later
      // it using the ID of the original listener.
      wrapper.guid = listener.guid;
      listen(target, 'one', type, wrapper);
    }
  },


  /**
   * Removes listener(s) from event(s) on an evented object.
   *
   * @param  {string|Array|Element|Object} [targetOrType]
   *         If this is a string or array, it represents the event type(s).
   *
   *         Another evented object can be passed here instead, in which case
   *         ALL 3 arguments are _required_.
   *
   * @param  {string|Array|Function} [typeOrListener]
   *         If the first argument was a string or array, this may be the
   *         listener function. Otherwise, this is a string or array of event
   *         type(s).
   *
   * @param  {Function} [listener]
   *         If the first argument was another evented object, this will be
   *         the listener function; otherwise, _all_ listeners bound to the
   *         event type(s) will be removed.
   */
  off: function off$$1(targetOrType, typeOrListener, listener) {

    // Targeting this evented object.
    if (!targetOrType || isValidEventType(targetOrType)) {
      off(this.eventBusEl_, targetOrType, typeOrListener);

      // Targeting another evented object.
    } else {
      var target = targetOrType;
      var type = typeOrListener;

      // Fail fast and in a meaningful way!
      validateTarget(target);
      validateEventType(type);
      validateListener(listener);

      // Ensure there's at least a guid, even if the function hasn't been used
      listener = bind(this, listener);

      // Remove the dispose listener on this evented object, which was given
      // the same guid as the event listener in on().
      this.off('dispose', listener);

      if (target.nodeName) {
        off(target, type, listener);
        off(target, 'dispose', listener);
      } else if (isEvented(target)) {
        target.off(type, listener);
        target.off('dispose', listener);
      }
    }
  },


  /**
   * Fire an event on this evented object, causing its listeners to be called.
   *
   * @param   {string|Object} event
   *          An event type or an object with a type property.
   *
   * @param   {Object} [hash]
   *          An additional object to pass along to listeners.
   *
   * @returns {boolean}
   *          Whether or not the default behavior was prevented.
   */
  trigger: function trigger$$1(event, hash) {
    return trigger(this.eventBusEl_, event, hash);
  }
};

/**
 * Applies {@link module:evented~EventedMixin|EventedMixin} to a target object.
 *
 * @param  {Object} target
 *         The object to which to add event methods.
 *
 * @param  {Object} [options={}]
 *         Options for customizing the mixin behavior.
 *
 * @param  {String} [options.eventBusKey]
 *         By default, adds a `eventBusEl_` DOM element to the target object,
 *         which is used as an event bus. If the target object already has a
 *         DOM element that should be used, pass its key here.
 *
 * @return {Object}
 *         The target object.
 */
function evented(target) {
  var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
  var eventBusKey = options.eventBusKey;

  // Set or create the eventBusEl_.

  if (eventBusKey) {
    if (!target[eventBusKey].nodeName) {
      throw new Error('The eventBusKey "' + eventBusKey + '" does not refer to an element.');
    }
    target.eventBusEl_ = target[eventBusKey];
  } else {
    target.eventBusEl_ = createEl('span', { className: 'vjs-event-bus' });
  }

  assign(target, EventedMixin);

  // When any evented object is disposed, it removes all its listeners.
  target.on('dispose', function () {
    target.off();
    window_1.setTimeout(function () {
      target.eventBusEl_ = null;
    }, 0);
  });

  return target;
}

/**
 * @file mixins/stateful.js
 * @module stateful
 */
/**
 * Contains methods that provide statefulness to an object which is passed
 * to {@link module:stateful}.
 *
 * @mixin StatefulMixin
 */
var StatefulMixin = {

  /**
   * A hash containing arbitrary keys and values representing the state of
   * the object.
   *
   * @type {Object}
   */
  state: {},

  /**
   * Set the state of an object by mutating its
   * {@link module:stateful~StatefulMixin.state|state} object in place.
   *
   * @fires   module:stateful~StatefulMixin#statechanged
   * @param   {Object|Function} stateUpdates
   *          A new set of properties to shallow-merge into the plugin state.
   *          Can be a plain object or a function returning a plain object.
   *
   * @returns {Object|undefined}
   *          An object containing changes that occurred. If no changes
   *          occurred, returns `undefined`.
   */
  setState: function setState(stateUpdates) {
    var _this = this;

    // Support providing the `stateUpdates` state as a function.
    if (typeof stateUpdates === 'function') {
      stateUpdates = stateUpdates();
    }

    var changes = void 0;

    each(stateUpdates, function (value, key) {

      // Record the change if the value is different from what's in the
      // current state.
      if (_this.state[key] !== value) {
        changes = changes || {};
        changes[key] = {
          from: _this.state[key],
          to: value
        };
      }

      _this.state[key] = value;
    });

    // Only trigger "statechange" if there were changes AND we have a trigger
    // function. This allows us to not require that the target object be an
    // evented object.
    if (changes && isEvented(this)) {

      /**
       * An event triggered on an object that is both
       * {@link module:stateful|stateful} and {@link module:evented|evented}
       * indicating that its state has changed.
       *
       * @event    module:stateful~StatefulMixin#statechanged
       * @type     {Object}
       * @property {Object} changes
       *           A hash containing the properties that were changed and
       *           the values they were changed `from` and `to`.
       */
      this.trigger({
        changes: changes,
        type: 'statechanged'
      });
    }

    return changes;
  }
};

/**
 * Applies {@link module:stateful~StatefulMixin|StatefulMixin} to a target
 * object.
 *
 * If the target object is {@link module:evented|evented} and has a
 * `handleStateChanged` method, that method will be automatically bound to the
 * `statechanged` event on itself.
 *
 * @param   {Object} target
 *          The object to be made stateful.
 *
 * @param   {Object} [defaultState]
 *          A default set of properties to populate the newly-stateful object's
 *          `state` property.
 *
 * @returns {Object}
 *          Returns the `target`.
 */
function stateful(target, defaultState) {
  assign(target, StatefulMixin);

  // This happens after the mixing-in because we need to replace the `state`
  // added in that step.
  target.state = assign({}, target.state, defaultState);

  // Auto-bind the `handleStateChanged` method of the target object if it exists.
  if (typeof target.handleStateChanged === 'function' && isEvented(target)) {
    target.on('statechanged', target.handleStateChanged);
  }

  return target;
}

/**
 * @file to-title-case.js
 * @module to-title-case
 */

/**
 * Uppercase the first letter of a string.
 *
 * @param {string} string
 *        String to be uppercased
 *
 * @return {string}
 *         The string with an uppercased first letter
 */
function toTitleCase(string) {
  if (typeof string !== 'string') {
    return string;
  }

  return string.charAt(0).toUpperCase() + string.slice(1);
}

/**
 * Compares the TitleCase versions of the two strings for equality.
 *
 * @param {string} str1
 *        The first string to compare
 *
 * @param {string} str2
 *        The second string to compare
 *
 * @return {boolean}
 *         Whether the TitleCase versions of the strings are equal
 */
function titleCaseEquals(str1, str2) {
  return toTitleCase(str1) === toTitleCase(str2);
}

/**
 * @file merge-options.js
 * @module merge-options
 */
/**
 * Deep-merge one or more options objects, recursively merging **only** plain
 * object properties.
 *
 * @param   {Object[]} sources
 *          One or more objects to merge into a new object.
 *
 * @returns {Object}
 *          A new object that is the merged result of all sources.
 */
function mergeOptions() {
  var result = {};

  for (var _len = arguments.length, sources = Array(_len), _key = 0; _key < _len; _key++) {
    sources[_key] = arguments[_key];
  }

  sources.forEach(function (source) {
    if (!source) {
      return;
    }

    each(source, function (value, key) {
      if (!isPlain(value)) {
        result[key] = value;
        return;
      }

      if (!isPlain(result[key])) {
        result[key] = {};
      }

      result[key] = mergeOptions(result[key], value);
    });
  });

  return result;
}

/**
 * Player Component - Base class for all UI objects
 *
 * @file component.js
 */
/**
 * Base class for all UI Components.
 * Components are UI objects which represent both a javascript object and an element
 * in the DOM. They can be children of other components, and can have
 * children themselves.
 *
 * Components can also use methods from {@link EventTarget}
 */

var Component = function () {

  /**
   * A callback that is called when a component is ready. Does not have any
   * paramters and any callback value will be ignored.
   *
   * @callback Component~ReadyCallback
   * @this Component
   */

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Object[]} [options.children]
   *        An array of children objects to intialize this component with. Children objects have
   *        a name property that will be used if more than one component of the same type needs to be
   *        added.
   *
   * @param {Component~ReadyCallback} [ready]
   *        Function that gets called when the `Component` is ready.
   */
  function Component(player, options, ready) {
    classCallCheck(this, Component);


    // The component might be the player itself and we can't pass `this` to super
    if (!player && this.play) {
      this.player_ = player = this; // eslint-disable-line
    } else {
      this.player_ = player;
    }

    // Make a copy of prototype.options_ to protect against overriding defaults
    this.options_ = mergeOptions({}, this.options_);

    // Updated options with supplied options
    options = this.options_ = mergeOptions(this.options_, options);

    // Get ID from options or options element if one is supplied
    this.id_ = options.id || options.el && options.el.id;

    // If there was no ID from the options, generate one
    if (!this.id_) {
      // Don't require the player ID function in the case of mock players
      var id = player && player.id && player.id() || 'no_player';

      this.id_ = id + '_component_' + newGUID();
    }

    this.name_ = options.name || null;

    // Create element if one wasn't provided in options
    if (options.el) {
      this.el_ = options.el;
    } else if (options.createEl !== false) {
      this.el_ = this.createEl();
    }

    // if evented is anything except false, we want to mixin in evented
    if (options.evented !== false) {
      // Make this an evented object and use `el_`, if available, as its event bus
      evented(this, { eventBusKey: this.el_ ? 'el_' : null });
    }
    stateful(this, this.constructor.defaultState);

    this.children_ = [];
    this.childIndex_ = {};
    this.childNameIndex_ = {};

    // Add any child components in options
    if (options.initChildren !== false) {
      this.initChildren();
    }

    this.ready(ready);
    // Don't want to trigger ready here or it will before init is actually
    // finished for all children that run this constructor

    if (options.reportTouchActivity !== false) {
      this.enableTouchActivity();
    }
  }

  /**
   * Dispose of the `Component` and all child components.
   *
   * @fires Component#dispose
   */


  Component.prototype.dispose = function dispose() {

    /**
     * Triggered when a `Component` is disposed.
     *
     * @event Component#dispose
     * @type {EventTarget~Event}
     *
     * @property {boolean} [bubbles=false]
     *           set to false so that the close event does not
     *           bubble up
     */
    this.trigger({ type: 'dispose', bubbles: false });

    // Dispose all children.
    if (this.children_) {
      for (var i = this.children_.length - 1; i >= 0; i--) {
        if (this.children_[i].dispose) {
          this.children_[i].dispose();
        }
      }
    }

    // Delete child references
    this.children_ = null;
    this.childIndex_ = null;
    this.childNameIndex_ = null;

    if (this.el_) {
      // Remove element from DOM
      if (this.el_.parentNode) {
        this.el_.parentNode.removeChild(this.el_);
      }

      removeData(this.el_);
      this.el_ = null;
    }

    // remove reference to the player after disposing of the element
    this.player_ = null;
  };

  /**
   * Return the {@link Player} that the `Component` has attached to.
   *
   * @return {Player}
   *         The player that this `Component` has attached to.
   */


  Component.prototype.player = function player() {
    return this.player_;
  };

  /**
   * Deep merge of options objects with new options.
   * > Note: When both `obj` and `options` contain properties whose values are objects.
   *         The two properties get merged using {@link module:mergeOptions}
   *
   * @param {Object} obj
   *        The object that contains new options.
   *
   * @return {Object}
   *         A new object of `this.options_` and `obj` merged together.
   *
   * @deprecated since version 5
   */


  Component.prototype.options = function options(obj) {
    log$1.warn('this.options() has been deprecated and will be moved to the constructor in 6.0');

    if (!obj) {
      return this.options_;
    }

    this.options_ = mergeOptions(this.options_, obj);
    return this.options_;
  };

  /**
   * Get the `Component`s DOM element
   *
   * @return {Element}
   *         The DOM element for this `Component`.
   */


  Component.prototype.el = function el() {
    return this.el_;
  };

  /**
   * Create the `Component`s DOM element.
   *
   * @param {string} [tagName]
   *        Element's DOM node type. e.g. 'div'
   *
   * @param {Object} [properties]
   *        An object of properties that should be set.
   *
   * @param {Object} [attributes]
   *        An object of attributes that should be set.
   *
   * @return {Element}
   *         The element that gets created.
   */


  Component.prototype.createEl = function createEl$$1(tagName, properties, attributes) {
    return createEl(tagName, properties, attributes);
  };

  /**
   * Localize a string given the string in english.
   *
   * If tokens are provided, it'll try and run a simple token replacement on the provided string.
   * The tokens it looks for look like `{1}` with the index being 1-indexed into the tokens array.
   *
   * If a `defaultValue` is provided, it'll use that over `string`,
   * if a value isn't found in provided language files.
   * This is useful if you want to have a descriptive key for token replacement
   * but have a succinct localized string and not require `en.json` to be included.
   *
   * Currently, it is used for the progress bar timing.
   * ```js
   * {
   *   "progress bar timing: currentTime={1} duration={2}": "{1} of {2}"
   * }
   * ```
   * It is then used like so:
   * ```js
   * this.localize('progress bar timing: currentTime={1} duration{2}',
   *               [this.player_.currentTime(), this.player_.duration()],
   *               '{1} of {2}');
   * ```
   *
   * Which outputs something like: `01:23 of 24:56`.
   *
   *
   * @param {string} string
   *        The string to localize and the key to lookup in the language files.
   * @param {string[]} [tokens]
   *        If the current item has token replacements, provide the tokens here.
   * @param {string} [defaultValue]
   *        Defaults to `string`. Can be a default value to use for token replacement
   *        if the lookup key is needed to be separate.
   *
   * @return {string}
   *         The localized string or if no localization exists the english string.
   */


  Component.prototype.localize = function localize(string, tokens) {
    var defaultValue = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : string;

    var code = this.player_.language && this.player_.language();
    var languages = this.player_.languages && this.player_.languages();
    var language = languages && languages[code];
    var primaryCode = code && code.split('-')[0];
    var primaryLang = languages && languages[primaryCode];

    var localizedString = defaultValue;

    if (language && language[string]) {
      localizedString = language[string];
    } else if (primaryLang && primaryLang[string]) {
      localizedString = primaryLang[string];
    }

    if (tokens) {
      localizedString = localizedString.replace(/\{(\d+)\}/g, function (match, index) {
        var value = tokens[index - 1];
        var ret = value;

        if (typeof value === 'undefined') {
          ret = match;
        }

        return ret;
      });
    }

    return localizedString;
  };

  /**
   * Return the `Component`s DOM element. This is where children get inserted.
   * This will usually be the the same as the element returned in {@link Component#el}.
   *
   * @return {Element}
   *         The content element for this `Component`.
   */


  Component.prototype.contentEl = function contentEl() {
    return this.contentEl_ || this.el_;
  };

  /**
   * Get this `Component`s ID
   *
   * @return {string}
   *         The id of this `Component`
   */


  Component.prototype.id = function id() {
    return this.id_;
  };

  /**
   * Get the `Component`s name. The name gets used to reference the `Component`
   * and is set during registration.
   *
   * @return {string}
   *         The name of this `Component`.
   */


  Component.prototype.name = function name() {
    return this.name_;
  };

  /**
   * Get an array of all child components
   *
   * @return {Array}
   *         The children
   */


  Component.prototype.children = function children() {
    return this.children_;
  };

  /**
   * Returns the child `Component` with the given `id`.
   *
   * @param {string} id
   *        The id of the child `Component` to get.
   *
   * @return {Component|undefined}
   *         The child `Component` with the given `id` or undefined.
   */


  Component.prototype.getChildById = function getChildById(id) {
    return this.childIndex_[id];
  };

  /**
   * Returns the child `Component` with the given `name`.
   *
   * @param {string} name
   *        The name of the child `Component` to get.
   *
   * @return {Component|undefined}
   *         The child `Component` with the given `name` or undefined.
   */


  Component.prototype.getChild = function getChild(name) {
    if (!name) {
      return;
    }

    name = toTitleCase(name);

    return this.childNameIndex_[name];
  };

  /**
   * Add a child `Component` inside the current `Component`.
   *
   *
   * @param {string|Component} child
   *        The name or instance of a child to add.
   *
   * @param {Object} [options={}]
   *        The key/value store of options that will get passed to children of
   *        the child.
   *
   * @param {number} [index=this.children_.length]
   *        The index to attempt to add a child into.
   *
   * @return {Component}
   *         The `Component` that gets added as a child. When using a string the
   *         `Component` will get created by this process.
   */


  Component.prototype.addChild = function addChild(child) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    var index = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : this.children_.length;

    var component = void 0;
    var componentName = void 0;

    // If child is a string, create component with options
    if (typeof child === 'string') {
      componentName = toTitleCase(child);

      var componentClassName = options.componentClass || componentName;

      // Set name through options
      options.name = componentName;

      // Create a new object & element for this controls set
      // If there's no .player_, this is a player
      var ComponentClass = Component.getComponent(componentClassName);

      if (!ComponentClass) {
        throw new Error('Component ' + componentClassName + ' does not exist');
      }

      // data stored directly on the videojs object may be
      // misidentified as a component to retain
      // backwards-compatibility with 4.x. check to make sure the
      // component class can be instantiated.
      if (typeof ComponentClass !== 'function') {
        return null;
      }

      component = new ComponentClass(this.player_ || this, options);

      // child is a component instance
    } else {
      component = child;
    }

    this.children_.splice(index, 0, component);

    if (typeof component.id === 'function') {
      this.childIndex_[component.id()] = component;
    }

    // If a name wasn't used to create the component, check if we can use the
    // name function of the component
    componentName = componentName || component.name && toTitleCase(component.name());

    if (componentName) {
      this.childNameIndex_[componentName] = component;
    }

    // Add the UI object's element to the container div (box)
    // Having an element is not required
    if (typeof component.el === 'function' && component.el()) {
      var childNodes = this.contentEl().children;
      var refNode = childNodes[index] || null;

      this.contentEl().insertBefore(component.el(), refNode);
    }

    // Return so it can stored on parent object if desired.
    return component;
  };

  /**
   * Remove a child `Component` from this `Component`s list of children. Also removes
   * the child `Component`s element from this `Component`s element.
   *
   * @param {Component} component
   *        The child `Component` to remove.
   */


  Component.prototype.removeChild = function removeChild(component) {
    if (typeof component === 'string') {
      component = this.getChild(component);
    }

    if (!component || !this.children_) {
      return;
    }

    var childFound = false;

    for (var i = this.children_.length - 1; i >= 0; i--) {
      if (this.children_[i] === component) {
        childFound = true;
        this.children_.splice(i, 1);
        break;
      }
    }

    if (!childFound) {
      return;
    }

    this.childIndex_[component.id()] = null;
    this.childNameIndex_[component.name()] = null;

    var compEl = component.el();

    if (compEl && compEl.parentNode === this.contentEl()) {
      this.contentEl().removeChild(component.el());
    }
  };

  /**
   * Add and initialize default child `Component`s based upon options.
   */


  Component.prototype.initChildren = function initChildren() {
    var _this = this;

    var children = this.options_.children;

    if (children) {
      // `this` is `parent`
      var parentOptions = this.options_;

      var handleAdd = function handleAdd(child) {
        var name = child.name;
        var opts = child.opts;

        // Allow options for children to be set at the parent options
        // e.g. videojs(id, { controlBar: false });
        // instead of videojs(id, { children: { controlBar: false });
        if (parentOptions[name] !== undefined) {
          opts = parentOptions[name];
        }

        // Allow for disabling default components
        // e.g. options['children']['posterImage'] = false
        if (opts === false) {
          return;
        }

        // Allow options to be passed as a simple boolean if no configuration
        // is necessary.
        if (opts === true) {
          opts = {};
        }

        // We also want to pass the original player options
        // to each component as well so they don't need to
        // reach back into the player for options later.
        opts.playerOptions = _this.options_.playerOptions;

        // Create and add the child component.
        // Add a direct reference to the child by name on the parent instance.
        // If two of the same component are used, different names should be supplied
        // for each
        var newChild = _this.addChild(name, opts);

        if (newChild) {
          _this[name] = newChild;
        }
      };

      // Allow for an array of children details to passed in the options
      var workingChildren = void 0;
      var Tech = Component.getComponent('Tech');

      if (Array.isArray(children)) {
        workingChildren = children;
      } else {
        workingChildren = Object.keys(children);
      }

      workingChildren
      // children that are in this.options_ but also in workingChildren  would
      // give us extra children we do not want. So, we want to filter them out.
      .concat(Object.keys(this.options_).filter(function (child) {
        return !workingChildren.some(function (wchild) {
          if (typeof wchild === 'string') {
            return child === wchild;
          }
          return child === wchild.name;
        });
      })).map(function (child) {
        var name = void 0;
        var opts = void 0;

        if (typeof child === 'string') {
          name = child;
          opts = children[name] || _this.options_[name] || {};
        } else {
          name = child.name;
          opts = child;
        }

        return { name: name, opts: opts };
      }).filter(function (child) {
        // we have to make sure that child.name isn't in the techOrder since
        // techs are registerd as Components but can't aren't compatible
        // See https://github.com/videojs/video.js/issues/2772
        var c = Component.getComponent(child.opts.componentClass || toTitleCase(child.name));

        return c && !Tech.isTech(c);
      }).forEach(handleAdd);
    }
  };

  /**
   * Builds the default DOM class name. Should be overriden by sub-components.
   *
   * @return {string}
   *         The DOM class name for this object.
   *
   * @abstract
   */


  Component.prototype.buildCSSClass = function buildCSSClass() {
    // Child classes can include a function that does:
    // return 'CLASS NAME' + this._super();
    return '';
  };

  /**
   * Bind a listener to the component's ready state.
   * Different from event listeners in that if the ready event has already happened
   * it will trigger the function immediately.
   *
   * @return {Component}
   *         Returns itself; method can be chained.
   */


  Component.prototype.ready = function ready(fn) {
    var sync = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : false;

    if (!fn) {
      return;
    }

    if (!this.isReady_) {
      this.readyQueue_ = this.readyQueue_ || [];
      this.readyQueue_.push(fn);
      return;
    }

    if (sync) {
      fn.call(this);
    } else {
      // Call the function asynchronously by default for consistency
      this.setTimeout(fn, 1);
    }
  };

  /**
   * Trigger all the ready listeners for this `Component`.
   *
   * @fires Component#ready
   */


  Component.prototype.triggerReady = function triggerReady() {
    this.isReady_ = true;

    // Ensure ready is triggered asynchronously
    this.setTimeout(function () {
      var readyQueue = this.readyQueue_;

      // Reset Ready Queue
      this.readyQueue_ = [];

      if (readyQueue && readyQueue.length > 0) {
        readyQueue.forEach(function (fn) {
          fn.call(this);
        }, this);
      }

      // Allow for using event listeners also
      /**
       * Triggered when a `Component` is ready.
       *
       * @event Component#ready
       * @type {EventTarget~Event}
       */
      this.trigger('ready');
    }, 1);
  };

  /**
   * Find a single DOM element matching a `selector`. This can be within the `Component`s
   * `contentEl()` or another custom context.
   *
   * @param {string} selector
   *        A valid CSS selector, which will be passed to `querySelector`.
   *
   * @param {Element|string} [context=this.contentEl()]
   *        A DOM element within which to query. Can also be a selector string in
   *        which case the first matching element will get used as context. If
   *        missing `this.contentEl()` gets used. If  `this.contentEl()` returns
   *        nothing it falls back to `document`.
   *
   * @return {Element|null}
   *         the dom element that was found, or null
   *
   * @see [Information on CSS Selectors](https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Getting_Started/Selectors)
   */


  Component.prototype.$ = function $$$1(selector, context) {
    return $(selector, context || this.contentEl());
  };

  /**
   * Finds all DOM element matching a `selector`. This can be within the `Component`s
   * `contentEl()` or another custom context.
   *
   * @param {string} selector
   *        A valid CSS selector, which will be passed to `querySelectorAll`.
   *
   * @param {Element|string} [context=this.contentEl()]
   *        A DOM element within which to query. Can also be a selector string in
   *        which case the first matching element will get used as context. If
   *        missing `this.contentEl()` gets used. If  `this.contentEl()` returns
   *        nothing it falls back to `document`.
   *
   * @return {NodeList}
   *         a list of dom elements that were found
   *
   * @see [Information on CSS Selectors](https://developer.mozilla.org/en-US/docs/Web/Guide/CSS/Getting_Started/Selectors)
   */


  Component.prototype.$$ = function $$$$1(selector, context) {
    return $$(selector, context || this.contentEl());
  };

  /**
   * Check if a component's element has a CSS class name.
   *
   * @param {string} classToCheck
   *        CSS class name to check.
   *
   * @return {boolean}
   *         - True if the `Component` has the class.
   *         - False if the `Component` does not have the class`
   */


  Component.prototype.hasClass = function hasClass$$1(classToCheck) {
    return hasClass(this.el_, classToCheck);
  };

  /**
   * Add a CSS class name to the `Component`s element.
   *
   * @param {string} classToAdd
   *        CSS class name to add
   */


  Component.prototype.addClass = function addClass$$1(classToAdd) {
    addClass(this.el_, classToAdd);
  };

  /**
   * Remove a CSS class name from the `Component`s element.
   *
   * @param {string} classToRemove
   *        CSS class name to remove
   */


  Component.prototype.removeClass = function removeClass$$1(classToRemove) {
    removeClass(this.el_, classToRemove);
  };

  /**
   * Add or remove a CSS class name from the component's element.
   * - `classToToggle` gets added when {@link Component#hasClass} would return false.
   * - `classToToggle` gets removed when {@link Component#hasClass} would return true.
   *
   * @param  {string} classToToggle
   *         The class to add or remove based on (@link Component#hasClass}
   *
   * @param  {boolean|Dom~predicate} [predicate]
   *         An {@link Dom~predicate} function or a boolean
   */


  Component.prototype.toggleClass = function toggleClass$$1(classToToggle, predicate) {
    toggleClass(this.el_, classToToggle, predicate);
  };

  /**
   * Show the `Component`s element if it is hidden by removing the
   * 'vjs-hidden' class name from it.
   */


  Component.prototype.show = function show() {
    this.removeClass('vjs-hidden');
  };

  /**
   * Hide the `Component`s element if it is currently showing by adding the
   * 'vjs-hidden` class name to it.
   */


  Component.prototype.hide = function hide() {
    this.addClass('vjs-hidden');
  };

  /**
   * Lock a `Component`s element in its visible state by adding the 'vjs-lock-showing'
   * class name to it. Used during fadeIn/fadeOut.
   *
   * @private
   */


  Component.prototype.lockShowing = function lockShowing() {
    this.addClass('vjs-lock-showing');
  };

  /**
   * Unlock a `Component`s element from its visible state by removing the 'vjs-lock-showing'
   * class name from it. Used during fadeIn/fadeOut.
   *
   * @private
   */


  Component.prototype.unlockShowing = function unlockShowing() {
    this.removeClass('vjs-lock-showing');
  };

  /**
   * Get the value of an attribute on the `Component`s element.
   *
   * @param {string} attribute
   *        Name of the attribute to get the value from.
   *
   * @return {string|null}
   *         - The value of the attribute that was asked for.
   *         - Can be an empty string on some browsers if the attribute does not exist
   *           or has no value
   *         - Most browsers will return null if the attibute does not exist or has
   *           no value.
   *
   * @see [DOM API]{@link https://developer.mozilla.org/en-US/docs/Web/API/Element/getAttribute}
   */


  Component.prototype.getAttribute = function getAttribute$$1(attribute) {
    return getAttribute(this.el_, attribute);
  };

  /**
   * Set the value of an attribute on the `Component`'s element
   *
   * @param {string} attribute
   *        Name of the attribute to set.
   *
   * @param {string} value
   *        Value to set the attribute to.
   *
   * @see [DOM API]{@link https://developer.mozilla.org/en-US/docs/Web/API/Element/setAttribute}
   */


  Component.prototype.setAttribute = function setAttribute$$1(attribute, value) {
    setAttribute(this.el_, attribute, value);
  };

  /**
   * Remove an attribute from the `Component`s element.
   *
   * @param {string} attribute
   *        Name of the attribute to remove.
   *
   * @see [DOM API]{@link https://developer.mozilla.org/en-US/docs/Web/API/Element/removeAttribute}
   */


  Component.prototype.removeAttribute = function removeAttribute$$1(attribute) {
    removeAttribute(this.el_, attribute);
  };

  /**
   * Get or set the width of the component based upon the CSS styles.
   * See {@link Component#dimension} for more detailed information.
   *
   * @param {number|string} [num]
   *        The width that you want to set postfixed with '%', 'px' or nothing.
   *
   * @param {boolean} [skipListeners]
   *        Skip the componentresize event trigger
   *
   * @return {number|string}
   *         The width when getting, zero if there is no width. Can be a string
   *           postpixed with '%' or 'px'.
   */


  Component.prototype.width = function width(num, skipListeners) {
    return this.dimension('width', num, skipListeners);
  };

  /**
   * Get or set the height of the component based upon the CSS styles.
   * See {@link Component#dimension} for more detailed information.
   *
   * @param {number|string} [num]
   *        The height that you want to set postfixed with '%', 'px' or nothing.
   *
   * @param {boolean} [skipListeners]
   *        Skip the componentresize event trigger
   *
   * @return {number|string}
   *         The width when getting, zero if there is no width. Can be a string
   *         postpixed with '%' or 'px'.
   */


  Component.prototype.height = function height(num, skipListeners) {
    return this.dimension('height', num, skipListeners);
  };

  /**
   * Set both the width and height of the `Component` element at the same time.
   *
   * @param  {number|string} width
   *         Width to set the `Component`s element to.
   *
   * @param  {number|string} height
   *         Height to set the `Component`s element to.
   */


  Component.prototype.dimensions = function dimensions(width, height) {
    // Skip componentresize listeners on width for optimization
    this.width(width, true);
    this.height(height);
  };

  /**
   * Get or set width or height of the `Component` element. This is the shared code
   * for the {@link Component#width} and {@link Component#height}.
   *
   * Things to know:
   * - If the width or height in an number this will return the number postfixed with 'px'.
   * - If the width/height is a percent this will return the percent postfixed with '%'
   * - Hidden elements have a width of 0 with `window.getComputedStyle`. This function
   *   defaults to the `Component`s `style.width` and falls back to `window.getComputedStyle`.
   *   See [this]{@link http://www.foliotek.com/devblog/getting-the-width-of-a-hidden-element-with-jquery-using-width/}
   *   for more information
   * - If you want the computed style of the component, use {@link Component#currentWidth}
   *   and {@link {Component#currentHeight}
   *
   * @fires Component#componentresize
   *
   * @param {string} widthOrHeight
   8        'width' or 'height'
   *
   * @param  {number|string} [num]
   8         New dimension
   *
   * @param  {boolean} [skipListeners]
   *         Skip componentresize event trigger
   *
   * @return {number}
   *         The dimension when getting or 0 if unset
   */


  Component.prototype.dimension = function dimension(widthOrHeight, num, skipListeners) {
    if (num !== undefined) {
      // Set to zero if null or literally NaN (NaN !== NaN)
      if (num === null || num !== num) {
        num = 0;
      }

      // Check if using css width/height (% or px) and adjust
      if (('' + num).indexOf('%') !== -1 || ('' + num).indexOf('px') !== -1) {
        this.el_.style[widthOrHeight] = num;
      } else if (num === 'auto') {
        this.el_.style[widthOrHeight] = '';
      } else {
        this.el_.style[widthOrHeight] = num + 'px';
      }

      // skipListeners allows us to avoid triggering the resize event when setting both width and height
      if (!skipListeners) {
        /**
         * Triggered when a component is resized.
         *
         * @event Component#componentresize
         * @type {EventTarget~Event}
         */
        this.trigger('componentresize');
      }

      return;
    }

    // Not setting a value, so getting it
    // Make sure element exists
    if (!this.el_) {
      return 0;
    }

    // Get dimension value from style
    var val = this.el_.style[widthOrHeight];
    var pxIndex = val.indexOf('px');

    if (pxIndex !== -1) {
      // Return the pixel value with no 'px'
      return parseInt(val.slice(0, pxIndex), 10);
    }

    // No px so using % or no style was set, so falling back to offsetWidth/height
    // If component has display:none, offset will return 0
    // TODO: handle display:none and no dimension style using px
    return parseInt(this.el_['offset' + toTitleCase(widthOrHeight)], 10);
  };

  /**
   * Get the width or the height of the `Component` elements computed style. Uses
   * `window.getComputedStyle`.
   *
   * @param {string} widthOrHeight
   *        A string containing 'width' or 'height'. Whichever one you want to get.
   *
   * @return {number}
   *         The dimension that gets asked for or 0 if nothing was set
   *         for that dimension.
   */


  Component.prototype.currentDimension = function currentDimension(widthOrHeight) {
    var computedWidthOrHeight = 0;

    if (widthOrHeight !== 'width' && widthOrHeight !== 'height') {
      throw new Error('currentDimension only accepts width or height value');
    }

    if (typeof window_1.getComputedStyle === 'function') {
      var computedStyle = window_1.getComputedStyle(this.el_);

      computedWidthOrHeight = computedStyle.getPropertyValue(widthOrHeight) || computedStyle[widthOrHeight];
    }

    // remove 'px' from variable and parse as integer
    computedWidthOrHeight = parseFloat(computedWidthOrHeight);

    // if the computed value is still 0, it's possible that the browser is lying
    // and we want to check the offset values.
    // This code also runs on IE8 and wherever getComputedStyle doesn't exist.
    if (computedWidthOrHeight === 0) {
      var rule = 'offset' + toTitleCase(widthOrHeight);

      computedWidthOrHeight = this.el_[rule];
    }

    return computedWidthOrHeight;
  };

  /**
   * An object that contains width and height values of the `Component`s
   * computed style. Uses `window.getComputedStyle`.
   *
   * @typedef {Object} Component~DimensionObject
   *
   * @property {number} width
   *           The width of the `Component`s computed style.
   *
   * @property {number} height
   *           The height of the `Component`s computed style.
   */

  /**
   * Get an object that contains width and height values of the `Component`s
   * computed style.
   *
   * @return {Component~DimensionObject}
   *         The dimensions of the components element
   */


  Component.prototype.currentDimensions = function currentDimensions() {
    return {
      width: this.currentDimension('width'),
      height: this.currentDimension('height')
    };
  };

  /**
   * Get the width of the `Component`s computed style. Uses `window.getComputedStyle`.
   *
   * @return {number} width
   *           The width of the `Component`s computed style.
   */


  Component.prototype.currentWidth = function currentWidth() {
    return this.currentDimension('width');
  };

  /**
   * Get the height of the `Component`s computed style. Uses `window.getComputedStyle`.
   *
   * @return {number} height
   *           The height of the `Component`s computed style.
   */


  Component.prototype.currentHeight = function currentHeight() {
    return this.currentDimension('height');
  };

  /**
   * Set the focus to this component
   */


  Component.prototype.focus = function focus() {
    this.el_.focus();
  };

  /**
   * Remove the focus from this component
   */


  Component.prototype.blur = function blur() {
    this.el_.blur();
  };

  /**
   * Emit a 'tap' events when touch event support gets detected. This gets used to
   * support toggling the controls through a tap on the video. They get enabled
   * because every sub-component would have extra overhead otherwise.
   *
   * @private
   * @fires Component#tap
   * @listens Component#touchstart
   * @listens Component#touchmove
   * @listens Component#touchleave
   * @listens Component#touchcancel
   * @listens Component#touchend
    */


  Component.prototype.emitTapEvents = function emitTapEvents() {
    // Track the start time so we can determine how long the touch lasted
    var touchStart = 0;
    var firstTouch = null;

    // Maximum movement allowed during a touch event to still be considered a tap
    // Other popular libs use anywhere from 2 (hammer.js) to 15,
    // so 10 seems like a nice, round number.
    var tapMovementThreshold = 10;

    // The maximum length a touch can be while still being considered a tap
    var touchTimeThreshold = 200;

    var couldBeTap = void 0;

    this.on('touchstart', function (event) {
      // If more than one finger, don't consider treating this as a click
      if (event.touches.length === 1) {
        // Copy pageX/pageY from the object
        firstTouch = {
          pageX: event.touches[0].pageX,
          pageY: event.touches[0].pageY
        };
        // Record start time so we can detect a tap vs. "touch and hold"
        touchStart = new Date().getTime();
        // Reset couldBeTap tracking
        couldBeTap = true;
      }
    });

    this.on('touchmove', function (event) {
      // If more than one finger, don't consider treating this as a click
      if (event.touches.length > 1) {
        couldBeTap = false;
      } else if (firstTouch) {
        // Some devices will throw touchmoves for all but the slightest of taps.
        // So, if we moved only a small distance, this could still be a tap
        var xdiff = event.touches[0].pageX - firstTouch.pageX;
        var ydiff = event.touches[0].pageY - firstTouch.pageY;
        var touchDistance = Math.sqrt(xdiff * xdiff + ydiff * ydiff);

        if (touchDistance > tapMovementThreshold) {
          couldBeTap = false;
        }
      }
    });

    var noTap = function noTap() {
      couldBeTap = false;
    };

    // TODO: Listen to the original target. http://youtu.be/DujfpXOKUp8?t=13m8s
    this.on('touchleave', noTap);
    this.on('touchcancel', noTap);

    // When the touch ends, measure how long it took and trigger the appropriate
    // event
    this.on('touchend', function (event) {
      firstTouch = null;
      // Proceed only if the touchmove/leave/cancel event didn't happen
      if (couldBeTap === true) {
        // Measure how long the touch lasted
        var touchTime = new Date().getTime() - touchStart;

        // Make sure the touch was less than the threshold to be considered a tap
        if (touchTime < touchTimeThreshold) {
          // Don't let browser turn this into a click
          event.preventDefault();
          /**
           * Triggered when a `Component` is tapped.
           *
           * @event Component#tap
           * @type {EventTarget~Event}
           */
          this.trigger('tap');
          // It may be good to copy the touchend event object and change the
          // type to tap, if the other event properties aren't exact after
          // Events.fixEvent runs (e.g. event.target)
        }
      }
    });
  };

  /**
   * This function reports user activity whenever touch events happen. This can get
   * turned off by any sub-components that wants touch events to act another way.
   *
   * Report user touch activity when touch events occur. User activity gets used to
   * determine when controls should show/hide. It is simple when it comes to mouse
   * events, because any mouse event should show the controls. So we capture mouse
   * events that bubble up to the player and report activity when that happens.
   * With touch events it isn't as easy as `touchstart` and `touchend` toggle player
   * controls. So touch events can't help us at the player level either.
   *
   * User activity gets checked asynchronously. So what could happen is a tap event
   * on the video turns the controls off. Then the `touchend` event bubbles up to
   * the player. Which, if it reported user activity, would turn the controls right
   * back on. We also don't want to completely block touch events from bubbling up.
   * Furthermore a `touchmove` event and anything other than a tap, should not turn
   * controls back on.
   *
   * @listens Component#touchstart
   * @listens Component#touchmove
   * @listens Component#touchend
   * @listens Component#touchcancel
   */


  Component.prototype.enableTouchActivity = function enableTouchActivity() {
    // Don't continue if the root player doesn't support reporting user activity
    if (!this.player() || !this.player().reportUserActivity) {
      return;
    }

    // listener for reporting that the user is active
    var report = bind(this.player(), this.player().reportUserActivity);

    var touchHolding = void 0;

    this.on('touchstart', function () {
      report();
      // For as long as the they are touching the device or have their mouse down,
      // we consider them active even if they're not moving their finger or mouse.
      // So we want to continue to update that they are active
      this.clearInterval(touchHolding);
      // report at the same interval as activityCheck
      touchHolding = this.setInterval(report, 250);
    });

    var touchEnd = function touchEnd(event) {
      report();
      // stop the interval that maintains activity if the touch is holding
      this.clearInterval(touchHolding);
    };

    this.on('touchmove', report);
    this.on('touchend', touchEnd);
    this.on('touchcancel', touchEnd);
  };

  /**
   * A callback that has no parameters and is bound into `Component`s context.
   *
   * @callback Component~GenericCallback
   * @this Component
   */

  /**
   * Creates a function that runs after an `x` millisecond timeout. This function is a
   * wrapper around `window.setTimeout`. There are a few reasons to use this one
   * instead though:
   * 1. It gets cleared via  {@link Component#clearTimeout} when
   *    {@link Component#dispose} gets called.
   * 2. The function callback will gets turned into a {@link Component~GenericCallback}
   *
   * > Note: You can't use `window.clearTimeout` on the id returned by this function. This
   *         will cause its dispose listener not to get cleaned up! Please use
   *         {@link Component#clearTimeout} or {@link Component#dispose} instead.
   *
   * @param {Component~GenericCallback} fn
   *        The function that will be run after `timeout`.
   *
   * @param {number} timeout
   *        Timeout in milliseconds to delay before executing the specified function.
   *
   * @return {number}
   *         Returns a timeout ID that gets used to identify the timeout. It can also
   *         get used in {@link Component#clearTimeout} to clear the timeout that
   *         was set.
   *
   * @listens Component#dispose
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/setTimeout}
   */


  Component.prototype.setTimeout = function setTimeout(fn, timeout) {
    var _this2 = this;

    // declare as variables so they are properly available in timeout function
    // eslint-disable-next-line
    var timeoutId, disposeFn;

    fn = bind(this, fn);

    timeoutId = window_1.setTimeout(function () {
      _this2.off('dispose', disposeFn);
      fn();
    }, timeout);

    disposeFn = function disposeFn() {
      return _this2.clearTimeout(timeoutId);
    };

    disposeFn.guid = 'vjs-timeout-' + timeoutId;

    this.on('dispose', disposeFn);

    return timeoutId;
  };

  /**
   * Clears a timeout that gets created via `window.setTimeout` or
   * {@link Component#setTimeout}. If you set a timeout via {@link Component#setTimeout}
   * use this function instead of `window.clearTimout`. If you don't your dispose
   * listener will not get cleaned up until {@link Component#dispose}!
   *
   * @param {number} timeoutId
   *        The id of the timeout to clear. The return value of
   *        {@link Component#setTimeout} or `window.setTimeout`.
   *
   * @return {number}
   *         Returns the timeout id that was cleared.
   *
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/clearTimeout}
   */


  Component.prototype.clearTimeout = function clearTimeout(timeoutId) {
    window_1.clearTimeout(timeoutId);

    var disposeFn = function disposeFn() {};

    disposeFn.guid = 'vjs-timeout-' + timeoutId;

    this.off('dispose', disposeFn);

    return timeoutId;
  };

  /**
   * Creates a function that gets run every `x` milliseconds. This function is a wrapper
   * around `window.setInterval`. There are a few reasons to use this one instead though.
   * 1. It gets cleared via  {@link Component#clearInterval} when
   *    {@link Component#dispose} gets called.
   * 2. The function callback will be a {@link Component~GenericCallback}
   *
   * @param {Component~GenericCallback} fn
   *        The function to run every `x` seconds.
   *
   * @param {number} interval
   *        Execute the specified function every `x` milliseconds.
   *
   * @return {number}
   *         Returns an id that can be used to identify the interval. It can also be be used in
   *         {@link Component#clearInterval} to clear the interval.
   *
   * @listens Component#dispose
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/setInterval}
   */


  Component.prototype.setInterval = function setInterval(fn, interval) {
    var _this3 = this;

    fn = bind(this, fn);

    var intervalId = window_1.setInterval(fn, interval);

    var disposeFn = function disposeFn() {
      return _this3.clearInterval(intervalId);
    };

    disposeFn.guid = 'vjs-interval-' + intervalId;

    this.on('dispose', disposeFn);

    return intervalId;
  };

  /**
   * Clears an interval that gets created via `window.setInterval` or
   * {@link Component#setInterval}. If you set an inteval via {@link Component#setInterval}
   * use this function instead of `window.clearInterval`. If you don't your dispose
   * listener will not get cleaned up until {@link Component#dispose}!
   *
   * @param {number} intervalId
   *        The id of the interval to clear. The return value of
   *        {@link Component#setInterval} or `window.setInterval`.
   *
   * @return {number}
   *         Returns the interval id that was cleared.
   *
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/WindowTimers/clearInterval}
   */


  Component.prototype.clearInterval = function clearInterval(intervalId) {
    window_1.clearInterval(intervalId);

    var disposeFn = function disposeFn() {};

    disposeFn.guid = 'vjs-interval-' + intervalId;

    this.off('dispose', disposeFn);

    return intervalId;
  };

  /**
   * Queues up a callback to be passed to requestAnimationFrame (rAF), but
   * with a few extra bonuses:
   *
   * - Supports browsers that do not support rAF by falling back to
   *   {@link Component#setTimeout}.
   *
   * - The callback is turned into a {@link Component~GenericCallback} (i.e.
   *   bound to the component).
   *
   * - Automatic cancellation of the rAF callback is handled if the component
   *   is disposed before it is called.
   *
   * @param  {Component~GenericCallback} fn
   *         A function that will be bound to this component and executed just
   *         before the browser's next repaint.
   *
   * @return {number}
   *         Returns an rAF ID that gets used to identify the timeout. It can
   *         also be used in {@link Component#cancelAnimationFrame} to cancel
   *         the animation frame callback.
   *
   * @listens Component#dispose
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/window/requestAnimationFrame}
   */


  Component.prototype.requestAnimationFrame = function requestAnimationFrame(fn) {
    var _this4 = this;

    // declare as variables so they are properly available in rAF function
    // eslint-disable-next-line
    var id, disposeFn;

    if (this.supportsRaf_) {
      fn = bind(this, fn);

      id = window_1.requestAnimationFrame(function () {
        _this4.off('dispose', disposeFn);
        fn();
      });

      disposeFn = function disposeFn() {
        return _this4.cancelAnimationFrame(id);
      };

      disposeFn.guid = 'vjs-raf-' + id;
      this.on('dispose', disposeFn);

      return id;
    }

    // Fall back to using a timer.
    return this.setTimeout(fn, 1000 / 60);
  };

  /**
   * Cancels a queued callback passed to {@link Component#requestAnimationFrame}
   * (rAF).
   *
   * If you queue an rAF callback via {@link Component#requestAnimationFrame},
   * use this function instead of `window.cancelAnimationFrame`. If you don't,
   * your dispose listener will not get cleaned up until {@link Component#dispose}!
   *
   * @param {number} id
   *        The rAF ID to clear. The return value of {@link Component#requestAnimationFrame}.
   *
   * @return {number}
   *         Returns the rAF ID that was cleared.
   *
   * @see [Similar to]{@link https://developer.mozilla.org/en-US/docs/Web/API/window/cancelAnimationFrame}
   */


  Component.prototype.cancelAnimationFrame = function cancelAnimationFrame(id) {
    if (this.supportsRaf_) {
      window_1.cancelAnimationFrame(id);

      var disposeFn = function disposeFn() {};

      disposeFn.guid = 'vjs-raf-' + id;

      this.off('dispose', disposeFn);

      return id;
    }

    // Fall back to using a timer.
    return this.clearTimeout(id);
  };

  /**
   * Register a `Component` with `videojs` given the name and the component.
   *
   * > NOTE: {@link Tech}s should not be registered as a `Component`. {@link Tech}s
   *         should be registered using {@link Tech.registerTech} or
   *         {@link videojs:videojs.registerTech}.
   *
   * > NOTE: This function can also be seen on videojs as
   *         {@link videojs:videojs.registerComponent}.
   *
   * @param {string} name
   *        The name of the `Component` to register.
   *
   * @param {Component} ComponentToRegister
   *        The `Component` class to register.
   *
   * @return {Component}
   *         The `Component` that was registered.
   */


  Component.registerComponent = function registerComponent(name, ComponentToRegister) {
    if (typeof name !== 'string' || !name) {
      throw new Error('Illegal component name, "' + name + '"; must be a non-empty string.');
    }

    var Tech = Component.getComponent('Tech');

    // We need to make sure this check is only done if Tech has been registered.
    var isTech = Tech && Tech.isTech(ComponentToRegister);
    var isComp = Component === ComponentToRegister || Component.prototype.isPrototypeOf(ComponentToRegister.prototype);

    if (isTech || !isComp) {
      var reason = void 0;

      if (isTech) {
        reason = 'techs must be registered using Tech.registerTech()';
      } else {
        reason = 'must be a Component subclass';
      }

      throw new Error('Illegal component, "' + name + '"; ' + reason + '.');
    }

    name = toTitleCase(name);

    if (!Component.components_) {
      Component.components_ = {};
    }

    var Player = Component.getComponent('Player');

    if (name === 'Player' && Player && Player.players) {
      var players = Player.players;
      var playerNames = Object.keys(players);

      // If we have players that were disposed, then their name will still be
      // in Players.players. So, we must loop through and verify that the value
      // for each item is not null. This allows registration of the Player component
      // after all players have been disposed or before any were created.
      if (players && playerNames.length > 0 && playerNames.map(function (pname) {
        return players[pname];
      }).every(Boolean)) {
        throw new Error('Can not register Player component after player has been created.');
      }
    }

    Component.components_[name] = ComponentToRegister;

    return ComponentToRegister;
  };

  /**
   * Get a `Component` based on the name it was registered with.
   *
   * @param {string} name
   *        The Name of the component to get.
   *
   * @return {Component}
   *         The `Component` that got registered under the given name.
   *
   * @deprecated In `videojs` 6 this will not return `Component`s that were not
   *             registered using {@link Component.registerComponent}. Currently we
   *             check the global `videojs` object for a `Component` name and
   *             return that if it exists.
   */


  Component.getComponent = function getComponent(name) {
    if (!name) {
      return;
    }

    name = toTitleCase(name);

    if (Component.components_ && Component.components_[name]) {
      return Component.components_[name];
    }
  };

  return Component;
}();

/**
 * Whether or not this component supports `requestAnimationFrame`.
 *
 * This is exposed primarily for testing purposes.
 *
 * @private
 * @type {Boolean}
 */


Component.prototype.supportsRaf_ = typeof window_1.requestAnimationFrame === 'function' && typeof window_1.cancelAnimationFrame === 'function';

Component.registerComponent('Component', Component);

/**
 * @file time-ranges.js
 * @module time-ranges
 */

/**
 * Returns the time for the specified index at the start or end
 * of a TimeRange object.
 *
 * @function time-ranges:indexFunction
 *
 * @param {number} [index=0]
 *        The range number to return the time for.
 *
 * @return {number}
 *         The time that offset at the specified index.
 *
 * @depricated index must be set to a value, in the future this will throw an error.
 */

/**
 * An object that contains ranges of time for various reasons.
 *
 * @typedef {Object} TimeRange
 *
 * @property {number} length
 *           The number of time ranges represented by this Object
 *
 * @property {time-ranges:indexFunction} start
 *           Returns the time offset at which a specified time range begins.
 *
 * @property {time-ranges:indexFunction} end
 *           Returns the time offset at which a specified time range ends.
 *
 * @see https://developer.mozilla.org/en-US/docs/Web/API/TimeRanges
 */

/**
 * Check if any of the time ranges are over the maximum index.
 *
 * @param {string} fnName
 *        The function name to use for logging
 *
 * @param {number} index
 *        The index to check
 *
 * @param {number} maxIndex
 *        The maximum possible index
 *
 * @throws {Error} if the timeRanges provided are over the maxIndex
 */
function rangeCheck(fnName, index, maxIndex) {
  if (typeof index !== 'number' || index < 0 || index > maxIndex) {
    throw new Error('Failed to execute \'' + fnName + '\' on \'TimeRanges\': The index provided (' + index + ') is non-numeric or out of bounds (0-' + maxIndex + ').');
  }
}

/**
 * Get the time for the specified index at the start or end
 * of a TimeRange object.
 *
 * @param {string} fnName
 *        The function name to use for logging
 *
 * @param {string} valueIndex
 *        The proprety that should be used to get the time. should be 'start' or 'end'
 *
 * @param {Array} ranges
 *        An array of time ranges
 *
 * @param {Array} [rangeIndex=0]
 *        The index to start the search at
 *
 * @return {number}
 *         The time that offset at the specified index.
 *
 *
 * @depricated rangeIndex must be set to a value, in the future this will throw an error.
 * @throws {Error} if rangeIndex is more than the length of ranges
 */
function getRange(fnName, valueIndex, ranges, rangeIndex) {
  rangeCheck(fnName, rangeIndex, ranges.length - 1);
  return ranges[rangeIndex][valueIndex];
}

/**
 * Create a time range object given ranges of time.
 *
 * @param {Array} [ranges]
 *        An array of time ranges.
 */
function createTimeRangesObj(ranges) {
  if (ranges === undefined || ranges.length === 0) {
    return {
      length: 0,
      start: function start() {
        throw new Error('This TimeRanges object is empty');
      },
      end: function end() {
        throw new Error('This TimeRanges object is empty');
      }
    };
  }
  return {
    length: ranges.length,
    start: getRange.bind(null, 'start', 0, ranges),
    end: getRange.bind(null, 'end', 1, ranges)
  };
}

/**
 * Should create a fake `TimeRange` object which mimics an HTML5 time range instance.
 *
 * @param {number|Array} start
 *        The start of a single range or an array of ranges
 *
 * @param {number} end
 *        The end of a single range.
 *
 * @private
 */
function createTimeRanges(start, end) {
  if (Array.isArray(start)) {
    return createTimeRangesObj(start);
  } else if (start === undefined || end === undefined) {
    return createTimeRangesObj();
  }
  return createTimeRangesObj([[start, end]]);
}

/**
 * @file buffer.js
 * @module buffer
 */
/**
 * Compute the percentage of the media that has been buffered.
 *
 * @param {TimeRange} buffered
 *        The current `TimeRange` object representing buffered time ranges
 *
 * @param {number} duration
 *        Total duration of the media
 *
 * @return {number}
 *         Percent buffered of the total duration in decimal form.
 */
function bufferedPercent(buffered, duration) {
  var bufferedDuration = 0;
  var start = void 0;
  var end = void 0;

  if (!duration) {
    return 0;
  }

  if (!buffered || !buffered.length) {
    buffered = createTimeRanges(0, 0);
  }

  for (var i = 0; i < buffered.length; i++) {
    start = buffered.start(i);
    end = buffered.end(i);

    // buffered end can be bigger than duration by a very small fraction
    if (end > duration) {
      end = duration;
    }

    bufferedDuration += end - start;
  }

  return bufferedDuration / duration;
}

/**
 * @file fullscreen-api.js
 * @module fullscreen-api
 * @private
 */
/**
 * Store the browser-specific methods for the fullscreen API.
 *
 * @type {Object}
 * @see [Specification]{@link https://fullscreen.spec.whatwg.org}
 * @see [Map Approach From Screenfull.js]{@link https://github.com/sindresorhus/screenfull.js}
 */
var FullscreenApi = {};

// browser API methods
var apiMap = [['requestFullscreen', 'exitFullscreen', 'fullscreenElement', 'fullscreenEnabled', 'fullscreenchange', 'fullscreenerror'],
// WebKit
['webkitRequestFullscreen', 'webkitExitFullscreen', 'webkitFullscreenElement', 'webkitFullscreenEnabled', 'webkitfullscreenchange', 'webkitfullscreenerror'],
// Old WebKit (Safari 5.1)
['webkitRequestFullScreen', 'webkitCancelFullScreen', 'webkitCurrentFullScreenElement', 'webkitCancelFullScreen', 'webkitfullscreenchange', 'webkitfullscreenerror'],
// Mozilla
['mozRequestFullScreen', 'mozCancelFullScreen', 'mozFullScreenElement', 'mozFullScreenEnabled', 'mozfullscreenchange', 'mozfullscreenerror'],
// Microsoft
['msRequestFullscreen', 'msExitFullscreen', 'msFullscreenElement', 'msFullscreenEnabled', 'MSFullscreenChange', 'MSFullscreenError']];

var specApi = apiMap[0];
var browserApi = void 0;

// determine the supported set of functions
for (var i = 0; i < apiMap.length; i++) {
  // check for exitFullscreen function
  if (apiMap[i][1] in document_1) {
    browserApi = apiMap[i];
    break;
  }
}

// map the browser API names to the spec API names
if (browserApi) {
  for (var _i = 0; _i < browserApi.length; _i++) {
    FullscreenApi[specApi[_i]] = browserApi[_i];
  }
}

/**
 * @file media-error.js
 */
/**
 * A Custom `MediaError` class which mimics the standard HTML5 `MediaError` class.
 *
 * @param {number|string|Object|MediaError} value
 *        This can be of multiple types:
 *        - number: should be a standard error code
 *        - string: an error message (the code will be 0)
 *        - Object: arbitrary properties
 *        - `MediaError` (native): used to populate a video.js `MediaError` object
 *        - `MediaError` (video.js): will return itself if it's already a
 *          video.js `MediaError` object.
 *
 * @see [MediaError Spec]{@link https://dev.w3.org/html5/spec-author-view/video.html#mediaerror}
 * @see [Encrypted MediaError Spec]{@link https://www.w3.org/TR/2013/WD-encrypted-media-20130510/#error-codes}
 *
 * @class MediaError
 */
function MediaError(value) {

  // Allow redundant calls to this constructor to avoid having `instanceof`
  // checks peppered around the code.
  if (value instanceof MediaError) {
    return value;
  }

  if (typeof value === 'number') {
    this.code = value;
  } else if (typeof value === 'string') {
    // default code is zero, so this is a custom error
    this.message = value;
  } else if (isObject(value)) {

    // We assign the `code` property manually because native `MediaError` objects
    // do not expose it as an own/enumerable property of the object.
    if (typeof value.code === 'number') {
      this.code = value.code;
    }

    assign(this, value);
  }

  if (!this.message) {
    this.message = MediaError.defaultMessages[this.code] || '';
  }
}

/**
 * The error code that refers two one of the defined `MediaError` types
 *
 * @type {Number}
 */
MediaError.prototype.code = 0;

/**
 * An optional message that to show with the error. Message is not part of the HTML5
 * video spec but allows for more informative custom errors.
 *
 * @type {String}
 */
MediaError.prototype.message = '';

/**
 * An optional status code that can be set by plugins to allow even more detail about
 * the error. For example a plugin might provide a specific HTTP status code and an
 * error message for that code. Then when the plugin gets that error this class will
 * know how to display an error message for it. This allows a custom message to show
 * up on the `Player` error overlay.
 *
 * @type {Array}
 */
MediaError.prototype.status = null;

/**
 * Errors indexed by the W3C standard. The order **CANNOT CHANGE**! See the
 * specification listed under {@link MediaError} for more information.
 *
 * @enum {array}
 * @readonly
 * @property {string} 0 - MEDIA_ERR_CUSTOM
 * @property {string} 1 - MEDIA_ERR_CUSTOM
 * @property {string} 2 - MEDIA_ERR_ABORTED
 * @property {string} 3 - MEDIA_ERR_NETWORK
 * @property {string} 4 - MEDIA_ERR_SRC_NOT_SUPPORTED
 * @property {string} 5 - MEDIA_ERR_ENCRYPTED
 */
MediaError.errorTypes = ['MEDIA_ERR_CUSTOM', 'MEDIA_ERR_ABORTED', 'MEDIA_ERR_NETWORK', 'MEDIA_ERR_DECODE', 'MEDIA_ERR_SRC_NOT_SUPPORTED', 'MEDIA_ERR_ENCRYPTED'];

/**
 * The default `MediaError` messages based on the {@link MediaError.errorTypes}.
 *
 * @type {Array}
 * @constant
 */
MediaError.defaultMessages = {
  1: 'You aborted the media playback',
  2: 'A network error caused the media download to fail part-way.',
  3: 'The media playback was aborted due to a corruption problem or because the media used features your browser did not support.',
  4: 'The media could not be loaded, either because the server or network failed or because the format is not supported.',
  5: 'The media is encrypted and we do not have the keys to decrypt it.'
};

// Add types as properties on MediaError
// e.g. MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED = 4;
for (var errNum = 0; errNum < MediaError.errorTypes.length; errNum++) {
  MediaError[MediaError.errorTypes[errNum]] = errNum;
  // values should be accessible on both the class and instance
  MediaError.prototype[MediaError.errorTypes[errNum]] = errNum;
}

var tuple = SafeParseTuple;

function SafeParseTuple(obj, reviver) {
    var json;
    var error = null;

    try {
        json = JSON.parse(obj, reviver);
    } catch (err) {
        error = err;
    }

    return [error, json]
}

/**
 * Returns whether an object is `Promise`-like (i.e. has a `then` method).
 *
 * @param  {Object}  value
 *         An object that may or may not be `Promise`-like.
 *
 * @return {Boolean}
 *         Whether or not the object is `Promise`-like.
 */
function isPromise(value) {
  return value !== undefined && value !== null && typeof value.then === 'function';
}

/**
 * Silence a Promise-like object.
 *
 * This is useful for avoiding non-harmful, but potentially confusing "uncaught
 * play promise" rejection error messages.
 *
 * @param  {Object} value
 *         An object that may or may not be `Promise`-like.
 */
function silencePromise(value) {
  if (isPromise(value)) {
    value.then(null, function (e) {});
  }
}

/**
 * @file text-track-list-converter.js Utilities for capturing text track state and
 * re-creating tracks based on a capture.
 *
 * @module text-track-list-converter
 */

/**
 * Examine a single {@link TextTrack} and return a JSON-compatible javascript object that
 * represents the {@link TextTrack}'s state.
 *
 * @param {TextTrack} track
 *        The text track to query.
 *
 * @return {Object}
 *         A serializable javascript representation of the TextTrack.
 * @private
 */
var trackToJson_ = function trackToJson_(track) {
  var ret = ['kind', 'label', 'language', 'id', 'inBandMetadataTrackDispatchType', 'mode', 'src'].reduce(function (acc, prop, i) {

    if (track[prop]) {
      acc[prop] = track[prop];
    }

    return acc;
  }, {
    cues: track.cues && Array.prototype.map.call(track.cues, function (cue) {
      return {
        startTime: cue.startTime,
        endTime: cue.endTime,
        text: cue.text,
        id: cue.id
      };
    })
  });

  return ret;
};

/**
 * Examine a {@link Tech} and return a JSON-compatible javascript array that represents the
 * state of all {@link TextTrack}s currently configured. The return array is compatible with
 * {@link text-track-list-converter:jsonToTextTracks}.
 *
 * @param {Tech} tech
 *        The tech object to query
 *
 * @return {Array}
 *         A serializable javascript representation of the {@link Tech}s
 *         {@link TextTrackList}.
 */
var textTracksToJson = function textTracksToJson(tech) {

  var trackEls = tech.$$('track');

  var trackObjs = Array.prototype.map.call(trackEls, function (t) {
    return t.track;
  });
  var tracks = Array.prototype.map.call(trackEls, function (trackEl) {
    var json = trackToJson_(trackEl.track);

    if (trackEl.src) {
      json.src = trackEl.src;
    }
    return json;
  });

  return tracks.concat(Array.prototype.filter.call(tech.textTracks(), function (track) {
    return trackObjs.indexOf(track) === -1;
  }).map(trackToJson_));
};

/**
 * Create a set of remote {@link TextTrack}s on a {@link Tech} based on an array of javascript
 * object {@link TextTrack} representations.
 *
 * @param {Array} json
 *        An array of `TextTrack` representation objects, like those that would be
 *        produced by `textTracksToJson`.
 *
 * @param {Tech} tech
 *        The `Tech` to create the `TextTrack`s on.
 */
var jsonToTextTracks = function jsonToTextTracks(json, tech) {
  json.forEach(function (track) {
    var addedTrack = tech.addRemoteTextTrack(track).track;

    if (!track.src && track.cues) {
      track.cues.forEach(function (cue) {
        return addedTrack.addCue(cue);
      });
    }
  });

  return tech.textTracks();
};

var textTrackConverter = { textTracksToJson: textTracksToJson, jsonToTextTracks: jsonToTextTracks, trackToJson_: trackToJson_ };

/**
 * @file modal-dialog.js
 */
var MODAL_CLASS_NAME = 'vjs-modal-dialog';
var ESC = 27;

/**
 * The `ModalDialog` displays over the video and its controls, which blocks
 * interaction with the player until it is closed.
 *
 * Modal dialogs include a "Close" button and will close when that button
 * is activated - or when ESC is pressed anywhere.
 *
 * @extends Component
 */

var ModalDialog = function (_Component) {
  inherits(ModalDialog, _Component);

  /**
   * Create an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Mixed} [options.content=undefined]
   *        Provide customized content for this modal.
   *
   * @param {string} [options.description]
   *        A text description for the modal, primarily for accessibility.
   *
   * @param {boolean} [options.fillAlways=false]
   *        Normally, modals are automatically filled only the first time
   *        they open. This tells the modal to refresh its content
   *        every time it opens.
   *
   * @param {string} [options.label]
   *        A text label for the modal, primarily for accessibility.
   *
   * @param {boolean} [options.temporary=true]
   *        If `true`, the modal can only be opened once; it will be
   *        disposed as soon as it's closed.
   *
   * @param {boolean} [options.uncloseable=false]
   *        If `true`, the user will not be able to close the modal
   *        through the UI in the normal ways. Programmatic closing is
   *        still possible.
   */
  function ModalDialog(player, options) {
    classCallCheck(this, ModalDialog);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.opened_ = _this.hasBeenOpened_ = _this.hasBeenFilled_ = false;

    _this.closeable(!_this.options_.uncloseable);
    _this.content(_this.options_.content);

    // Make sure the contentEl is defined AFTER any children are initialized
    // because we only want the contents of the modal in the contentEl
    // (not the UI elements like the close button).
    _this.contentEl_ = createEl('div', {
      className: MODAL_CLASS_NAME + '-content'
    }, {
      role: 'document'
    });

    _this.descEl_ = createEl('p', {
      className: MODAL_CLASS_NAME + '-description vjs-control-text',
      id: _this.el().getAttribute('aria-describedby')
    });

    textContent(_this.descEl_, _this.description());
    _this.el_.appendChild(_this.descEl_);
    _this.el_.appendChild(_this.contentEl_);
    return _this;
  }

  /**
   * Create the `ModalDialog`'s DOM element
   *
   * @return {Element}
   *         The DOM element that gets created.
   */


  ModalDialog.prototype.createEl = function createEl$$1() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: this.buildCSSClass(),
      tabIndex: -1
    }, {
      'aria-describedby': this.id() + '_description',
      'aria-hidden': 'true',
      'aria-label': this.label(),
      'role': 'dialog'
    });
  };

  ModalDialog.prototype.dispose = function dispose() {
    this.contentEl_ = null;
    this.descEl_ = null;
    this.previouslyActiveEl_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  ModalDialog.prototype.buildCSSClass = function buildCSSClass() {
    return MODAL_CLASS_NAME + ' vjs-hidden ' + _Component.prototype.buildCSSClass.call(this);
  };

  /**
   * Handles `keydown` events on the document, looking for ESC, which closes
   * the modal.
   *
   * @param {EventTarget~Event} e
   *        The keypress that triggered this event.
   *
   * @listens keydown
   */


  ModalDialog.prototype.handleKeyPress = function handleKeyPress(e) {
    if (e.which === ESC && this.closeable()) {
      this.close();
    }
  };

  /**
   * Returns the label string for this modal. Primarily used for accessibility.
   *
   * @return {string}
   *         the localized or raw label of this modal.
   */


  ModalDialog.prototype.label = function label() {
    return this.localize(this.options_.label || 'Modal Window');
  };

  /**
   * Returns the description string for this modal. Primarily used for
   * accessibility.
   *
   * @return {string}
   *         The localized or raw description of this modal.
   */


  ModalDialog.prototype.description = function description() {
    var desc = this.options_.description || this.localize('This is a modal window.');

    // Append a universal closeability message if the modal is closeable.
    if (this.closeable()) {
      desc += ' ' + this.localize('This modal can be closed by pressing the Escape key or activating the close button.');
    }

    return desc;
  };

  /**
   * Opens the modal.
   *
   * @fires ModalDialog#beforemodalopen
   * @fires ModalDialog#modalopen
   */


  ModalDialog.prototype.open = function open() {
    if (!this.opened_) {
      var player = this.player();

      /**
        * Fired just before a `ModalDialog` is opened.
        *
        * @event ModalDialog#beforemodalopen
        * @type {EventTarget~Event}
        */
      this.trigger('beforemodalopen');
      this.opened_ = true;

      // Fill content if the modal has never opened before and
      // never been filled.
      if (this.options_.fillAlways || !this.hasBeenOpened_ && !this.hasBeenFilled_) {
        this.fill();
      }

      // If the player was playing, pause it and take note of its previously
      // playing state.
      this.wasPlaying_ = !player.paused();

      if (this.options_.pauseOnOpen && this.wasPlaying_) {
        player.pause();
      }

      if (this.closeable()) {
        this.on(this.el_.ownerDocument, 'keydown', bind(this, this.handleKeyPress));
      }

      // Hide controls and note if they were enabled.
      this.hadControls_ = player.controls();
      player.controls(false);

      this.show();
      this.conditionalFocus_();
      this.el().setAttribute('aria-hidden', 'false');

      /**
        * Fired just after a `ModalDialog` is opened.
        *
        * @event ModalDialog#modalopen
        * @type {EventTarget~Event}
        */
      this.trigger('modalopen');
      this.hasBeenOpened_ = true;
    }
  };

  /**
   * If the `ModalDialog` is currently open or closed.
   *
   * @param  {boolean} [value]
   *         If given, it will open (`true`) or close (`false`) the modal.
   *
   * @return {boolean}
   *         the current open state of the modaldialog
   */


  ModalDialog.prototype.opened = function opened(value) {
    if (typeof value === 'boolean') {
      this[value ? 'open' : 'close']();
    }
    return this.opened_;
  };

  /**
   * Closes the modal, does nothing if the `ModalDialog` is
   * not open.
   *
   * @fires ModalDialog#beforemodalclose
   * @fires ModalDialog#modalclose
   */


  ModalDialog.prototype.close = function close() {
    if (!this.opened_) {
      return;
    }
    var player = this.player();

    /**
      * Fired just before a `ModalDialog` is closed.
      *
      * @event ModalDialog#beforemodalclose
      * @type {EventTarget~Event}
      */
    this.trigger('beforemodalclose');
    this.opened_ = false;

    if (this.wasPlaying_ && this.options_.pauseOnOpen) {
      player.play();
    }

    if (this.closeable()) {
      this.off(this.el_.ownerDocument, 'keydown', bind(this, this.handleKeyPress));
    }

    if (this.hadControls_) {
      player.controls(true);
    }

    this.hide();
    this.el().setAttribute('aria-hidden', 'true');

    /**
      * Fired just after a `ModalDialog` is closed.
      *
      * @event ModalDialog#modalclose
      * @type {EventTarget~Event}
      */
    this.trigger('modalclose');
    this.conditionalBlur_();

    if (this.options_.temporary) {
      this.dispose();
    }
  };

  /**
   * Check to see if the `ModalDialog` is closeable via the UI.
   *
   * @param  {boolean} [value]
   *         If given as a boolean, it will set the `closeable` option.
   *
   * @return {boolean}
   *         Returns the final value of the closable option.
   */


  ModalDialog.prototype.closeable = function closeable(value) {
    if (typeof value === 'boolean') {
      var closeable = this.closeable_ = !!value;
      var close = this.getChild('closeButton');

      // If this is being made closeable and has no close button, add one.
      if (closeable && !close) {

        // The close button should be a child of the modal - not its
        // content element, so temporarily change the content element.
        var temp = this.contentEl_;

        this.contentEl_ = this.el_;
        close = this.addChild('closeButton', { controlText: 'Close Modal Dialog' });
        this.contentEl_ = temp;
        this.on(close, 'close', this.close);
      }

      // If this is being made uncloseable and has a close button, remove it.
      if (!closeable && close) {
        this.off(close, 'close', this.close);
        this.removeChild(close);
        close.dispose();
      }
    }
    return this.closeable_;
  };

  /**
   * Fill the modal's content element with the modal's "content" option.
   * The content element will be emptied before this change takes place.
   */


  ModalDialog.prototype.fill = function fill() {
    this.fillWith(this.content());
  };

  /**
   * Fill the modal's content element with arbitrary content.
   * The content element will be emptied before this change takes place.
   *
   * @fires ModalDialog#beforemodalfill
   * @fires ModalDialog#modalfill
   *
   * @param {Mixed} [content]
   *        The same rules apply to this as apply to the `content` option.
   */


  ModalDialog.prototype.fillWith = function fillWith(content) {
    var contentEl = this.contentEl();
    var parentEl = contentEl.parentNode;
    var nextSiblingEl = contentEl.nextSibling;

    /**
     * Fired just before a `ModalDialog` is filled with content.
     *
     * @event ModalDialog#beforemodalfill
     * @type {EventTarget~Event}
     */
    this.trigger('beforemodalfill');
    this.hasBeenFilled_ = true;

    // Detach the content element from the DOM before performing
    // manipulation to avoid modifying the live DOM multiple times.
    parentEl.removeChild(contentEl);
    this.empty();
    insertContent(contentEl, content);
    /**
     * Fired just after a `ModalDialog` is filled with content.
     *
     * @event ModalDialog#modalfill
     * @type {EventTarget~Event}
     */
    this.trigger('modalfill');

    // Re-inject the re-filled content element.
    if (nextSiblingEl) {
      parentEl.insertBefore(contentEl, nextSiblingEl);
    } else {
      parentEl.appendChild(contentEl);
    }

    // make sure that the close button is last in the dialog DOM
    var closeButton = this.getChild('closeButton');

    if (closeButton) {
      parentEl.appendChild(closeButton.el_);
    }
  };

  /**
   * Empties the content element. This happens anytime the modal is filled.
   *
   * @fires ModalDialog#beforemodalempty
   * @fires ModalDialog#modalempty
   */


  ModalDialog.prototype.empty = function empty() {
    /**
     * Fired just before a `ModalDialog` is emptied.
     *
     * @event ModalDialog#beforemodalempty
     * @type {EventTarget~Event}
     */
    this.trigger('beforemodalempty');
    emptyEl(this.contentEl());

    /**
     * Fired just after a `ModalDialog` is emptied.
     *
     * @event ModalDialog#modalempty
     * @type {EventTarget~Event}
     */
    this.trigger('modalempty');
  };

  /**
   * Gets or sets the modal content, which gets normalized before being
   * rendered into the DOM.
   *
   * This does not update the DOM or fill the modal, but it is called during
   * that process.
   *
   * @param  {Mixed} [value]
   *         If defined, sets the internal content value to be used on the
   *         next call(s) to `fill`. This value is normalized before being
   *         inserted. To "clear" the internal content value, pass `null`.
   *
   * @return {Mixed}
   *         The current content of the modal dialog
   */


  ModalDialog.prototype.content = function content(value) {
    if (typeof value !== 'undefined') {
      this.content_ = value;
    }
    return this.content_;
  };

  /**
   * conditionally focus the modal dialog if focus was previously on the player.
   *
   * @private
   */


  ModalDialog.prototype.conditionalFocus_ = function conditionalFocus_() {
    var activeEl = document_1.activeElement;
    var playerEl = this.player_.el_;

    this.previouslyActiveEl_ = null;

    if (playerEl.contains(activeEl) || playerEl === activeEl) {
      this.previouslyActiveEl_ = activeEl;

      this.focus();

      this.on(document_1, 'keydown', this.handleKeyDown);
    }
  };

  /**
   * conditionally blur the element and refocus the last focused element
   *
   * @private
   */


  ModalDialog.prototype.conditionalBlur_ = function conditionalBlur_() {
    if (this.previouslyActiveEl_) {
      this.previouslyActiveEl_.focus();
      this.previouslyActiveEl_ = null;
    }

    this.off(document_1, 'keydown', this.handleKeyDown);
  };

  /**
   * Keydown handler. Attached when modal is focused.
   *
   * @listens keydown
   */


  ModalDialog.prototype.handleKeyDown = function handleKeyDown(event) {
    // exit early if it isn't a tab key
    if (event.which !== 9) {
      return;
    }

    var focusableEls = this.focusableEls_();
    var activeEl = this.el_.querySelector(':focus');
    var focusIndex = void 0;

    for (var i = 0; i < focusableEls.length; i++) {
      if (activeEl === focusableEls[i]) {
        focusIndex = i;
        break;
      }
    }

    if (document_1.activeElement === this.el_) {
      focusIndex = 0;
    }

    if (event.shiftKey && focusIndex === 0) {
      focusableEls[focusableEls.length - 1].focus();
      event.preventDefault();
    } else if (!event.shiftKey && focusIndex === focusableEls.length - 1) {
      focusableEls[0].focus();
      event.preventDefault();
    }
  };

  /**
   * get all focusable elements
   *
   * @private
   */


  ModalDialog.prototype.focusableEls_ = function focusableEls_() {
    var allChildren = this.el_.querySelectorAll('*');

    return Array.prototype.filter.call(allChildren, function (child) {
      return (child instanceof window_1.HTMLAnchorElement || child instanceof window_1.HTMLAreaElement) && child.hasAttribute('href') || (child instanceof window_1.HTMLInputElement || child instanceof window_1.HTMLSelectElement || child instanceof window_1.HTMLTextAreaElement || child instanceof window_1.HTMLButtonElement) && !child.hasAttribute('disabled') || child instanceof window_1.HTMLIFrameElement || child instanceof window_1.HTMLObjectElement || child instanceof window_1.HTMLEmbedElement || child.hasAttribute('tabindex') && child.getAttribute('tabindex') !== -1 || child.hasAttribute('contenteditable');
    });
  };

  return ModalDialog;
}(Component);

/**
 * Default options for `ModalDialog` default options.
 *
 * @type {Object}
 * @private
 */


ModalDialog.prototype.options_ = {
  pauseOnOpen: true,
  temporary: true
};

Component.registerComponent('ModalDialog', ModalDialog);

/**
 * @file track-list.js
 */
/**
 * Common functionaliy between {@link TextTrackList}, {@link AudioTrackList}, and
 * {@link VideoTrackList}
 *
 * @extends EventTarget
 */

var TrackList = function (_EventTarget) {
  inherits(TrackList, _EventTarget);

  /**
   * Create an instance of this class
   *
   * @param {Track[]} tracks
   *        A list of tracks to initialize the list with.
   *
   * @param {Object} [list]
   *        The child object with inheritance done manually for ie8.
   *
   * @abstract
   */
  function TrackList() {
    var tracks = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];

    var _ret;

    var list = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : null;
    classCallCheck(this, TrackList);

    var _this = possibleConstructorReturn(this, _EventTarget.call(this));

    if (!list) {
      list = _this; // eslint-disable-line
      if (IS_IE8) {
        list = document_1.createElement('custom');
        for (var prop in TrackList.prototype) {
          if (prop !== 'constructor') {
            list[prop] = TrackList.prototype[prop];
          }
        }
      }
    }

    list.tracks_ = [];

    /**
     * @memberof TrackList
     * @member {number} length
     *         The current number of `Track`s in the this Trackist.
     * @instance
     */
    Object.defineProperty(list, 'length', {
      get: function get$$1() {
        return this.tracks_.length;
      }
    });

    for (var i = 0; i < tracks.length; i++) {
      list.addTrack(tracks[i]);
    }

    // must return the object, as for ie8 it will not be this
    // but a reference to a document object
    return _ret = list, possibleConstructorReturn(_this, _ret);
  }

  /**
   * Add a {@link Track} to the `TrackList`
   *
   * @param {Track} track
   *        The audio, video, or text track to add to the list.
   *
   * @fires TrackList#addtrack
   */


  TrackList.prototype.addTrack = function addTrack(track) {
    var index = this.tracks_.length;

    if (!('' + index in this)) {
      Object.defineProperty(this, index, {
        get: function get$$1() {
          return this.tracks_[index];
        }
      });
    }

    // Do not add duplicate tracks
    if (this.tracks_.indexOf(track) === -1) {
      this.tracks_.push(track);
      /**
       * Triggered when a track is added to a track list.
       *
       * @event TrackList#addtrack
       * @type {EventTarget~Event}
       * @property {Track} track
       *           A reference to track that was added.
       */
      this.trigger({
        track: track,
        type: 'addtrack'
      });
    }
  };

  /**
   * Remove a {@link Track} from the `TrackList`
   *
   * @param {Track} rtrack
   *        The audio, video, or text track to remove from the list.
   *
   * @fires TrackList#removetrack
   */


  TrackList.prototype.removeTrack = function removeTrack(rtrack) {
    var track = void 0;

    for (var i = 0, l = this.length; i < l; i++) {
      if (this[i] === rtrack) {
        track = this[i];
        if (track.off) {
          track.off();
        }

        this.tracks_.splice(i, 1);

        break;
      }
    }

    if (!track) {
      return;
    }

    /**
     * Triggered when a track is removed from track list.
     *
     * @event TrackList#removetrack
     * @type {EventTarget~Event}
     * @property {Track} track
     *           A reference to track that was removed.
     */
    this.trigger({
      track: track,
      type: 'removetrack'
    });
  };

  /**
   * Get a Track from the TrackList by a tracks id
   *
   * @param {String} id - the id of the track to get
   * @method getTrackById
   * @return {Track}
   * @private
   */


  TrackList.prototype.getTrackById = function getTrackById(id) {
    var result = null;

    for (var i = 0, l = this.length; i < l; i++) {
      var track = this[i];

      if (track.id === id) {
        result = track;
        break;
      }
    }

    return result;
  };

  return TrackList;
}(EventTarget);

/**
 * Triggered when a different track is selected/enabled.
 *
 * @event TrackList#change
 * @type {EventTarget~Event}
 */

/**
 * Events that can be called with on + eventName. See {@link EventHandler}.
 *
 * @property {Object} TrackList#allowedEvents_
 * @private
 */


TrackList.prototype.allowedEvents_ = {
  change: 'change',
  addtrack: 'addtrack',
  removetrack: 'removetrack'
};

// emulate attribute EventHandler support to allow for feature detection
for (var event in TrackList.prototype.allowedEvents_) {
  TrackList.prototype['on' + event] = null;
}

/**
 * @file audio-track-list.js
 */
/**
 * Anywhere we call this function we diverge from the spec
 * as we only support one enabled audiotrack at a time
 *
 * @param {AudioTrackList} list
 *        list to work on
 *
 * @param {AudioTrack} track
 *        The track to skip
 *
 * @private
 */
var disableOthers = function disableOthers(list, track) {
  for (var i = 0; i < list.length; i++) {
    if (!Object.keys(list[i]).length || track.id === list[i].id) {
      continue;
    }
    // another audio track is enabled, disable it
    list[i].enabled = false;
  }
};

/**
 * The current list of {@link AudioTrack} for a media file.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#audiotracklist}
 * @extends TrackList
 */

var AudioTrackList = function (_TrackList) {
  inherits(AudioTrackList, _TrackList);

  /**
   * Create an instance of this class.
   *
   * @param {AudioTrack[]} [tracks=[]]
   *        A list of `AudioTrack` to instantiate the list with.
   */
  function AudioTrackList() {
    var _this, _ret;

    var tracks = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
    classCallCheck(this, AudioTrackList);

    var list = void 0;

    // make sure only 1 track is enabled
    // sorted from last index to first index
    for (var i = tracks.length - 1; i >= 0; i--) {
      if (tracks[i].enabled) {
        disableOthers(tracks, tracks[i]);
        break;
      }
    }

    // IE8 forces us to implement inheritance ourselves
    // as it does not support Object.defineProperty properly
    if (IS_IE8) {
      list = document_1.createElement('custom');
      for (var prop in TrackList.prototype) {
        if (prop !== 'constructor') {
          list[prop] = TrackList.prototype[prop];
        }
      }
      for (var _prop in AudioTrackList.prototype) {
        if (_prop !== 'constructor') {
          list[_prop] = AudioTrackList.prototype[_prop];
        }
      }
    }

    list = (_this = possibleConstructorReturn(this, _TrackList.call(this, tracks, list)), _this);
    list.changing_ = false;

    return _ret = list, possibleConstructorReturn(_this, _ret);
  }

  /**
   * Add an {@link AudioTrack} to the `AudioTrackList`.
   *
   * @param {AudioTrack} track
   *        The AudioTrack to add to the list
   *
   * @fires TrackList#addtrack
   */


  AudioTrackList.prototype.addTrack = function addTrack(track) {
    var _this2 = this;

    if (track.enabled) {
      disableOthers(this, track);
    }

    _TrackList.prototype.addTrack.call(this, track);
    // native tracks don't have this
    if (!track.addEventListener) {
      return;
    }

    /**
     * @listens AudioTrack#enabledchange
     * @fires TrackList#change
     */
    track.addEventListener('enabledchange', function () {
      // when we are disabling other tracks (since we don't support
      // more than one track at a time) we will set changing_
      // to true so that we don't trigger additional change events
      if (_this2.changing_) {
        return;
      }
      _this2.changing_ = true;
      disableOthers(_this2, track);
      _this2.changing_ = false;
      _this2.trigger('change');
    });
  };

  return AudioTrackList;
}(TrackList);

/**
 * @file video-track-list.js
 */
/**
 * Un-select all other {@link VideoTrack}s that are selected.
 *
 * @param {VideoTrackList} list
 *        list to work on
 *
 * @param {VideoTrack} track
 *        The track to skip
 *
 * @private
 */
var disableOthers$1 = function disableOthers(list, track) {
  for (var i = 0; i < list.length; i++) {
    if (!Object.keys(list[i]).length || track.id === list[i].id) {
      continue;
    }
    // another video track is enabled, disable it
    list[i].selected = false;
  }
};

/**
 * The current list of {@link VideoTrack} for a video.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#videotracklist}
 * @extends TrackList
 */

var VideoTrackList = function (_TrackList) {
  inherits(VideoTrackList, _TrackList);

  /**
   * Create an instance of this class.
   *
   * @param {VideoTrack[]} [tracks=[]]
   *        A list of `VideoTrack` to instantiate the list with.
   */
  function VideoTrackList() {
    var _this, _ret;

    var tracks = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
    classCallCheck(this, VideoTrackList);

    var list = void 0;

    // make sure only 1 track is enabled
    // sorted from last index to first index
    for (var i = tracks.length - 1; i >= 0; i--) {
      if (tracks[i].selected) {
        disableOthers$1(tracks, tracks[i]);
        break;
      }
    }

    // IE8 forces us to implement inheritance ourselves
    // as it does not support Object.defineProperty properly
    if (IS_IE8) {
      list = document_1.createElement('custom');
      for (var prop in TrackList.prototype) {
        if (prop !== 'constructor') {
          list[prop] = TrackList.prototype[prop];
        }
      }
      for (var _prop in VideoTrackList.prototype) {
        if (_prop !== 'constructor') {
          list[_prop] = VideoTrackList.prototype[_prop];
        }
      }
    }

    list = (_this = possibleConstructorReturn(this, _TrackList.call(this, tracks, list)), _this);
    list.changing_ = false;

    /**
     * @member {number} VideoTrackList#selectedIndex
     *         The current index of the selected {@link VideoTrack`}.
     */
    Object.defineProperty(list, 'selectedIndex', {
      get: function get$$1() {
        for (var _i = 0; _i < this.length; _i++) {
          if (this[_i].selected) {
            return _i;
          }
        }
        return -1;
      },
      set: function set$$1() {}
    });

    return _ret = list, possibleConstructorReturn(_this, _ret);
  }

  /**
   * Add a {@link VideoTrack} to the `VideoTrackList`.
   *
   * @param {VideoTrack} track
   *        The VideoTrack to add to the list
   *
   * @fires TrackList#addtrack
   */


  VideoTrackList.prototype.addTrack = function addTrack(track) {
    var _this2 = this;

    if (track.selected) {
      disableOthers$1(this, track);
    }

    _TrackList.prototype.addTrack.call(this, track);
    // native tracks don't have this
    if (!track.addEventListener) {
      return;
    }

    /**
     * @listens VideoTrack#selectedchange
     * @fires TrackList#change
     */
    track.addEventListener('selectedchange', function () {
      if (_this2.changing_) {
        return;
      }
      _this2.changing_ = true;
      disableOthers$1(_this2, track);
      _this2.changing_ = false;
      _this2.trigger('change');
    });
  };

  return VideoTrackList;
}(TrackList);

/**
 * @file text-track-list.js
 */
/**
 * The current list of {@link TextTrack} for a media file.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#texttracklist}
 * @extends TrackList
 */

var TextTrackList = function (_TrackList) {
  inherits(TextTrackList, _TrackList);

  /**
   * Create an instance of this class.
   *
   * @param {TextTrack[]} [tracks=[]]
   *        A list of `TextTrack` to instantiate the list with.
   */
  function TextTrackList() {
    var _this, _ret;

    var tracks = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
    classCallCheck(this, TextTrackList);

    var list = void 0;

    // IE8 forces us to implement inheritance ourselves
    // as it does not support Object.defineProperty properly
    if (IS_IE8) {
      list = document_1.createElement('custom');
      for (var prop in TrackList.prototype) {
        if (prop !== 'constructor') {
          list[prop] = TrackList.prototype[prop];
        }
      }
      for (var _prop in TextTrackList.prototype) {
        if (_prop !== 'constructor') {
          list[_prop] = TextTrackList.prototype[_prop];
        }
      }
    }

    list = (_this = possibleConstructorReturn(this, _TrackList.call(this, tracks, list)), _this);
    return _ret = list, possibleConstructorReturn(_this, _ret);
  }

  /**
   * Add a {@link TextTrack} to the `TextTrackList`
   *
   * @param {TextTrack} track
   *        The text track to add to the list.
   *
   * @fires TrackList#addtrack
   */


  TextTrackList.prototype.addTrack = function addTrack(track) {
    _TrackList.prototype.addTrack.call(this, track);

    /**
     * @listens TextTrack#modechange
     * @fires TrackList#change
     */
    track.addEventListener('modechange', bind(this, function () {
      this.trigger('change');
    }));

    var nonLanguageTextTrackKind = ['metadata', 'chapters'];

    if (nonLanguageTextTrackKind.indexOf(track.kind) === -1) {
      track.addEventListener('modechange', bind(this, function () {
        this.trigger('selectedlanguagechange');
      }));
    }
  };

  return TextTrackList;
}(TrackList);

/**
 * @file html-track-element-list.js
 */

/**
 * The current list of {@link HtmlTrackElement}s.
 */

var HtmlTrackElementList = function () {

  /**
   * Create an instance of this class.
   *
   * @param {HtmlTrackElement[]} [tracks=[]]
   *        A list of `HtmlTrackElement` to instantiate the list with.
   */
  function HtmlTrackElementList() {
    var trackElements = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
    classCallCheck(this, HtmlTrackElementList);

    var list = this; // eslint-disable-line

    if (IS_IE8) {
      list = document_1.createElement('custom');

      for (var prop in HtmlTrackElementList.prototype) {
        if (prop !== 'constructor') {
          list[prop] = HtmlTrackElementList.prototype[prop];
        }
      }
    }

    list.trackElements_ = [];

    /**
     * @memberof HtmlTrackElementList
     * @member {number} length
     *         The current number of `Track`s in the this Trackist.
     * @instance
     */
    Object.defineProperty(list, 'length', {
      get: function get$$1() {
        return this.trackElements_.length;
      }
    });

    for (var i = 0, length = trackElements.length; i < length; i++) {
      list.addTrackElement_(trackElements[i]);
    }

    if (IS_IE8) {
      return list;
    }
  }

  /**
   * Add an {@link HtmlTrackElement} to the `HtmlTrackElementList`
   *
   * @param {HtmlTrackElement} trackElement
   *        The track element to add to the list.
   *
   * @private
   */


  HtmlTrackElementList.prototype.addTrackElement_ = function addTrackElement_(trackElement) {
    var index = this.trackElements_.length;

    if (!('' + index in this)) {
      Object.defineProperty(this, index, {
        get: function get$$1() {
          return this.trackElements_[index];
        }
      });
    }

    // Do not add duplicate elements
    if (this.trackElements_.indexOf(trackElement) === -1) {
      this.trackElements_.push(trackElement);
    }
  };

  /**
   * Get an {@link HtmlTrackElement} from the `HtmlTrackElementList` given an
   * {@link TextTrack}.
   *
   * @param {TextTrack} track
   *        The track associated with a track element.
   *
   * @return {HtmlTrackElement|undefined}
   *         The track element that was found or undefined.
   *
   * @private
   */


  HtmlTrackElementList.prototype.getTrackElementByTrack_ = function getTrackElementByTrack_(track) {
    var trackElement_ = void 0;

    for (var i = 0, length = this.trackElements_.length; i < length; i++) {
      if (track === this.trackElements_[i].track) {
        trackElement_ = this.trackElements_[i];

        break;
      }
    }

    return trackElement_;
  };

  /**
   * Remove a {@link HtmlTrackElement} from the `HtmlTrackElementList`
   *
   * @param {HtmlTrackElement} trackElement
   *        The track element to remove from the list.
   *
   * @private
   */


  HtmlTrackElementList.prototype.removeTrackElement_ = function removeTrackElement_(trackElement) {
    for (var i = 0, length = this.trackElements_.length; i < length; i++) {
      if (trackElement === this.trackElements_[i]) {
        this.trackElements_.splice(i, 1);

        break;
      }
    }
  };

  return HtmlTrackElementList;
}();

/**
 * @file text-track-cue-list.js
 */
/**
 * @typedef {Object} TextTrackCueList~TextTrackCue
 *
 * @property {string} id
 *           The unique id for this text track cue
 *
 * @property {number} startTime
 *           The start time for this text track cue
 *
 * @property {number} endTime
 *           The end time for this text track cue
 *
 * @property {boolean} pauseOnExit
 *           Pause when the end time is reached if true.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#texttrackcue}
 */

/**
 * A List of TextTrackCues.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#texttrackcuelist}
 */

var TextTrackCueList = function () {

  /**
   * Create an instance of this class..
   *
   * @param {Array} cues
   *        A list of cues to be initialized with
   */
  function TextTrackCueList(cues) {
    classCallCheck(this, TextTrackCueList);

    var list = this; // eslint-disable-line

    if (IS_IE8) {
      list = document_1.createElement('custom');

      for (var prop in TextTrackCueList.prototype) {
        if (prop !== 'constructor') {
          list[prop] = TextTrackCueList.prototype[prop];
        }
      }
    }

    TextTrackCueList.prototype.setCues_.call(list, cues);

    /**
     * @memberof TextTrackCueList
     * @member {number} length
     *         The current number of `TextTrackCue`s in the TextTrackCueList.
     * @instance
     */
    Object.defineProperty(list, 'length', {
      get: function get$$1() {
        return this.length_;
      }
    });

    if (IS_IE8) {
      return list;
    }
  }

  /**
   * A setter for cues in this list. Creates getters
   * an an index for the cues.
   *
   * @param {Array} cues
   *        An array of cues to set
   *
   * @private
   */


  TextTrackCueList.prototype.setCues_ = function setCues_(cues) {
    var oldLength = this.length || 0;
    var i = 0;
    var l = cues.length;

    this.cues_ = cues;
    this.length_ = cues.length;

    var defineProp = function defineProp(index) {
      if (!('' + index in this)) {
        Object.defineProperty(this, '' + index, {
          get: function get$$1() {
            return this.cues_[index];
          }
        });
      }
    };

    if (oldLength < l) {
      i = oldLength;

      for (; i < l; i++) {
        defineProp.call(this, i);
      }
    }
  };

  /**
   * Get a `TextTrackCue` that is currently in the `TextTrackCueList` by id.
   *
   * @param {string} id
   *        The id of the cue that should be searched for.
   *
   * @return {TextTrackCueList~TextTrackCue|null}
   *         A single cue or null if none was found.
   */


  TextTrackCueList.prototype.getCueById = function getCueById(id) {
    var result = null;

    for (var i = 0, l = this.length; i < l; i++) {
      var cue = this[i];

      if (cue.id === id) {
        result = cue;
        break;
      }
    }

    return result;
  };

  return TextTrackCueList;
}();

/**
 * @file track-kinds.js
 */

/**
 * All possible `VideoTrackKind`s
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-videotrack-kind
 * @typedef VideoTrack~Kind
 * @enum
 */
var VideoTrackKind = {
  alternative: 'alternative',
  captions: 'captions',
  main: 'main',
  sign: 'sign',
  subtitles: 'subtitles',
  commentary: 'commentary'
};

/**
 * All possible `AudioTrackKind`s
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-audiotrack-kind
 * @typedef AudioTrack~Kind
 * @enum
 */
var AudioTrackKind = {
  'alternative': 'alternative',
  'descriptions': 'descriptions',
  'main': 'main',
  'main-desc': 'main-desc',
  'translation': 'translation',
  'commentary': 'commentary'
};

/**
 * All possible `TextTrackKind`s
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-texttrack-kind
 * @typedef TextTrack~Kind
 * @enum
 */
var TextTrackKind = {
  subtitles: 'subtitles',
  captions: 'captions',
  descriptions: 'descriptions',
  chapters: 'chapters',
  metadata: 'metadata'
};

/**
 * All possible `TextTrackMode`s
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#texttrackmode
 * @typedef TextTrack~Mode
 * @enum
 */
var TextTrackMode = {
  disabled: 'disabled',
  hidden: 'hidden',
  showing: 'showing'
};

/**
 * @file track.js
 */
/**
 * A Track class that contains all of the common functionality for {@link AudioTrack},
 * {@link VideoTrack}, and {@link TextTrack}.
 *
 * > Note: This class should not be used directly
 *
 * @see {@link https://html.spec.whatwg.org/multipage/embedded-content.html}
 * @extends EventTarget
 * @abstract
 */

var Track = function (_EventTarget) {
  inherits(Track, _EventTarget);

  /**
   * Create an instance of this class.
   *
   * @param {Object} [options={}]
   *        Object of option names and values
   *
   * @param {string} [options.kind='']
   *        A valid kind for the track type you are creating.
   *
   * @param {string} [options.id='vjs_track_' + Guid.newGUID()]
   *        A unique id for this AudioTrack.
   *
   * @param {string} [options.label='']
   *        The menu label for this track.
   *
   * @param {string} [options.language='']
   *        A valid two character language code.
   *
   * @abstract
   */
  function Track() {
    var _ret;

    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    classCallCheck(this, Track);

    var _this = possibleConstructorReturn(this, _EventTarget.call(this));

    var track = _this; // eslint-disable-line

    if (IS_IE8) {
      track = document_1.createElement('custom');
      for (var prop in Track.prototype) {
        if (prop !== 'constructor') {
          track[prop] = Track.prototype[prop];
        }
      }
    }

    var trackProps = {
      id: options.id || 'vjs_track_' + newGUID(),
      kind: options.kind || '',
      label: options.label || '',
      language: options.language || ''
    };

    /**
     * @memberof Track
     * @member {string} id
     *         The id of this track. Cannot be changed after creation.
     * @instance
     *
     * @readonly
     */

    /**
     * @memberof Track
     * @member {string} kind
     *         The kind of track that this is. Cannot be changed after creation.
     * @instance
     *
     * @readonly
     */

    /**
     * @memberof Track
     * @member {string} label
     *         The label of this track. Cannot be changed after creation.
     * @instance
     *
     * @readonly
     */

    /**
     * @memberof Track
     * @member {string} language
     *         The two letter language code for this track. Cannot be changed after
     *         creation.
     * @instance
     *
     * @readonly
     */

    var _loop = function _loop(key) {
      Object.defineProperty(track, key, {
        get: function get$$1() {
          return trackProps[key];
        },
        set: function set$$1() {}
      });
    };

    for (var key in trackProps) {
      _loop(key);
    }

    return _ret = track, possibleConstructorReturn(_this, _ret);
  }

  return Track;
}(EventTarget);

/**
 * @file url.js
 * @module url
 */
/**
 * @typedef {Object} url:URLObject
 *
 * @property {string} protocol
 *           The protocol of the url that was parsed.
 *
 * @property {string} hostname
 *           The hostname of the url that was parsed.
 *
 * @property {string} port
 *           The port of the url that was parsed.
 *
 * @property {string} pathname
 *           The pathname of the url that was parsed.
 *
 * @property {string} search
 *           The search query of the url that was parsed.
 *
 * @property {string} hash
 *           The hash of the url that was parsed.
 *
 * @property {string} host
 *           The host of the url that was parsed.
 */

/**
 * Resolve and parse the elements of a URL.
 *
 * @param  {String} url
 *         The url to parse
 *
 * @return {url:URLObject}
 *         An object of url details
 */
var parseUrl = function parseUrl(url) {
  var props = ['protocol', 'hostname', 'port', 'pathname', 'search', 'hash', 'host'];

  // add the url to an anchor and let the browser parse the URL
  var a = document_1.createElement('a');

  a.href = url;

  // IE8 (and 9?) Fix
  // ie8 doesn't parse the URL correctly until the anchor is actually
  // added to the body, and an innerHTML is needed to trigger the parsing
  var addToBody = a.host === '' && a.protocol !== 'file:';
  var div = void 0;

  if (addToBody) {
    div = document_1.createElement('div');
    div.innerHTML = '<a href="' + url + '"></a>';
    a = div.firstChild;
    // prevent the div from affecting layout
    div.setAttribute('style', 'display:none; position:absolute;');
    document_1.body.appendChild(div);
  }

  // Copy the specific URL properties to a new object
  // This is also needed for IE8 because the anchor loses its
  // properties when it's removed from the dom
  var details = {};

  for (var i = 0; i < props.length; i++) {
    details[props[i]] = a[props[i]];
  }

  // IE9 adds the port to the host property unlike everyone else. If
  // a port identifier is added for standard ports, strip it.
  if (details.protocol === 'http:') {
    details.host = details.host.replace(/:80$/, '');
  }

  if (details.protocol === 'https:') {
    details.host = details.host.replace(/:443$/, '');
  }

  if (!details.protocol) {
    details.protocol = window_1.location.protocol;
  }

  if (addToBody) {
    document_1.body.removeChild(div);
  }

  return details;
};

/**
 * Get absolute version of relative URL. Used to tell flash correct URL.
 *
 *
 * @param  {string} url
 *         URL to make absolute
 *
 * @return {string}
 *         Absolute URL
 *
 * @see http://stackoverflow.com/questions/470832/getting-an-absolute-url-from-a-relative-one-ie6-issue
 */
var getAbsoluteURL = function getAbsoluteURL(url) {
  // Check if absolute URL
  if (!url.match(/^https?:\/\//)) {
    // Convert to absolute URL. Flash hosted off-site needs an absolute URL.
    var div = document_1.createElement('div');

    div.innerHTML = '<a href="' + url + '">x</a>';
    url = div.firstChild.href;
  }

  return url;
};

/**
 * Returns the extension of the passed file name. It will return an empty string
 * if passed an invalid path.
 *
 * @param {string} path
 *        The fileName path like '/path/to/file.mp4'
 *
 * @returns {string}
 *          The extension in lower case or an empty string if no
 *          extension could be found.
 */
var getFileExtension = function getFileExtension(path) {
  if (typeof path === 'string') {
    var splitPathRe = /^(\/?)([\s\S]*?)((?:\.{1,2}|[^\/]+?)(\.([^\.\/\?]+)))(?:[\/]*|[\?].*)$/i;
    var pathParts = splitPathRe.exec(path);

    if (pathParts) {
      return pathParts.pop().toLowerCase();
    }
  }

  return '';
};

/**
 * Returns whether the url passed is a cross domain request or not.
 *
 * @param {string} url
 *        The url to check.
 *
 * @return {boolean}
 *         Whether it is a cross domain request or not.
 */
var isCrossOrigin = function isCrossOrigin(url) {
  var winLoc = window_1.location;
  var urlInfo = parseUrl(url);

  // IE8 protocol relative urls will return ':' for protocol
  var srcProtocol = urlInfo.protocol === ':' ? winLoc.protocol : urlInfo.protocol;

  // Check if url is for another domain/origin
  // IE8 doesn't know location.origin, so we won't rely on it here
  var crossOrigin = srcProtocol + urlInfo.host !== winLoc.protocol + winLoc.host;

  return crossOrigin;
};

var Url = (Object.freeze || Object)({
	parseUrl: parseUrl,
	getAbsoluteURL: getAbsoluteURL,
	getFileExtension: getFileExtension,
	isCrossOrigin: isCrossOrigin
});

var isFunction_1 = isFunction;

var toString$1 = Object.prototype.toString;

function isFunction (fn) {
  var string = toString$1.call(fn);
  return string === '[object Function]' ||
    (typeof fn === 'function' && string !== '[object RegExp]') ||
    (typeof window !== 'undefined' &&
     // IE8 and below
     (fn === window.setTimeout ||
      fn === window.alert ||
      fn === window.confirm ||
      fn === window.prompt))
}

var trim_1 = createCommonjsModule(function (module, exports) {
exports = module.exports = trim;

function trim(str){
  return str.replace(/^\s*|\s*$/g, '');
}

exports.left = function(str){
  return str.replace(/^\s*/, '');
};

exports.right = function(str){
  return str.replace(/\s*$/, '');
};
});

var forEach_1 = forEach;

var toString$2 = Object.prototype.toString;
var hasOwnProperty = Object.prototype.hasOwnProperty;

function forEach(list, iterator, context) {
    if (!isFunction_1(iterator)) {
        throw new TypeError('iterator must be a function')
    }

    if (arguments.length < 3) {
        context = this;
    }
    
    if (toString$2.call(list) === '[object Array]')
        forEachArray$1(list, iterator, context);
    else if (typeof list === 'string')
        forEachString(list, iterator, context);
    else
        forEachObject(list, iterator, context);
}

function forEachArray$1(array, iterator, context) {
    for (var i = 0, len = array.length; i < len; i++) {
        if (hasOwnProperty.call(array, i)) {
            iterator.call(context, array[i], i, array);
        }
    }
}

function forEachString(string, iterator, context) {
    for (var i = 0, len = string.length; i < len; i++) {
        // no such thing as a sparse string.
        iterator.call(context, string.charAt(i), i, string);
    }
}

function forEachObject(object, iterator, context) {
    for (var k in object) {
        if (hasOwnProperty.call(object, k)) {
            iterator.call(context, object[k], k, object);
        }
    }
}

var isArray = function(arg) {
      return Object.prototype.toString.call(arg) === '[object Array]';
    };

var parseHeaders = function (headers) {
  if (!headers)
    return {}

  var result = {};

  forEach_1(
      trim_1(headers).split('\n')
    , function (row) {
        var index = row.indexOf(':')
          , key = trim_1(row.slice(0, index)).toLowerCase()
          , value = trim_1(row.slice(index + 1));

        if (typeof(result[key]) === 'undefined') {
          result[key] = value;
        } else if (isArray(result[key])) {
          result[key].push(value);
        } else {
          result[key] = [ result[key], value ];
        }
      }
  );

  return result
};

var immutable = extend;

var hasOwnProperty$1 = Object.prototype.hasOwnProperty;

function extend() {
    var target = {};

    for (var i = 0; i < arguments.length; i++) {
        var source = arguments[i];

        for (var key in source) {
            if (hasOwnProperty$1.call(source, key)) {
                target[key] = source[key];
            }
        }
    }

    return target
}

var xhr = createXHR;
createXHR.XMLHttpRequest = window_1.XMLHttpRequest || noop;
createXHR.XDomainRequest = "withCredentials" in (new createXHR.XMLHttpRequest()) ? createXHR.XMLHttpRequest : window_1.XDomainRequest;

forEachArray(["get", "put", "post", "patch", "head", "delete"], function(method) {
    createXHR[method === "delete" ? "del" : method] = function(uri, options, callback) {
        options = initParams(uri, options, callback);
        options.method = method.toUpperCase();
        return _createXHR(options)
    };
});

function forEachArray(array, iterator) {
    for (var i = 0; i < array.length; i++) {
        iterator(array[i]);
    }
}

function isEmpty(obj){
    for(var i in obj){
        if(obj.hasOwnProperty(i)) return false
    }
    return true
}

function initParams(uri, options, callback) {
    var params = uri;

    if (isFunction_1(options)) {
        callback = options;
        if (typeof uri === "string") {
            params = {uri:uri};
        }
    } else {
        params = immutable(options, {uri: uri});
    }

    params.callback = callback;
    return params
}

function createXHR(uri, options, callback) {
    options = initParams(uri, options, callback);
    return _createXHR(options)
}

function _createXHR(options) {
    if(typeof options.callback === "undefined"){
        throw new Error("callback argument missing")
    }

    var called = false;
    var callback = function cbOnce(err, response, body){
        if(!called){
            called = true;
            options.callback(err, response, body);
        }
    };

    function readystatechange() {
        if (xhr.readyState === 4) {
            setTimeout(loadFunc, 0);
        }
    }

    function getBody() {
        // Chrome with requestType=blob throws errors arround when even testing access to responseText
        var body = undefined;

        if (xhr.response) {
            body = xhr.response;
        } else {
            body = xhr.responseText || getXml(xhr);
        }

        if (isJson) {
            try {
                body = JSON.parse(body);
            } catch (e) {}
        }

        return body
    }

    function errorFunc(evt) {
        clearTimeout(timeoutTimer);
        if(!(evt instanceof Error)){
            evt = new Error("" + (evt || "Unknown XMLHttpRequest Error") );
        }
        evt.statusCode = 0;
        return callback(evt, failureResponse)
    }

    // will load the data & process the response in a special response object
    function loadFunc() {
        if (aborted) return
        var status;
        clearTimeout(timeoutTimer);
        if(options.useXDR && xhr.status===undefined) {
            //IE8 CORS GET successful response doesn't have a status field, but body is fine
            status = 200;
        } else {
            status = (xhr.status === 1223 ? 204 : xhr.status);
        }
        var response = failureResponse;
        var err = null;

        if (status !== 0){
            response = {
                body: getBody(),
                statusCode: status,
                method: method,
                headers: {},
                url: uri,
                rawRequest: xhr
            };
            if(xhr.getAllResponseHeaders){ //remember xhr can in fact be XDR for CORS in IE
                response.headers = parseHeaders(xhr.getAllResponseHeaders());
            }
        } else {
            err = new Error("Internal XMLHttpRequest Error");
        }
        return callback(err, response, response.body)
    }

    var xhr = options.xhr || null;

    if (!xhr) {
        if (options.cors || options.useXDR) {
            xhr = new createXHR.XDomainRequest();
        }else{
            xhr = new createXHR.XMLHttpRequest();
        }
    }

    var key;
    var aborted;
    var uri = xhr.url = options.uri || options.url;
    var method = xhr.method = options.method || "GET";
    var body = options.body || options.data;
    var headers = xhr.headers = options.headers || {};
    var sync = !!options.sync;
    var isJson = false;
    var timeoutTimer;
    var failureResponse = {
        body: undefined,
        headers: {},
        statusCode: 0,
        method: method,
        url: uri,
        rawRequest: xhr
    };

    if ("json" in options && options.json !== false) {
        isJson = true;
        headers["accept"] || headers["Accept"] || (headers["Accept"] = "application/json"); //Don't override existing accept header declared by user
        if (method !== "GET" && method !== "HEAD") {
            headers["content-type"] || headers["Content-Type"] || (headers["Content-Type"] = "application/json"); //Don't override existing accept header declared by user
            body = JSON.stringify(options.json === true ? body : options.json);
        }
    }

    xhr.onreadystatechange = readystatechange;
    xhr.onload = loadFunc;
    xhr.onerror = errorFunc;
    // IE9 must have onprogress be set to a unique function.
    xhr.onprogress = function () {
        // IE must die
    };
    xhr.onabort = function(){
        aborted = true;
    };
    xhr.ontimeout = errorFunc;
    xhr.open(method, uri, !sync, options.username, options.password);
    //has to be after open
    if(!sync) {
        xhr.withCredentials = !!options.withCredentials;
    }
    // Cannot set timeout with sync request
    // not setting timeout on the xhr object, because of old webkits etc. not handling that correctly
    // both npm's request and jquery 1.x use this kind of timeout, so this is being consistent
    if (!sync && options.timeout > 0 ) {
        timeoutTimer = setTimeout(function(){
            if (aborted) return
            aborted = true;//IE9 may still call readystatechange
            xhr.abort("timeout");
            var e = new Error("XMLHttpRequest timeout");
            e.code = "ETIMEDOUT";
            errorFunc(e);
        }, options.timeout );
    }

    if (xhr.setRequestHeader) {
        for(key in headers){
            if(headers.hasOwnProperty(key)){
                xhr.setRequestHeader(key, headers[key]);
            }
        }
    } else if (options.headers && !isEmpty(options.headers)) {
        throw new Error("Headers cannot be set on an XDomainRequest object")
    }

    if ("responseType" in options) {
        xhr.responseType = options.responseType;
    }

    if ("beforeSend" in options &&
        typeof options.beforeSend === "function"
    ) {
        options.beforeSend(xhr);
    }

    // Microsoft Edge browser sends "undefined" when send is called with undefined value.
    // XMLHttpRequest spec says to pass null as body to indicate no body
    // See https://github.com/naugtur/xhr/issues/100.
    xhr.send(body || null);

    return xhr


}

function getXml(xhr) {
    if (xhr.responseType === "document") {
        return xhr.responseXML
    }
    var firefoxBugTakenEffect = xhr.responseXML && xhr.responseXML.documentElement.nodeName === "parsererror";
    if (xhr.responseType === "" && !firefoxBugTakenEffect) {
        return xhr.responseXML
    }

    return null
}

function noop() {}

/**
 * @file text-track.js
 */
/**
 * Takes a webvtt file contents and parses it into cues
 *
 * @param {string} srcContent
 *        webVTT file contents
 *
 * @param {TextTrack} track
 *        TextTrack to add cues to. Cues come from the srcContent.
 *
 * @private
 */
var parseCues = function parseCues(srcContent, track) {
  var parser = new window_1.WebVTT.Parser(window_1, window_1.vttjs, window_1.WebVTT.StringDecoder());
  var errors = [];

  parser.oncue = function (cue) {
    track.addCue(cue);
  };

  parser.onparsingerror = function (error) {
    errors.push(error);
  };

  parser.onflush = function () {
    track.trigger({
      type: 'loadeddata',
      target: track
    });
  };

  parser.parse(srcContent);
  if (errors.length > 0) {
    if (window_1.console && window_1.console.groupCollapsed) {
      window_1.console.groupCollapsed('Text Track parsing errors for ' + track.src);
    }
    errors.forEach(function (error) {
      return log$1.error(error);
    });
    if (window_1.console && window_1.console.groupEnd) {
      window_1.console.groupEnd();
    }
  }

  parser.flush();
};

/**
 * Load a `TextTrack` from a specifed url.
 *
 * @param {string} src
 *        Url to load track from.
 *
 * @param {TextTrack} track
 *        Track to add cues to. Comes from the content at the end of `url`.
 *
 * @private
 */
var loadTrack = function loadTrack(src, track) {
  var opts = {
    uri: src
  };
  var crossOrigin = isCrossOrigin(src);

  if (crossOrigin) {
    opts.cors = crossOrigin;
  }

  xhr(opts, bind(this, function (err, response, responseBody) {
    if (err) {
      return log$1.error(err, response);
    }

    track.loaded_ = true;

    // Make sure that vttjs has loaded, otherwise, wait till it finished loading
    // NOTE: this is only used for the alt/video.novtt.js build
    if (typeof window_1.WebVTT !== 'function') {
      if (track.tech_) {
        var loadHandler = function loadHandler() {
          return parseCues(responseBody, track);
        };

        track.tech_.on('vttjsloaded', loadHandler);
        track.tech_.on('vttjserror', function () {
          log$1.error('vttjs failed to load, stopping trying to process ' + track.src);
          track.tech_.off('vttjsloaded', loadHandler);
        });
      }
    } else {
      parseCues(responseBody, track);
    }
  }));
};

/**
 * A representation of a single `TextTrack`.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#texttrack}
 * @extends Track
 */

var TextTrack = function (_Track) {
  inherits(TextTrack, _Track);

  /**
   * Create an instance of this class.
   *
   * @param {Object} options={}
   *        Object of option names and values
   *
   * @param {Tech} options.tech
   *        A reference to the tech that owns this TextTrack.
   *
   * @param {TextTrack~Kind} [options.kind='subtitles']
   *        A valid text track kind.
   *
   * @param {TextTrack~Mode} [options.mode='disabled']
   *        A valid text track mode.
   *
   * @param {string} [options.id='vjs_track_' + Guid.newGUID()]
   *        A unique id for this TextTrack.
   *
   * @param {string} [options.label='']
   *        The menu label for this track.
   *
   * @param {string} [options.language='']
   *        A valid two character language code.
   *
   * @param {string} [options.srclang='']
   *        A valid two character language code. An alternative, but deprioritized
   *        vesion of `options.language`
   *
   * @param {string} [options.src]
   *        A url to TextTrack cues.
   *
   * @param {boolean} [options.default]
   *        If this track should default to on or off.
   */
  function TextTrack() {
    var _this, _ret;

    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    classCallCheck(this, TextTrack);

    if (!options.tech) {
      throw new Error('A tech was not provided.');
    }

    var settings = mergeOptions(options, {
      kind: TextTrackKind[options.kind] || 'subtitles',
      language: options.language || options.srclang || ''
    });
    var mode = TextTrackMode[settings.mode] || 'disabled';
    var default_ = settings['default'];

    if (settings.kind === 'metadata' || settings.kind === 'chapters') {
      mode = 'hidden';
    }
    // on IE8 this will be a document element
    // for every other browser this will be a normal object
    var tt = (_this = possibleConstructorReturn(this, _Track.call(this, settings)), _this);

    tt.tech_ = settings.tech;

    if (IS_IE8) {
      for (var prop in TextTrack.prototype) {
        if (prop !== 'constructor') {
          tt[prop] = TextTrack.prototype[prop];
        }
      }
    }

    tt.cues_ = [];
    tt.activeCues_ = [];

    var cues = new TextTrackCueList(tt.cues_);
    var activeCues = new TextTrackCueList(tt.activeCues_);
    var changed = false;
    var timeupdateHandler = bind(tt, function () {

      // Accessing this.activeCues for the side-effects of updating itself
      // due to it's nature as a getter function. Do not remove or cues will
      // stop updating!
      // Use the setter to prevent deletion from uglify (pure_getters rule)
      this.activeCues = this.activeCues;
      if (changed) {
        this.trigger('cuechange');
        changed = false;
      }
    });

    if (mode !== 'disabled') {
      tt.tech_.ready(function () {
        tt.tech_.on('timeupdate', timeupdateHandler);
      }, true);
    }

    /**
     * @memberof TextTrack
     * @member {boolean} default
     *         If this track was set to be on or off by default. Cannot be changed after
     *         creation.
     * @instance
     *
     * @readonly
     */
    Object.defineProperty(tt, 'default', {
      get: function get$$1() {
        return default_;
      },
      set: function set$$1() {}
    });

    /**
     * @memberof TextTrack
     * @member {string} mode
     *         Set the mode of this TextTrack to a valid {@link TextTrack~Mode}. Will
     *         not be set if setting to an invalid mode.
     * @instance
     *
     * @fires TextTrack#modechange
     */
    Object.defineProperty(tt, 'mode', {
      get: function get$$1() {
        return mode;
      },
      set: function set$$1(newMode) {
        var _this2 = this;

        if (!TextTrackMode[newMode]) {
          return;
        }
        mode = newMode;
        if (mode === 'showing') {

          this.tech_.ready(function () {
            _this2.tech_.on('timeupdate', timeupdateHandler);
          }, true);
        }
        /**
         * An event that fires when mode changes on this track. This allows
         * the TextTrackList that holds this track to act accordingly.
         *
         * > Note: This is not part of the spec!
         *
         * @event TextTrack#modechange
         * @type {EventTarget~Event}
         */
        this.trigger('modechange');
      }
    });

    /**
     * @memberof TextTrack
     * @member {TextTrackCueList} cues
     *         The text track cue list for this TextTrack.
     * @instance
     */
    Object.defineProperty(tt, 'cues', {
      get: function get$$1() {
        if (!this.loaded_) {
          return null;
        }

        return cues;
      },
      set: function set$$1() {}
    });

    /**
     * @memberof TextTrack
     * @member {TextTrackCueList} activeCues
     *         The list text track cues that are currently active for this TextTrack.
     * @instance
     */
    Object.defineProperty(tt, 'activeCues', {
      get: function get$$1() {
        if (!this.loaded_) {
          return null;
        }

        // nothing to do
        if (this.cues.length === 0) {
          return activeCues;
        }

        var ct = this.tech_.currentTime();
        var active = [];

        for (var i = 0, l = this.cues.length; i < l; i++) {
          var cue = this.cues[i];

          if (cue.startTime <= ct && cue.endTime >= ct) {
            active.push(cue);
          } else if (cue.startTime === cue.endTime && cue.startTime <= ct && cue.startTime + 0.5 >= ct) {
            active.push(cue);
          }
        }

        changed = false;

        if (active.length !== this.activeCues_.length) {
          changed = true;
        } else {
          for (var _i = 0; _i < active.length; _i++) {
            if (this.activeCues_.indexOf(active[_i]) === -1) {
              changed = true;
            }
          }
        }

        this.activeCues_ = active;
        activeCues.setCues_(this.activeCues_);

        return activeCues;
      },


      // /!\ Keep this setter empty (see the timeupdate handler above)
      set: function set$$1() {}
    });

    if (settings.src) {
      tt.src = settings.src;
      loadTrack(settings.src, tt);
    } else {
      tt.loaded_ = true;
    }

    return _ret = tt, possibleConstructorReturn(_this, _ret);
  }

  /**
   * Add a cue to the internal list of cues.
   *
   * @param {TextTrack~Cue} cue
   *        The cue to add to our internal list
   */


  TextTrack.prototype.addCue = function addCue(originalCue) {
    var cue = originalCue;

    if (window_1.vttjs && !(originalCue instanceof window_1.vttjs.VTTCue)) {
      cue = new window_1.vttjs.VTTCue(originalCue.startTime, originalCue.endTime, originalCue.text);

      for (var prop in originalCue) {
        if (!(prop in cue)) {
          cue[prop] = originalCue[prop];
        }
      }

      // make sure that `id` is copied over
      cue.id = originalCue.id;
      cue.originalCue_ = originalCue;
    }

    var tracks = this.tech_.textTracks();

    for (var i = 0; i < tracks.length; i++) {
      if (tracks[i] !== this) {
        tracks[i].removeCue(cue);
      }
    }

    this.cues_.push(cue);
    this.cues.setCues_(this.cues_);
  };

  /**
   * Remove a cue from our internal list
   *
   * @param {TextTrack~Cue} removeCue
   *        The cue to remove from our internal list
   */


  TextTrack.prototype.removeCue = function removeCue(_removeCue) {
    var i = this.cues_.length;

    while (i--) {
      var cue = this.cues_[i];

      if (cue === _removeCue || cue.originalCue_ && cue.originalCue_ === _removeCue) {
        this.cues_.splice(i, 1);
        this.cues.setCues_(this.cues_);
        break;
      }
    }
  };

  return TextTrack;
}(Track);

/**
 * cuechange - One or more cues in the track have become active or stopped being active.
 */


TextTrack.prototype.allowedEvents_ = {
  cuechange: 'cuechange'
};

/**
 * A representation of a single `AudioTrack`. If it is part of an {@link AudioTrackList}
 * only one `AudioTrack` in the list will be enabled at a time.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#audiotrack}
 * @extends Track
 */

var AudioTrack = function (_Track) {
  inherits(AudioTrack, _Track);

  /**
   * Create an instance of this class.
   *
   * @param {Object} [options={}]
   *        Object of option names and values
   *
   * @param {AudioTrack~Kind} [options.kind='']
   *        A valid audio track kind
   *
   * @param {string} [options.id='vjs_track_' + Guid.newGUID()]
   *        A unique id for this AudioTrack.
   *
   * @param {string} [options.label='']
   *        The menu label for this track.
   *
   * @param {string} [options.language='']
   *        A valid two character language code.
   *
   * @param {boolean} [options.enabled]
   *        If this track is the one that is currently playing. If this track is part of
   *        an {@link AudioTrackList}, only one {@link AudioTrack} will be enabled.
   */
  function AudioTrack() {
    var _this, _ret;

    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    classCallCheck(this, AudioTrack);

    var settings = mergeOptions(options, {
      kind: AudioTrackKind[options.kind] || ''
    });
    // on IE8 this will be a document element
    // for every other browser this will be a normal object
    var track = (_this = possibleConstructorReturn(this, _Track.call(this, settings)), _this);
    var enabled = false;

    if (IS_IE8) {
      for (var prop in AudioTrack.prototype) {
        if (prop !== 'constructor') {
          track[prop] = AudioTrack.prototype[prop];
        }
      }
    }
    /**
     * @memberof AudioTrack
     * @member {boolean} enabled
     *         If this `AudioTrack` is enabled or not. When setting this will
     *         fire {@link AudioTrack#enabledchange} if the state of enabled is changed.
     * @instance
     *
     * @fires VideoTrack#selectedchange
     */
    Object.defineProperty(track, 'enabled', {
      get: function get$$1() {
        return enabled;
      },
      set: function set$$1(newEnabled) {
        // an invalid or unchanged value
        if (typeof newEnabled !== 'boolean' || newEnabled === enabled) {
          return;
        }
        enabled = newEnabled;

        /**
         * An event that fires when enabled changes on this track. This allows
         * the AudioTrackList that holds this track to act accordingly.
         *
         * > Note: This is not part of the spec! Native tracks will do
         *         this internally without an event.
         *
         * @event AudioTrack#enabledchange
         * @type {EventTarget~Event}
         */
        this.trigger('enabledchange');
      }
    });

    // if the user sets this track to selected then
    // set selected to that true value otherwise
    // we keep it false
    if (settings.enabled) {
      track.enabled = settings.enabled;
    }
    track.loaded_ = true;

    return _ret = track, possibleConstructorReturn(_this, _ret);
  }

  return AudioTrack;
}(Track);

/**
 * A representation of a single `VideoTrack`.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#videotrack}
 * @extends Track
 */

var VideoTrack = function (_Track) {
  inherits(VideoTrack, _Track);

  /**
   * Create an instance of this class.
   *
   * @param {Object} [options={}]
   *        Object of option names and values
   *
   * @param {string} [options.kind='']
   *        A valid {@link VideoTrack~Kind}
   *
   * @param {string} [options.id='vjs_track_' + Guid.newGUID()]
   *        A unique id for this AudioTrack.
   *
   * @param {string} [options.label='']
   *        The menu label for this track.
   *
   * @param {string} [options.language='']
   *        A valid two character language code.
   *
   * @param {boolean} [options.selected]
   *        If this track is the one that is currently playing.
   */
  function VideoTrack() {
    var _this, _ret;

    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    classCallCheck(this, VideoTrack);

    var settings = mergeOptions(options, {
      kind: VideoTrackKind[options.kind] || ''
    });

    // on IE8 this will be a document element
    // for every other browser this will be a normal object
    var track = (_this = possibleConstructorReturn(this, _Track.call(this, settings)), _this);
    var selected = false;

    if (IS_IE8) {
      for (var prop in VideoTrack.prototype) {
        if (prop !== 'constructor') {
          track[prop] = VideoTrack.prototype[prop];
        }
      }
    }

    /**
     * @memberof VideoTrack
     * @member {boolean} selected
     *         If this `VideoTrack` is selected or not. When setting this will
     *         fire {@link VideoTrack#selectedchange} if the state of selected changed.
     * @instance
     *
     * @fires VideoTrack#selectedchange
     */
    Object.defineProperty(track, 'selected', {
      get: function get$$1() {
        return selected;
      },
      set: function set$$1(newSelected) {
        // an invalid or unchanged value
        if (typeof newSelected !== 'boolean' || newSelected === selected) {
          return;
        }
        selected = newSelected;

        /**
         * An event that fires when selected changes on this track. This allows
         * the VideoTrackList that holds this track to act accordingly.
         *
         * > Note: This is not part of the spec! Native tracks will do
         *         this internally without an event.
         *
         * @event VideoTrack#selectedchange
         * @type {EventTarget~Event}
         */
        this.trigger('selectedchange');
      }
    });

    // if the user sets this track to selected then
    // set selected to that true value otherwise
    // we keep it false
    if (settings.selected) {
      track.selected = settings.selected;
    }

    return _ret = track, possibleConstructorReturn(_this, _ret);
  }

  return VideoTrack;
}(Track);

/**
 * @file html-track-element.js
 */

/**
 * @memberof HTMLTrackElement
 * @typedef {HTMLTrackElement~ReadyState}
 * @enum {number}
 */
var NONE = 0;
var LOADING = 1;
var LOADED = 2;
var ERROR = 3;

/**
 * A single track represented in the DOM.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#htmltrackelement}
 * @extends EventTarget
 */

var HTMLTrackElement = function (_EventTarget) {
  inherits(HTMLTrackElement, _EventTarget);

  /**
   * Create an instance of this class.
   *
   * @param {Object} options={}
   *        Object of option names and values
   *
   * @param {Tech} options.tech
   *        A reference to the tech that owns this HTMLTrackElement.
   *
   * @param {TextTrack~Kind} [options.kind='subtitles']
   *        A valid text track kind.
   *
   * @param {TextTrack~Mode} [options.mode='disabled']
   *        A valid text track mode.
   *
   * @param {string} [options.id='vjs_track_' + Guid.newGUID()]
   *        A unique id for this TextTrack.
   *
   * @param {string} [options.label='']
   *        The menu label for this track.
   *
   * @param {string} [options.language='']
   *        A valid two character language code.
   *
   * @param {string} [options.srclang='']
   *        A valid two character language code. An alternative, but deprioritized
   *        vesion of `options.language`
   *
   * @param {string} [options.src]
   *        A url to TextTrack cues.
   *
   * @param {boolean} [options.default]
   *        If this track should default to on or off.
   */
  function HTMLTrackElement() {
    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    classCallCheck(this, HTMLTrackElement);

    var _this = possibleConstructorReturn(this, _EventTarget.call(this));

    var readyState = void 0;
    var trackElement = _this; // eslint-disable-line

    if (IS_IE8) {
      trackElement = document_1.createElement('custom');

      for (var prop in HTMLTrackElement.prototype) {
        if (prop !== 'constructor') {
          trackElement[prop] = HTMLTrackElement.prototype[prop];
        }
      }
    }

    var track = new TextTrack(options);

    trackElement.kind = track.kind;
    trackElement.src = track.src;
    trackElement.srclang = track.language;
    trackElement.label = track.label;
    trackElement['default'] = track['default'];

    /**
     * @memberof HTMLTrackElement
     * @member {HTMLTrackElement~ReadyState} readyState
     *         The current ready state of the track element.
     * @instance
     */
    Object.defineProperty(trackElement, 'readyState', {
      get: function get$$1() {
        return readyState;
      }
    });

    /**
     * @memberof HTMLTrackElement
     * @member {TextTrack} track
     *         The underlying TextTrack object.
     * @instance
     *
     */
    Object.defineProperty(trackElement, 'track', {
      get: function get$$1() {
        return track;
      }
    });

    readyState = NONE;

    /**
     * @listens TextTrack#loadeddata
     * @fires HTMLTrackElement#load
     */
    track.addEventListener('loadeddata', function () {
      readyState = LOADED;

      trackElement.trigger({
        type: 'load',
        target: trackElement
      });
    });

    if (IS_IE8) {
      var _ret;

      return _ret = trackElement, possibleConstructorReturn(_this, _ret);
    }
    return _this;
  }

  return HTMLTrackElement;
}(EventTarget);

HTMLTrackElement.prototype.allowedEvents_ = {
  load: 'load'
};

HTMLTrackElement.NONE = NONE;
HTMLTrackElement.LOADING = LOADING;
HTMLTrackElement.LOADED = LOADED;
HTMLTrackElement.ERROR = ERROR;

/*
 * This file contains all track properties that are used in
 * player.js, tech.js, html5.js and possibly other techs in the future.
 */

var NORMAL = {
  audio: {
    ListClass: AudioTrackList,
    TrackClass: AudioTrack,
    capitalName: 'Audio'
  },
  video: {
    ListClass: VideoTrackList,
    TrackClass: VideoTrack,
    capitalName: 'Video'
  },
  text: {
    ListClass: TextTrackList,
    TrackClass: TextTrack,
    capitalName: 'Text'
  }
};

Object.keys(NORMAL).forEach(function (type) {
  NORMAL[type].getterName = type + 'Tracks';
  NORMAL[type].privateName = type + 'Tracks_';
});

var REMOTE = {
  remoteText: {
    ListClass: TextTrackList,
    TrackClass: TextTrack,
    capitalName: 'RemoteText',
    getterName: 'remoteTextTracks',
    privateName: 'remoteTextTracks_'
  },
  remoteTextEl: {
    ListClass: HtmlTrackElementList,
    TrackClass: HTMLTrackElement,
    capitalName: 'RemoteTextTrackEls',
    getterName: 'remoteTextTrackEls',
    privateName: 'remoteTextTrackEls_'
  }
};

var ALL = mergeOptions(NORMAL, REMOTE);

REMOTE.names = Object.keys(REMOTE);
NORMAL.names = Object.keys(NORMAL);
ALL.names = [].concat(REMOTE.names).concat(NORMAL.names);

/**
 * Copyright 2013 vtt.js Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/* -*- Mode: Java; tab-width: 2; indent-tabs-mode: nil; c-basic-offset: 2 -*- */
/* vim: set shiftwidth=2 tabstop=2 autoindent cindent expandtab: */
var _objCreate = Object.create || (function() {
  function F() {}
  return function(o) {
    if (arguments.length !== 1) {
      throw new Error('Object.create shim only accepts one parameter.');
    }
    F.prototype = o;
    return new F();
  };
})();

// Creates a new ParserError object from an errorData object. The errorData
// object should have default code and message properties. The default message
// property can be overriden by passing in a message parameter.
// See ParsingError.Errors below for acceptable errors.
function ParsingError(errorData, message) {
  this.name = "ParsingError";
  this.code = errorData.code;
  this.message = message || errorData.message;
}
ParsingError.prototype = _objCreate(Error.prototype);
ParsingError.prototype.constructor = ParsingError;

// ParsingError metadata for acceptable ParsingErrors.
ParsingError.Errors = {
  BadSignature: {
    code: 0,
    message: "Malformed WebVTT signature."
  },
  BadTimeStamp: {
    code: 1,
    message: "Malformed time stamp."
  }
};

// Try to parse input as a time stamp.
function parseTimeStamp(input) {

  function computeSeconds(h, m, s, f) {
    return (h | 0) * 3600 + (m | 0) * 60 + (s | 0) + (f | 0) / 1000;
  }

  var m = input.match(/^(\d+):(\d{2})(:\d{2})?\.(\d{3})/);
  if (!m) {
    return null;
  }

  if (m[3]) {
    // Timestamp takes the form of [hours]:[minutes]:[seconds].[milliseconds]
    return computeSeconds(m[1], m[2], m[3].replace(":", ""), m[4]);
  } else if (m[1] > 59) {
    // Timestamp takes the form of [hours]:[minutes].[milliseconds]
    // First position is hours as it's over 59.
    return computeSeconds(m[1], m[2], 0,  m[4]);
  } else {
    // Timestamp takes the form of [minutes]:[seconds].[milliseconds]
    return computeSeconds(0, m[1], m[2], m[4]);
  }
}

// A settings object holds key/value pairs and will ignore anything but the first
// assignment to a specific key.
function Settings() {
  this.values = _objCreate(null);
}

Settings.prototype = {
  // Only accept the first assignment to any key.
  set: function(k, v) {
    if (!this.get(k) && v !== "") {
      this.values[k] = v;
    }
  },
  // Return the value for a key, or a default value.
  // If 'defaultKey' is passed then 'dflt' is assumed to be an object with
  // a number of possible default values as properties where 'defaultKey' is
  // the key of the property that will be chosen; otherwise it's assumed to be
  // a single value.
  get: function(k, dflt, defaultKey) {
    if (defaultKey) {
      return this.has(k) ? this.values[k] : dflt[defaultKey];
    }
    return this.has(k) ? this.values[k] : dflt;
  },
  // Check whether we have a value for a key.
  has: function(k) {
    return k in this.values;
  },
  // Accept a setting if its one of the given alternatives.
  alt: function(k, v, a) {
    for (var n = 0; n < a.length; ++n) {
      if (v === a[n]) {
        this.set(k, v);
        break;
      }
    }
  },
  // Accept a setting if its a valid (signed) integer.
  integer: function(k, v) {
    if (/^-?\d+$/.test(v)) { // integer
      this.set(k, parseInt(v, 10));
    }
  },
  // Accept a setting if its a valid percentage.
  percent: function(k, v) {
    var m;
    if ((m = v.match(/^([\d]{1,3})(\.[\d]*)?%$/))) {
      v = parseFloat(v);
      if (v >= 0 && v <= 100) {
        this.set(k, v);
        return true;
      }
    }
    return false;
  }
};

// Helper function to parse input into groups separated by 'groupDelim', and
// interprete each group as a key/value pair separated by 'keyValueDelim'.
function parseOptions(input, callback, keyValueDelim, groupDelim) {
  var groups = groupDelim ? input.split(groupDelim) : [input];
  for (var i in groups) {
    if (typeof groups[i] !== "string") {
      continue;
    }
    var kv = groups[i].split(keyValueDelim);
    if (kv.length !== 2) {
      continue;
    }
    var k = kv[0];
    var v = kv[1];
    callback(k, v);
  }
}

function parseCue(input, cue, regionList) {
  // Remember the original input if we need to throw an error.
  var oInput = input;
  // 4.1 WebVTT timestamp
  function consumeTimeStamp() {
    var ts = parseTimeStamp(input);
    if (ts === null) {
      throw new ParsingError(ParsingError.Errors.BadTimeStamp,
                            "Malformed timestamp: " + oInput);
    }
    // Remove time stamp from input.
    input = input.replace(/^[^\sa-zA-Z-]+/, "");
    return ts;
  }

  // 4.4.2 WebVTT cue settings
  function consumeCueSettings(input, cue) {
    var settings = new Settings();

    parseOptions(input, function (k, v) {
      switch (k) {
      case "region":
        // Find the last region we parsed with the same region id.
        for (var i = regionList.length - 1; i >= 0; i--) {
          if (regionList[i].id === v) {
            settings.set(k, regionList[i].region);
            break;
          }
        }
        break;
      case "vertical":
        settings.alt(k, v, ["rl", "lr"]);
        break;
      case "line":
        var vals = v.split(","),
            vals0 = vals[0];
        settings.integer(k, vals0);
        settings.percent(k, vals0) ? settings.set("snapToLines", false) : null;
        settings.alt(k, vals0, ["auto"]);
        if (vals.length === 2) {
          settings.alt("lineAlign", vals[1], ["start", "middle", "end"]);
        }
        break;
      case "position":
        vals = v.split(",");
        settings.percent(k, vals[0]);
        if (vals.length === 2) {
          settings.alt("positionAlign", vals[1], ["start", "middle", "end"]);
        }
        break;
      case "size":
        settings.percent(k, v);
        break;
      case "align":
        settings.alt(k, v, ["start", "middle", "end", "left", "right"]);
        break;
      }
    }, /:/, /\s/);

    // Apply default values for any missing fields.
    cue.region = settings.get("region", null);
    cue.vertical = settings.get("vertical", "");
    cue.line = settings.get("line", "auto");
    cue.lineAlign = settings.get("lineAlign", "start");
    cue.snapToLines = settings.get("snapToLines", true);
    cue.size = settings.get("size", 100);
    cue.align = settings.get("align", "middle");
    cue.position = settings.get("position", {
      start: 0,
      left: 0,
      middle: 50,
      end: 100,
      right: 100
    }, cue.align);
    cue.positionAlign = settings.get("positionAlign", {
      start: "start",
      left: "start",
      middle: "middle",
      end: "end",
      right: "end"
    }, cue.align);
  }

  function skipWhitespace() {
    input = input.replace(/^\s+/, "");
  }

  // 4.1 WebVTT cue timings.
  skipWhitespace();
  cue.startTime = consumeTimeStamp();   // (1) collect cue start time
  skipWhitespace();
  if (input.substr(0, 3) !== "-->") {     // (3) next characters must match "-->"
    throw new ParsingError(ParsingError.Errors.BadTimeStamp,
                           "Malformed time stamp (time stamps must be separated by '-->'): " +
                           oInput);
  }
  input = input.substr(3);
  skipWhitespace();
  cue.endTime = consumeTimeStamp();     // (5) collect cue end time

  // 4.1 WebVTT cue settings list.
  skipWhitespace();
  consumeCueSettings(input, cue);
}

var ESCAPE = {
  "&amp;": "&",
  "&lt;": "<",
  "&gt;": ">",
  "&lrm;": "\u200e",
  "&rlm;": "\u200f",
  "&nbsp;": "\u00a0"
};

var TAG_NAME = {
  c: "span",
  i: "i",
  b: "b",
  u: "u",
  ruby: "ruby",
  rt: "rt",
  v: "span",
  lang: "span"
};

var TAG_ANNOTATION = {
  v: "title",
  lang: "lang"
};

var NEEDS_PARENT = {
  rt: "ruby"
};

// Parse content into a document fragment.
function parseContent(window, input) {
  function nextToken() {
    // Check for end-of-string.
    if (!input) {
      return null;
    }

    // Consume 'n' characters from the input.
    function consume(result) {
      input = input.substr(result.length);
      return result;
    }

    var m = input.match(/^([^<]*)(<[^>]*>?)?/);
    // If there is some text before the next tag, return it, otherwise return
    // the tag.
    return consume(m[1] ? m[1] : m[2]);
  }

  // Unescape a string 's'.
  function unescape1(e) {
    return ESCAPE[e];
  }
  function unescape(s) {
    while ((m = s.match(/&(amp|lt|gt|lrm|rlm|nbsp);/))) {
      s = s.replace(m[0], unescape1);
    }
    return s;
  }

  function shouldAdd(current, element) {
    return !NEEDS_PARENT[element.localName] ||
           NEEDS_PARENT[element.localName] === current.localName;
  }

  // Create an element for this tag.
  function createElement(type, annotation) {
    var tagName = TAG_NAME[type];
    if (!tagName) {
      return null;
    }
    var element = window.document.createElement(tagName);
    element.localName = tagName;
    var name = TAG_ANNOTATION[type];
    if (name && annotation) {
      element[name] = annotation.trim();
    }
    return element;
  }

  var rootDiv = window.document.createElement("div"),
      current = rootDiv,
      t,
      tagStack = [];

  while ((t = nextToken()) !== null) {
    if (t[0] === '<') {
      if (t[1] === "/") {
        // If the closing tag matches, move back up to the parent node.
        if (tagStack.length &&
            tagStack[tagStack.length - 1] === t.substr(2).replace(">", "")) {
          tagStack.pop();
          current = current.parentNode;
        }
        // Otherwise just ignore the end tag.
        continue;
      }
      var ts = parseTimeStamp(t.substr(1, t.length - 2));
      var node;
      if (ts) {
        // Timestamps are lead nodes as well.
        node = window.document.createProcessingInstruction("timestamp", ts);
        current.appendChild(node);
        continue;
      }
      var m = t.match(/^<([^.\s/0-9>]+)(\.[^\s\\>]+)?([^>\\]+)?(\\?)>?$/);
      // If we can't parse the tag, skip to the next tag.
      if (!m) {
        continue;
      }
      // Try to construct an element, and ignore the tag if we couldn't.
      node = createElement(m[1], m[3]);
      if (!node) {
        continue;
      }
      // Determine if the tag should be added based on the context of where it
      // is placed in the cuetext.
      if (!shouldAdd(current, node)) {
        continue;
      }
      // Set the class list (as a list of classes, separated by space).
      if (m[2]) {
        node.className = m[2].substr(1).replace('.', ' ');
      }
      // Append the node to the current node, and enter the scope of the new
      // node.
      tagStack.push(m[1]);
      current.appendChild(node);
      current = node;
      continue;
    }

    // Text nodes are leaf nodes.
    current.appendChild(window.document.createTextNode(unescape(t)));
  }

  return rootDiv;
}

// This is a list of all the Unicode characters that have a strong
// right-to-left category. What this means is that these characters are
// written right-to-left for sure. It was generated by pulling all the strong
// right-to-left characters out of the Unicode data table. That table can
// found at: http://www.unicode.org/Public/UNIDATA/UnicodeData.txt
var strongRTLRanges = [[0x5be, 0x5be], [0x5c0, 0x5c0], [0x5c3, 0x5c3], [0x5c6, 0x5c6],
 [0x5d0, 0x5ea], [0x5f0, 0x5f4], [0x608, 0x608], [0x60b, 0x60b], [0x60d, 0x60d],
 [0x61b, 0x61b], [0x61e, 0x64a], [0x66d, 0x66f], [0x671, 0x6d5], [0x6e5, 0x6e6],
 [0x6ee, 0x6ef], [0x6fa, 0x70d], [0x70f, 0x710], [0x712, 0x72f], [0x74d, 0x7a5],
 [0x7b1, 0x7b1], [0x7c0, 0x7ea], [0x7f4, 0x7f5], [0x7fa, 0x7fa], [0x800, 0x815],
 [0x81a, 0x81a], [0x824, 0x824], [0x828, 0x828], [0x830, 0x83e], [0x840, 0x858],
 [0x85e, 0x85e], [0x8a0, 0x8a0], [0x8a2, 0x8ac], [0x200f, 0x200f],
 [0xfb1d, 0xfb1d], [0xfb1f, 0xfb28], [0xfb2a, 0xfb36], [0xfb38, 0xfb3c],
 [0xfb3e, 0xfb3e], [0xfb40, 0xfb41], [0xfb43, 0xfb44], [0xfb46, 0xfbc1],
 [0xfbd3, 0xfd3d], [0xfd50, 0xfd8f], [0xfd92, 0xfdc7], [0xfdf0, 0xfdfc],
 [0xfe70, 0xfe74], [0xfe76, 0xfefc], [0x10800, 0x10805], [0x10808, 0x10808],
 [0x1080a, 0x10835], [0x10837, 0x10838], [0x1083c, 0x1083c], [0x1083f, 0x10855],
 [0x10857, 0x1085f], [0x10900, 0x1091b], [0x10920, 0x10939], [0x1093f, 0x1093f],
 [0x10980, 0x109b7], [0x109be, 0x109bf], [0x10a00, 0x10a00], [0x10a10, 0x10a13],
 [0x10a15, 0x10a17], [0x10a19, 0x10a33], [0x10a40, 0x10a47], [0x10a50, 0x10a58],
 [0x10a60, 0x10a7f], [0x10b00, 0x10b35], [0x10b40, 0x10b55], [0x10b58, 0x10b72],
 [0x10b78, 0x10b7f], [0x10c00, 0x10c48], [0x1ee00, 0x1ee03], [0x1ee05, 0x1ee1f],
 [0x1ee21, 0x1ee22], [0x1ee24, 0x1ee24], [0x1ee27, 0x1ee27], [0x1ee29, 0x1ee32],
 [0x1ee34, 0x1ee37], [0x1ee39, 0x1ee39], [0x1ee3b, 0x1ee3b], [0x1ee42, 0x1ee42],
 [0x1ee47, 0x1ee47], [0x1ee49, 0x1ee49], [0x1ee4b, 0x1ee4b], [0x1ee4d, 0x1ee4f],
 [0x1ee51, 0x1ee52], [0x1ee54, 0x1ee54], [0x1ee57, 0x1ee57], [0x1ee59, 0x1ee59],
 [0x1ee5b, 0x1ee5b], [0x1ee5d, 0x1ee5d], [0x1ee5f, 0x1ee5f], [0x1ee61, 0x1ee62],
 [0x1ee64, 0x1ee64], [0x1ee67, 0x1ee6a], [0x1ee6c, 0x1ee72], [0x1ee74, 0x1ee77],
 [0x1ee79, 0x1ee7c], [0x1ee7e, 0x1ee7e], [0x1ee80, 0x1ee89], [0x1ee8b, 0x1ee9b],
 [0x1eea1, 0x1eea3], [0x1eea5, 0x1eea9], [0x1eeab, 0x1eebb], [0x10fffd, 0x10fffd]];

function isStrongRTLChar(charCode) {
  for (var i = 0; i < strongRTLRanges.length; i++) {
    var currentRange = strongRTLRanges[i];
    if (charCode >= currentRange[0] && charCode <= currentRange[1]) {
      return true;
    }
  }

  return false;
}

function determineBidi(cueDiv) {
  var nodeStack = [],
      text = "",
      charCode;

  if (!cueDiv || !cueDiv.childNodes) {
    return "ltr";
  }

  function pushNodes(nodeStack, node) {
    for (var i = node.childNodes.length - 1; i >= 0; i--) {
      nodeStack.push(node.childNodes[i]);
    }
  }

  function nextTextNode(nodeStack) {
    if (!nodeStack || !nodeStack.length) {
      return null;
    }

    var node = nodeStack.pop(),
        text = node.textContent || node.innerText;
    if (text) {
      // TODO: This should match all unicode type B characters (paragraph
      // separator characters). See issue #115.
      var m = text.match(/^.*(\n|\r)/);
      if (m) {
        nodeStack.length = 0;
        return m[0];
      }
      return text;
    }
    if (node.tagName === "ruby") {
      return nextTextNode(nodeStack);
    }
    if (node.childNodes) {
      pushNodes(nodeStack, node);
      return nextTextNode(nodeStack);
    }
  }

  pushNodes(nodeStack, cueDiv);
  while ((text = nextTextNode(nodeStack))) {
    for (var i = 0; i < text.length; i++) {
      charCode = text.charCodeAt(i);
      if (isStrongRTLChar(charCode)) {
        return "rtl";
      }
    }
  }
  return "ltr";
}

function computeLinePos(cue) {
  if (typeof cue.line === "number" &&
      (cue.snapToLines || (cue.line >= 0 && cue.line <= 100))) {
    return cue.line;
  }
  if (!cue.track || !cue.track.textTrackList ||
      !cue.track.textTrackList.mediaElement) {
    return -1;
  }
  var track = cue.track,
      trackList = track.textTrackList,
      count = 0;
  for (var i = 0; i < trackList.length && trackList[i] !== track; i++) {
    if (trackList[i].mode === "showing") {
      count++;
    }
  }
  return ++count * -1;
}

function StyleBox() {
}

// Apply styles to a div. If there is no div passed then it defaults to the
// div on 'this'.
StyleBox.prototype.applyStyles = function(styles, div) {
  div = div || this.div;
  for (var prop in styles) {
    if (styles.hasOwnProperty(prop)) {
      div.style[prop] = styles[prop];
    }
  }
};

StyleBox.prototype.formatStyle = function(val, unit) {
  return val === 0 ? 0 : val + unit;
};

// Constructs the computed display state of the cue (a div). Places the div
// into the overlay which should be a block level element (usually a div).
function CueStyleBox(window, cue, styleOptions) {
  var isIE8 = (/MSIE\s8\.0/).test(navigator.userAgent);
  var color = "rgba(255, 255, 255, 1)";
  var backgroundColor = "rgba(0, 0, 0, 0.8)";

  if (isIE8) {
    color = "rgb(255, 255, 255)";
    backgroundColor = "rgb(0, 0, 0)";
  }

  StyleBox.call(this);
  this.cue = cue;

  // Parse our cue's text into a DOM tree rooted at 'cueDiv'. This div will
  // have inline positioning and will function as the cue background box.
  this.cueDiv = parseContent(window, cue.text);
  var styles = {
    color: color,
    backgroundColor: backgroundColor,
    position: "relative",
    left: 0,
    right: 0,
    top: 0,
    bottom: 0,
    display: "inline"
  };

  if (!isIE8) {
    styles.writingMode = cue.vertical === "" ? "horizontal-tb"
                                             : cue.vertical === "lr" ? "vertical-lr"
                                                                     : "vertical-rl";
    styles.unicodeBidi = "plaintext";
  }
  this.applyStyles(styles, this.cueDiv);

  // Create an absolutely positioned div that will be used to position the cue
  // div. Note, all WebVTT cue-setting alignments are equivalent to the CSS
  // mirrors of them except "middle" which is "center" in CSS.
  this.div = window.document.createElement("div");
  styles = {
    textAlign: cue.align === "middle" ? "center" : cue.align,
    font: styleOptions.font,
    whiteSpace: "pre-line",
    position: "absolute"
  };

  if (!isIE8) {
    styles.direction = determineBidi(this.cueDiv);
    styles.writingMode = cue.vertical === "" ? "horizontal-tb"
                                             : cue.vertical === "lr" ? "vertical-lr"
                                                                     : "vertical-rl".
    stylesunicodeBidi =  "plaintext";
  }

  this.applyStyles(styles);

  this.div.appendChild(this.cueDiv);

  // Calculate the distance from the reference edge of the viewport to the text
  // position of the cue box. The reference edge will be resolved later when
  // the box orientation styles are applied.
  var textPos = 0;
  switch (cue.positionAlign) {
  case "start":
    textPos = cue.position;
    break;
  case "middle":
    textPos = cue.position - (cue.size / 2);
    break;
  case "end":
    textPos = cue.position - cue.size;
    break;
  }

  // Horizontal box orientation; textPos is the distance from the left edge of the
  // area to the left edge of the box and cue.size is the distance extending to
  // the right from there.
  if (cue.vertical === "") {
    this.applyStyles({
      left:  this.formatStyle(textPos, "%"),
      width: this.formatStyle(cue.size, "%")
    });
  // Vertical box orientation; textPos is the distance from the top edge of the
  // area to the top edge of the box and cue.size is the height extending
  // downwards from there.
  } else {
    this.applyStyles({
      top: this.formatStyle(textPos, "%"),
      height: this.formatStyle(cue.size, "%")
    });
  }

  this.move = function(box) {
    this.applyStyles({
      top: this.formatStyle(box.top, "px"),
      bottom: this.formatStyle(box.bottom, "px"),
      left: this.formatStyle(box.left, "px"),
      right: this.formatStyle(box.right, "px"),
      height: this.formatStyle(box.height, "px"),
      width: this.formatStyle(box.width, "px")
    });
  };
}
CueStyleBox.prototype = _objCreate(StyleBox.prototype);
CueStyleBox.prototype.constructor = CueStyleBox;

// Represents the co-ordinates of an Element in a way that we can easily
// compute things with such as if it overlaps or intersects with another Element.
// Can initialize it with either a StyleBox or another BoxPosition.
function BoxPosition(obj) {
  var isIE8 = (/MSIE\s8\.0/).test(navigator.userAgent);

  // Either a BoxPosition was passed in and we need to copy it, or a StyleBox
  // was passed in and we need to copy the results of 'getBoundingClientRect'
  // as the object returned is readonly. All co-ordinate values are in reference
  // to the viewport origin (top left).
  var lh, height, width, top;
  if (obj.div) {
    height = obj.div.offsetHeight;
    width = obj.div.offsetWidth;
    top = obj.div.offsetTop;

    var rects = (rects = obj.div.childNodes) && (rects = rects[0]) &&
                rects.getClientRects && rects.getClientRects();
    obj = obj.div.getBoundingClientRect();
    // In certain cases the outter div will be slightly larger then the sum of
    // the inner div's lines. This could be due to bold text, etc, on some platforms.
    // In this case we should get the average line height and use that. This will
    // result in the desired behaviour.
    lh = rects ? Math.max((rects[0] && rects[0].height) || 0, obj.height / rects.length)
               : 0;

  }
  this.left = obj.left;
  this.right = obj.right;
  this.top = obj.top || top;
  this.height = obj.height || height;
  this.bottom = obj.bottom || (top + (obj.height || height));
  this.width = obj.width || width;
  this.lineHeight = lh !== undefined ? lh : obj.lineHeight;

  if (isIE8 && !this.lineHeight) {
    this.lineHeight = 13;
  }
}

// Move the box along a particular axis. Optionally pass in an amount to move
// the box. If no amount is passed then the default is the line height of the
// box.
BoxPosition.prototype.move = function(axis, toMove) {
  toMove = toMove !== undefined ? toMove : this.lineHeight;
  switch (axis) {
  case "+x":
    this.left += toMove;
    this.right += toMove;
    break;
  case "-x":
    this.left -= toMove;
    this.right -= toMove;
    break;
  case "+y":
    this.top += toMove;
    this.bottom += toMove;
    break;
  case "-y":
    this.top -= toMove;
    this.bottom -= toMove;
    break;
  }
};

// Check if this box overlaps another box, b2.
BoxPosition.prototype.overlaps = function(b2) {
  return this.left < b2.right &&
         this.right > b2.left &&
         this.top < b2.bottom &&
         this.bottom > b2.top;
};

// Check if this box overlaps any other boxes in boxes.
BoxPosition.prototype.overlapsAny = function(boxes) {
  for (var i = 0; i < boxes.length; i++) {
    if (this.overlaps(boxes[i])) {
      return true;
    }
  }
  return false;
};

// Check if this box is within another box.
BoxPosition.prototype.within = function(container) {
  return this.top >= container.top &&
         this.bottom <= container.bottom &&
         this.left >= container.left &&
         this.right <= container.right;
};

// Check if this box is entirely within the container or it is overlapping
// on the edge opposite of the axis direction passed. For example, if "+x" is
// passed and the box is overlapping on the left edge of the container, then
// return true.
BoxPosition.prototype.overlapsOppositeAxis = function(container, axis) {
  switch (axis) {
  case "+x":
    return this.left < container.left;
  case "-x":
    return this.right > container.right;
  case "+y":
    return this.top < container.top;
  case "-y":
    return this.bottom > container.bottom;
  }
};

// Find the percentage of the area that this box is overlapping with another
// box.
BoxPosition.prototype.intersectPercentage = function(b2) {
  var x = Math.max(0, Math.min(this.right, b2.right) - Math.max(this.left, b2.left)),
      y = Math.max(0, Math.min(this.bottom, b2.bottom) - Math.max(this.top, b2.top)),
      intersectArea = x * y;
  return intersectArea / (this.height * this.width);
};

// Convert the positions from this box to CSS compatible positions using
// the reference container's positions. This has to be done because this
// box's positions are in reference to the viewport origin, whereas, CSS
// values are in referecne to their respective edges.
BoxPosition.prototype.toCSSCompatValues = function(reference) {
  return {
    top: this.top - reference.top,
    bottom: reference.bottom - this.bottom,
    left: this.left - reference.left,
    right: reference.right - this.right,
    height: this.height,
    width: this.width
  };
};

// Get an object that represents the box's position without anything extra.
// Can pass a StyleBox, HTMLElement, or another BoxPositon.
BoxPosition.getSimpleBoxPosition = function(obj) {
  var height = obj.div ? obj.div.offsetHeight : obj.tagName ? obj.offsetHeight : 0;
  var width = obj.div ? obj.div.offsetWidth : obj.tagName ? obj.offsetWidth : 0;
  var top = obj.div ? obj.div.offsetTop : obj.tagName ? obj.offsetTop : 0;

  obj = obj.div ? obj.div.getBoundingClientRect() :
                obj.tagName ? obj.getBoundingClientRect() : obj;
  var ret = {
    left: obj.left,
    right: obj.right,
    top: obj.top || top,
    height: obj.height || height,
    bottom: obj.bottom || (top + (obj.height || height)),
    width: obj.width || width
  };
  return ret;
};

// Move a StyleBox to its specified, or next best, position. The containerBox
// is the box that contains the StyleBox, such as a div. boxPositions are
// a list of other boxes that the styleBox can't overlap with.
function moveBoxToLinePosition(window, styleBox, containerBox, boxPositions) {

  // Find the best position for a cue box, b, on the video. The axis parameter
  // is a list of axis, the order of which, it will move the box along. For example:
  // Passing ["+x", "-x"] will move the box first along the x axis in the positive
  // direction. If it doesn't find a good position for it there it will then move
  // it along the x axis in the negative direction.
  function findBestPosition(b, axis) {
    var bestPosition,
        specifiedPosition = new BoxPosition(b),
        percentage = 1; // Highest possible so the first thing we get is better.

    for (var i = 0; i < axis.length; i++) {
      while (b.overlapsOppositeAxis(containerBox, axis[i]) ||
             (b.within(containerBox) && b.overlapsAny(boxPositions))) {
        b.move(axis[i]);
      }
      // We found a spot where we aren't overlapping anything. This is our
      // best position.
      if (b.within(containerBox)) {
        return b;
      }
      var p = b.intersectPercentage(containerBox);
      // If we're outside the container box less then we were on our last try
      // then remember this position as the best position.
      if (percentage > p) {
        bestPosition = new BoxPosition(b);
        percentage = p;
      }
      // Reset the box position to the specified position.
      b = new BoxPosition(specifiedPosition);
    }
    return bestPosition || specifiedPosition;
  }

  var boxPosition = new BoxPosition(styleBox),
      cue = styleBox.cue,
      linePos = computeLinePos(cue),
      axis = [];

  // If we have a line number to align the cue to.
  if (cue.snapToLines) {
    var size;
    switch (cue.vertical) {
    case "":
      axis = [ "+y", "-y" ];
      size = "height";
      break;
    case "rl":
      axis = [ "+x", "-x" ];
      size = "width";
      break;
    case "lr":
      axis = [ "-x", "+x" ];
      size = "width";
      break;
    }

    var step = boxPosition.lineHeight,
        position = step * Math.round(linePos),
        maxPosition = containerBox[size] + step,
        initialAxis = axis[0];

    // If the specified intial position is greater then the max position then
    // clamp the box to the amount of steps it would take for the box to
    // reach the max position.
    if (Math.abs(position) > maxPosition) {
      position = position < 0 ? -1 : 1;
      position *= Math.ceil(maxPosition / step) * step;
    }

    // If computed line position returns negative then line numbers are
    // relative to the bottom of the video instead of the top. Therefore, we
    // need to increase our initial position by the length or width of the
    // video, depending on the writing direction, and reverse our axis directions.
    if (linePos < 0) {
      position += cue.vertical === "" ? containerBox.height : containerBox.width;
      axis = axis.reverse();
    }

    // Move the box to the specified position. This may not be its best
    // position.
    boxPosition.move(initialAxis, position);

  } else {
    // If we have a percentage line value for the cue.
    var calculatedPercentage = (boxPosition.lineHeight / containerBox.height) * 100;

    switch (cue.lineAlign) {
    case "middle":
      linePos -= (calculatedPercentage / 2);
      break;
    case "end":
      linePos -= calculatedPercentage;
      break;
    }

    // Apply initial line position to the cue box.
    switch (cue.vertical) {
    case "":
      styleBox.applyStyles({
        top: styleBox.formatStyle(linePos, "%")
      });
      break;
    case "rl":
      styleBox.applyStyles({
        left: styleBox.formatStyle(linePos, "%")
      });
      break;
    case "lr":
      styleBox.applyStyles({
        right: styleBox.formatStyle(linePos, "%")
      });
      break;
    }

    axis = [ "+y", "-x", "+x", "-y" ];

    // Get the box position again after we've applied the specified positioning
    // to it.
    boxPosition = new BoxPosition(styleBox);
  }

  var bestPosition = findBestPosition(boxPosition, axis);
  styleBox.move(bestPosition.toCSSCompatValues(containerBox));
}

function WebVTT$1() {
  // Nothing
}

// Helper to allow strings to be decoded instead of the default binary utf8 data.
WebVTT$1.StringDecoder = function() {
  return {
    decode: function(data) {
      if (!data) {
        return "";
      }
      if (typeof data !== "string") {
        throw new Error("Error - expected string data.");
      }
      return decodeURIComponent(encodeURIComponent(data));
    }
  };
};

WebVTT$1.convertCueToDOMTree = function(window, cuetext) {
  if (!window || !cuetext) {
    return null;
  }
  return parseContent(window, cuetext);
};

var FONT_SIZE_PERCENT = 0.05;
var FONT_STYLE = "sans-serif";
var CUE_BACKGROUND_PADDING = "1.5%";

// Runs the processing model over the cues and regions passed to it.
// @param overlay A block level element (usually a div) that the computed cues
//                and regions will be placed into.
WebVTT$1.processCues = function(window, cues, overlay) {
  if (!window || !cues || !overlay) {
    return null;
  }

  // Remove all previous children.
  while (overlay.firstChild) {
    overlay.removeChild(overlay.firstChild);
  }

  var paddedOverlay = window.document.createElement("div");
  paddedOverlay.style.position = "absolute";
  paddedOverlay.style.left = "0";
  paddedOverlay.style.right = "0";
  paddedOverlay.style.top = "0";
  paddedOverlay.style.bottom = "0";
  paddedOverlay.style.margin = CUE_BACKGROUND_PADDING;
  overlay.appendChild(paddedOverlay);

  // Determine if we need to compute the display states of the cues. This could
  // be the case if a cue's state has been changed since the last computation or
  // if it has not been computed yet.
  function shouldCompute(cues) {
    for (var i = 0; i < cues.length; i++) {
      if (cues[i].hasBeenReset || !cues[i].displayState) {
        return true;
      }
    }
    return false;
  }

  // We don't need to recompute the cues' display states. Just reuse them.
  if (!shouldCompute(cues)) {
    for (var i = 0; i < cues.length; i++) {
      paddedOverlay.appendChild(cues[i].displayState);
    }
    return;
  }

  var boxPositions = [],
      containerBox = BoxPosition.getSimpleBoxPosition(paddedOverlay),
      fontSize = Math.round(containerBox.height * FONT_SIZE_PERCENT * 100) / 100;
  var styleOptions = {
    font: fontSize + "px " + FONT_STYLE
  };

  (function() {
    var styleBox, cue;

    for (var i = 0; i < cues.length; i++) {
      cue = cues[i];

      // Compute the intial position and styles of the cue div.
      styleBox = new CueStyleBox(window, cue, styleOptions);
      paddedOverlay.appendChild(styleBox.div);

      // Move the cue div to it's correct line position.
      moveBoxToLinePosition(window, styleBox, containerBox, boxPositions);

      // Remember the computed div so that we don't have to recompute it later
      // if we don't have too.
      cue.displayState = styleBox.div;

      boxPositions.push(BoxPosition.getSimpleBoxPosition(styleBox));
    }
  })();
};

WebVTT$1.Parser = function(window, vttjs, decoder) {
  if (!decoder) {
    decoder = vttjs;
    vttjs = {};
  }
  if (!vttjs) {
    vttjs = {};
  }

  this.window = window;
  this.vttjs = vttjs;
  this.state = "INITIAL";
  this.buffer = "";
  this.decoder = decoder || new TextDecoder("utf8");
  this.regionList = [];
};

WebVTT$1.Parser.prototype = {
  // If the error is a ParsingError then report it to the consumer if
  // possible. If it's not a ParsingError then throw it like normal.
  reportOrThrowError: function(e) {
    if (e instanceof ParsingError) {
      this.onparsingerror && this.onparsingerror(e);
    } else {
      throw e;
    }
  },
  parse: function (data) {
    var self = this;

    // If there is no data then we won't decode it, but will just try to parse
    // whatever is in buffer already. This may occur in circumstances, for
    // example when flush() is called.
    if (data) {
      // Try to decode the data that we received.
      self.buffer += self.decoder.decode(data, {stream: true});
    }

    function collectNextLine() {
      var buffer = self.buffer;
      var pos = 0;
      while (pos < buffer.length && buffer[pos] !== '\r' && buffer[pos] !== '\n') {
        ++pos;
      }
      var line = buffer.substr(0, pos);
      // Advance the buffer early in case we fail below.
      if (buffer[pos] === '\r') {
        ++pos;
      }
      if (buffer[pos] === '\n') {
        ++pos;
      }
      self.buffer = buffer.substr(pos);
      return line;
    }

    // 3.4 WebVTT region and WebVTT region settings syntax
    function parseRegion(input) {
      var settings = new Settings();

      parseOptions(input, function (k, v) {
        switch (k) {
        case "id":
          settings.set(k, v);
          break;
        case "width":
          settings.percent(k, v);
          break;
        case "lines":
          settings.integer(k, v);
          break;
        case "regionanchor":
        case "viewportanchor":
          var xy = v.split(',');
          if (xy.length !== 2) {
            break;
          }
          // We have to make sure both x and y parse, so use a temporary
          // settings object here.
          var anchor = new Settings();
          anchor.percent("x", xy[0]);
          anchor.percent("y", xy[1]);
          if (!anchor.has("x") || !anchor.has("y")) {
            break;
          }
          settings.set(k + "X", anchor.get("x"));
          settings.set(k + "Y", anchor.get("y"));
          break;
        case "scroll":
          settings.alt(k, v, ["up"]);
          break;
        }
      }, /=/, /\s/);

      // Create the region, using default values for any values that were not
      // specified.
      if (settings.has("id")) {
        var region = new (self.vttjs.VTTRegion || self.window.VTTRegion)();
        region.width = settings.get("width", 100);
        region.lines = settings.get("lines", 3);
        region.regionAnchorX = settings.get("regionanchorX", 0);
        region.regionAnchorY = settings.get("regionanchorY", 100);
        region.viewportAnchorX = settings.get("viewportanchorX", 0);
        region.viewportAnchorY = settings.get("viewportanchorY", 100);
        region.scroll = settings.get("scroll", "");
        // Register the region.
        self.onregion && self.onregion(region);
        // Remember the VTTRegion for later in case we parse any VTTCues that
        // reference it.
        self.regionList.push({
          id: settings.get("id"),
          region: region
        });
      }
    }

    // draft-pantos-http-live-streaming-20
    // https://tools.ietf.org/html/draft-pantos-http-live-streaming-20#section-3.5
    // 3.5 WebVTT
    function parseTimestampMap(input) {
      var settings = new Settings();

      parseOptions(input, function(k, v) {
        switch(k) {
        case "MPEGT":
          settings.integer(k + 'S', v);
          break;
        case "LOCA":
          settings.set(k + 'L', parseTimeStamp(v));
          break;
        }
      }, /[^\d]:/, /,/);

      self.ontimestampmap && self.ontimestampmap({
        "MPEGTS": settings.get("MPEGTS"),
        "LOCAL": settings.get("LOCAL")
      });
    }

    // 3.2 WebVTT metadata header syntax
    function parseHeader(input) {
      if (input.match(/X-TIMESTAMP-MAP/)) {
        // This line contains HLS X-TIMESTAMP-MAP metadata
        parseOptions(input, function(k, v) {
          switch(k) {
          case "X-TIMESTAMP-MAP":
            parseTimestampMap(v);
            break;
          }
        }, /=/);
      } else {
        parseOptions(input, function (k, v) {
          switch (k) {
          case "Region":
            // 3.3 WebVTT region metadata header syntax
            parseRegion(v);
            break;
          }
        }, /:/);
      }

    }

    // 5.1 WebVTT file parsing.
    try {
      var line;
      if (self.state === "INITIAL") {
        // We can't start parsing until we have the first line.
        if (!/\r\n|\n/.test(self.buffer)) {
          return this;
        }

        line = collectNextLine();

        var m = line.match(/^WEBVTT([ \t].*)?$/);
        if (!m || !m[0]) {
          throw new ParsingError(ParsingError.Errors.BadSignature);
        }

        self.state = "HEADER";
      }

      var alreadyCollectedLine = false;
      while (self.buffer) {
        // We can't parse a line until we have the full line.
        if (!/\r\n|\n/.test(self.buffer)) {
          return this;
        }

        if (!alreadyCollectedLine) {
          line = collectNextLine();
        } else {
          alreadyCollectedLine = false;
        }

        switch (self.state) {
        case "HEADER":
          // 13-18 - Allow a header (metadata) under the WEBVTT line.
          if (/:/.test(line)) {
            parseHeader(line);
          } else if (!line) {
            // An empty line terminates the header and starts the body (cues).
            self.state = "ID";
          }
          continue;
        case "NOTE":
          // Ignore NOTE blocks.
          if (!line) {
            self.state = "ID";
          }
          continue;
        case "ID":
          // Check for the start of NOTE blocks.
          if (/^NOTE($|[ \t])/.test(line)) {
            self.state = "NOTE";
            break;
          }
          // 19-29 - Allow any number of line terminators, then initialize new cue values.
          if (!line) {
            continue;
          }
          self.cue = new (self.vttjs.VTTCue || self.window.VTTCue)(0, 0, "");
          self.state = "CUE";
          // 30-39 - Check if self line contains an optional identifier or timing data.
          if (line.indexOf("-->") === -1) {
            self.cue.id = line;
            continue;
          }
          // Process line as start of a cue.
          /*falls through*/
        case "CUE":
          // 40 - Collect cue timings and settings.
          try {
            parseCue(line, self.cue, self.regionList);
          } catch (e) {
            self.reportOrThrowError(e);
            // In case of an error ignore rest of the cue.
            self.cue = null;
            self.state = "BADCUE";
            continue;
          }
          self.state = "CUETEXT";
          continue;
        case "CUETEXT":
          var hasSubstring = line.indexOf("-->") !== -1;
          // 34 - If we have an empty line then report the cue.
          // 35 - If we have the special substring '-->' then report the cue,
          // but do not collect the line as we need to process the current
          // one as a new cue.
          if (!line || hasSubstring && (alreadyCollectedLine = true)) {
            // We are done parsing self cue.
            self.oncue && self.oncue(self.cue);
            self.cue = null;
            self.state = "ID";
            continue;
          }
          if (self.cue.text) {
            self.cue.text += "\n";
          }
          self.cue.text += line;
          continue;
        case "BADCUE": // BADCUE
          // 54-62 - Collect and discard the remaining cue.
          if (!line) {
            self.state = "ID";
          }
          continue;
        }
      }
    } catch (e) {
      self.reportOrThrowError(e);

      // If we are currently parsing a cue, report what we have.
      if (self.state === "CUETEXT" && self.cue && self.oncue) {
        self.oncue(self.cue);
      }
      self.cue = null;
      // Enter BADWEBVTT state if header was not parsed correctly otherwise
      // another exception occurred so enter BADCUE state.
      self.state = self.state === "INITIAL" ? "BADWEBVTT" : "BADCUE";
    }
    return this;
  },
  flush: function () {
    var self = this;
    try {
      // Finish decoding the stream.
      self.buffer += self.decoder.decode();
      // Synthesize the end of the current cue or region.
      if (self.cue || self.state === "HEADER") {
        self.buffer += "\n\n";
        self.parse();
      }
      // If we've flushed, parsed, and we're still on the INITIAL state then
      // that means we don't have enough of the stream to parse the first
      // line.
      if (self.state === "INITIAL") {
        throw new ParsingError(ParsingError.Errors.BadSignature);
      }
    } catch(e) {
      self.reportOrThrowError(e);
    }
    self.onflush && self.onflush();
    return this;
  }
};

var vtt$1 = WebVTT$1;

/**
 * Copyright 2013 vtt.js Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var autoKeyword = "auto";
var directionSetting = {
  "": true,
  "lr": true,
  "rl": true
};
var alignSetting = {
  "start": true,
  "middle": true,
  "end": true,
  "left": true,
  "right": true
};

function findDirectionSetting(value) {
  if (typeof value !== "string") {
    return false;
  }
  var dir = directionSetting[value.toLowerCase()];
  return dir ? value.toLowerCase() : false;
}

function findAlignSetting(value) {
  if (typeof value !== "string") {
    return false;
  }
  var align = alignSetting[value.toLowerCase()];
  return align ? value.toLowerCase() : false;
}

function extend$1(obj) {
  var i = 1;
  for (; i < arguments.length; i++) {
    var cobj = arguments[i];
    for (var p in cobj) {
      obj[p] = cobj[p];
    }
  }

  return obj;
}

function VTTCue(startTime, endTime, text) {
  var cue = this;
  var isIE8 = (/MSIE\s8\.0/).test(navigator.userAgent);
  var baseObj = {};

  if (isIE8) {
    cue = document.createElement('custom');
  } else {
    baseObj.enumerable = true;
  }

  /**
   * Shim implementation specific properties. These properties are not in
   * the spec.
   */

  // Lets us know when the VTTCue's data has changed in such a way that we need
  // to recompute its display state. This lets us compute its display state
  // lazily.
  cue.hasBeenReset = false;

  /**
   * VTTCue and TextTrackCue properties
   * http://dev.w3.org/html5/webvtt/#vttcue-interface
   */

  var _id = "";
  var _pauseOnExit = false;
  var _startTime = startTime;
  var _endTime = endTime;
  var _text = text;
  var _region = null;
  var _vertical = "";
  var _snapToLines = true;
  var _line = "auto";
  var _lineAlign = "start";
  var _position = 50;
  var _positionAlign = "middle";
  var _size = 50;
  var _align = "middle";

  Object.defineProperty(cue,
    "id", extend$1({}, baseObj, {
      get: function() {
        return _id;
      },
      set: function(value) {
        _id = "" + value;
      }
    }));

  Object.defineProperty(cue,
    "pauseOnExit", extend$1({}, baseObj, {
      get: function() {
        return _pauseOnExit;
      },
      set: function(value) {
        _pauseOnExit = !!value;
      }
    }));

  Object.defineProperty(cue,
    "startTime", extend$1({}, baseObj, {
      get: function() {
        return _startTime;
      },
      set: function(value) {
        if (typeof value !== "number") {
          throw new TypeError("Start time must be set to a number.");
        }
        _startTime = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "endTime", extend$1({}, baseObj, {
      get: function() {
        return _endTime;
      },
      set: function(value) {
        if (typeof value !== "number") {
          throw new TypeError("End time must be set to a number.");
        }
        _endTime = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "text", extend$1({}, baseObj, {
      get: function() {
        return _text;
      },
      set: function(value) {
        _text = "" + value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "region", extend$1({}, baseObj, {
      get: function() {
        return _region;
      },
      set: function(value) {
        _region = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "vertical", extend$1({}, baseObj, {
      get: function() {
        return _vertical;
      },
      set: function(value) {
        var setting = findDirectionSetting(value);
        // Have to check for false because the setting an be an empty string.
        if (setting === false) {
          throw new SyntaxError("An invalid or illegal string was specified.");
        }
        _vertical = setting;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "snapToLines", extend$1({}, baseObj, {
      get: function() {
        return _snapToLines;
      },
      set: function(value) {
        _snapToLines = !!value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "line", extend$1({}, baseObj, {
      get: function() {
        return _line;
      },
      set: function(value) {
        if (typeof value !== "number" && value !== autoKeyword) {
          throw new SyntaxError("An invalid number or illegal string was specified.");
        }
        _line = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "lineAlign", extend$1({}, baseObj, {
      get: function() {
        return _lineAlign;
      },
      set: function(value) {
        var setting = findAlignSetting(value);
        if (!setting) {
          throw new SyntaxError("An invalid or illegal string was specified.");
        }
        _lineAlign = setting;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "position", extend$1({}, baseObj, {
      get: function() {
        return _position;
      },
      set: function(value) {
        if (value < 0 || value > 100) {
          throw new Error("Position must be between 0 and 100.");
        }
        _position = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "positionAlign", extend$1({}, baseObj, {
      get: function() {
        return _positionAlign;
      },
      set: function(value) {
        var setting = findAlignSetting(value);
        if (!setting) {
          throw new SyntaxError("An invalid or illegal string was specified.");
        }
        _positionAlign = setting;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "size", extend$1({}, baseObj, {
      get: function() {
        return _size;
      },
      set: function(value) {
        if (value < 0 || value > 100) {
          throw new Error("Size must be between 0 and 100.");
        }
        _size = value;
        this.hasBeenReset = true;
      }
    }));

  Object.defineProperty(cue,
    "align", extend$1({}, baseObj, {
      get: function() {
        return _align;
      },
      set: function(value) {
        var setting = findAlignSetting(value);
        if (!setting) {
          throw new SyntaxError("An invalid or illegal string was specified.");
        }
        _align = setting;
        this.hasBeenReset = true;
      }
    }));

  /**
   * Other <track> spec defined properties
   */

  // http://www.whatwg.org/specs/web-apps/current-work/multipage/the-video-element.html#text-track-cue-display-state
  cue.displayState = undefined;

  if (isIE8) {
    return cue;
  }
}

/**
 * VTTCue methods
 */

VTTCue.prototype.getCueAsHTML = function() {
  // Assume WebVTT.convertCueToDOMTree is on the global.
  return WebVTT.convertCueToDOMTree(window, this.text);
};

var vttcue = VTTCue;

/**
 * Copyright 2013 vtt.js Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

var scrollSetting = {
  "": true,
  "up": true
};

function findScrollSetting(value) {
  if (typeof value !== "string") {
    return false;
  }
  var scroll = scrollSetting[value.toLowerCase()];
  return scroll ? value.toLowerCase() : false;
}

function isValidPercentValue(value) {
  return typeof value === "number" && (value >= 0 && value <= 100);
}

// VTTRegion shim http://dev.w3.org/html5/webvtt/#vttregion-interface
function VTTRegion() {
  var _width = 100;
  var _lines = 3;
  var _regionAnchorX = 0;
  var _regionAnchorY = 100;
  var _viewportAnchorX = 0;
  var _viewportAnchorY = 100;
  var _scroll = "";

  Object.defineProperties(this, {
    "width": {
      enumerable: true,
      get: function() {
        return _width;
      },
      set: function(value) {
        if (!isValidPercentValue(value)) {
          throw new Error("Width must be between 0 and 100.");
        }
        _width = value;
      }
    },
    "lines": {
      enumerable: true,
      get: function() {
        return _lines;
      },
      set: function(value) {
        if (typeof value !== "number") {
          throw new TypeError("Lines must be set to a number.");
        }
        _lines = value;
      }
    },
    "regionAnchorY": {
      enumerable: true,
      get: function() {
        return _regionAnchorY;
      },
      set: function(value) {
        if (!isValidPercentValue(value)) {
          throw new Error("RegionAnchorX must be between 0 and 100.");
        }
        _regionAnchorY = value;
      }
    },
    "regionAnchorX": {
      enumerable: true,
      get: function() {
        return _regionAnchorX;
      },
      set: function(value) {
        if(!isValidPercentValue(value)) {
          throw new Error("RegionAnchorY must be between 0 and 100.");
        }
        _regionAnchorX = value;
      }
    },
    "viewportAnchorY": {
      enumerable: true,
      get: function() {
        return _viewportAnchorY;
      },
      set: function(value) {
        if (!isValidPercentValue(value)) {
          throw new Error("ViewportAnchorY must be between 0 and 100.");
        }
        _viewportAnchorY = value;
      }
    },
    "viewportAnchorX": {
      enumerable: true,
      get: function() {
        return _viewportAnchorX;
      },
      set: function(value) {
        if (!isValidPercentValue(value)) {
          throw new Error("ViewportAnchorX must be between 0 and 100.");
        }
        _viewportAnchorX = value;
      }
    },
    "scroll": {
      enumerable: true,
      get: function() {
        return _scroll;
      },
      set: function(value) {
        var setting = findScrollSetting(value);
        // Have to check for false as an empty string is a legal value.
        if (setting === false) {
          throw new SyntaxError("An invalid or illegal string was specified.");
        }
        _scroll = setting;
      }
    }
  });
}

var vttregion = VTTRegion;

var browserIndex = createCommonjsModule(function (module) {
/**
 * Copyright 2013 vtt.js Contributors
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

// Default exports for Node. Export the extended versions of VTTCue and
// VTTRegion in Node since we likely want the capability to convert back and
// forth between JSON. If we don't then it's not that big of a deal since we're
// off browser.



var vttjs = module.exports = {
  WebVTT: vtt$1,
  VTTCue: vttcue,
  VTTRegion: vttregion
};

window_1.vttjs = vttjs;
window_1.WebVTT = vttjs.WebVTT;

var cueShim = vttjs.VTTCue;
var regionShim = vttjs.VTTRegion;
var nativeVTTCue = window_1.VTTCue;
var nativeVTTRegion = window_1.VTTRegion;

vttjs.shim = function() {
  window_1.VTTCue = cueShim;
  window_1.VTTRegion = regionShim;
};

vttjs.restore = function() {
  window_1.VTTCue = nativeVTTCue;
  window_1.VTTRegion = nativeVTTRegion;
};

if (!window_1.VTTCue) {
  vttjs.shim();
}
});

/**
 * @file tech.js
 */

/**
 * An Object containing a structure like: `{src: 'url', type: 'mimetype'}` or string
 * that just contains the src url alone.
 * * `var SourceObject = {src: 'http://ex.com/video.mp4', type: 'video/mp4'};`
   * `var SourceString = 'http://example.com/some-video.mp4';`
 *
 * @typedef {Object|string} Tech~SourceObject
 *
 * @property {string} src
 *           The url to the source
 *
 * @property {string} type
 *           The mime type of the source
 */

/**
 * A function used by {@link Tech} to create a new {@link TextTrack}.
 *
 * @private
 *
 * @param {Tech} self
 *        An instance of the Tech class.
 *
 * @param {string} kind
 *        `TextTrack` kind (subtitles, captions, descriptions, chapters, or metadata)
 *
 * @param {string} [label]
 *        Label to identify the text track
 *
 * @param {string} [language]
 *        Two letter language abbreviation
 *
 * @param {Object} [options={}]
 *        An object with additional text track options
 *
 * @return {TextTrack}
 *          The text track that was created.
 */
function createTrackHelper(self, kind, label, language) {
  var options = arguments.length > 4 && arguments[4] !== undefined ? arguments[4] : {};

  var tracks = self.textTracks();

  options.kind = kind;

  if (label) {
    options.label = label;
  }
  if (language) {
    options.language = language;
  }
  options.tech = self;

  var track = new ALL.text.TrackClass(options);

  tracks.addTrack(track);

  return track;
}

/**
 * This is the base class for media playback technology controllers, such as
 * {@link Flash} and {@link HTML5}
 *
 * @extends Component
 */

var Tech = function (_Component) {
  inherits(Tech, _Component);

  /**
   * Create an instance of this Tech.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} ready
   *        Callback function to call when the `HTML5` Tech is ready.
   */
  function Tech() {
    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    var ready = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : function () {};
    classCallCheck(this, Tech);

    // we don't want the tech to report user activity automatically.
    // This is done manually in addControlsListeners
    options.reportTouchActivity = false;

    // keep track of whether the current source has played at all to
    // implement a very limited played()
    var _this = possibleConstructorReturn(this, _Component.call(this, null, options, ready));

    _this.hasStarted_ = false;
    _this.on('playing', function () {
      this.hasStarted_ = true;
    });
    _this.on('loadstart', function () {
      this.hasStarted_ = false;
    });

    ALL.names.forEach(function (name) {
      var props = ALL[name];

      if (options && options[props.getterName]) {
        _this[props.privateName] = options[props.getterName];
      }
    });

    // Manually track progress in cases where the browser/flash player doesn't report it.
    if (!_this.featuresProgressEvents) {
      _this.manualProgressOn();
    }

    // Manually track timeupdates in cases where the browser/flash player doesn't report it.
    if (!_this.featuresTimeupdateEvents) {
      _this.manualTimeUpdatesOn();
    }

    ['Text', 'Audio', 'Video'].forEach(function (track) {
      if (options['native' + track + 'Tracks'] === false) {
        _this['featuresNative' + track + 'Tracks'] = false;
      }
    });

    if (options.nativeCaptions === false || options.nativeTextTracks === false) {
      _this.featuresNativeTextTracks = false;
    } else if (options.nativeCaptions === true || options.nativeTextTracks === true) {
      _this.featuresNativeTextTracks = true;
    }

    if (!_this.featuresNativeTextTracks) {
      _this.emulateTextTracks();
    }

    _this.autoRemoteTextTracks_ = new ALL.text.ListClass();

    _this.initTrackListeners();

    // Turn on component tap events only if not using native controls
    if (!options.nativeControlsForTouch) {
      _this.emitTapEvents();
    }

    if (_this.constructor) {
      _this.name_ = _this.constructor.name || 'Unknown Tech';
    }
    return _this;
  }

  /**
   * A special function to trigger source set in a way that will allow player
   * to re-trigger if the player or tech are not ready yet.
   *
   * @fires Tech#sourceset
   * @param {string} src The source string at the time of the source changing.
   */


  Tech.prototype.triggerSourceset = function triggerSourceset(src) {
    var _this2 = this;

    if (!this.isReady_) {
      // on initial ready we have to trigger source set
      // 1ms after ready so that player can watch for it.
      this.one('ready', function () {
        return _this2.setTimeout(function () {
          return _this2.triggerSourceset(src);
        }, 1);
      });
    }

    /**
     * Fired when the source is set on the tech causing the media element
     * to reload.
     *
     * @see {@link Player#event:sourceset}
     * @event Tech#sourceset
     * @type {EventTarget~Event}
     */
    this.trigger({
      src: src,
      type: 'sourceset'
    });
  };

  /* Fallbacks for unsupported event types
  ================================================================================ */

  /**
   * Polyfill the `progress` event for browsers that don't support it natively.
   *
   * @see {@link Tech#trackProgress}
   */


  Tech.prototype.manualProgressOn = function manualProgressOn() {
    this.on('durationchange', this.onDurationChange);

    this.manualProgress = true;

    // Trigger progress watching when a source begins loading
    this.one('ready', this.trackProgress);
  };

  /**
   * Turn off the polyfill for `progress` events that was created in
   * {@link Tech#manualProgressOn}
   */


  Tech.prototype.manualProgressOff = function manualProgressOff() {
    this.manualProgress = false;
    this.stopTrackingProgress();

    this.off('durationchange', this.onDurationChange);
  };

  /**
   * This is used to trigger a `progress` event when the buffered percent changes. It
   * sets an interval function that will be called every 500 milliseconds to check if the
   * buffer end percent has changed.
   *
   * > This function is called by {@link Tech#manualProgressOn}
   *
   * @param {EventTarget~Event} event
   *        The `ready` event that caused this to run.
   *
   * @listens Tech#ready
   * @fires Tech#progress
   */


  Tech.prototype.trackProgress = function trackProgress(event) {
    this.stopTrackingProgress();
    this.progressInterval = this.setInterval(bind(this, function () {
      // Don't trigger unless buffered amount is greater than last time

      var numBufferedPercent = this.bufferedPercent();

      if (this.bufferedPercent_ !== numBufferedPercent) {
        /**
         * See {@link Player#progress}
         *
         * @event Tech#progress
         * @type {EventTarget~Event}
         */
        this.trigger('progress');
      }

      this.bufferedPercent_ = numBufferedPercent;

      if (numBufferedPercent === 1) {
        this.stopTrackingProgress();
      }
    }), 500);
  };

  /**
   * Update our internal duration on a `durationchange` event by calling
   * {@link Tech#duration}.
   *
   * @param {EventTarget~Event} event
   *        The `durationchange` event that caused this to run.
   *
   * @listens Tech#durationchange
   */


  Tech.prototype.onDurationChange = function onDurationChange(event) {
    this.duration_ = this.duration();
  };

  /**
   * Get and create a `TimeRange` object for buffering.
   *
   * @return {TimeRange}
   *         The time range object that was created.
   */


  Tech.prototype.buffered = function buffered() {
    return createTimeRanges(0, 0);
  };

  /**
   * Get the percentage of the current video that is currently buffered.
   *
   * @return {number}
   *         A number from 0 to 1 that represents the decimal percentage of the
   *         video that is buffered.
   *
   */


  Tech.prototype.bufferedPercent = function bufferedPercent$$1() {
    return bufferedPercent(this.buffered(), this.duration_);
  };

  /**
   * Turn off the polyfill for `progress` events that was created in
   * {@link Tech#manualProgressOn}
   * Stop manually tracking progress events by clearing the interval that was set in
   * {@link Tech#trackProgress}.
   */


  Tech.prototype.stopTrackingProgress = function stopTrackingProgress() {
    this.clearInterval(this.progressInterval);
  };

  /**
   * Polyfill the `timeupdate` event for browsers that don't support it.
   *
   * @see {@link Tech#trackCurrentTime}
   */


  Tech.prototype.manualTimeUpdatesOn = function manualTimeUpdatesOn() {
    this.manualTimeUpdates = true;

    this.on('play', this.trackCurrentTime);
    this.on('pause', this.stopTrackingCurrentTime);
  };

  /**
   * Turn off the polyfill for `timeupdate` events that was created in
   * {@link Tech#manualTimeUpdatesOn}
   */


  Tech.prototype.manualTimeUpdatesOff = function manualTimeUpdatesOff() {
    this.manualTimeUpdates = false;
    this.stopTrackingCurrentTime();
    this.off('play', this.trackCurrentTime);
    this.off('pause', this.stopTrackingCurrentTime);
  };

  /**
   * Sets up an interval function to track current time and trigger `timeupdate` every
   * 250 milliseconds.
   *
   * @listens Tech#play
   * @triggers Tech#timeupdate
   */


  Tech.prototype.trackCurrentTime = function trackCurrentTime() {
    if (this.currentTimeInterval) {
      this.stopTrackingCurrentTime();
    }
    this.currentTimeInterval = this.setInterval(function () {
      /**
       * Triggered at an interval of 250ms to indicated that time is passing in the video.
       *
       * @event Tech#timeupdate
       * @type {EventTarget~Event}
       */
      this.trigger({ type: 'timeupdate', target: this, manuallyTriggered: true });

      // 42 = 24 fps // 250 is what Webkit uses // FF uses 15
    }, 250);
  };

  /**
   * Stop the interval function created in {@link Tech#trackCurrentTime} so that the
   * `timeupdate` event is no longer triggered.
   *
   * @listens {Tech#pause}
   */


  Tech.prototype.stopTrackingCurrentTime = function stopTrackingCurrentTime() {
    this.clearInterval(this.currentTimeInterval);

    // #1002 - if the video ends right before the next timeupdate would happen,
    // the progress bar won't make it all the way to the end
    this.trigger({ type: 'timeupdate', target: this, manuallyTriggered: true });
  };

  /**
   * Turn off all event polyfills, clear the `Tech`s {@link AudioTrackList},
   * {@link VideoTrackList}, and {@link TextTrackList}, and dispose of this Tech.
   *
   * @fires Component#dispose
   */


  Tech.prototype.dispose = function dispose() {

    // clear out all tracks because we can't reuse them between techs
    this.clearTracks(NORMAL.names);

    // Turn off any manual progress or timeupdate tracking
    if (this.manualProgress) {
      this.manualProgressOff();
    }

    if (this.manualTimeUpdates) {
      this.manualTimeUpdatesOff();
    }

    _Component.prototype.dispose.call(this);
  };

  /**
   * Clear out a single `TrackList` or an array of `TrackLists` given their names.
   *
   * > Note: Techs without source handlers should call this between sources for `video`
   *         & `audio` tracks. You don't want to use them between tracks!
   *
   * @param {string[]|string} types
   *        TrackList names to clear, valid names are `video`, `audio`, and
   *        `text`.
   */


  Tech.prototype.clearTracks = function clearTracks(types) {
    var _this3 = this;

    types = [].concat(types);
    // clear out all tracks because we can't reuse them between techs
    types.forEach(function (type) {
      var list = _this3[type + 'Tracks']() || [];
      var i = list.length;

      while (i--) {
        var track = list[i];

        if (type === 'text') {
          _this3.removeRemoteTextTrack(track);
        }
        list.removeTrack(track);
      }
    });
  };

  /**
   * Remove any TextTracks added via addRemoteTextTrack that are
   * flagged for automatic garbage collection
   */


  Tech.prototype.cleanupAutoTextTracks = function cleanupAutoTextTracks() {
    var list = this.autoRemoteTextTracks_ || [];
    var i = list.length;

    while (i--) {
      var track = list[i];

      this.removeRemoteTextTrack(track);
    }
  };

  /**
   * Reset the tech, which will removes all sources and reset the internal readyState.
   *
   * @abstract
   */


  Tech.prototype.reset = function reset() {};

  /**
   * Get or set an error on the Tech.
   *
   * @param {MediaError} [err]
   *        Error to set on the Tech
   *
   * @return {MediaError|null}
   *         The current error object on the tech, or null if there isn't one.
   */


  Tech.prototype.error = function error(err) {
    if (err !== undefined) {
      this.error_ = new MediaError(err);
      this.trigger('error');
    }
    return this.error_;
  };

  /**
   * Returns the `TimeRange`s that have been played through for the current source.
   *
   * > NOTE: This implementation is incomplete. It does not track the played `TimeRange`.
   *         It only checks wether the source has played at all or not.
   *
   * @return {TimeRange}
   *         - A single time range if this video has played
   *         - An empty set of ranges if not.
   */


  Tech.prototype.played = function played() {
    if (this.hasStarted_) {
      return createTimeRanges(0, 0);
    }
    return createTimeRanges();
  };

  /**
   * Causes a manual time update to occur if {@link Tech#manualTimeUpdatesOn} was
   * previously called.
   *
   * @fires Tech#timeupdate
   */


  Tech.prototype.setCurrentTime = function setCurrentTime() {
    // improve the accuracy of manual timeupdates
    if (this.manualTimeUpdates) {
      /**
       * A manual `timeupdate` event.
       *
       * @event Tech#timeupdate
       * @type {EventTarget~Event}
       */
      this.trigger({ type: 'timeupdate', target: this, manuallyTriggered: true });
    }
  };

  /**
   * Turn on listeners for {@link VideoTrackList}, {@link {AudioTrackList}, and
   * {@link TextTrackList} events.
   *
   * This adds {@link EventTarget~EventListeners} for `addtrack`, and  `removetrack`.
   *
   * @fires Tech#audiotrackchange
   * @fires Tech#videotrackchange
   * @fires Tech#texttrackchange
   */


  Tech.prototype.initTrackListeners = function initTrackListeners() {
    var _this4 = this;

    /**
     * Triggered when tracks are added or removed on the Tech {@link AudioTrackList}
     *
     * @event Tech#audiotrackchange
     * @type {EventTarget~Event}
     */

    /**
     * Triggered when tracks are added or removed on the Tech {@link VideoTrackList}
     *
     * @event Tech#videotrackchange
     * @type {EventTarget~Event}
     */

    /**
     * Triggered when tracks are added or removed on the Tech {@link TextTrackList}
     *
     * @event Tech#texttrackchange
     * @type {EventTarget~Event}
     */
    NORMAL.names.forEach(function (name) {
      var props = NORMAL[name];
      var trackListChanges = function trackListChanges() {
        _this4.trigger(name + 'trackchange');
      };

      var tracks = _this4[props.getterName]();

      tracks.addEventListener('removetrack', trackListChanges);
      tracks.addEventListener('addtrack', trackListChanges);

      _this4.on('dispose', function () {
        tracks.removeEventListener('removetrack', trackListChanges);
        tracks.removeEventListener('addtrack', trackListChanges);
      });
    });
  };

  /**
   * Emulate TextTracks using vtt.js if necessary
   *
   * @fires Tech#vttjsloaded
   * @fires Tech#vttjserror
   */


  Tech.prototype.addWebVttScript_ = function addWebVttScript_() {
    var _this5 = this;

    if (window_1.WebVTT) {
      return;
    }

    // Initially, Tech.el_ is a child of a dummy-div wait until the Component system
    // signals that the Tech is ready at which point Tech.el_ is part of the DOM
    // before inserting the WebVTT script
    if (document_1.body.contains(this.el())) {

      // load via require if available and vtt.js script location was not passed in
      // as an option. novtt builds will turn the above require call into an empty object
      // which will cause this if check to always fail.
      if (!this.options_['vtt.js'] && isPlain(browserIndex) && Object.keys(browserIndex).length > 0) {
        this.trigger('vttjsloaded');
        return;
      }

      // load vtt.js via the script location option or the cdn of no location was
      // passed in
      var script = document_1.createElement('script');

      script.src = this.options_['vtt.js'] || 'https://vjs.zencdn.net/vttjs/0.12.4/vtt.min.js';
      script.onload = function () {
        /**
         * Fired when vtt.js is loaded.
         *
         * @event Tech#vttjsloaded
         * @type {EventTarget~Event}
         */
        _this5.trigger('vttjsloaded');
      };
      script.onerror = function () {
        /**
         * Fired when vtt.js was not loaded due to an error
         *
         * @event Tech#vttjsloaded
         * @type {EventTarget~Event}
         */
        _this5.trigger('vttjserror');
      };
      this.on('dispose', function () {
        script.onload = null;
        script.onerror = null;
      });
      // but have not loaded yet and we set it to true before the inject so that
      // we don't overwrite the injected window.WebVTT if it loads right away
      window_1.WebVTT = true;
      this.el().parentNode.appendChild(script);
    } else {
      this.ready(this.addWebVttScript_);
    }
  };

  /**
   * Emulate texttracks
   *
   */


  Tech.prototype.emulateTextTracks = function emulateTextTracks() {
    var _this6 = this;

    var tracks = this.textTracks();
    var remoteTracks = this.remoteTextTracks();
    var handleAddTrack = function handleAddTrack(e) {
      return tracks.addTrack(e.track);
    };
    var handleRemoveTrack = function handleRemoveTrack(e) {
      return tracks.removeTrack(e.track);
    };

    remoteTracks.on('addtrack', handleAddTrack);
    remoteTracks.on('removetrack', handleRemoveTrack);

    this.addWebVttScript_();

    var updateDisplay = function updateDisplay() {
      return _this6.trigger('texttrackchange');
    };

    var textTracksChanges = function textTracksChanges() {
      updateDisplay();

      for (var i = 0; i < tracks.length; i++) {
        var track = tracks[i];

        track.removeEventListener('cuechange', updateDisplay);
        if (track.mode === 'showing') {
          track.addEventListener('cuechange', updateDisplay);
        }
      }
    };

    textTracksChanges();
    tracks.addEventListener('change', textTracksChanges);
    tracks.addEventListener('addtrack', textTracksChanges);
    tracks.addEventListener('removetrack', textTracksChanges);

    this.on('dispose', function () {
      remoteTracks.off('addtrack', handleAddTrack);
      remoteTracks.off('removetrack', handleRemoveTrack);
      tracks.removeEventListener('change', textTracksChanges);
      tracks.removeEventListener('addtrack', textTracksChanges);
      tracks.removeEventListener('removetrack', textTracksChanges);

      for (var i = 0; i < tracks.length; i++) {
        var track = tracks[i];

        track.removeEventListener('cuechange', updateDisplay);
      }
    });
  };

  /**
   * Create and returns a remote {@link TextTrack} object.
   *
   * @param {string} kind
   *        `TextTrack` kind (subtitles, captions, descriptions, chapters, or metadata)
   *
   * @param {string} [label]
   *        Label to identify the text track
   *
   * @param {string} [language]
   *        Two letter language abbreviation
   *
   * @return {TextTrack}
   *         The TextTrack that gets created.
   */


  Tech.prototype.addTextTrack = function addTextTrack(kind, label, language) {
    if (!kind) {
      throw new Error('TextTrack kind is required but was not provided');
    }

    return createTrackHelper(this, kind, label, language);
  };

  /**
   * Create an emulated TextTrack for use by addRemoteTextTrack
   *
   * This is intended to be overridden by classes that inherit from
   * Tech in order to create native or custom TextTracks.
   *
   * @param {Object} options
   *        The object should contain the options to initialize the TextTrack with.
   *
   * @param {string} [options.kind]
   *        `TextTrack` kind (subtitles, captions, descriptions, chapters, or metadata).
   *
   * @param {string} [options.label].
   *        Label to identify the text track
   *
   * @param {string} [options.language]
   *        Two letter language abbreviation.
   *
   * @return {HTMLTrackElement}
   *         The track element that gets created.
   */


  Tech.prototype.createRemoteTextTrack = function createRemoteTextTrack(options) {
    var track = mergeOptions(options, {
      tech: this
    });

    return new REMOTE.remoteTextEl.TrackClass(track);
  };

  /**
   * Creates a remote text track object and returns an html track element.
   *
   * > Note: This can be an emulated {@link HTMLTrackElement} or a native one.
   *
   * @param {Object} options
   *        See {@link Tech#createRemoteTextTrack} for more detailed properties.
   *
   * @param {boolean} [manualCleanup=true]
   *        - When false: the TextTrack will be automatically removed from the video
   *          element whenever the source changes
   *        - When True: The TextTrack will have to be cleaned up manually
   *
   * @return {HTMLTrackElement}
   *         An Html Track Element.
   *
   * @deprecated The default functionality for this function will be equivalent
   *             to "manualCleanup=false" in the future. The manualCleanup parameter will
   *             also be removed.
   */


  Tech.prototype.addRemoteTextTrack = function addRemoteTextTrack() {
    var _this7 = this;

    var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
    var manualCleanup = arguments[1];

    var htmlTrackElement = this.createRemoteTextTrack(options);

    if (manualCleanup !== true && manualCleanup !== false) {
      // deprecation warning
      log$1.warn('Calling addRemoteTextTrack without explicitly setting the "manualCleanup" parameter to `true` is deprecated and default to `false` in future version of video.js');
      manualCleanup = true;
    }

    // store HTMLTrackElement and TextTrack to remote list
    this.remoteTextTrackEls().addTrackElement_(htmlTrackElement);
    this.remoteTextTracks().addTrack(htmlTrackElement.track);

    if (manualCleanup !== true) {
      // create the TextTrackList if it doesn't exist
      this.ready(function () {
        return _this7.autoRemoteTextTracks_.addTrack(htmlTrackElement.track);
      });
    }

    return htmlTrackElement;
  };

  /**
   * Remove a remote text track from the remote `TextTrackList`.
   *
   * @param {TextTrack} track
   *        `TextTrack` to remove from the `TextTrackList`
   */


  Tech.prototype.removeRemoteTextTrack = function removeRemoteTextTrack(track) {
    var trackElement = this.remoteTextTrackEls().getTrackElementByTrack_(track);

    // remove HTMLTrackElement and TextTrack from remote list
    this.remoteTextTrackEls().removeTrackElement_(trackElement);
    this.remoteTextTracks().removeTrack(track);
    this.autoRemoteTextTracks_.removeTrack(track);
  };

  /**
   * Gets available media playback quality metrics as specified by the W3C's Media
   * Playback Quality API.
   *
   * @see [Spec]{@link https://wicg.github.io/media-playback-quality}
   *
   * @return {Object}
   *         An object with supported media playback quality metrics
   *
   * @abstract
   */


  Tech.prototype.getVideoPlaybackQuality = function getVideoPlaybackQuality() {
    return {};
  };

  /**
   * A method to set a poster from a `Tech`.
   *
   * @abstract
   */


  Tech.prototype.setPoster = function setPoster() {};

  /**
   * A method to check for the presence of the 'playsinine' <video> attribute.
   *
   * @abstract
   */


  Tech.prototype.playsinline = function playsinline() {};

  /**
   * A method to set or unset the 'playsinine' <video> attribute.
   *
   * @abstract
   */


  Tech.prototype.setPlaysinline = function setPlaysinline() {};

  /*
   * Check if the tech can support the given mime-type.
   *
   * The base tech does not support any type, but source handlers might
   * overwrite this.
   *
   * @param  {string} type
   *         The mimetype to check for support
   *
   * @return {string}
   *         'probably', 'maybe', or empty string
   *
   * @see [Spec]{@link https://developer.mozilla.org/en-US/docs/Web/API/HTMLMediaElement/canPlayType}
   *
   * @abstract
   */


  Tech.prototype.canPlayType = function canPlayType() {
    return '';
  };

  /**
   * Check if the type is supported by this tech.
   *
   * The base tech does not support any type, but source handlers might
   * overwrite this.
   *
   * @param {string} type
   *        The media type to check
   * @return {string} Returns the native video element's response
   */


  Tech.canPlayType = function canPlayType() {
    return '';
  };

  /**
   * Check if the tech can support the given source
   * @param {Object} srcObj
   *        The source object
   * @param {Object} options
   *        The options passed to the tech
   * @return {string} 'probably', 'maybe', or '' (empty string)
   */


  Tech.canPlaySource = function canPlaySource(srcObj, options) {
    return Tech.canPlayType(srcObj.type);
  };

  /*
   * Return whether the argument is a Tech or not.
   * Can be passed either a Class like `Html5` or a instance like `player.tech_`
   *
   * @param {Object} component
   *        The item to check
   *
   * @return {boolean}
   *         Whether it is a tech or not
   *         - True if it is a tech
   *         - False if it is not
   */


  Tech.isTech = function isTech(component) {
    return component.prototype instanceof Tech || component instanceof Tech || component === Tech;
  };

  /**
   * Registers a `Tech` into a shared list for videojs.
   *
   * @param {string} name
   *        Name of the `Tech` to register.
   *
   * @param {Object} tech
   *        The `Tech` class to register.
   */


  Tech.registerTech = function registerTech(name, tech) {
    if (!Tech.techs_) {
      Tech.techs_ = {};
    }

    if (!Tech.isTech(tech)) {
      throw new Error('Tech ' + name + ' must be a Tech');
    }

    if (!Tech.canPlayType) {
      throw new Error('Techs must have a static canPlayType method on them');
    }
    if (!Tech.canPlaySource) {
      throw new Error('Techs must have a static canPlaySource method on them');
    }

    name = toTitleCase(name);

    Tech.techs_[name] = tech;
    if (name !== 'Tech') {
      // camel case the techName for use in techOrder
      Tech.defaultTechOrder_.push(name);
    }
    return tech;
  };

  /**
   * Get a `Tech` from the shared list by name.
   *
   * @param {string} name
   *        `camelCase` or `TitleCase` name of the Tech to get
   *
   * @return {Tech|undefined}
   *         The `Tech` or undefined if there was no tech with the name requsted.
   */


  Tech.getTech = function getTech(name) {
    if (!name) {
      return;
    }

    name = toTitleCase(name);

    if (Tech.techs_ && Tech.techs_[name]) {
      return Tech.techs_[name];
    }

    if (window_1 && window_1.videojs && window_1.videojs[name]) {
      log$1.warn('The ' + name + ' tech was added to the videojs object when it should be registered using videojs.registerTech(name, tech)');
      return window_1.videojs[name];
    }
  };

  return Tech;
}(Component);

/**
 * Get the {@link VideoTrackList}
 *
 * @returns {VideoTrackList}
 * @method Tech.prototype.videoTracks
 */

/**
 * Get the {@link AudioTrackList}
 *
 * @returns {AudioTrackList}
 * @method Tech.prototype.audioTracks
 */

/**
 * Get the {@link TextTrackList}
 *
 * @returns {TextTrackList}
 * @method Tech.prototype.textTracks
 */

/**
 * Get the remote element {@link TextTrackList}
 *
 * @returns {TextTrackList}
 * @method Tech.prototype.remoteTextTracks
 */

/**
 * Get the remote element {@link HtmlTrackElementList}
 *
 * @returns {HtmlTrackElementList}
 * @method Tech.prototype.remoteTextTrackEls
 */

ALL.names.forEach(function (name) {
  var props = ALL[name];

  Tech.prototype[props.getterName] = function () {
    this[props.privateName] = this[props.privateName] || new props.ListClass();
    return this[props.privateName];
  };
});

/**
 * List of associated text tracks
 *
 * @type {TextTrackList}
 * @private
 * @property Tech#textTracks_
 */

/**
 * List of associated audio tracks.
 *
 * @type {AudioTrackList}
 * @private
 * @property Tech#audioTracks_
 */

/**
 * List of associated video tracks.
 *
 * @type {VideoTrackList}
 * @private
 * @property Tech#videoTracks_
 */

/**
 * Boolean indicating wether the `Tech` supports volume control.
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresVolumeControl = true;

/**
 * Boolean indicating whether the `Tech` supports muting volume.
 *
 * @type {bolean}
 * @default
 */
Tech.prototype.featuresMuteControl = true;

/**
 * Boolean indicating whether the `Tech` supports fullscreen resize control.
 * Resizing plugins using request fullscreen reloads the plugin
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresFullscreenResize = false;

/**
 * Boolean indicating wether the `Tech` supports changing the speed at which the video
 * plays. Examples:
 *   - Set player to play 2x (twice) as fast
 *   - Set player to play 0.5x (half) as fast
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresPlaybackRate = false;

/**
 * Boolean indicating wether the `Tech` supports the `progress` event. This is currently
 * not triggered by video-js-swf. This will be used to determine if
 * {@link Tech#manualProgressOn} should be called.
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresProgressEvents = false;

/**
 * Boolean indicating wether the `Tech` supports the `sourceset` event.
 *
 * A tech should set this to `true` and then use {@link Tech#triggerSourceset}
 * to trigger a {@link Tech#event:sourceset} at the earliest time after getting
 * a new source.
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresSourceset = false;

/**
 * Boolean indicating wether the `Tech` supports the `timeupdate` event. This is currently
 * not triggered by video-js-swf. This will be used to determine if
 * {@link Tech#manualTimeUpdates} should be called.
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresTimeupdateEvents = false;

/**
 * Boolean indicating wether the `Tech` supports the native `TextTrack`s.
 * This will help us integrate with native `TextTrack`s if the browser supports them.
 *
 * @type {boolean}
 * @default
 */
Tech.prototype.featuresNativeTextTracks = false;

/**
 * A functional mixin for techs that want to use the Source Handler pattern.
 * Source handlers are scripts for handling specific formats.
 * The source handler pattern is used for adaptive formats (HLS, DASH) that
 * manually load video data and feed it into a Source Buffer (Media Source Extensions)
 * Example: `Tech.withSourceHandlers.call(MyTech);`
 *
 * @param {Tech} _Tech
 *        The tech to add source handler functions to.
 *
 * @mixes Tech~SourceHandlerAdditions
 */
Tech.withSourceHandlers = function (_Tech) {

  /**
   * Register a source handler
   *
   * @param {Function} handler
   *        The source handler class
   *
   * @param {number} [index]
   *        Register it at the following index
   */
  _Tech.registerSourceHandler = function (handler, index) {
    var handlers = _Tech.sourceHandlers;

    if (!handlers) {
      handlers = _Tech.sourceHandlers = [];
    }

    if (index === undefined) {
      // add to the end of the list
      index = handlers.length;
    }

    handlers.splice(index, 0, handler);
  };

  /**
   * Check if the tech can support the given type. Also checks the
   * Techs sourceHandlers.
   *
   * @param {string} type
   *         The mimetype to check.
   *
   * @return {string}
   *         'probably', 'maybe', or '' (empty string)
   */
  _Tech.canPlayType = function (type) {
    var handlers = _Tech.sourceHandlers || [];
    var can = void 0;

    for (var i = 0; i < handlers.length; i++) {
      can = handlers[i].canPlayType(type);

      if (can) {
        return can;
      }
    }

    return '';
  };

  /**
   * Returns the first source handler that supports the source.
   *
   * TODO: Answer question: should 'probably' be prioritized over 'maybe'
   *
   * @param {Tech~SourceObject} source
   *        The source object
   *
   * @param {Object} options
   *        The options passed to the tech
   *
   * @return {SourceHandler|null}
   *          The first source handler that supports the source or null if
   *          no SourceHandler supports the source
   */
  _Tech.selectSourceHandler = function (source, options) {
    var handlers = _Tech.sourceHandlers || [];
    var can = void 0;

    for (var i = 0; i < handlers.length; i++) {
      can = handlers[i].canHandleSource(source, options);

      if (can) {
        return handlers[i];
      }
    }

    return null;
  };

  /**
   * Check if the tech can support the given source.
   *
   * @param {Tech~SourceObject} srcObj
   *        The source object
   *
   * @param {Object} options
   *        The options passed to the tech
   *
   * @return {string}
   *         'probably', 'maybe', or '' (empty string)
   */
  _Tech.canPlaySource = function (srcObj, options) {
    var sh = _Tech.selectSourceHandler(srcObj, options);

    if (sh) {
      return sh.canHandleSource(srcObj, options);
    }

    return '';
  };

  /**
   * When using a source handler, prefer its implementation of
   * any function normally provided by the tech.
   */
  var deferrable = ['seekable', 'seeking', 'duration'];

  /**
   * A wrapper around {@link Tech#seekable} that will call a `SourceHandler`s seekable
   * function if it exists, with a fallback to the Techs seekable function.
   *
   * @method _Tech.seekable
   */

  /**
   * A wrapper around {@link Tech#duration} that will call a `SourceHandler`s duration
   * function if it exists, otherwise it will fallback to the techs duration function.
   *
   * @method _Tech.duration
   */

  deferrable.forEach(function (fnName) {
    var originalFn = this[fnName];

    if (typeof originalFn !== 'function') {
      return;
    }

    this[fnName] = function () {
      if (this.sourceHandler_ && this.sourceHandler_[fnName]) {
        return this.sourceHandler_[fnName].apply(this.sourceHandler_, arguments);
      }
      return originalFn.apply(this, arguments);
    };
  }, _Tech.prototype);

  /**
   * Create a function for setting the source using a source object
   * and source handlers.
   * Should never be called unless a source handler was found.
   *
   * @param {Tech~SourceObject} source
   *        A source object with src and type keys
   */
  _Tech.prototype.setSource = function (source) {
    var sh = _Tech.selectSourceHandler(source, this.options_);

    if (!sh) {
      // Fall back to a native source hander when unsupported sources are
      // deliberately set
      if (_Tech.nativeSourceHandler) {
        sh = _Tech.nativeSourceHandler;
      } else {
        log$1.error('No source hander found for the current source.');
      }
    }

    // Dispose any existing source handler
    this.disposeSourceHandler();
    this.off('dispose', this.disposeSourceHandler);

    if (sh !== _Tech.nativeSourceHandler) {
      this.currentSource_ = source;
    }

    this.sourceHandler_ = sh.handleSource(source, this, this.options_);
    this.on('dispose', this.disposeSourceHandler);
  };

  /**
   * Clean up any existing SourceHandlers and listeners when the Tech is disposed.
   *
   * @listens Tech#dispose
   */
  _Tech.prototype.disposeSourceHandler = function () {
    // if we have a source and get another one
    // then we are loading something new
    // than clear all of our current tracks
    if (this.currentSource_) {
      this.clearTracks(['audio', 'video']);
      this.currentSource_ = null;
    }

    // always clean up auto-text tracks
    this.cleanupAutoTextTracks();

    if (this.sourceHandler_) {

      if (this.sourceHandler_.dispose) {
        this.sourceHandler_.dispose();
      }

      this.sourceHandler_ = null;
    }
  };
};

// The base Tech class needs to be registered as a Component. It is the only
// Tech that can be registered as a Component.
Component.registerComponent('Tech', Tech);
Tech.registerTech('Tech', Tech);

/**
 * A list of techs that should be added to techOrder on Players
 *
 * @private
 */
Tech.defaultTechOrder_ = [];

var middlewares = {};
var middlewareInstances = {};

var TERMINATOR = {};

function use(type, middleware) {
  middlewares[type] = middlewares[type] || [];
  middlewares[type].push(middleware);
}



function setSource(player, src, next) {
  player.setTimeout(function () {
    return setSourceHelper(src, middlewares[src.type], next, player);
  }, 1);
}

function setTech(middleware, tech) {
  middleware.forEach(function (mw) {
    return mw.setTech && mw.setTech(tech);
  });
}

/**
 * Calls a getter on the tech first, through each middleware
 * from right to left to the player.
 */
function get$1(middleware, tech, method) {
  return middleware.reduceRight(middlewareIterator(method), tech[method]());
}

/**
 * Takes the argument given to the player and calls the setter method on each
 * middlware from left to right to the tech.
 */
function set$1(middleware, tech, method, arg) {
  return tech[method](middleware.reduce(middlewareIterator(method), arg));
}

/**
 * Takes the argument given to the player and calls the `call` version of the method
 * on each middleware from left to right.
 * Then, call the passed in method on the tech and return the result unchanged
 * back to the player, through middleware, this time from right to left.
 */
function mediate(middleware, tech, method) {
  var arg = arguments.length > 3 && arguments[3] !== undefined ? arguments[3] : null;

  var callMethod = 'call' + toTitleCase(method);
  var middlewareValue = middleware.reduce(middlewareIterator(callMethod), arg);
  var terminated = middlewareValue === TERMINATOR;
  var returnValue = terminated ? null : tech[method](middlewareValue);

  executeRight(middleware, method, returnValue, terminated);

  return returnValue;
}

var allowedGetters = {
  buffered: 1,
  currentTime: 1,
  duration: 1,
  seekable: 1,
  played: 1,
  paused: 1
};

var allowedSetters = {
  setCurrentTime: 1
};

var allowedMediators = {
  play: 1,
  pause: 1
};

function middlewareIterator(method) {
  return function (value, mw) {
    // if the previous middleware terminated, pass along the termination
    if (value === TERMINATOR) {
      return TERMINATOR;
    }

    if (mw[method]) {
      return mw[method](value);
    }

    return value;
  };
}

function executeRight(mws, method, value, terminated) {
  for (var i = mws.length - 1; i >= 0; i--) {
    var mw = mws[i];

    if (mw[method]) {
      mw[method](terminated, value);
    }
  }
}

function clearCacheForPlayer(player) {
  middlewareInstances[player.id()] = null;
}

/**
 * {
 *  [playerId]: [[mwFactory, mwInstance], ...]
 * }
 */
function getOrCreateFactory(player, mwFactory) {
  var mws = middlewareInstances[player.id()];
  var mw = null;

  if (mws === undefined || mws === null) {
    mw = mwFactory(player);
    middlewareInstances[player.id()] = [[mwFactory, mw]];
    return mw;
  }

  for (var i = 0; i < mws.length; i++) {
    var _mws$i = mws[i],
        mwf = _mws$i[0],
        mwi = _mws$i[1];


    if (mwf !== mwFactory) {
      continue;
    }

    mw = mwi;
  }

  if (mw === null) {
    mw = mwFactory(player);
    mws.push([mwFactory, mw]);
  }

  return mw;
}

function setSourceHelper() {
  var src = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var middleware = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : [];
  var next = arguments[2];
  var player = arguments[3];
  var acc = arguments.length > 4 && arguments[4] !== undefined ? arguments[4] : [];
  var lastRun = arguments.length > 5 && arguments[5] !== undefined ? arguments[5] : false;
  var mwFactory = middleware[0],
      mwrest = middleware.slice(1);

  // if mwFactory is a string, then we're at a fork in the road

  if (typeof mwFactory === 'string') {
    setSourceHelper(src, middlewares[mwFactory], next, player, acc, lastRun);

    // if we have an mwFactory, call it with the player to get the mw,
    // then call the mw's setSource method
  } else if (mwFactory) {
    var mw = getOrCreateFactory(player, mwFactory);

    // if setSource isn't present, implicitly select this middleware
    if (!mw.setSource) {
      acc.push(mw);
      return setSourceHelper(src, mwrest, next, player, acc, lastRun);
    }

    mw.setSource(assign({}, src), function (err, _src) {

      // something happened, try the next middleware on the current level
      // make sure to use the old src
      if (err) {
        return setSourceHelper(src, mwrest, next, player, acc, lastRun);
      }

      // we've succeeded, now we need to go deeper
      acc.push(mw);

      // if it's the same type, continue down the current chain
      // otherwise, we want to go down the new chain
      setSourceHelper(_src, src.type === _src.type ? mwrest : middlewares[_src.type], next, player, acc, lastRun);
    });
  } else if (mwrest.length) {
    setSourceHelper(src, mwrest, next, player, acc, lastRun);
  } else if (lastRun) {
    next(src, acc);
  } else {
    setSourceHelper(src, middlewares['*'], next, player, acc, true);
  }
}

/**
 * Mimetypes
 *
 * @see http://hul.harvard.edu/ois/////systems/wax/wax-public-help/mimetypes.htm
 * @typedef Mimetypes~Kind
 * @enum
 */
var MimetypesKind = {
  opus: 'video/ogg',
  ogv: 'video/ogg',
  mp4: 'video/mp4',
  mov: 'video/mp4',
  m4v: 'video/mp4',
  mkv: 'video/x-matroska',
  mp3: 'audio/mpeg',
  aac: 'audio/aac',
  oga: 'audio/ogg',
  m3u8: 'application/x-mpegURL'
};

/**
 * Get the mimetype of a given src url if possible
 *
 * @param {string} src
 *        The url to the src
 *
 * @return {string}
 *         return the mimetype if it was known or empty string otherwise
 */
var getMimetype = function getMimetype() {
  var src = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : '';

  var ext = getFileExtension(src);
  var mimetype = MimetypesKind[ext.toLowerCase()];

  return mimetype || '';
};

/**
 * Find the mime type of a given source string if possible. Uses the player
 * source cache.
 *
 * @param {Player} player
 *        The player object
 *
 * @param {string} src
 *        The source string
 *
 * @return {string}
 *         The type that was found
 */
var findMimetype = function findMimetype(player, src) {
  if (!src) {
    return '';
  }

  // 1. check for the type in the `source` cache
  if (player.cache_.source.src === src && player.cache_.source.type) {
    return player.cache_.source.type;
  }

  // 2. see if we have this source in our `currentSources` cache
  var matchingSources = player.cache_.sources.filter(function (s) {
    return s.src === src;
  });

  if (matchingSources.length) {
    return matchingSources[0].type;
  }

  // 3. look for the src url in source elements and use the type there
  var sources = player.$$('source');

  for (var i = 0; i < sources.length; i++) {
    var s = sources[i];

    if (s.type && s.src && s.src === src) {
      return s.type;
    }
  }

  // 4. finally fallback to our list of mime types based on src url extension
  return getMimetype(src);
};

/**
 * @module filter-source
 */
/**
 * Filter out single bad source objects or multiple source objects in an
 * array. Also flattens nested source object arrays into a 1 dimensional
 * array of source objects.
 *
 * @param {Tech~SourceObject|Tech~SourceObject[]} src
 *        The src object to filter
 *
 * @return {Tech~SourceObject[]}
 *         An array of sourceobjects containing only valid sources
 *
 * @private
 */
var filterSource = function filterSource(src) {
  // traverse array
  if (Array.isArray(src)) {
    var newsrc = [];

    src.forEach(function (srcobj) {
      srcobj = filterSource(srcobj);

      if (Array.isArray(srcobj)) {
        newsrc = newsrc.concat(srcobj);
      } else if (isObject(srcobj)) {
        newsrc.push(srcobj);
      }
    });

    src = newsrc;
  } else if (typeof src === 'string' && src.trim()) {
    // convert string into object
    src = [fixSource({ src: src })];
  } else if (isObject(src) && typeof src.src === 'string' && src.src && src.src.trim()) {
    // src is already valid
    src = [fixSource(src)];
  } else {
    // invalid source, turn it into an empty array
    src = [];
  }

  return src;
};

/**
 * Checks src mimetype, adding it when possible
 *
 * @param {Tech~SourceObject} src
 *        The src object to check
 * @return {Tech~SourceObject}
 *        src Object with known type
 */
function fixSource(src) {
  var mimetype = getMimetype(src.src);

  if (!src.type && mimetype) {
    src.type = mimetype;
  }

  return src;
}

/**
 * @file loader.js
 */
/**
 * The `MediaLoader` is the `Component` that decides which playback technology to load
 * when a player is initialized.
 *
 * @extends Component
 */

var MediaLoader = function (_Component) {
  inherits(MediaLoader, _Component);

  /**
   * Create an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should attach to.
   *
   * @param {Object} [options]
   *        The key/value stroe of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function that is run when this component is ready.
   */
  function MediaLoader(player, options, ready) {
    classCallCheck(this, MediaLoader);

    // MediaLoader has no element
    var options_ = mergeOptions({ createEl: false }, options);

    // If there are no sources when the player is initialized,
    // load the first supported playback technology.

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options_, ready));

    if (!options.playerOptions.sources || options.playerOptions.sources.length === 0) {
      for (var i = 0, j = options.playerOptions.techOrder; i < j.length; i++) {
        var techName = toTitleCase(j[i]);
        var tech = Tech.getTech(techName);

        // Support old behavior of techs being registered as components.
        // Remove once that deprecated behavior is removed.
        if (!techName) {
          tech = Component.getComponent(techName);
        }

        // Check if the browser supports this technology
        if (tech && tech.isSupported()) {
          player.loadTech_(techName);
          break;
        }
      }
    } else {
      // Loop through playback technologies (HTML5, Flash) and check for support.
      // Then load the best source.
      // A few assumptions here:
      //   All playback technologies respect preload false.
      player.src(options.playerOptions.sources);
    }
    return _this;
  }

  return MediaLoader;
}(Component);

Component.registerComponent('MediaLoader', MediaLoader);

/**
 * @file button.js
 */
/**
 * Clickable Component which is clickable or keyboard actionable,
 * but is not a native HTML button.
 *
 * @extends Component
 */

var ClickableComponent = function (_Component) {
  inherits(ClickableComponent, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param  {Player} player
   *         The `Player` that this class should be attached to.
   *
   * @param  {Object} [options]
   *         The key/value store of player options.
   */
  function ClickableComponent(player, options) {
    classCallCheck(this, ClickableComponent);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.emitTapEvents();

    _this.enable();
    return _this;
  }

  /**
   * Create the `Component`s DOM element.
   *
   * @param {string} [tag=div]
   *        The element's node type.
   *
   * @param {Object} [props={}]
   *        An object of properties that should be set on the element.
   *
   * @param {Object} [attributes={}]
   *        An object of attributes that should be set on the element.
   *
   * @return {Element}
   *         The element that gets created.
   */


  ClickableComponent.prototype.createEl = function createEl$$1() {
    var tag = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'div';
    var props = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    var attributes = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};

    props = assign({
      innerHTML: '<span aria-hidden="true" class="vjs-icon-placeholder"></span>',
      className: this.buildCSSClass(),
      tabIndex: 0
    }, props);

    if (tag === 'button') {
      log$1.error('Creating a ClickableComponent with an HTML element of ' + tag + ' is not supported; use a Button instead.');
    }

    // Add ARIA attributes for clickable element which is not a native HTML button
    attributes = assign({
      role: 'button'
    }, attributes);

    this.tabIndex_ = props.tabIndex;

    var el = _Component.prototype.createEl.call(this, tag, props, attributes);

    this.createControlTextEl(el);

    return el;
  };

  ClickableComponent.prototype.dispose = function dispose() {
    // remove controlTextEl_ on dipose
    this.controlTextEl_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Create a control text element on this `Component`
   *
   * @param {Element} [el]
   *        Parent element for the control text.
   *
   * @return {Element}
   *         The control text element that gets created.
   */


  ClickableComponent.prototype.createControlTextEl = function createControlTextEl(el) {
    this.controlTextEl_ = createEl('span', {
      className: 'vjs-control-text'
    }, {
      // let the screen reader user know that the text of the element may change
      'aria-live': 'polite'
    });

    if (el) {
      el.appendChild(this.controlTextEl_);
    }

    this.controlText(this.controlText_, el);

    return this.controlTextEl_;
  };

  /**
   * Get or set the localize text to use for the controls on the `Component`.
   *
   * @param {string} [text]
   *        Control text for element.
   *
   * @param {Element} [el=this.el()]
   *        Element to set the title on.
   *
   * @return {string}
   *         - The control text when getting
   */


  ClickableComponent.prototype.controlText = function controlText(text) {
    var el = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : this.el();

    if (text === undefined) {
      return this.controlText_ || 'Need Text';
    }

    var localizedText = this.localize(text);

    this.controlText_ = text;
    textContent(this.controlTextEl_, localizedText);
    if (!this.nonIconControl) {
      // Set title attribute if only an icon is shown
      el.setAttribute('title', localizedText);
    }
  };

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  ClickableComponent.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-control vjs-button ' + _Component.prototype.buildCSSClass.call(this);
  };

  /**
   * Enable this `Component`s element.
   */


  ClickableComponent.prototype.enable = function enable() {
    if (!this.enabled_) {
      this.enabled_ = true;
      this.removeClass('vjs-disabled');
      this.el_.setAttribute('aria-disabled', 'false');
      if (typeof this.tabIndex_ !== 'undefined') {
        this.el_.setAttribute('tabIndex', this.tabIndex_);
      }
      this.on(['tap', 'click'], this.handleClick);
      this.on('focus', this.handleFocus);
      this.on('blur', this.handleBlur);
    }
  };

  /**
   * Disable this `Component`s element.
   */


  ClickableComponent.prototype.disable = function disable() {
    this.enabled_ = false;
    this.addClass('vjs-disabled');
    this.el_.setAttribute('aria-disabled', 'true');
    if (typeof this.tabIndex_ !== 'undefined') {
      this.el_.removeAttribute('tabIndex');
    }
    this.off(['tap', 'click'], this.handleClick);
    this.off('focus', this.handleFocus);
    this.off('blur', this.handleBlur);
  };

  /**
   * This gets called when a `ClickableComponent` gets:
   * - Clicked (via the `click` event, listening starts in the constructor)
   * - Tapped (via the `tap` event, listening starts in the constructor)
   * - The following things happen in order:
   *   1. {@link ClickableComponent#handleFocus} is called via a `focus` event on the
   *      `ClickableComponent`.
   *   2. {@link ClickableComponent#handleFocus} adds a listener for `keydown` on using
   *      {@link ClickableComponent#handleKeyPress}.
   *   3. `ClickableComponent` has not had a `blur` event (`blur` means that focus was lost). The user presses
   *      the space or enter key.
   *   4. {@link ClickableComponent#handleKeyPress} calls this function with the `keydown`
   *      event as a parameter.
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   * @abstract
   */


  ClickableComponent.prototype.handleClick = function handleClick(event) {};

  /**
   * This gets called when a `ClickableComponent` gains focus via a `focus` event.
   * Turns on listening for `keydown` events. When they happen it
   * calls `this.handleKeyPress`.
   *
   * @param {EventTarget~Event} event
   *        The `focus` event that caused this function to be called.
   *
   * @listens focus
   */


  ClickableComponent.prototype.handleFocus = function handleFocus(event) {
    on(document_1, 'keydown', bind(this, this.handleKeyPress));
  };

  /**
   * Called when this ClickableComponent has focus and a key gets pressed down. By
   * default it will call `this.handleClick` when the key is space or enter.
   *
   * @param {EventTarget~Event} event
   *        The `keydown` event that caused this function to be called.
   *
   * @listens keydown
   */


  ClickableComponent.prototype.handleKeyPress = function handleKeyPress(event) {

    // Support Space (32) or Enter (13) key operation to fire a click event
    if (event.which === 32 || event.which === 13) {
      event.preventDefault();
      this.trigger('click');
    } else if (_Component.prototype.handleKeyPress) {

      // Pass keypress handling up for unsupported keys
      _Component.prototype.handleKeyPress.call(this, event);
    }
  };

  /**
   * Called when a `ClickableComponent` loses focus. Turns off the listener for
   * `keydown` events. Which Stops `this.handleKeyPress` from getting called.
   *
   * @param {EventTarget~Event} event
   *        The `blur` event that caused this function to be called.
   *
   * @listens blur
   */


  ClickableComponent.prototype.handleBlur = function handleBlur(event) {
    off(document_1, 'keydown', bind(this, this.handleKeyPress));
  };

  return ClickableComponent;
}(Component);

Component.registerComponent('ClickableComponent', ClickableComponent);

/**
 * @file poster-image.js
 */
/**
 * A `ClickableComponent` that handles showing the poster image for the player.
 *
 * @extends ClickableComponent
 */

var PosterImage = function (_ClickableComponent) {
  inherits(PosterImage, _ClickableComponent);

  /**
   * Create an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should attach to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function PosterImage(player, options) {
    classCallCheck(this, PosterImage);

    var _this = possibleConstructorReturn(this, _ClickableComponent.call(this, player, options));

    _this.update();
    player.on('posterchange', bind(_this, _this.update));
    return _this;
  }

  /**
   * Clean up and dispose of the `PosterImage`.
   */


  PosterImage.prototype.dispose = function dispose() {
    this.player().off('posterchange', this.update);
    _ClickableComponent.prototype.dispose.call(this);
  };

  /**
   * Create the `PosterImage`s DOM element.
   *
   * @return {Element}
   *         The element that gets created.
   */


  PosterImage.prototype.createEl = function createEl$$1() {
    var el = createEl('div', {
      className: 'vjs-poster',

      // Don't want poster to be tabbable.
      tabIndex: -1
    });

    // To ensure the poster image resizes while maintaining its original aspect
    // ratio, use a div with `background-size` when available. For browsers that
    // do not support `background-size` (e.g. IE8), fall back on using a regular
    // img element.
    if (!BACKGROUND_SIZE_SUPPORTED) {
      this.fallbackImg_ = createEl('img');
      el.appendChild(this.fallbackImg_);
    }

    return el;
  };

  /**
   * An {@link EventTarget~EventListener} for {@link Player#posterchange} events.
   *
   * @listens Player#posterchange
   *
   * @param {EventTarget~Event} [event]
   *        The `Player#posterchange` event that triggered this function.
   */


  PosterImage.prototype.update = function update(event) {
    var url = this.player().poster();

    this.setSrc(url);

    // If there's no poster source we should display:none on this component
    // so it's not still clickable or right-clickable
    if (url) {
      this.show();
    } else {
      this.hide();
    }
  };

  /**
   * Set the source of the `PosterImage` depending on the display method.
   *
   * @param {string} url
   *        The URL to the source for the `PosterImage`.
   */


  PosterImage.prototype.setSrc = function setSrc(url) {
    if (this.fallbackImg_) {
      this.fallbackImg_.src = url;
    } else {
      var backgroundImage = '';

      // Any falsey values should stay as an empty string, otherwise
      // this will throw an extra error
      if (url) {
        backgroundImage = 'url("' + url + '")';
      }

      this.el_.style.backgroundImage = backgroundImage;
    }
  };

  /**
   * An {@link EventTarget~EventListener} for clicks on the `PosterImage`. See
   * {@link ClickableComponent#handleClick} for instances where this will be triggered.
   *
   * @listens tap
   * @listens click
   * @listens keydown
   *
   * @param {EventTarget~Event} event
   +        The `click`, `tap` or `keydown` event that caused this function to be called.
   */


  PosterImage.prototype.handleClick = function handleClick(event) {
    // We don't want a click to trigger playback when controls are disabled
    if (!this.player_.controls()) {
      return;
    }

    if (this.player_.paused()) {
      silencePromise(this.player_.play());
    } else {
      this.player_.pause();
    }
  };

  return PosterImage;
}(ClickableComponent);

Component.registerComponent('PosterImage', PosterImage);

/**
 * @file text-track-display.js
 */
var darkGray = '#222';
var lightGray = '#ccc';
var fontMap = {
  monospace: 'monospace',
  sansSerif: 'sans-serif',
  serif: 'serif',
  monospaceSansSerif: '"Andale Mono", "Lucida Console", monospace',
  monospaceSerif: '"Courier New", monospace',
  proportionalSansSerif: 'sans-serif',
  proportionalSerif: 'serif',
  casual: '"Comic Sans MS", Impact, fantasy',
  script: '"Monotype Corsiva", cursive',
  smallcaps: '"Andale Mono", "Lucida Console", monospace, sans-serif'
};

/**
 * Construct an rgba color from a given hex color code.
 *
 * @param {number} color
 *        Hex number for color, like #f0e or #f604e2.
 *
 * @param {number} opacity
 *        Value for opacity, 0.0 - 1.0.
 *
 * @return {string}
 *         The rgba color that was created, like 'rgba(255, 0, 0, 0.3)'.
 */
function constructColor(color, opacity) {
  var hex = void 0;

  if (color.length === 4) {
    // color looks like "#f0e"
    hex = color[1] + color[1] + color[2] + color[2] + color[3] + color[3];
  } else if (color.length === 7) {
    // color looks like "#f604e2"
    hex = color.slice(1);
  } else {
    throw new Error('Invalid color code provided, ' + color + '; must be formatted as e.g. #f0e or #f604e2.');
  }
  return 'rgba(' + parseInt(hex.slice(0, 2), 16) + ',' + parseInt(hex.slice(2, 4), 16) + ',' + parseInt(hex.slice(4, 6), 16) + ',' + opacity + ')';
}

/**
 * Try to update the style of a DOM element. Some style changes will throw an error,
 * particularly in IE8. Those should be noops.
 *
 * @param {Element} el
 *        The DOM element to be styled.
 *
 * @param {string} style
 *        The CSS property on the element that should be styled.
 *
 * @param {string} rule
 *        The style rule that should be applied to the property.
 *
 * @private
 */
function tryUpdateStyle(el, style, rule) {
  try {
    el.style[style] = rule;
  } catch (e) {

    // Satisfies linter.
    return;
  }
}

/**
 * The component for displaying text track cues.
 *
 * @extends Component
 */

var TextTrackDisplay = function (_Component) {
  inherits(TextTrackDisplay, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function to call when `TextTrackDisplay` is ready.
   */
  function TextTrackDisplay(player, options, ready) {
    classCallCheck(this, TextTrackDisplay);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options, ready));

    player.on('loadstart', bind(_this, _this.toggleDisplay));
    player.on('texttrackchange', bind(_this, _this.updateDisplay));
    player.on('loadstart', bind(_this, _this.preselectTrack));

    // This used to be called during player init, but was causing an error
    // if a track should show by default and the display hadn't loaded yet.
    // Should probably be moved to an external track loader when we support
    // tracks that don't need a display.
    player.ready(bind(_this, function () {
      if (player.tech_ && player.tech_.featuresNativeTextTracks) {
        this.hide();
        return;
      }

      player.on('fullscreenchange', bind(this, this.updateDisplay));

      var tracks = this.options_.playerOptions.tracks || [];

      for (var i = 0; i < tracks.length; i++) {
        this.player_.addRemoteTextTrack(tracks[i], true);
      }

      this.preselectTrack();
    }));
    return _this;
  }

  /**
  * Preselect a track following this precedence:
  * - matches the previously selected {@link TextTrack}'s language and kind
  * - matches the previously selected {@link TextTrack}'s language only
  * - is the first default captions track
  * - is the first default descriptions track
  *
  * @listens Player#loadstart
  */


  TextTrackDisplay.prototype.preselectTrack = function preselectTrack() {
    var modes = { captions: 1, subtitles: 1 };
    var trackList = this.player_.textTracks();
    var userPref = this.player_.cache_.selectedLanguage;
    var firstDesc = void 0;
    var firstCaptions = void 0;
    var preferredTrack = void 0;

    for (var i = 0; i < trackList.length; i++) {
      var track = trackList[i];

      if (userPref && userPref.enabled && userPref.language === track.language) {
        // Always choose the track that matches both language and kind
        if (track.kind === userPref.kind) {
          preferredTrack = track;
          // or choose the first track that matches language
        } else if (!preferredTrack) {
          preferredTrack = track;
        }

        // clear everything if offTextTrackMenuItem was clicked
      } else if (userPref && !userPref.enabled) {
        preferredTrack = null;
        firstDesc = null;
        firstCaptions = null;
      } else if (track['default']) {
        if (track.kind === 'descriptions' && !firstDesc) {
          firstDesc = track;
        } else if (track.kind in modes && !firstCaptions) {
          firstCaptions = track;
        }
      }
    }

    // The preferredTrack matches the user preference and takes
    // precendence over all the other tracks.
    // So, display the preferredTrack before the first default track
    // and the subtitles/captions track before the descriptions track
    if (preferredTrack) {
      preferredTrack.mode = 'showing';
    } else if (firstCaptions) {
      firstCaptions.mode = 'showing';
    } else if (firstDesc) {
      firstDesc.mode = 'showing';
    }
  };

  /**
   * Turn display of {@link TextTrack}'s from the current state into the other state.
   * There are only two states:
   * - 'shown'
   * - 'hidden'
   *
   * @listens Player#loadstart
   */


  TextTrackDisplay.prototype.toggleDisplay = function toggleDisplay() {
    if (this.player_.tech_ && this.player_.tech_.featuresNativeTextTracks) {
      this.hide();
    } else {
      this.show();
    }
  };

  /**
   * Create the {@link Component}'s DOM element.
   *
   * @return {Element}
   *         The element that was created.
   */


  TextTrackDisplay.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-text-track-display'
    }, {
      'aria-live': 'off',
      'aria-atomic': 'true'
    });
  };

  /**
   * Clear all displayed {@link TextTrack}s.
   */


  TextTrackDisplay.prototype.clearDisplay = function clearDisplay() {
    if (typeof window_1.WebVTT === 'function') {
      window_1.WebVTT.processCues(window_1, [], this.el_);
    }
  };

  /**
   * Update the displayed TextTrack when a either a {@link Player#texttrackchange} or
   * a {@link Player#fullscreenchange} is fired.
   *
   * @listens Player#texttrackchange
   * @listens Player#fullscreenchange
   */


  TextTrackDisplay.prototype.updateDisplay = function updateDisplay() {
    var tracks = this.player_.textTracks();

    this.clearDisplay();

    // Track display prioritization model: if multiple tracks are 'showing',
    //  display the first 'subtitles' or 'captions' track which is 'showing',
    //  otherwise display the first 'descriptions' track which is 'showing'

    var descriptionsTrack = null;
    var captionsSubtitlesTrack = null;
    var i = tracks.length;

    while (i--) {
      var track = tracks[i];

      if (track.mode === 'showing') {
        if (track.kind === 'descriptions') {
          descriptionsTrack = track;
        } else {
          captionsSubtitlesTrack = track;
        }
      }
    }

    if (captionsSubtitlesTrack) {
      if (this.getAttribute('aria-live') !== 'off') {
        this.setAttribute('aria-live', 'off');
      }
      this.updateForTrack(captionsSubtitlesTrack);
    } else if (descriptionsTrack) {
      if (this.getAttribute('aria-live') !== 'assertive') {
        this.setAttribute('aria-live', 'assertive');
      }
      this.updateForTrack(descriptionsTrack);
    }
  };

  /**
   * Add an {@link Texttrack} to to the {@link Tech}s {@link TextTrackList}.
   *
   * @param {TextTrack} track
   *        Text track object to be added to the list.
   */


  TextTrackDisplay.prototype.updateForTrack = function updateForTrack(track) {
    if (typeof window_1.WebVTT !== 'function' || !track.activeCues) {
      return;
    }

    var cues = [];

    for (var _i = 0; _i < track.activeCues.length; _i++) {
      cues.push(track.activeCues[_i]);
    }

    window_1.WebVTT.processCues(window_1, cues, this.el_);

    if (!this.player_.textTrackSettings) {
      return;
    }

    var overrides = this.player_.textTrackSettings.getValues();

    var i = cues.length;

    while (i--) {
      var cue = cues[i];

      if (!cue) {
        continue;
      }

      var cueDiv = cue.displayState;

      if (overrides.color) {
        cueDiv.firstChild.style.color = overrides.color;
      }
      if (overrides.textOpacity) {
        tryUpdateStyle(cueDiv.firstChild, 'color', constructColor(overrides.color || '#fff', overrides.textOpacity));
      }
      if (overrides.backgroundColor) {
        cueDiv.firstChild.style.backgroundColor = overrides.backgroundColor;
      }
      if (overrides.backgroundOpacity) {
        tryUpdateStyle(cueDiv.firstChild, 'backgroundColor', constructColor(overrides.backgroundColor || '#000', overrides.backgroundOpacity));
      }
      if (overrides.windowColor) {
        if (overrides.windowOpacity) {
          tryUpdateStyle(cueDiv, 'backgroundColor', constructColor(overrides.windowColor, overrides.windowOpacity));
        } else {
          cueDiv.style.backgroundColor = overrides.windowColor;
        }
      }
      if (overrides.edgeStyle) {
        if (overrides.edgeStyle === 'dropshadow') {
          cueDiv.firstChild.style.textShadow = '2px 2px 3px ' + darkGray + ', 2px 2px 4px ' + darkGray + ', 2px 2px 5px ' + darkGray;
        } else if (overrides.edgeStyle === 'raised') {
          cueDiv.firstChild.style.textShadow = '1px 1px ' + darkGray + ', 2px 2px ' + darkGray + ', 3px 3px ' + darkGray;
        } else if (overrides.edgeStyle === 'depressed') {
          cueDiv.firstChild.style.textShadow = '1px 1px ' + lightGray + ', 0 1px ' + lightGray + ', -1px -1px ' + darkGray + ', 0 -1px ' + darkGray;
        } else if (overrides.edgeStyle === 'uniform') {
          cueDiv.firstChild.style.textShadow = '0 0 4px ' + darkGray + ', 0 0 4px ' + darkGray + ', 0 0 4px ' + darkGray + ', 0 0 4px ' + darkGray;
        }
      }
      if (overrides.fontPercent && overrides.fontPercent !== 1) {
        var fontSize = window_1.parseFloat(cueDiv.style.fontSize);

        cueDiv.style.fontSize = fontSize * overrides.fontPercent + 'px';
        cueDiv.style.height = 'auto';
        cueDiv.style.top = 'auto';
        cueDiv.style.bottom = '2px';
      }
      if (overrides.fontFamily && overrides.fontFamily !== 'default') {
        if (overrides.fontFamily === 'small-caps') {
          cueDiv.firstChild.style.fontVariant = 'small-caps';
        } else {
          cueDiv.firstChild.style.fontFamily = fontMap[overrides.fontFamily];
        }
      }
    }
  };

  return TextTrackDisplay;
}(Component);

Component.registerComponent('TextTrackDisplay', TextTrackDisplay);

/**
 * @file loading-spinner.js
 */
/**
 * A loading spinner for use during waiting/loading events.
 *
 * @extends Component
 */

var LoadingSpinner = function (_Component) {
  inherits(LoadingSpinner, _Component);

  function LoadingSpinner() {
    classCallCheck(this, LoadingSpinner);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the `LoadingSpinner`s DOM element.
   *
   * @return {Element}
   *         The dom element that gets created.
   */
  LoadingSpinner.prototype.createEl = function createEl$$1() {
    var isAudio = this.player_.isAudio();
    var playerType = this.localize(isAudio ? 'Audio Player' : 'Video Player');
    var controlText = createEl('span', {
      className: 'vjs-control-text',
      innerHTML: this.localize('{1} is loading.', [playerType])
    });

    var el = _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-loading-spinner',
      dir: 'ltr'
    });

    el.appendChild(controlText);

    return el;
  };

  return LoadingSpinner;
}(Component);

Component.registerComponent('LoadingSpinner', LoadingSpinner);

/**
 * @file button.js
 */
/**
 * Base class for all buttons.
 *
 * @extends ClickableComponent
 */

var Button = function (_ClickableComponent) {
  inherits(Button, _ClickableComponent);

  function Button() {
    classCallCheck(this, Button);
    return possibleConstructorReturn(this, _ClickableComponent.apply(this, arguments));
  }

  /**
   * Create the `Button`s DOM element.
   *
   * @param {string} [tag="button"]
   *        The element's node type. This argument is IGNORED: no matter what
   *        is passed, it will always create a `button` element.
   *
   * @param {Object} [props={}]
   *        An object of properties that should be set on the element.
   *
   * @param {Object} [attributes={}]
   *        An object of attributes that should be set on the element.
   *
   * @return {Element}
   *         The element that gets created.
   */
  Button.prototype.createEl = function createEl(tag) {
    var props = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    var attributes = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};

    tag = 'button';

    props = assign({
      innerHTML: '<span aria-hidden="true" class="vjs-icon-placeholder"></span>',
      className: this.buildCSSClass()
    }, props);

    // Add attributes for button element
    attributes = assign({

      // Necessary since the default button type is "submit"
      type: 'button'
    }, attributes);

    var el = Component.prototype.createEl.call(this, tag, props, attributes);

    this.createControlTextEl(el);

    return el;
  };

  /**
   * Add a child `Component` inside of this `Button`.
   *
   * @param {string|Component} child
   *        The name or instance of a child to add.
   *
   * @param {Object} [options={}]
   *        The key/value store of options that will get passed to children of
   *        the child.
   *
   * @return {Component}
   *         The `Component` that gets added as a child. When using a string the
   *         `Component` will get created by this process.
   *
   * @deprecated since version 5
   */


  Button.prototype.addChild = function addChild(child) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};

    var className = this.constructor.name;

    log$1.warn('Adding an actionable (user controllable) child to a Button (' + className + ') is not supported; use a ClickableComponent instead.');

    // Avoid the error message generated by ClickableComponent's addChild method
    return Component.prototype.addChild.call(this, child, options);
  };

  /**
   * Enable the `Button` element so that it can be activated or clicked. Use this with
   * {@link Button#disable}.
   */


  Button.prototype.enable = function enable() {
    _ClickableComponent.prototype.enable.call(this);
    this.el_.removeAttribute('disabled');
  };

  /**
   * Disable the `Button` element so that it cannot be activated or clicked. Use this with
   * {@link Button#enable}.
   */


  Button.prototype.disable = function disable() {
    _ClickableComponent.prototype.disable.call(this);
    this.el_.setAttribute('disabled', 'disabled');
  };

  /**
   * This gets called when a `Button` has focus and `keydown` is triggered via a key
   * press.
   *
   * @param {EventTarget~Event} event
   *        The event that caused this function to get called.
   *
   * @listens keydown
   */


  Button.prototype.handleKeyPress = function handleKeyPress(event) {

    // Ignore Space (32) or Enter (13) key operation, which is handled by the browser for a button.
    if (event.which === 32 || event.which === 13) {
      return;
    }

    // Pass keypress handling up for unsupported keys
    _ClickableComponent.prototype.handleKeyPress.call(this, event);
  };

  return Button;
}(ClickableComponent);

Component.registerComponent('Button', Button);

/**
 * @file big-play-button.js
 */
/**
 * The initial play button that shows before the video has played. The hiding of the
 * `BigPlayButton` get done via CSS and `Player` states.
 *
 * @extends Button
 */

var BigPlayButton = function (_Button) {
  inherits(BigPlayButton, _Button);

  function BigPlayButton(player, options) {
    classCallCheck(this, BigPlayButton);

    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    _this.mouseused_ = false;

    _this.on('mousedown', _this.handleMouseDown);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object. Always returns 'vjs-big-play-button'.
   */


  BigPlayButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-big-play-button';
  };

  /**
   * This gets called when a `BigPlayButton` "clicked". See {@link ClickableComponent}
   * for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  BigPlayButton.prototype.handleClick = function handleClick(event) {
    var playPromise = this.player_.play();

    // exit early if clicked via the mouse
    if (this.mouseused_ && event.clientX && event.clientY) {
      silencePromise(playPromise);
      return;
    }

    var cb = this.player_.getChild('controlBar');
    var playToggle = cb && cb.getChild('playToggle');

    if (!playToggle) {
      this.player_.focus();
      return;
    }

    var playFocus = function playFocus() {
      return playToggle.focus();
    };

    if (isPromise(playPromise)) {
      playPromise.then(playFocus, function () {});
    } else {
      this.setTimeout(playFocus, 1);
    }
  };

  BigPlayButton.prototype.handleKeyPress = function handleKeyPress(event) {
    this.mouseused_ = false;

    _Button.prototype.handleKeyPress.call(this, event);
  };

  BigPlayButton.prototype.handleMouseDown = function handleMouseDown(event) {
    this.mouseused_ = true;
  };

  return BigPlayButton;
}(Button);

/**
 * The text that should display over the `BigPlayButton`s controls. Added to for localization.
 *
 * @type {string}
 * @private
 */


BigPlayButton.prototype.controlText_ = 'Play Video';

Component.registerComponent('BigPlayButton', BigPlayButton);

/**
 * @file close-button.js
 */
/**
 * The `CloseButton` is a `{@link Button}` that fires a `close` event when
 * it gets clicked.
 *
 * @extends Button
 */

var CloseButton = function (_Button) {
  inherits(CloseButton, _Button);

  /**
   * Creates an instance of the this class.
   *
   * @param  {Player} player
   *         The `Player` that this class should be attached to.
   *
   * @param  {Object} [options]
   *         The key/value store of player options.
   */
  function CloseButton(player, options) {
    classCallCheck(this, CloseButton);

    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    _this.controlText(options && options.controlText || _this.localize('Close'));
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  CloseButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-close-button ' + _Button.prototype.buildCSSClass.call(this);
  };

  /**
   * This gets called when a `CloseButton` gets clicked. See
   * {@link ClickableComponent#handleClick} for more information on when this will be
   * triggered
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   * @fires CloseButton#close
   */


  CloseButton.prototype.handleClick = function handleClick(event) {

    /**
     * Triggered when the a `CloseButton` is clicked.
     *
     * @event CloseButton#close
     * @type {EventTarget~Event}
     *
     * @property {boolean} [bubbles=false]
     *           set to false so that the close event does not
     *           bubble up to parents if there is no listener
     */
    this.trigger({ type: 'close', bubbles: false });
  };

  return CloseButton;
}(Button);

Component.registerComponent('CloseButton', CloseButton);

/**
 * @file play-toggle.js
 */
/**
 * Button to toggle between play and pause.
 *
 * @extends Button
 */

var PlayToggle = function (_Button) {
  inherits(PlayToggle, _Button);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function PlayToggle(player, options) {
    classCallCheck(this, PlayToggle);

    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    _this.on(player, 'play', _this.handlePlay);
    _this.on(player, 'pause', _this.handlePause);
    _this.on(player, 'ended', _this.handleEnded);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  PlayToggle.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-play-control ' + _Button.prototype.buildCSSClass.call(this);
  };

  /**
   * This gets called when an `PlayToggle` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  PlayToggle.prototype.handleClick = function handleClick(event) {
    if (this.player_.paused()) {
      this.player_.play();
    } else {
      this.player_.pause();
    }
  };

  /**
   * This gets called once after the video has ended and the user seeks so that
   * we can change the replay button back to a play button.
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#seeked
   */


  PlayToggle.prototype.handleSeeked = function handleSeeked(event) {
    this.removeClass('vjs-ended');

    if (this.player_.paused()) {
      this.handlePause(event);
    } else {
      this.handlePlay(event);
    }
  };

  /**
   * Add the vjs-playing class to the element so it can change appearance.
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#play
   */


  PlayToggle.prototype.handlePlay = function handlePlay(event) {
    this.removeClass('vjs-ended');
    this.removeClass('vjs-paused');
    this.addClass('vjs-playing');
    // change the button text to "Pause"
    this.controlText('Pause');
  };

  /**
   * Add the vjs-paused class to the element so it can change appearance.
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#pause
   */


  PlayToggle.prototype.handlePause = function handlePause(event) {
    this.removeClass('vjs-playing');
    this.addClass('vjs-paused');
    // change the button text to "Play"
    this.controlText('Play');
  };

  /**
   * Add the vjs-ended class to the element so it can change appearance
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#ended
   */


  PlayToggle.prototype.handleEnded = function handleEnded(event) {
    this.removeClass('vjs-playing');
    this.addClass('vjs-ended');
    // change the button text to "Replay"
    this.controlText('Replay');

    // on the next seek remove the replay button
    this.one(this.player_, 'seeked', this.handleSeeked);
  };

  return PlayToggle;
}(Button);

/**
 * The text that should display over the `PlayToggle`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


PlayToggle.prototype.controlText_ = 'Play';

Component.registerComponent('PlayToggle', PlayToggle);

/**
 * @file format-time.js
 * @module format-time
 */

/**
* Format seconds as a time string, H:MM:SS or M:SS. Supplying a guide (in seconds)
* will force a number of leading zeros to cover the length of the guide.
*
* @param {number} seconds
*        Number of seconds to be turned into a string
*
* @param {number} guide
*        Number (in seconds) to model the string after
*
* @return {string}
*         Time formatted as H:MM:SS or M:SS
*/
var defaultImplementation = function defaultImplementation(seconds, guide) {
  seconds = seconds < 0 ? 0 : seconds;
  var s = Math.floor(seconds % 60);
  var m = Math.floor(seconds / 60 % 60);
  var h = Math.floor(seconds / 3600);
  var gm = Math.floor(guide / 60 % 60);
  var gh = Math.floor(guide / 3600);

  // handle invalid times
  if (isNaN(seconds) || seconds === Infinity) {
    // '-' is false for all relational operators (e.g. <, >=) so this setting
    // will add the minimum number of fields specified by the guide
    h = m = s = '-';
  }

  // Check if we need to show hours
  h = h > 0 || gh > 0 ? h + ':' : '';

  // If hours are showing, we may need to add a leading zero.
  // Always show at least one digit of minutes.
  m = ((h || gm >= 10) && m < 10 ? '0' + m : m) + ':';

  // Check if leading zero is need for seconds
  s = s < 10 ? '0' + s : s;

  return h + m + s;
};

var implementation = defaultImplementation;

/**
 * Replaces the default formatTime implementation with a custom implementation.
 *
 * @param {Function} customImplementation
 *        A function which will be used in place of the default formatTime implementation.
 *        Will receive the current time in seconds and the guide (in seconds) as arguments.
 */
function setFormatTime(customImplementation) {
  implementation = customImplementation;
}

/**
 * Resets formatTime to the default implementation.
 */
function resetFormatTime() {
  implementation = defaultImplementation;
}

var formatTime = function (seconds) {
  var guide = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : seconds;

  return implementation(seconds, guide);
};

/**
 * @file time-display.js
 */
/**
 * Displays the time left in the video
 *
 * @extends Component
 */

var TimeDisplay = function (_Component) {
  inherits(TimeDisplay, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function TimeDisplay(player, options) {
    classCallCheck(this, TimeDisplay);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.throttledUpdateContent = throttle(bind(_this, _this.updateContent), 25);
    _this.on(player, 'timeupdate', _this.throttledUpdateContent);
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  TimeDisplay.prototype.createEl = function createEl$$1(plainName) {
    var className = this.buildCSSClass();
    var el = _Component.prototype.createEl.call(this, 'div', {
      className: className + ' vjs-time-control vjs-control',
      innerHTML: '<span class="vjs-control-text">' + this.localize(this.labelText_) + '\xA0</span>'
    });

    this.contentEl_ = createEl('span', {
      className: className + '-display'
    }, {
      // tell screen readers not to automatically read the time as it changes
      'aria-live': 'off'
    });

    this.updateTextNode_();
    el.appendChild(this.contentEl_);
    return el;
  };

  TimeDisplay.prototype.dispose = function dispose() {
    this.contentEl_ = null;
    this.textNode_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Updates the "remaining time" text node with new content using the
   * contents of the `formattedTime_` property.
   *
   * @private
   */


  TimeDisplay.prototype.updateTextNode_ = function updateTextNode_() {
    if (!this.contentEl_) {
      return;
    }

    while (this.contentEl_.firstChild) {
      this.contentEl_.removeChild(this.contentEl_.firstChild);
    }

    this.textNode_ = document_1.createTextNode(this.formattedTime_ || this.formatTime_(0));
    this.contentEl_.appendChild(this.textNode_);
  };

  /**
   * Generates a formatted time for this component to use in display.
   *
   * @param  {number} time
   *         A numeric time, in seconds.
   *
   * @return {string}
   *         A formatted time
   *
   * @private
   */


  TimeDisplay.prototype.formatTime_ = function formatTime_(time) {
    return formatTime(time);
  };

  /**
   * Updates the time display text node if it has what was passed in changed
   * the formatted time.
   *
   * @param {number} time
   *        The time to update to
   *
   * @private
   */


  TimeDisplay.prototype.updateFormattedTime_ = function updateFormattedTime_(time) {
    var formattedTime = this.formatTime_(time);

    if (formattedTime === this.formattedTime_) {
      return;
    }

    this.formattedTime_ = formattedTime;
    this.requestAnimationFrame(this.updateTextNode_);
  };

  /**
   * To be filled out in the child class, should update the displayed time
   * in accordance with the fact that the current time has changed.
   *
   * @param {EventTarget~Event} [event]
   *        The `timeupdate`  event that caused this to run.
   *
   * @listens Player#timeupdate
   */


  TimeDisplay.prototype.updateContent = function updateContent(event) {};

  return TimeDisplay;
}(Component);

/**
 * The text that is added to the `TimeDisplay` for screen reader users.
 *
 * @type {string}
 * @private
 */


TimeDisplay.prototype.labelText_ = 'Time';

/**
 * The text that should display over the `TimeDisplay`s controls. Added to for localization.
 *
 * @type {string}
 * @private
 *
 * @deprecated in v7; controlText_ is not used in non-active display Components
 */
TimeDisplay.prototype.controlText_ = 'Time';

Component.registerComponent('TimeDisplay', TimeDisplay);

/**
 * @file current-time-display.js
 */
/**
 * Displays the current time
 *
 * @extends Component
 */

var CurrentTimeDisplay = function (_TimeDisplay) {
  inherits(CurrentTimeDisplay, _TimeDisplay);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function CurrentTimeDisplay(player, options) {
    classCallCheck(this, CurrentTimeDisplay);

    var _this = possibleConstructorReturn(this, _TimeDisplay.call(this, player, options));

    _this.on(player, 'ended', _this.handleEnded);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  CurrentTimeDisplay.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-current-time';
  };

  /**
   * Update current time display
   *
   * @param {EventTarget~Event} [event]
   *        The `timeupdate` event that caused this function to run.
   *
   * @listens Player#timeupdate
   */


  CurrentTimeDisplay.prototype.updateContent = function updateContent(event) {
    // Allows for smooth scrubbing, when player can't keep up.
    var time = this.player_.scrubbing() ? this.player_.getCache().currentTime : this.player_.currentTime();

    this.updateFormattedTime_(time);
  };

  /**
   * When the player fires ended there should be no time left. Sadly
   * this is not always the case, lets make it seem like that is the case
   * for users.
   *
   * @param {EventTarget~Event} [event]
   *        The `ended` event that caused this to run.
   *
   * @listens Player#ended
   */


  CurrentTimeDisplay.prototype.handleEnded = function handleEnded(event) {
    if (!this.player_.duration()) {
      return;
    }
    this.updateFormattedTime_(this.player_.duration());
  };

  return CurrentTimeDisplay;
}(TimeDisplay);

/**
 * The text that is added to the `CurrentTimeDisplay` for screen reader users.
 *
 * @type {string}
 * @private
 */


CurrentTimeDisplay.prototype.labelText_ = 'Current Time';

/**
 * The text that should display over the `CurrentTimeDisplay`s controls. Added to for localization.
 *
 * @type {string}
 * @private
 *
 * @deprecated in v7; controlText_ is not used in non-active display Components
 */
CurrentTimeDisplay.prototype.controlText_ = 'Current Time';

Component.registerComponent('CurrentTimeDisplay', CurrentTimeDisplay);

/**
 * @file duration-display.js
 */
/**
 * Displays the duration
 *
 * @extends Component
 */

var DurationDisplay = function (_TimeDisplay) {
  inherits(DurationDisplay, _TimeDisplay);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function DurationDisplay(player, options) {
    classCallCheck(this, DurationDisplay);

    // we do not want to/need to throttle duration changes,
    // as they should always display the changed duration as
    // it has changed
    var _this = possibleConstructorReturn(this, _TimeDisplay.call(this, player, options));

    _this.on(player, 'durationchange', _this.updateContent);

    // Also listen for timeupdate (in the parent) and loadedmetadata because removing those
    // listeners could have broken dependent applications/libraries. These
    // can likely be removed for 7.0.
    _this.on(player, 'loadedmetadata', _this.throttledUpdateContent);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  DurationDisplay.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-duration';
  };

  /**
   * Update duration time display.
   *
   * @param {EventTarget~Event} [event]
   *        The `durationchange`, `timeupdate`, or `loadedmetadata` event that caused
   *        this function to be called.
   *
   * @listens Player#durationchange
   * @listens Player#timeupdate
   * @listens Player#loadedmetadata
   */


  DurationDisplay.prototype.updateContent = function updateContent(event) {
    var duration = this.player_.duration();

    if (duration && this.duration_ !== duration) {
      this.duration_ = duration;
      this.updateFormattedTime_(duration);
    }
  };

  return DurationDisplay;
}(TimeDisplay);

/**
 * The text that is added to the `DurationDisplay` for screen reader users.
 *
 * @type {string}
 * @private
 */


DurationDisplay.prototype.labelText_ = 'Duration';

/**
 * The text that should display over the `DurationDisplay`s controls. Added to for localization.
 *
 * @type {string}
 * @private
 *
 * @deprecated in v7; controlText_ is not used in non-active display Components
 */
DurationDisplay.prototype.controlText_ = 'Duration';

Component.registerComponent('DurationDisplay', DurationDisplay);

/**
 * @file time-divider.js
 */
/**
 * The separator between the current time and duration.
 * Can be hidden if it's not needed in the design.
 *
 * @extends Component
 */

var TimeDivider = function (_Component) {
  inherits(TimeDivider, _Component);

  function TimeDivider() {
    classCallCheck(this, TimeDivider);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the component's DOM element
   *
   * @return {Element}
   *         The element that was created.
   */
  TimeDivider.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-time-control vjs-time-divider',
      innerHTML: '<div><span>/</span></div>'
    });
  };

  return TimeDivider;
}(Component);

Component.registerComponent('TimeDivider', TimeDivider);

/**
 * @file remaining-time-display.js
 */
/**
 * Displays the time left in the video
 *
 * @extends Component
 */

var RemainingTimeDisplay = function (_TimeDisplay) {
  inherits(RemainingTimeDisplay, _TimeDisplay);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function RemainingTimeDisplay(player, options) {
    classCallCheck(this, RemainingTimeDisplay);

    var _this = possibleConstructorReturn(this, _TimeDisplay.call(this, player, options));

    _this.on(player, 'durationchange', _this.throttledUpdateContent);
    _this.on(player, 'ended', _this.handleEnded);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  RemainingTimeDisplay.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-remaining-time';
  };

  /**
   * The remaining time display prefixes numbers with a "minus" character.
   *
   * @param  {number} time
   *         A numeric time, in seconds.
   *
   * @return {string}
   *         A formatted time
   *
   * @private
   */


  RemainingTimeDisplay.prototype.formatTime_ = function formatTime_(time) {
    // TODO: The "-" should be decorative, and not announced by a screen reader
    return '-' + _TimeDisplay.prototype.formatTime_.call(this, time);
  };

  /**
   * Update remaining time display.
   *
   * @param {EventTarget~Event} [event]
   *        The `timeupdate` or `durationchange` event that caused this to run.
   *
   * @listens Player#timeupdate
   * @listens Player#durationchange
   */


  RemainingTimeDisplay.prototype.updateContent = function updateContent(event) {
    if (!this.player_.duration()) {
      return;
    }

    // @deprecated We should only use remainingTimeDisplay
    // as of video.js 7
    if (this.player_.remainingTimeDisplay) {
      this.updateFormattedTime_(this.player_.remainingTimeDisplay());
    } else {
      this.updateFormattedTime_(this.player_.remainingTime());
    }
  };

  /**
   * When the player fires ended there should be no time left. Sadly
   * this is not always the case, lets make it seem like that is the case
   * for users.
   *
   * @param {EventTarget~Event} [event]
   *        The `ended` event that caused this to run.
   *
   * @listens Player#ended
   */


  RemainingTimeDisplay.prototype.handleEnded = function handleEnded(event) {
    if (!this.player_.duration()) {
      return;
    }
    this.updateFormattedTime_(0);
  };

  return RemainingTimeDisplay;
}(TimeDisplay);

/**
 * The text that is added to the `RemainingTimeDisplay` for screen reader users.
 *
 * @type {string}
 * @private
 */


RemainingTimeDisplay.prototype.labelText_ = 'Remaining Time';

/**
 * The text that should display over the `RemainingTimeDisplay`s controls. Added to for localization.
 *
 * @type {string}
 * @private
 *
 * @deprecated in v7; controlText_ is not used in non-active display Components
 */
RemainingTimeDisplay.prototype.controlText_ = 'Remaining Time';

Component.registerComponent('RemainingTimeDisplay', RemainingTimeDisplay);

/**
 * @file live-display.js
 */
// TODO - Future make it click to snap to live

/**
 * Displays the live indicator when duration is Infinity.
 *
 * @extends Component
 */

var LiveDisplay = function (_Component) {
  inherits(LiveDisplay, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function LiveDisplay(player, options) {
    classCallCheck(this, LiveDisplay);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.updateShowing();
    _this.on(_this.player(), 'durationchange', _this.updateShowing);
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  LiveDisplay.prototype.createEl = function createEl$$1() {
    var el = _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-live-control vjs-control'
    });

    this.contentEl_ = createEl('div', {
      className: 'vjs-live-display',
      innerHTML: '<span class="vjs-control-text">' + this.localize('Stream Type') + '\xA0</span>' + this.localize('LIVE')
    }, {
      'aria-live': 'off'
    });

    el.appendChild(this.contentEl_);
    return el;
  };

  LiveDisplay.prototype.dispose = function dispose() {
    this.contentEl_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Check the duration to see if the LiveDisplay should be showing or not. Then show/hide
   * it accordingly
   *
   * @param {EventTarget~Event} [event]
   *        The {@link Player#durationchange} event that caused this function to run.
   *
   * @listens Player#durationchange
   */


  LiveDisplay.prototype.updateShowing = function updateShowing(event) {
    if (this.player().duration() === Infinity) {
      this.show();
    } else {
      this.hide();
    }
  };

  return LiveDisplay;
}(Component);

Component.registerComponent('LiveDisplay', LiveDisplay);

/**
 * @file slider.js
 */
/**
 * The base functionality for a slider. Can be vertical or horizontal.
 * For instance the volume bar or the seek bar on a video is a slider.
 *
 * @extends Component
 */

var Slider = function (_Component) {
  inherits(Slider, _Component);

  /**
   * Create an instance of this class
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function Slider(player, options) {
    classCallCheck(this, Slider);

    // Set property names to bar to match with the child Slider class is looking for
    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.bar = _this.getChild(_this.options_.barName);

    // Set a horizontal or vertical class on the slider depending on the slider type
    _this.vertical(!!_this.options_.vertical);

    _this.enable();
    return _this;
  }

  /**
   * Are controls are currently enabled for this slider or not.
   *
   * @return {boolean}
   *         true if controls are enabled, false otherwise
   */


  Slider.prototype.enabled = function enabled() {
    return this.enabled_;
  };

  /**
   * Enable controls for this slider if they are disabled
   */


  Slider.prototype.enable = function enable() {
    if (this.enabled()) {
      return;
    }

    this.on('mousedown', this.handleMouseDown);
    this.on('touchstart', this.handleMouseDown);
    this.on('focus', this.handleFocus);
    this.on('blur', this.handleBlur);
    this.on('click', this.handleClick);

    this.on(this.player_, 'controlsvisible', this.update);

    if (this.playerEvent) {
      this.on(this.player_, this.playerEvent, this.update);
    }

    this.removeClass('disabled');
    this.setAttribute('tabindex', 0);

    this.enabled_ = true;
  };

  /**
   * Disable controls for this slider if they are enabled
   */


  Slider.prototype.disable = function disable() {
    if (!this.enabled()) {
      return;
    }
    var doc = this.bar.el_.ownerDocument;

    this.off('mousedown', this.handleMouseDown);
    this.off('touchstart', this.handleMouseDown);
    this.off('focus', this.handleFocus);
    this.off('blur', this.handleBlur);
    this.off('click', this.handleClick);
    this.off(this.player_, 'controlsvisible', this.update);
    this.off(doc, 'mousemove', this.handleMouseMove);
    this.off(doc, 'mouseup', this.handleMouseUp);
    this.off(doc, 'touchmove', this.handleMouseMove);
    this.off(doc, 'touchend', this.handleMouseUp);
    this.removeAttribute('tabindex');

    this.addClass('disabled');

    if (this.playerEvent) {
      this.off(this.player_, this.playerEvent, this.update);
    }
    this.enabled_ = false;
  };

  /**
   * Create the `Button`s DOM element.
   *
   * @param {string} type
   *        Type of element to create.
   *
   * @param {Object} [props={}]
   *        List of properties in Object form.
   *
   * @param {Object} [attributes={}]
   *        list of attributes in Object form.
   *
   * @return {Element}
   *         The element that gets created.
   */


  Slider.prototype.createEl = function createEl$$1(type) {
    var props = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    var attributes = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : {};

    // Add the slider element class to all sub classes
    props.className = props.className + ' vjs-slider';
    props = assign({
      tabIndex: 0
    }, props);

    attributes = assign({
      'role': 'slider',
      'aria-valuenow': 0,
      'aria-valuemin': 0,
      'aria-valuemax': 100,
      'tabIndex': 0
    }, attributes);

    return _Component.prototype.createEl.call(this, type, props, attributes);
  };

  /**
   * Handle `mousedown` or `touchstart` events on the `Slider`.
   *
   * @param {EventTarget~Event} event
   *        `mousedown` or `touchstart` event that triggered this function
   *
   * @listens mousedown
   * @listens touchstart
   * @fires Slider#slideractive
   */


  Slider.prototype.handleMouseDown = function handleMouseDown(event) {
    var doc = this.bar.el_.ownerDocument;

    if (event.type === 'mousedown') {
      event.preventDefault();
    }
    // Do not call preventDefault() on touchstart in Chrome
    // to avoid console warnings. Use a 'touch-action: none' style
    // instead to prevent unintented scrolling.
    // https://developers.google.com/web/updates/2017/01/scrolling-intervention
    if (event.type === 'touchstart' && !IS_CHROME) {
      event.preventDefault();
    }
    blockTextSelection();

    this.addClass('vjs-sliding');
    /**
     * Triggered when the slider is in an active state
     *
     * @event Slider#slideractive
     * @type {EventTarget~Event}
     */
    this.trigger('slideractive');

    this.on(doc, 'mousemove', this.handleMouseMove);
    this.on(doc, 'mouseup', this.handleMouseUp);
    this.on(doc, 'touchmove', this.handleMouseMove);
    this.on(doc, 'touchend', this.handleMouseUp);

    this.handleMouseMove(event);
  };

  /**
   * Handle the `mousemove`, `touchmove`, and `mousedown` events on this `Slider`.
   * The `mousemove` and `touchmove` events will only only trigger this function during
   * `mousedown` and `touchstart`. This is due to {@link Slider#handleMouseDown} and
   * {@link Slider#handleMouseUp}.
   *
   * @param {EventTarget~Event} event
   *        `mousedown`, `mousemove`, `touchstart`, or `touchmove` event that triggered
   *        this function
   *
   * @listens mousemove
   * @listens touchmove
   */


  Slider.prototype.handleMouseMove = function handleMouseMove(event) {};

  /**
   * Handle `mouseup` or `touchend` events on the `Slider`.
   *
   * @param {EventTarget~Event} event
   *        `mouseup` or `touchend` event that triggered this function.
   *
   * @listens touchend
   * @listens mouseup
   * @fires Slider#sliderinactive
   */


  Slider.prototype.handleMouseUp = function handleMouseUp() {
    var doc = this.bar.el_.ownerDocument;

    unblockTextSelection();

    this.removeClass('vjs-sliding');
    /**
     * Triggered when the slider is no longer in an active state.
     *
     * @event Slider#sliderinactive
     * @type {EventTarget~Event}
     */
    this.trigger('sliderinactive');

    this.off(doc, 'mousemove', this.handleMouseMove);
    this.off(doc, 'mouseup', this.handleMouseUp);
    this.off(doc, 'touchmove', this.handleMouseMove);
    this.off(doc, 'touchend', this.handleMouseUp);

    this.update();
  };

  /**
   * Update the progress bar of the `Slider`.
   *
   * @returns {number}
   *          The percentage of progress the progress bar represents as a
   *          number from 0 to 1.
   */


  Slider.prototype.update = function update() {

    // In VolumeBar init we have a setTimeout for update that pops and update
    // to the end of the execution stack. The player is destroyed before then
    // update will cause an error
    if (!this.el_) {
      return;
    }

    // If scrubbing, we could use a cached value to make the handle keep up
    // with the user's mouse. On HTML5 browsers scrubbing is really smooth, but
    // some flash players are slow, so we might want to utilize this later.
    // var progress =  (this.player_.scrubbing()) ? this.player_.getCache().currentTime / this.player_.duration() : this.player_.currentTime() / this.player_.duration();
    var progress = this.getPercent();
    var bar = this.bar;

    // If there's no bar...
    if (!bar) {
      return;
    }

    // Protect against no duration and other division issues
    if (typeof progress !== 'number' || progress !== progress || progress < 0 || progress === Infinity) {
      progress = 0;
    }

    // Convert to a percentage for setting
    var percentage = (progress * 100).toFixed(2) + '%';
    var style = bar.el().style;

    // Set the new bar width or height
    if (this.vertical()) {
      style.height = percentage;
    } else {
      style.width = percentage;
    }

    return progress;
  };

  /**
   * Calculate distance for slider
   *
   * @param {EventTarget~Event} event
   *        The event that caused this function to run.
   *
   * @return {number}
   *         The current position of the Slider.
   *         - postition.x for vertical `Slider`s
   *         - postition.y for horizontal `Slider`s
   */


  Slider.prototype.calculateDistance = function calculateDistance(event) {
    var position = getPointerPosition(this.el_, event);

    if (this.vertical()) {
      return position.y;
    }
    return position.x;
  };

  /**
   * Handle a `focus` event on this `Slider`.
   *
   * @param {EventTarget~Event} event
   *        The `focus` event that caused this function to run.
   *
   * @listens focus
   */


  Slider.prototype.handleFocus = function handleFocus() {
    this.on(this.bar.el_.ownerDocument, 'keydown', this.handleKeyPress);
  };

  /**
   * Handle a `keydown` event on the `Slider`. Watches for left, rigth, up, and down
   * arrow keys. This function will only be called when the slider has focus. See
   * {@link Slider#handleFocus} and {@link Slider#handleBlur}.
   *
   * @param {EventTarget~Event} event
   *        the `keydown` event that caused this function to run.
   *
   * @listens keydown
   */


  Slider.prototype.handleKeyPress = function handleKeyPress(event) {
    // Left and Down Arrows
    if (event.which === 37 || event.which === 40) {
      event.preventDefault();
      this.stepBack();

      // Up and Right Arrows
    } else if (event.which === 38 || event.which === 39) {
      event.preventDefault();
      this.stepForward();
    }
  };

  /**
   * Handle a `blur` event on this `Slider`.
   *
   * @param {EventTarget~Event} event
   *        The `blur` event that caused this function to run.
   *
   * @listens blur
   */

  Slider.prototype.handleBlur = function handleBlur() {
    this.off(this.bar.el_.ownerDocument, 'keydown', this.handleKeyPress);
  };

  /**
   * Listener for click events on slider, used to prevent clicks
   *   from bubbling up to parent elements like button menus.
   *
   * @param {Object} event
   *        Event that caused this object to run
   */


  Slider.prototype.handleClick = function handleClick(event) {
    event.stopImmediatePropagation();
    event.preventDefault();
  };

  /**
   * Get/set if slider is horizontal for vertical
   *
   * @param {boolean} [bool]
   *        - true if slider is vertical,
   *        - false is horizontal
   *
   * @return {boolean}
   *         - true if slider is vertical, and getting
   *         - false if the slider is horizontal, and getting
   */


  Slider.prototype.vertical = function vertical(bool) {
    if (bool === undefined) {
      return this.vertical_ || false;
    }

    this.vertical_ = !!bool;

    if (this.vertical_) {
      this.addClass('vjs-slider-vertical');
    } else {
      this.addClass('vjs-slider-horizontal');
    }
  };

  return Slider;
}(Component);

Component.registerComponent('Slider', Slider);

/**
 * @file load-progress-bar.js
 */
/**
 * Shows loading progress
 *
 * @extends Component
 */

var LoadProgressBar = function (_Component) {
  inherits(LoadProgressBar, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function LoadProgressBar(player, options) {
    classCallCheck(this, LoadProgressBar);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.partEls_ = [];
    _this.on(player, 'progress', _this.update);
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  LoadProgressBar.prototype.createEl = function createEl$$1() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-load-progress',
      innerHTML: '<span class="vjs-control-text"><span>' + this.localize('Loaded') + '</span>: 0%</span>'
    });
  };

  LoadProgressBar.prototype.dispose = function dispose() {
    this.partEls_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Update progress bar
   *
   * @param {EventTarget~Event} [event]
   *        The `progress` event that caused this function to run.
   *
   * @listens Player#progress
   */


  LoadProgressBar.prototype.update = function update(event) {
    var buffered = this.player_.buffered();
    var duration = this.player_.duration();
    var bufferedEnd = this.player_.bufferedEnd();
    var children = this.partEls_;

    // get the percent width of a time compared to the total end
    var percentify = function percentify(time, end) {
      // no NaN
      var percent = time / end || 0;

      return (percent >= 1 ? 1 : percent) * 100 + '%';
    };

    // update the width of the progress bar
    this.el_.style.width = percentify(bufferedEnd, duration);

    // add child elements to represent the individual buffered time ranges
    for (var i = 0; i < buffered.length; i++) {
      var start = buffered.start(i);
      var end = buffered.end(i);
      var part = children[i];

      if (!part) {
        part = this.el_.appendChild(createEl());
        children[i] = part;
      }

      // set the percent based on the width of the progress bar (bufferedEnd)
      part.style.left = percentify(start, bufferedEnd);
      part.style.width = percentify(end - start, bufferedEnd);
    }

    // remove unused buffered range elements
    for (var _i = children.length; _i > buffered.length; _i--) {
      this.el_.removeChild(children[_i - 1]);
    }
    children.length = buffered.length;
  };

  return LoadProgressBar;
}(Component);

Component.registerComponent('LoadProgressBar', LoadProgressBar);

/**
 * @file time-tooltip.js
 */
/**
 * Time tooltips display a time above the progress bar.
 *
 * @extends Component
 */

var TimeTooltip = function (_Component) {
  inherits(TimeTooltip, _Component);

  function TimeTooltip() {
    classCallCheck(this, TimeTooltip);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the time tooltip DOM element
   *
   * @return {Element}
   *         The element that was created.
   */
  TimeTooltip.prototype.createEl = function createEl$$1() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-time-tooltip'
    });
  };

  /**
   * Updates the position of the time tooltip relative to the `SeekBar`.
   *
   * @param {Object} seekBarRect
   *        The `ClientRect` for the {@link SeekBar} element.
   *
   * @param {number} seekBarPoint
   *        A number from 0 to 1, representing a horizontal reference point
   *        from the left edge of the {@link SeekBar}
   */


  TimeTooltip.prototype.update = function update(seekBarRect, seekBarPoint, content) {
    var tooltipRect = getBoundingClientRect(this.el_);
    var playerRect = getBoundingClientRect(this.player_.el());
    var seekBarPointPx = seekBarRect.width * seekBarPoint;

    // do nothing if either rect isn't available
    // for example, if the player isn't in the DOM for testing
    if (!playerRect || !tooltipRect) {
      return;
    }

    // This is the space left of the `seekBarPoint` available within the bounds
    // of the player. We calculate any gap between the left edge of the player
    // and the left edge of the `SeekBar` and add the number of pixels in the
    // `SeekBar` before hitting the `seekBarPoint`
    var spaceLeftOfPoint = seekBarRect.left - playerRect.left + seekBarPointPx;

    // This is the space right of the `seekBarPoint` available within the bounds
    // of the player. We calculate the number of pixels from the `seekBarPoint`
    // to the right edge of the `SeekBar` and add to that any gap between the
    // right edge of the `SeekBar` and the player.
    var spaceRightOfPoint = seekBarRect.width - seekBarPointPx + (playerRect.right - seekBarRect.right);

    // This is the number of pixels by which the tooltip will need to be pulled
    // further to the right to center it over the `seekBarPoint`.
    var pullTooltipBy = tooltipRect.width / 2;

    // Adjust the `pullTooltipBy` distance to the left or right depending on
    // the results of the space calculations above.
    if (spaceLeftOfPoint < pullTooltipBy) {
      pullTooltipBy += pullTooltipBy - spaceLeftOfPoint;
    } else if (spaceRightOfPoint < pullTooltipBy) {
      pullTooltipBy = spaceRightOfPoint;
    }

    // Due to the imprecision of decimal/ratio based calculations and varying
    // rounding behaviors, there are cases where the spacing adjustment is off
    // by a pixel or two. This adds insurance to these calculations.
    if (pullTooltipBy < 0) {
      pullTooltipBy = 0;
    } else if (pullTooltipBy > tooltipRect.width) {
      pullTooltipBy = tooltipRect.width;
    }

    this.el_.style.right = '-' + pullTooltipBy + 'px';
    textContent(this.el_, content);
  };

  return TimeTooltip;
}(Component);

Component.registerComponent('TimeTooltip', TimeTooltip);

/**
 * @file play-progress-bar.js
 */
/**
 * Used by {@link SeekBar} to display media playback progress as part of the
 * {@link ProgressControl}.
 *
 * @extends Component
 */

var PlayProgressBar = function (_Component) {
  inherits(PlayProgressBar, _Component);

  function PlayProgressBar() {
    classCallCheck(this, PlayProgressBar);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the the DOM element for this class.
   *
   * @return {Element}
   *         The element that was created.
   */
  PlayProgressBar.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-play-progress vjs-slider-bar',
      innerHTML: '<span class="vjs-control-text"><span>' + this.localize('Progress') + '</span>: 0%</span>'
    });
  };

  /**
   * Enqueues updates to its own DOM as well as the DOM of its
   * {@link TimeTooltip} child.
   *
   * @param {Object} seekBarRect
   *        The `ClientRect` for the {@link SeekBar} element.
   *
   * @param {number} seekBarPoint
   *        A number from 0 to 1, representing a horizontal reference point
   *        from the left edge of the {@link SeekBar}
   */


  PlayProgressBar.prototype.update = function update(seekBarRect, seekBarPoint) {
    var _this2 = this;

    // If there is an existing rAF ID, cancel it so we don't over-queue.
    if (this.rafId_) {
      this.cancelAnimationFrame(this.rafId_);
    }

    this.rafId_ = this.requestAnimationFrame(function () {
      var time = _this2.player_.scrubbing() ? _this2.player_.getCache().currentTime : _this2.player_.currentTime();

      var content = formatTime(time, _this2.player_.duration());
      var timeTooltip = _this2.getChild('timeTooltip');

      if (timeTooltip) {
        timeTooltip.update(seekBarRect, seekBarPoint, content);
      }
    });
  };

  return PlayProgressBar;
}(Component);

/**
 * Default options for {@link PlayProgressBar}.
 *
 * @type {Object}
 * @private
 */


PlayProgressBar.prototype.options_ = {
  children: []
};

// Time tooltips should not be added to a player on mobile devices or IE8
if ((!IE_VERSION || IE_VERSION > 8) && !IS_IOS && !IS_ANDROID) {
  PlayProgressBar.prototype.options_.children.push('timeTooltip');
}

Component.registerComponent('PlayProgressBar', PlayProgressBar);

/**
 * @file mouse-time-display.js
 */
/**
 * The {@link MouseTimeDisplay} component tracks mouse movement over the
 * {@link ProgressControl}. It displays an indicator and a {@link TimeTooltip}
 * indicating the time which is represented by a given point in the
 * {@link ProgressControl}.
 *
 * @extends Component
 */

var MouseTimeDisplay = function (_Component) {
  inherits(MouseTimeDisplay, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The {@link Player} that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function MouseTimeDisplay(player, options) {
    classCallCheck(this, MouseTimeDisplay);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.update = throttle(bind(_this, _this.update), 25);
    return _this;
  }

  /**
   * Create the DOM element for this class.
   *
   * @return {Element}
   *         The element that was created.
   */


  MouseTimeDisplay.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-mouse-display'
    });
  };

  /**
   * Enqueues updates to its own DOM as well as the DOM of its
   * {@link TimeTooltip} child.
   *
   * @param {Object} seekBarRect
   *        The `ClientRect` for the {@link SeekBar} element.
   *
   * @param {number} seekBarPoint
   *        A number from 0 to 1, representing a horizontal reference point
   *        from the left edge of the {@link SeekBar}
   */


  MouseTimeDisplay.prototype.update = function update(seekBarRect, seekBarPoint) {
    var _this2 = this;

    // If there is an existing rAF ID, cancel it so we don't over-queue.
    if (this.rafId_) {
      this.cancelAnimationFrame(this.rafId_);
    }

    this.rafId_ = this.requestAnimationFrame(function () {
      var duration = _this2.player_.duration();
      var content = formatTime(seekBarPoint * duration, duration);

      _this2.el_.style.left = seekBarRect.width * seekBarPoint + 'px';
      _this2.getChild('timeTooltip').update(seekBarRect, seekBarPoint, content);
    });
  };

  return MouseTimeDisplay;
}(Component);

/**
 * Default options for `MouseTimeDisplay`
 *
 * @type {Object}
 * @private
 */


MouseTimeDisplay.prototype.options_ = {
  children: ['timeTooltip']
};

Component.registerComponent('MouseTimeDisplay', MouseTimeDisplay);

/**
 * @file seek-bar.js
 */
// The number of seconds the `step*` functions move the timeline.
var STEP_SECONDS = 5;

// The interval at which the bar should update as it progresses.
var UPDATE_REFRESH_INTERVAL = 30;

/**
 * Seek bar and container for the progress bars. Uses {@link PlayProgressBar}
 * as its `bar`.
 *
 * @extends Slider
 */

var SeekBar = function (_Slider) {
  inherits(SeekBar, _Slider);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function SeekBar(player, options) {
    classCallCheck(this, SeekBar);

    var _this = possibleConstructorReturn(this, _Slider.call(this, player, options));

    _this.setEventHandlers_();
    return _this;
  }

  /**
   * Sets the event handlers
   *
   * @private
   */


  SeekBar.prototype.setEventHandlers_ = function setEventHandlers_() {
    var _this2 = this;

    this.update = throttle(bind(this, this.update), UPDATE_REFRESH_INTERVAL);

    this.on(this.player_, 'timeupdate', this.update);
    this.on(this.player_, 'ended', this.handleEnded);

    // when playing, let's ensure we smoothly update the play progress bar
    // via an interval
    this.updateInterval = null;

    this.on(this.player_, ['playing'], function () {
      _this2.clearInterval(_this2.updateInterval);

      _this2.updateInterval = _this2.setInterval(function () {
        _this2.requestAnimationFrame(function () {
          _this2.update();
        });
      }, UPDATE_REFRESH_INTERVAL);
    });

    this.on(this.player_, ['ended', 'pause', 'waiting'], function () {
      _this2.clearInterval(_this2.updateInterval);
    });

    this.on(this.player_, ['timeupdate', 'ended'], this.update);
  };

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  SeekBar.prototype.createEl = function createEl$$1() {
    return _Slider.prototype.createEl.call(this, 'div', {
      className: 'vjs-progress-holder'
    }, {
      'aria-label': this.localize('Progress Bar')
    });
  };

  /**
   * This function updates the play progress bar and accessiblity
   * attributes to whatever is passed in.
   *
   * @param {number} currentTime
   *        The currentTime value that should be used for accessiblity
   *
   * @param {number} percent
   *        The percentage as a decimal that the bar should be filled from 0-1.
   *
   * @private
   */


  SeekBar.prototype.update_ = function update_(currentTime, percent) {
    var duration = this.player_.duration();

    // machine readable value of progress bar (percentage complete)
    this.el_.setAttribute('aria-valuenow', (percent * 100).toFixed(2));

    // human readable value of progress bar (time complete)
    this.el_.setAttribute('aria-valuetext', this.localize('progress bar timing: currentTime={1} duration={2}', [formatTime(currentTime, duration), formatTime(duration, duration)], '{1} of {2}'));

    // Update the `PlayProgressBar`.
    this.bar.update(getBoundingClientRect(this.el_), percent);
  };

  /**
   * Update the seek bar's UI.
   *
   * @param {EventTarget~Event} [event]
   *        The `timeupdate` or `ended` event that caused this to run.
   *
   * @listens Player#timeupdate
   *
   * @returns {number}
   *          The current percent at a number from 0-1
   */


  SeekBar.prototype.update = function update(event) {
    var percent = _Slider.prototype.update.call(this);

    this.update_(this.getCurrentTime_(), percent);
    return percent;
  };

  /**
   * Get the value of current time but allows for smooth scrubbing,
   * when player can't keep up.
   *
   * @return {number}
   *         The current time value to display
   *
   * @private
   */


  SeekBar.prototype.getCurrentTime_ = function getCurrentTime_() {
    return this.player_.scrubbing() ? this.player_.getCache().currentTime : this.player_.currentTime();
  };

  /**
   * We want the seek bar to be full on ended
   * no matter what the actual internal values are. so we force it.
   *
   * @param {EventTarget~Event} [event]
   *        The `timeupdate` or `ended` event that caused this to run.
   *
   * @listens Player#ended
   */


  SeekBar.prototype.handleEnded = function handleEnded(event) {
    this.update_(this.player_.duration(), 1);
  };

  /**
   * Get the percentage of media played so far.
   *
   * @return {number}
   *         The percentage of media played so far (0 to 1).
   */


  SeekBar.prototype.getPercent = function getPercent() {
    var percent = this.getCurrentTime_() / this.player_.duration();

    return percent >= 1 ? 1 : percent;
  };

  /**
   * Handle mouse down on seek bar
   *
   * @param {EventTarget~Event} event
   *        The `mousedown` event that caused this to run.
   *
   * @listens mousedown
   */


  SeekBar.prototype.handleMouseDown = function handleMouseDown(event) {
    if (!isSingleLeftClick(event)) {
      return;
    }

    // Stop event propagation to prevent double fire in progress-control.js
    event.stopPropagation();
    this.player_.scrubbing(true);

    this.videoWasPlaying = !this.player_.paused();
    this.player_.pause();

    _Slider.prototype.handleMouseDown.call(this, event);
  };

  /**
   * Handle mouse move on seek bar
   *
   * @param {EventTarget~Event} event
   *        The `mousemove` event that caused this to run.
   *
   * @listens mousemove
   */


  SeekBar.prototype.handleMouseMove = function handleMouseMove(event) {
    if (!isSingleLeftClick(event)) {
      return;
    }

    var newTime = this.calculateDistance(event) * this.player_.duration();

    // Don't let video end while scrubbing.
    if (newTime === this.player_.duration()) {
      newTime = newTime - 0.1;
    }

    // Set new time (tell player to seek to new time)
    this.player_.currentTime(newTime);
  };

  SeekBar.prototype.enable = function enable() {
    _Slider.prototype.enable.call(this);
    var mouseTimeDisplay = this.getChild('mouseTimeDisplay');

    if (!mouseTimeDisplay) {
      return;
    }

    mouseTimeDisplay.show();
  };

  SeekBar.prototype.disable = function disable() {
    _Slider.prototype.disable.call(this);
    var mouseTimeDisplay = this.getChild('mouseTimeDisplay');

    if (!mouseTimeDisplay) {
      return;
    }

    mouseTimeDisplay.hide();
  };

  /**
   * Handle mouse up on seek bar
   *
   * @param {EventTarget~Event} event
   *        The `mouseup` event that caused this to run.
   *
   * @listens mouseup
   */


  SeekBar.prototype.handleMouseUp = function handleMouseUp(event) {
    _Slider.prototype.handleMouseUp.call(this, event);

    // Stop event propagation to prevent double fire in progress-control.js
    if (event) {
      event.stopPropagation();
    }
    this.player_.scrubbing(false);

    /**
     * Trigger timeupdate because we're done seeking and the time has changed.
     * This is particularly useful for if the player is paused to time the time displays.
     *
     * @event Tech#timeupdate
     * @type {EventTarget~Event}
     */
    this.player_.trigger({ type: 'timeupdate', target: this, manuallyTriggered: true });
    if (this.videoWasPlaying) {
      silencePromise(this.player_.play());
    }
  };

  /**
   * Move more quickly fast forward for keyboard-only users
   */


  SeekBar.prototype.stepForward = function stepForward() {
    this.player_.currentTime(this.player_.currentTime() + STEP_SECONDS);
  };

  /**
   * Move more quickly rewind for keyboard-only users
   */


  SeekBar.prototype.stepBack = function stepBack() {
    this.player_.currentTime(this.player_.currentTime() - STEP_SECONDS);
  };

  /**
   * Toggles the playback state of the player
   * This gets called when enter or space is used on the seekbar
   *
   * @param {EventTarget~Event} event
   *        The `keydown` event that caused this function to be called
   *
   */


  SeekBar.prototype.handleAction = function handleAction(event) {
    if (this.player_.paused()) {
      this.player_.play();
    } else {
      this.player_.pause();
    }
  };

  /**
   * Called when this SeekBar has focus and a key gets pressed down. By
   * default it will call `this.handleAction` when the key is space or enter.
   *
   * @param {EventTarget~Event} event
   *        The `keydown` event that caused this function to be called.
   *
   * @listens keydown
   */


  SeekBar.prototype.handleKeyPress = function handleKeyPress(event) {

    // Support Space (32) or Enter (13) key operation to fire a click event
    if (event.which === 32 || event.which === 13) {
      event.preventDefault();
      this.handleAction(event);
    } else if (_Slider.prototype.handleKeyPress) {

      // Pass keypress handling up for unsupported keys
      _Slider.prototype.handleKeyPress.call(this, event);
    }
  };

  return SeekBar;
}(Slider);

/**
 * Default options for the `SeekBar`
 *
 * @type {Object}
 * @private
 */


SeekBar.prototype.options_ = {
  children: ['loadProgressBar', 'playProgressBar'],
  barName: 'playProgressBar'
};

// MouseTimeDisplay tooltips should not be added to a player on mobile devices or IE8
if ((!IE_VERSION || IE_VERSION > 8) && !IS_IOS && !IS_ANDROID) {
  SeekBar.prototype.options_.children.splice(1, 0, 'mouseTimeDisplay');
}

/**
 * Call the update event for this Slider when this event happens on the player.
 *
 * @type {string}
 */
SeekBar.prototype.playerEvent = 'timeupdate';

Component.registerComponent('SeekBar', SeekBar);

/**
 * @file progress-control.js
 */
/**
 * The Progress Control component contains the seek bar, load progress,
 * and play progress.
 *
 * @extends Component
 */

var ProgressControl = function (_Component) {
  inherits(ProgressControl, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function ProgressControl(player, options) {
    classCallCheck(this, ProgressControl);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.handleMouseMove = throttle(bind(_this, _this.handleMouseMove), 25);
    _this.throttledHandleMouseSeek = throttle(bind(_this, _this.handleMouseSeek), 25);

    _this.enable();
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  ProgressControl.prototype.createEl = function createEl$$1() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-progress-control vjs-control'
    });
  };

  /**
   * When the mouse moves over the `ProgressControl`, the pointer position
   * gets passed down to the `MouseTimeDisplay` component.
   *
   * @param {EventTarget~Event} event
   *        The `mousemove` event that caused this function to run.
   *
   * @listen mousemove
   */


  ProgressControl.prototype.handleMouseMove = function handleMouseMove(event) {
    var seekBar = this.getChild('seekBar');

    if (seekBar) {
      var mouseTimeDisplay = seekBar.getChild('mouseTimeDisplay');
      var seekBarEl = seekBar.el();
      var seekBarRect = getBoundingClientRect(seekBarEl);
      var seekBarPoint = getPointerPosition(seekBarEl, event).x;

      // The default skin has a gap on either side of the `SeekBar`. This means
      // that it's possible to trigger this behavior outside the boundaries of
      // the `SeekBar`. This ensures we stay within it at all times.
      if (seekBarPoint > 1) {
        seekBarPoint = 1;
      } else if (seekBarPoint < 0) {
        seekBarPoint = 0;
      }

      if (mouseTimeDisplay) {
        mouseTimeDisplay.update(seekBarRect, seekBarPoint);
      }
    }
  };

  /**
   * A throttled version of the {@link ProgressControl#handleMouseSeek} listener.
   *
   * @method ProgressControl#throttledHandleMouseSeek
   * @param {EventTarget~Event} event
   *        The `mousemove` event that caused this function to run.
   *
   * @listen mousemove
   * @listen touchmove
   */

  /**
   * Handle `mousemove` or `touchmove` events on the `ProgressControl`.
   *
   * @param {EventTarget~Event} event
   *        `mousedown` or `touchstart` event that triggered this function
   *
   * @listens mousemove
   * @listens touchmove
   */


  ProgressControl.prototype.handleMouseSeek = function handleMouseSeek(event) {
    var seekBar = this.getChild('seekBar');

    if (seekBar) {
      seekBar.handleMouseMove(event);
    }
  };

  /**
   * Are controls are currently enabled for this progress control.
   *
   * @return {boolean}
   *         true if controls are enabled, false otherwise
   */


  ProgressControl.prototype.enabled = function enabled() {
    return this.enabled_;
  };

  /**
   * Disable all controls on the progress control and its children
   */


  ProgressControl.prototype.disable = function disable() {
    this.children().forEach(function (child) {
      return child.disable && child.disable();
    });

    if (!this.enabled()) {
      return;
    }

    this.off(['mousedown', 'touchstart'], this.handleMouseDown);
    this.off(this.el_, 'mousemove', this.handleMouseMove);
    this.handleMouseUp();

    this.addClass('disabled');

    this.enabled_ = false;
  };

  /**
   * Enable all controls on the progress control and its children
   */


  ProgressControl.prototype.enable = function enable() {
    this.children().forEach(function (child) {
      return child.enable && child.enable();
    });

    if (this.enabled()) {
      return;
    }

    this.on(['mousedown', 'touchstart'], this.handleMouseDown);
    this.on(this.el_, 'mousemove', this.handleMouseMove);
    this.removeClass('disabled');

    this.enabled_ = true;
  };

  /**
   * Handle `mousedown` or `touchstart` events on the `ProgressControl`.
   *
   * @param {EventTarget~Event} event
   *        `mousedown` or `touchstart` event that triggered this function
   *
   * @listens mousedown
   * @listens touchstart
   */


  ProgressControl.prototype.handleMouseDown = function handleMouseDown(event) {
    var doc = this.el_.ownerDocument;
    var seekBar = this.getChild('seekBar');

    if (seekBar) {
      seekBar.handleMouseDown(event);
    }

    this.on(doc, 'mousemove', this.throttledHandleMouseSeek);
    this.on(doc, 'touchmove', this.throttledHandleMouseSeek);
    this.on(doc, 'mouseup', this.handleMouseUp);
    this.on(doc, 'touchend', this.handleMouseUp);
  };

  /**
   * Handle `mouseup` or `touchend` events on the `ProgressControl`.
   *
   * @param {EventTarget~Event} event
   *        `mouseup` or `touchend` event that triggered this function.
   *
   * @listens touchend
   * @listens mouseup
   */


  ProgressControl.prototype.handleMouseUp = function handleMouseUp(event) {
    var doc = this.el_.ownerDocument;
    var seekBar = this.getChild('seekBar');

    if (seekBar) {
      seekBar.handleMouseUp(event);
    }

    this.off(doc, 'mousemove', this.throttledHandleMouseSeek);
    this.off(doc, 'touchmove', this.throttledHandleMouseSeek);
    this.off(doc, 'mouseup', this.handleMouseUp);
    this.off(doc, 'touchend', this.handleMouseUp);
  };

  return ProgressControl;
}(Component);

/**
 * Default options for `ProgressControl`
 *
 * @type {Object}
 * @private
 */


ProgressControl.prototype.options_ = {
  children: ['seekBar']
};

Component.registerComponent('ProgressControl', ProgressControl);

/**
 * @file fullscreen-toggle.js
 */
/**
 * Toggle fullscreen video
 *
 * @extends Button
 */

var FullscreenToggle = function (_Button) {
  inherits(FullscreenToggle, _Button);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function FullscreenToggle(player, options) {
    classCallCheck(this, FullscreenToggle);

    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    _this.on(player, 'fullscreenchange', _this.handleFullscreenChange);

    if (document_1[FullscreenApi.fullscreenEnabled] === false) {
      _this.disable();
    }
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  FullscreenToggle.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-fullscreen-control ' + _Button.prototype.buildCSSClass.call(this);
  };

  /**
   * Handles fullscreenchange on the player and change control text accordingly.
   *
   * @param {EventTarget~Event} [event]
   *        The {@link Player#fullscreenchange} event that caused this function to be
   *        called.
   *
   * @listens Player#fullscreenchange
   */


  FullscreenToggle.prototype.handleFullscreenChange = function handleFullscreenChange(event) {
    if (this.player_.isFullscreen()) {
      this.controlText('Non-Fullscreen');
    } else {
      this.controlText('Fullscreen');
    }
  };

  /**
   * This gets called when an `FullscreenToggle` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  FullscreenToggle.prototype.handleClick = function handleClick(event) {
    if (!this.player_.isFullscreen()) {
      this.player_.requestFullscreen();
    } else {
      this.player_.exitFullscreen();
    }
  };

  return FullscreenToggle;
}(Button);

/**
 * The text that should display over the `FullscreenToggle`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


FullscreenToggle.prototype.controlText_ = 'Fullscreen';

Component.registerComponent('FullscreenToggle', FullscreenToggle);

/**
 * Check if volume control is supported and if it isn't hide the
 * `Component` that was passed  using the `vjs-hidden` class.
 *
 * @param {Component} self
 *        The component that should be hidden if volume is unsupported
 *
 * @param {Player} player
 *        A reference to the player
 *
 * @private
 */
var checkVolumeSupport = function checkVolumeSupport(self, player) {
  // hide volume controls when they're not supported by the current tech
  if (player.tech_ && !player.tech_.featuresVolumeControl) {
    self.addClass('vjs-hidden');
  }

  self.on(player, 'loadstart', function () {
    if (!player.tech_.featuresVolumeControl) {
      self.addClass('vjs-hidden');
    } else {
      self.removeClass('vjs-hidden');
    }
  });
};

/**
 * @file volume-level.js
 */
/**
 * Shows volume level
 *
 * @extends Component
 */

var VolumeLevel = function (_Component) {
  inherits(VolumeLevel, _Component);

  function VolumeLevel() {
    classCallCheck(this, VolumeLevel);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */
  VolumeLevel.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-volume-level',
      innerHTML: '<span class="vjs-control-text"></span>'
    });
  };

  return VolumeLevel;
}(Component);

Component.registerComponent('VolumeLevel', VolumeLevel);

/**
 * @file volume-bar.js
 */
// Required children
/**
 * The bar that contains the volume level and can be clicked on to adjust the level
 *
 * @extends Slider
 */

var VolumeBar = function (_Slider) {
  inherits(VolumeBar, _Slider);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function VolumeBar(player, options) {
    classCallCheck(this, VolumeBar);

    var _this = possibleConstructorReturn(this, _Slider.call(this, player, options));

    _this.on('slideractive', _this.updateLastVolume_);
    _this.on(player, 'volumechange', _this.updateARIAAttributes);
    player.ready(function () {
      return _this.updateARIAAttributes();
    });
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  VolumeBar.prototype.createEl = function createEl$$1() {
    return _Slider.prototype.createEl.call(this, 'div', {
      className: 'vjs-volume-bar vjs-slider-bar'
    }, {
      'aria-label': this.localize('Volume Level'),
      'aria-live': 'polite'
    });
  };

  /**
   * Handle mouse down on volume bar
   *
   * @param {EventTarget~Event} event
   *        The `mousedown` event that caused this to run.
   *
   * @listens mousedown
   */


  VolumeBar.prototype.handleMouseDown = function handleMouseDown(event) {
    if (!isSingleLeftClick(event)) {
      return;
    }

    _Slider.prototype.handleMouseDown.call(this, event);
  };

  /**
   * Handle movement events on the {@link VolumeMenuButton}.
   *
   * @param {EventTarget~Event} event
   *        The event that caused this function to run.
   *
   * @listens mousemove
   */


  VolumeBar.prototype.handleMouseMove = function handleMouseMove(event) {
    if (!isSingleLeftClick(event)) {
      return;
    }

    this.checkMuted();
    this.player_.volume(this.calculateDistance(event));
  };

  /**
   * If the player is muted unmute it.
   */


  VolumeBar.prototype.checkMuted = function checkMuted() {
    if (this.player_.muted()) {
      this.player_.muted(false);
    }
  };

  /**
   * Get percent of volume level
   *
   * @return {number}
   *         Volume level percent as a decimal number.
   */


  VolumeBar.prototype.getPercent = function getPercent() {
    if (this.player_.muted()) {
      return 0;
    }
    return this.player_.volume();
  };

  /**
   * Increase volume level for keyboard users
   */


  VolumeBar.prototype.stepForward = function stepForward() {
    this.checkMuted();
    this.player_.volume(this.player_.volume() + 0.1);
  };

  /**
   * Decrease volume level for keyboard users
   */


  VolumeBar.prototype.stepBack = function stepBack() {
    this.checkMuted();
    this.player_.volume(this.player_.volume() - 0.1);
  };

  /**
   * Update ARIA accessibility attributes
   *
   * @param {EventTarget~Event} [event]
   *        The `volumechange` event that caused this function to run.
   *
   * @listens Player#volumechange
   */


  VolumeBar.prototype.updateARIAAttributes = function updateARIAAttributes(event) {
    var ariaValue = this.player_.muted() ? 0 : this.volumeAsPercentage_();

    this.el_.setAttribute('aria-valuenow', ariaValue);
    this.el_.setAttribute('aria-valuetext', ariaValue + '%');
  };

  /**
   * Returns the current value of the player volume as a percentage
   *
   * @private
   */


  VolumeBar.prototype.volumeAsPercentage_ = function volumeAsPercentage_() {
    return Math.round(this.player_.volume() * 100);
  };

  /**
   * When user starts dragging the VolumeBar, store the volume and listen for
   * the end of the drag. When the drag ends, if the volume was set to zero,
   * set lastVolume to the stored volume.
   *
   * @listens slideractive
   * @private
   */


  VolumeBar.prototype.updateLastVolume_ = function updateLastVolume_() {
    var _this2 = this;

    var volumeBeforeDrag = this.player_.volume();

    this.one('sliderinactive', function () {
      if (_this2.player_.volume() === 0) {
        _this2.player_.lastVolume_(volumeBeforeDrag);
      }
    });
  };

  return VolumeBar;
}(Slider);

/**
 * Default options for the `VolumeBar`
 *
 * @type {Object}
 * @private
 */


VolumeBar.prototype.options_ = {
  children: ['volumeLevel'],
  barName: 'volumeLevel'
};

/**
 * Call the update event for this Slider when this event happens on the player.
 *
 * @type {string}
 */
VolumeBar.prototype.playerEvent = 'volumechange';

Component.registerComponent('VolumeBar', VolumeBar);

/**
 * @file volume-control.js
 */
// Required children
/**
 * The component for controlling the volume level
 *
 * @extends Component
 */

var VolumeControl = function (_Component) {
  inherits(VolumeControl, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   */
  function VolumeControl(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, VolumeControl);

    options.vertical = options.vertical || false;

    // Pass the vertical option down to the VolumeBar if
    // the VolumeBar is turned on.
    if (typeof options.volumeBar === 'undefined' || isPlain(options.volumeBar)) {
      options.volumeBar = options.volumeBar || {};
      options.volumeBar.vertical = options.vertical;
    }

    // hide this control if volume support is missing
    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    checkVolumeSupport(_this, player);

    _this.throttledHandleMouseMove = throttle(bind(_this, _this.handleMouseMove), 25);

    _this.on('mousedown', _this.handleMouseDown);
    _this.on('touchstart', _this.handleMouseDown);

    // while the slider is active (the mouse has been pressed down and
    // is dragging) or in focus we do not want to hide the VolumeBar
    _this.on(_this.volumeBar, ['focus', 'slideractive'], function () {
      _this.volumeBar.addClass('vjs-slider-active');
      _this.addClass('vjs-slider-active');
      _this.trigger('slideractive');
    });

    _this.on(_this.volumeBar, ['blur', 'sliderinactive'], function () {
      _this.volumeBar.removeClass('vjs-slider-active');
      _this.removeClass('vjs-slider-active');
      _this.trigger('sliderinactive');
    });
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  VolumeControl.prototype.createEl = function createEl() {
    var orientationClass = 'vjs-volume-horizontal';

    if (this.options_.vertical) {
      orientationClass = 'vjs-volume-vertical';
    }

    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-volume-control vjs-control ' + orientationClass
    });
  };

  /**
   * Handle `mousedown` or `touchstart` events on the `VolumeControl`.
   *
   * @param {EventTarget~Event} event
   *        `mousedown` or `touchstart` event that triggered this function
   *
   * @listens mousedown
   * @listens touchstart
   */


  VolumeControl.prototype.handleMouseDown = function handleMouseDown(event) {
    var doc = this.el_.ownerDocument;

    this.on(doc, 'mousemove', this.throttledHandleMouseMove);
    this.on(doc, 'touchmove', this.throttledHandleMouseMove);
    this.on(doc, 'mouseup', this.handleMouseUp);
    this.on(doc, 'touchend', this.handleMouseUp);
  };

  /**
   * Handle `mouseup` or `touchend` events on the `VolumeControl`.
   *
   * @param {EventTarget~Event} event
   *        `mouseup` or `touchend` event that triggered this function.
   *
   * @listens touchend
   * @listens mouseup
   */


  VolumeControl.prototype.handleMouseUp = function handleMouseUp(event) {
    var doc = this.el_.ownerDocument;

    this.off(doc, 'mousemove', this.throttledHandleMouseMove);
    this.off(doc, 'touchmove', this.throttledHandleMouseMove);
    this.off(doc, 'mouseup', this.handleMouseUp);
    this.off(doc, 'touchend', this.handleMouseUp);
  };

  /**
   * Handle `mousedown` or `touchstart` events on the `VolumeControl`.
   *
   * @param {EventTarget~Event} event
   *        `mousedown` or `touchstart` event that triggered this function
   *
   * @listens mousedown
   * @listens touchstart
   */


  VolumeControl.prototype.handleMouseMove = function handleMouseMove(event) {
    this.volumeBar.handleMouseMove(event);
  };

  return VolumeControl;
}(Component);

/**
 * Default options for the `VolumeControl`
 *
 * @type {Object}
 * @private
 */


VolumeControl.prototype.options_ = {
  children: ['volumeBar']
};

Component.registerComponent('VolumeControl', VolumeControl);

/**
 * Check if muting volume is supported and if it isn't hide the mute toggle
 * button.
 *
 * @param {Component} self
 *        A reference to the mute toggle button
 *
 * @param {Player} player
 *        A reference to the player
 *
 * @private
 */
var checkMuteSupport = function checkMuteSupport(self, player) {
  // hide mute toggle button if it's not supported by the current tech
  if (player.tech_ && !player.tech_.featuresMuteControl) {
    self.addClass('vjs-hidden');
  }

  self.on(player, 'loadstart', function () {
    if (!player.tech_.featuresMuteControl) {
      self.addClass('vjs-hidden');
    } else {
      self.removeClass('vjs-hidden');
    }
  });
};

/**
 * @file mute-toggle.js
 */
/**
 * A button component for muting the audio.
 *
 * @extends Button
 */

var MuteToggle = function (_Button) {
  inherits(MuteToggle, _Button);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function MuteToggle(player, options) {
    classCallCheck(this, MuteToggle);

    // hide this control if volume support is missing
    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    checkMuteSupport(_this, player);

    _this.on(player, ['loadstart', 'volumechange'], _this.update);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  MuteToggle.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-mute-control ' + _Button.prototype.buildCSSClass.call(this);
  };

  /**
   * This gets called when an `MuteToggle` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  MuteToggle.prototype.handleClick = function handleClick(event) {
    var vol = this.player_.volume();
    var lastVolume = this.player_.lastVolume_();

    if (vol === 0) {
      var volumeToSet = lastVolume < 0.1 ? 0.1 : lastVolume;

      this.player_.volume(volumeToSet);
      this.player_.muted(false);
    } else {
      this.player_.muted(this.player_.muted() ? false : true);
    }
  };

  /**
   * Update the `MuteToggle` button based on the state of `volume` and `muted`
   * on the player.
   *
   * @param {EventTarget~Event} [event]
   *        The {@link Player#loadstart} event if this function was called
   *        through an event.
   *
   * @listens Player#loadstart
   * @listens Player#volumechange
   */


  MuteToggle.prototype.update = function update(event) {
    this.updateIcon_();
    this.updateControlText_();
  };

  /**
   * Update the appearance of the `MuteToggle` icon.
   *
   * Possible states (given `level` variable below):
   * - 0: crossed out
   * - 1: zero bars of volume
   * - 2: one bar of volume
   * - 3: two bars of volume
   *
   * @private
   */


  MuteToggle.prototype.updateIcon_ = function updateIcon_() {
    var vol = this.player_.volume();
    var level = 3;

    // in iOS when a player is loaded with muted attribute
    // and volume is changed with a native mute button
    // we want to make sure muted state is updated
    if (IS_IOS) {
      this.player_.muted(this.player_.tech_.el_.muted);
    }

    if (vol === 0 || this.player_.muted()) {
      level = 0;
    } else if (vol < 0.33) {
      level = 1;
    } else if (vol < 0.67) {
      level = 2;
    }

    // TODO improve muted icon classes
    for (var i = 0; i < 4; i++) {
      removeClass(this.el_, 'vjs-vol-' + i);
    }
    addClass(this.el_, 'vjs-vol-' + level);
  };

  /**
   * If `muted` has changed on the player, update the control text
   * (`title` attribute on `vjs-mute-control` element and content of
   * `vjs-control-text` element).
   *
   * @private
   */


  MuteToggle.prototype.updateControlText_ = function updateControlText_() {
    var soundOff = this.player_.muted() || this.player_.volume() === 0;
    var text = soundOff ? 'Unmute' : 'Mute';

    if (this.controlText() !== text) {
      this.controlText(text);
    }
  };

  return MuteToggle;
}(Button);

/**
 * The text that should display over the `MuteToggle`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


MuteToggle.prototype.controlText_ = 'Mute';

Component.registerComponent('MuteToggle', MuteToggle);

/**
 * @file volume-control.js
 */
// Required children
/**
 * A Component to contain the MuteToggle and VolumeControl so that
 * they can work together.
 *
 * @extends Component
 */

var VolumePanel = function (_Component) {
  inherits(VolumePanel, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   */
  function VolumePanel(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, VolumePanel);

    if (typeof options.inline !== 'undefined') {
      options.inline = options.inline;
    } else {
      options.inline = true;
    }

    // pass the inline option down to the VolumeControl as vertical if
    // the VolumeControl is on.
    if (typeof options.volumeControl === 'undefined' || isPlain(options.volumeControl)) {
      options.volumeControl = options.volumeControl || {};
      options.volumeControl.vertical = !options.inline;
    }

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.on(player, ['loadstart'], _this.volumePanelState_);

    // while the slider is active (the mouse has been pressed down and
    // is dragging) we do not want to hide the VolumeBar
    _this.on(_this.volumeControl, ['slideractive'], _this.sliderActive_);

    _this.on(_this.volumeControl, ['sliderinactive'], _this.sliderInactive_);
    return _this;
  }

  /**
   * Add vjs-slider-active class to the VolumePanel
   *
   * @listens VolumeControl#slideractive
   * @private
   */


  VolumePanel.prototype.sliderActive_ = function sliderActive_() {
    this.addClass('vjs-slider-active');
  };

  /**
   * Removes vjs-slider-active class to the VolumePanel
   *
   * @listens VolumeControl#sliderinactive
   * @private
   */


  VolumePanel.prototype.sliderInactive_ = function sliderInactive_() {
    this.removeClass('vjs-slider-active');
  };

  /**
   * Adds vjs-hidden or vjs-mute-toggle-only to the VolumePanel
   * depending on MuteToggle and VolumeControl state
   *
   * @listens Player#loadstart
   * @private
   */


  VolumePanel.prototype.volumePanelState_ = function volumePanelState_() {
    // hide volume panel if neither volume control or mute toggle
    // are displayed
    if (this.volumeControl.hasClass('vjs-hidden') && this.muteToggle.hasClass('vjs-hidden')) {
      this.addClass('vjs-hidden');
    }

    // if only mute toggle is visible we don't want
    // volume panel expanding when hovered or active
    if (this.volumeControl.hasClass('vjs-hidden') && !this.muteToggle.hasClass('vjs-hidden')) {
      this.addClass('vjs-mute-toggle-only');
    }
  };

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  VolumePanel.prototype.createEl = function createEl() {
    var orientationClass = 'vjs-volume-panel-horizontal';

    if (!this.options_.inline) {
      orientationClass = 'vjs-volume-panel-vertical';
    }

    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-volume-panel vjs-control ' + orientationClass
    });
  };

  return VolumePanel;
}(Component);

/**
 * Default options for the `VolumeControl`
 *
 * @type {Object}
 * @private
 */


VolumePanel.prototype.options_ = {
  children: ['muteToggle', 'volumeControl']
};

Component.registerComponent('VolumePanel', VolumePanel);

/**
 * @file menu.js
 */
/**
 * The Menu component is used to build popup menus, including subtitle and
 * captions selection menus.
 *
 * @extends Component
 */

var Menu = function (_Component) {
  inherits(Menu, _Component);

  /**
   * Create an instance of this class.
   *
   * @param {Player} player
   *        the player that this component should attach to
   *
   * @param {Object} [options]
   *        Object of option names and values
   *
   */
  function Menu(player, options) {
    classCallCheck(this, Menu);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    if (options) {
      _this.menuButton_ = options.menuButton;
    }

    _this.focusedChild_ = -1;

    _this.on('keydown', _this.handleKeyPress);
    return _this;
  }

  /**
   * Add a {@link MenuItem} to the menu.
   *
   * @param {Object|string} component
   *        The name or instance of the `MenuItem` to add.
   *
   */


  Menu.prototype.addItem = function addItem(component) {
    this.addChild(component);
    component.on('click', bind(this, function (event) {
      // Unpress the associated MenuButton, and move focus back to it
      if (this.menuButton_) {
        this.menuButton_.unpressButton();

        // don't focus menu button if item is a caption settings item
        // because focus will move elsewhere and it logs an error on IE8
        if (component.name() !== 'CaptionSettingsMenuItem') {
          this.menuButton_.focus();
        }
      }
    }));
  };

  /**
   * Create the `Menu`s DOM element.
   *
   * @return {Element}
   *         the element that was created
   */


  Menu.prototype.createEl = function createEl$$1() {
    var contentElType = this.options_.contentElType || 'ul';

    this.contentEl_ = createEl(contentElType, {
      className: 'vjs-menu-content'
    });

    this.contentEl_.setAttribute('role', 'menu');

    var el = _Component.prototype.createEl.call(this, 'div', {
      append: this.contentEl_,
      className: 'vjs-menu'
    });

    el.appendChild(this.contentEl_);

    // Prevent clicks from bubbling up. Needed for Menu Buttons,
    // where a click on the parent is significant
    on(el, 'click', function (event) {
      event.preventDefault();
      event.stopImmediatePropagation();
    });

    return el;
  };

  Menu.prototype.dispose = function dispose() {
    this.contentEl_ = null;

    _Component.prototype.dispose.call(this);
  };

  /**
   * Handle a `keydown` event on this menu. This listener is added in the constructor.
   *
   * @param {EventTarget~Event} event
   *        A `keydown` event that happened on the menu.
   *
   * @listens keydown
   */


  Menu.prototype.handleKeyPress = function handleKeyPress(event) {
    // Left and Down Arrows
    if (event.which === 37 || event.which === 40) {
      event.preventDefault();
      this.stepForward();

      // Up and Right Arrows
    } else if (event.which === 38 || event.which === 39) {
      event.preventDefault();
      this.stepBack();
    }
  };

  /**
   * Move to next (lower) menu item for keyboard users.
   */


  Menu.prototype.stepForward = function stepForward() {
    var stepChild = 0;

    if (this.focusedChild_ !== undefined) {
      stepChild = this.focusedChild_ + 1;
    }
    this.focus(stepChild);
  };

  /**
   * Move to previous (higher) menu item for keyboard users.
   */


  Menu.prototype.stepBack = function stepBack() {
    var stepChild = 0;

    if (this.focusedChild_ !== undefined) {
      stepChild = this.focusedChild_ - 1;
    }
    this.focus(stepChild);
  };

  /**
   * Set focus on a {@link MenuItem} in the `Menu`.
   *
   * @param {Object|string} [item=0]
   *        Index of child item set focus on.
   */


  Menu.prototype.focus = function focus() {
    var item = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 0;

    var children = this.children().slice();
    var haveTitle = children.length && children[0].className && /vjs-menu-title/.test(children[0].className);

    if (haveTitle) {
      children.shift();
    }

    if (children.length > 0) {
      if (item < 0) {
        item = 0;
      } else if (item >= children.length) {
        item = children.length - 1;
      }

      this.focusedChild_ = item;

      children[item].el_.focus();
    }
  };

  return Menu;
}(Component);

Component.registerComponent('Menu', Menu);

/**
 * @file menu-button.js
 */
/**
 * A `MenuButton` class for any popup {@link Menu}.
 *
 * @extends Component
 */

var MenuButton = function (_Component) {
  inherits(MenuButton, _Component);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   */
  function MenuButton(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, MenuButton);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.menuButton_ = new Button(player, options);

    _this.menuButton_.controlText(_this.controlText_);
    _this.menuButton_.el_.setAttribute('aria-haspopup', 'true');

    // Add buildCSSClass values to the button, not the wrapper
    var buttonClass = Button.prototype.buildCSSClass();

    _this.menuButton_.el_.className = _this.buildCSSClass() + ' ' + buttonClass;
    _this.menuButton_.removeClass('vjs-control');

    _this.addChild(_this.menuButton_);

    _this.update();

    _this.enabled_ = true;

    _this.on(_this.menuButton_, 'tap', _this.handleClick);
    _this.on(_this.menuButton_, 'click', _this.handleClick);
    _this.on(_this.menuButton_, 'focus', _this.handleFocus);
    _this.on(_this.menuButton_, 'blur', _this.handleBlur);

    _this.on('keydown', _this.handleSubmenuKeyPress);
    return _this;
  }

  /**
   * Update the menu based on the current state of its items.
   */


  MenuButton.prototype.update = function update() {
    var menu = this.createMenu();

    if (this.menu) {
      this.menu.dispose();
      this.removeChild(this.menu);
    }

    this.menu = menu;
    this.addChild(menu);

    /**
     * Track the state of the menu button
     *
     * @type {Boolean}
     * @private
     */
    this.buttonPressed_ = false;
    this.menuButton_.el_.setAttribute('aria-expanded', 'false');

    if (this.items && this.items.length <= this.hideThreshold_) {
      this.hide();
    } else {
      this.show();
    }
  };

  /**
   * Create the menu and add all items to it.
   *
   * @return {Menu}
   *         The constructed menu
   */


  MenuButton.prototype.createMenu = function createMenu() {
    var menu = new Menu(this.player_, { menuButton: this });

    /**
     * Hide the menu if the number of items is less than or equal to this threshold. This defaults
     * to 0 and whenever we add items which can be hidden to the menu we'll increment it. We list
     * it here because every time we run `createMenu` we need to reset the value.
     *
     * @protected
     * @type {Number}
     */
    this.hideThreshold_ = 0;

    // Add a title list item to the top
    if (this.options_.title) {
      var title = createEl('li', {
        className: 'vjs-menu-title',
        innerHTML: toTitleCase(this.options_.title),
        tabIndex: -1
      });

      this.hideThreshold_ += 1;

      menu.children_.unshift(title);
      prependTo(title, menu.contentEl());
    }

    this.items = this.createItems();

    if (this.items) {
      // Add menu items to the menu
      for (var i = 0; i < this.items.length; i++) {
        menu.addItem(this.items[i]);
      }
    }

    return menu;
  };

  /**
   * Create the list of menu items. Specific to each subclass.
   *
   * @abstract
   */


  MenuButton.prototype.createItems = function createItems() {};

  /**
   * Create the `MenuButtons`s DOM element.
   *
   * @return {Element}
   *         The element that gets created.
   */


  MenuButton.prototype.createEl = function createEl$$1() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: this.buildWrapperCSSClass()
    }, {});
  };

  /**
   * Allow sub components to stack CSS class names for the wrapper element
   *
   * @return {string}
   *         The constructed wrapper DOM `className`
   */


  MenuButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    var menuButtonClass = 'vjs-menu-button';

    // If the inline option is passed, we want to use different styles altogether.
    if (this.options_.inline === true) {
      menuButtonClass += '-inline';
    } else {
      menuButtonClass += '-popup';
    }

    // TODO: Fix the CSS so that this isn't necessary
    var buttonClass = Button.prototype.buildCSSClass();

    return 'vjs-menu-button ' + menuButtonClass + ' ' + buttonClass + ' ' + _Component.prototype.buildCSSClass.call(this);
  };

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  MenuButton.prototype.buildCSSClass = function buildCSSClass() {
    var menuButtonClass = 'vjs-menu-button';

    // If the inline option is passed, we want to use different styles altogether.
    if (this.options_.inline === true) {
      menuButtonClass += '-inline';
    } else {
      menuButtonClass += '-popup';
    }

    return 'vjs-menu-button ' + menuButtonClass + ' ' + _Component.prototype.buildCSSClass.call(this);
  };

  /**
   * Get or set the localized control text that will be used for accessibility.
   *
   * > NOTE: This will come from the internal `menuButton_` element.
   *
   * @param {string} [text]
   *        Control text for element.
   *
   * @param {Element} [el=this.menuButton_.el()]
   *        Element to set the title on.
   *
   * @return {string}
   *         - The control text when getting
   */


  MenuButton.prototype.controlText = function controlText(text) {
    var el = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : this.menuButton_.el();

    return this.menuButton_.controlText(text, el);
  };

  /**
   * Handle a click on a `MenuButton`.
   * See {@link ClickableComponent#handleClick} for instances where this is called.
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  MenuButton.prototype.handleClick = function handleClick(event) {
    // When you click the button it adds focus, which will show the menu.
    // So we'll remove focus when the mouse leaves the button. Focus is needed
    // for tab navigation.

    this.one(this.menu.contentEl(), 'mouseleave', bind(this, function (e) {
      this.unpressButton();
      this.el_.blur();
    }));
    if (this.buttonPressed_) {
      this.unpressButton();
    } else {
      this.pressButton();
    }
  };

  /**
   * Set the focus to the actual button, not to this element
   */


  MenuButton.prototype.focus = function focus() {
    this.menuButton_.focus();
  };

  /**
   * Remove the focus from the actual button, not this element
   */


  MenuButton.prototype.blur = function blur() {
    this.menuButton_.blur();
  };

  /**
   * This gets called when a `MenuButton` gains focus via a `focus` event.
   * Turns on listening for `keydown` events. When they happen it
   * calls `this.handleKeyPress`.
   *
   * @param {EventTarget~Event} event
   *        The `focus` event that caused this function to be called.
   *
   * @listens focus
   */


  MenuButton.prototype.handleFocus = function handleFocus() {
    on(document_1, 'keydown', bind(this, this.handleKeyPress));
  };

  /**
   * Called when a `MenuButton` loses focus. Turns off the listener for
   * `keydown` events. Which Stops `this.handleKeyPress` from getting called.
   *
   * @param {EventTarget~Event} event
   *        The `blur` event that caused this function to be called.
   *
   * @listens blur
   */


  MenuButton.prototype.handleBlur = function handleBlur() {
    off(document_1, 'keydown', bind(this, this.handleKeyPress));
  };

  /**
   * Handle tab, escape, down arrow, and up arrow keys for `MenuButton`. See
   * {@link ClickableComponent#handleKeyPress} for instances where this is called.
   *
   * @param {EventTarget~Event} event
   *        The `keydown` event that caused this function to be called.
   *
   * @listens keydown
   */


  MenuButton.prototype.handleKeyPress = function handleKeyPress(event) {

    // Escape (27) key or Tab (9) key unpress the 'button'
    if (event.which === 27 || event.which === 9) {
      if (this.buttonPressed_) {
        this.unpressButton();
      }
      // Don't preventDefault for Tab key - we still want to lose focus
      if (event.which !== 9) {
        event.preventDefault();
        // Set focus back to the menu button's button
        this.menuButton_.el_.focus();
      }
      // Up (38) key or Down (40) key press the 'button'
    } else if (event.which === 38 || event.which === 40) {
      if (!this.buttonPressed_) {
        this.pressButton();
        event.preventDefault();
      }
    }
  };

  /**
   * Handle a `keydown` event on a sub-menu. The listener for this is added in
   * the constructor.
   *
   * @param {EventTarget~Event} event
   *        Key press event
   *
   * @listens keydown
   */


  MenuButton.prototype.handleSubmenuKeyPress = function handleSubmenuKeyPress(event) {

    // Escape (27) key or Tab (9) key unpress the 'button'
    if (event.which === 27 || event.which === 9) {
      if (this.buttonPressed_) {
        this.unpressButton();
      }
      // Don't preventDefault for Tab key - we still want to lose focus
      if (event.which !== 9) {
        event.preventDefault();
        // Set focus back to the menu button's button
        this.menuButton_.el_.focus();
      }
    }
  };

  /**
   * Put the current `MenuButton` into a pressed state.
   */


  MenuButton.prototype.pressButton = function pressButton() {
    if (this.enabled_) {
      this.buttonPressed_ = true;
      this.menu.lockShowing();
      this.menuButton_.el_.setAttribute('aria-expanded', 'true');

      // set the focus into the submenu, except on iOS where it is resulting in
      // undesired scrolling behavior when the player is in an iframe
      if (IS_IOS && isInFrame()) {
        // Return early so that the menu isn't focused
        return;
      }

      this.menu.focus();
    }
  };

  /**
   * Take the current `MenuButton` out of a pressed state.
   */


  MenuButton.prototype.unpressButton = function unpressButton() {
    if (this.enabled_) {
      this.buttonPressed_ = false;
      this.menu.unlockShowing();
      this.menuButton_.el_.setAttribute('aria-expanded', 'false');
    }
  };

  /**
   * Disable the `MenuButton`. Don't allow it to be clicked.
   */


  MenuButton.prototype.disable = function disable() {
    this.unpressButton();

    this.enabled_ = false;
    this.addClass('vjs-disabled');

    this.menuButton_.disable();
  };

  /**
   * Enable the `MenuButton`. Allow it to be clicked.
   */


  MenuButton.prototype.enable = function enable() {
    this.enabled_ = true;
    this.removeClass('vjs-disabled');

    this.menuButton_.enable();
  };

  return MenuButton;
}(Component);

Component.registerComponent('MenuButton', MenuButton);

/**
 * @file track-button.js
 */
/**
 * The base class for buttons that toggle specific  track types (e.g. subtitles).
 *
 * @extends MenuButton
 */

var TrackButton = function (_MenuButton) {
  inherits(TrackButton, _MenuButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function TrackButton(player, options) {
    classCallCheck(this, TrackButton);

    var tracks = options.tracks;

    var _this = possibleConstructorReturn(this, _MenuButton.call(this, player, options));

    if (_this.items.length <= 1) {
      _this.hide();
    }

    if (!tracks) {
      return possibleConstructorReturn(_this);
    }

    var updateHandler = bind(_this, _this.update);

    tracks.addEventListener('removetrack', updateHandler);
    tracks.addEventListener('addtrack', updateHandler);
    _this.player_.on('ready', updateHandler);

    _this.player_.on('dispose', function () {
      tracks.removeEventListener('removetrack', updateHandler);
      tracks.removeEventListener('addtrack', updateHandler);
    });
    return _this;
  }

  return TrackButton;
}(MenuButton);

Component.registerComponent('TrackButton', TrackButton);

/**
 * @file menu-item.js
 */
/**
 * The component for a menu item. `<li>`
 *
 * @extends ClickableComponent
 */

var MenuItem = function (_ClickableComponent) {
  inherits(MenuItem, _ClickableComponent);

  /**
   * Creates an instance of the this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   *
   */
  function MenuItem(player, options) {
    classCallCheck(this, MenuItem);

    var _this = possibleConstructorReturn(this, _ClickableComponent.call(this, player, options));

    _this.selectable = options.selectable;
    _this.isSelected_ = options.selected || false;
    _this.multiSelectable = options.multiSelectable;

    _this.selected(_this.isSelected_);

    if (_this.selectable) {
      if (_this.multiSelectable) {
        _this.el_.setAttribute('role', 'menuitemcheckbox');
      } else {
        _this.el_.setAttribute('role', 'menuitemradio');
      }
    } else {
      _this.el_.setAttribute('role', 'menuitem');
    }
    return _this;
  }

  /**
   * Create the `MenuItem's DOM element
   *
   * @param {string} [type=li]
   *        Element's node type, not actually used, always set to `li`.
   *
   * @param {Object} [props={}]
   *        An object of properties that should be set on the element
   *
   * @param {Object} [attrs={}]
   *        An object of attributes that should be set on the element
   *
   * @return {Element}
   *         The element that gets created.
   */


  MenuItem.prototype.createEl = function createEl(type, props, attrs) {
    // The control is textual, not just an icon
    this.nonIconControl = true;

    return _ClickableComponent.prototype.createEl.call(this, 'li', assign({
      className: 'vjs-menu-item',
      innerHTML: '<span class="vjs-menu-item-text">' + this.localize(this.options_.label) + '</span>',
      tabIndex: -1
    }, props), attrs);
  };

  /**
   * Any click on a `MenuItem` puts it into the selected state.
   * See {@link ClickableComponent#handleClick} for instances where this is called.
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  MenuItem.prototype.handleClick = function handleClick(event) {
    this.selected(true);
  };

  /**
   * Set the state for this menu item as selected or not.
   *
   * @param {boolean} selected
   *        if the menu item is selected or not
   */


  MenuItem.prototype.selected = function selected(_selected) {
    if (this.selectable) {
      if (_selected) {
        this.addClass('vjs-selected');
        this.el_.setAttribute('aria-checked', 'true');
        // aria-checked isn't fully supported by browsers/screen readers,
        // so indicate selected state to screen reader in the control text.
        this.controlText(', selected');
        this.isSelected_ = true;
      } else {
        this.removeClass('vjs-selected');
        this.el_.setAttribute('aria-checked', 'false');
        // Indicate un-selected state to screen reader
        this.controlText('');
        this.isSelected_ = false;
      }
    }
  };

  return MenuItem;
}(ClickableComponent);

Component.registerComponent('MenuItem', MenuItem);

/**
 * @file text-track-menu-item.js
 */
/**
 * The specific menu item type for selecting a language within a text track kind
 *
 * @extends MenuItem
 */

var TextTrackMenuItem = function (_MenuItem) {
  inherits(TextTrackMenuItem, _MenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function TextTrackMenuItem(player, options) {
    classCallCheck(this, TextTrackMenuItem);

    var track = options.track;
    var tracks = player.textTracks();

    // Modify options for parent MenuItem class's init.
    options.label = track.label || track.language || 'Unknown';
    options.selected = track.mode === 'showing';

    var _this = possibleConstructorReturn(this, _MenuItem.call(this, player, options));

    _this.track = track;
    var changeHandler = function changeHandler() {
      for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }

      _this.handleTracksChange.apply(_this, args);
    };
    var selectedLanguageChangeHandler = function selectedLanguageChangeHandler() {
      for (var _len2 = arguments.length, args = Array(_len2), _key2 = 0; _key2 < _len2; _key2++) {
        args[_key2] = arguments[_key2];
      }

      _this.handleSelectedLanguageChange.apply(_this, args);
    };

    player.on(['loadstart', 'texttrackchange'], changeHandler);
    tracks.addEventListener('change', changeHandler);
    tracks.addEventListener('selectedlanguagechange', selectedLanguageChangeHandler);
    _this.on('dispose', function () {
      player.off(['loadstart', 'texttrackchange'], changeHandler);
      tracks.removeEventListener('change', changeHandler);
      tracks.removeEventListener('selectedlanguagechange', selectedLanguageChangeHandler);
    });

    // iOS7 doesn't dispatch change events to TextTrackLists when an
    // associated track's mode changes. Without something like
    // Object.observe() (also not present on iOS7), it's not
    // possible to detect changes to the mode attribute and polyfill
    // the change event. As a poor substitute, we manually dispatch
    // change events whenever the controls modify the mode.
    if (tracks.onchange === undefined) {
      var event = void 0;

      _this.on(['tap', 'click'], function () {
        if (_typeof(window_1.Event) !== 'object') {
          // Android 2.3 throws an Illegal Constructor error for window.Event
          try {
            event = new window_1.Event('change');
          } catch (err) {
            // continue regardless of error
          }
        }

        if (!event) {
          event = document_1.createEvent('Event');
          event.initEvent('change', true, true);
        }

        tracks.dispatchEvent(event);
      });
    }

    // set the default state based on current tracks
    _this.handleTracksChange();
    return _this;
  }

  /**
   * This gets called when an `TextTrackMenuItem` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} event
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  TextTrackMenuItem.prototype.handleClick = function handleClick(event) {
    var kind = this.track.kind;
    var kinds = this.track.kinds;
    var tracks = this.player_.textTracks();

    if (!kinds) {
      kinds = [kind];
    }

    _MenuItem.prototype.handleClick.call(this, event);

    if (!tracks) {
      return;
    }

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      if (track === this.track && kinds.indexOf(track.kind) > -1) {
        if (track.mode !== 'showing') {
          track.mode = 'showing';
        }
      } else if (track.mode !== 'disabled') {
        track.mode = 'disabled';
      }
    }
  };

  /**
   * Handle text track list change
   *
   * @param {EventTarget~Event} event
   *        The `change` event that caused this function to be called.
   *
   * @listens TextTrackList#change
   */


  TextTrackMenuItem.prototype.handleTracksChange = function handleTracksChange(event) {
    var shouldBeSelected = this.track.mode === 'showing';

    // Prevent redundant selected() calls because they may cause
    // screen readers to read the appended control text unnecessarily
    if (shouldBeSelected !== this.isSelected_) {
      this.selected(shouldBeSelected);
    }
  };

  TextTrackMenuItem.prototype.handleSelectedLanguageChange = function handleSelectedLanguageChange(event) {
    if (this.track.mode === 'showing') {
      var selectedLanguage = this.player_.cache_.selectedLanguage;

      // Don't replace the kind of track across the same language
      if (selectedLanguage && selectedLanguage.enabled && selectedLanguage.language === this.track.language && selectedLanguage.kind !== this.track.kind) {
        return;
      }

      this.player_.cache_.selectedLanguage = {
        enabled: true,
        language: this.track.language,
        kind: this.track.kind
      };
    }
  };

  TextTrackMenuItem.prototype.dispose = function dispose() {
    // remove reference to track object on dispose
    this.track = null;

    _MenuItem.prototype.dispose.call(this);
  };

  return TextTrackMenuItem;
}(MenuItem);

Component.registerComponent('TextTrackMenuItem', TextTrackMenuItem);

/**
 * @file off-text-track-menu-item.js
 */
/**
 * A special menu item for turning of a specific type of text track
 *
 * @extends TextTrackMenuItem
 */

var OffTextTrackMenuItem = function (_TextTrackMenuItem) {
  inherits(OffTextTrackMenuItem, _TextTrackMenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function OffTextTrackMenuItem(player, options) {
    classCallCheck(this, OffTextTrackMenuItem);

    // Create pseudo track info
    // Requires options['kind']
    options.track = {
      player: player,
      kind: options.kind,
      kinds: options.kinds,
      'default': false,
      mode: 'disabled'
    };

    if (!options.kinds) {
      options.kinds = [options.kind];
    }

    if (options.label) {
      options.track.label = options.label;
    } else {
      options.track.label = options.kinds.join(' and ') + ' off';
    }

    // MenuItem is selectable
    options.selectable = true;
    // MenuItem is NOT multiSelectable (i.e. only one can be marked "selected" at a time)
    options.multiSelectable = false;

    return possibleConstructorReturn(this, _TextTrackMenuItem.call(this, player, options));
  }

  /**
   * Handle text track change
   *
   * @param {EventTarget~Event} event
   *        The event that caused this function to run
   */


  OffTextTrackMenuItem.prototype.handleTracksChange = function handleTracksChange(event) {
    var tracks = this.player().textTracks();
    var shouldBeSelected = true;

    for (var i = 0, l = tracks.length; i < l; i++) {
      var track = tracks[i];

      if (this.options_.kinds.indexOf(track.kind) > -1 && track.mode === 'showing') {
        shouldBeSelected = false;
        break;
      }
    }

    // Prevent redundant selected() calls because they may cause
    // screen readers to read the appended control text unnecessarily
    if (shouldBeSelected !== this.isSelected_) {
      this.selected(shouldBeSelected);
    }
  };

  OffTextTrackMenuItem.prototype.handleSelectedLanguageChange = function handleSelectedLanguageChange(event) {
    var tracks = this.player().textTracks();
    var allHidden = true;

    for (var i = 0, l = tracks.length; i < l; i++) {
      var track = tracks[i];

      if (['captions', 'descriptions', 'subtitles'].indexOf(track.kind) > -1 && track.mode === 'showing') {
        allHidden = false;
        break;
      }
    }

    if (allHidden) {
      this.player_.cache_.selectedLanguage = {
        enabled: false
      };
    }
  };

  return OffTextTrackMenuItem;
}(TextTrackMenuItem);

Component.registerComponent('OffTextTrackMenuItem', OffTextTrackMenuItem);

/**
 * @file text-track-button.js
 */
/**
 * The base class for buttons that toggle specific text track types (e.g. subtitles)
 *
 * @extends MenuButton
 */

var TextTrackButton = function (_TrackButton) {
  inherits(TextTrackButton, _TrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   */
  function TextTrackButton(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, TextTrackButton);

    options.tracks = player.textTracks();

    return possibleConstructorReturn(this, _TrackButton.call(this, player, options));
  }

  /**
   * Create a menu item for each text track
   *
   * @param {TextTrackMenuItem[]} [items=[]]
   *        Existing array of items to use during creation
   *
   * @return {TextTrackMenuItem[]}
   *         Array of menu items that were created
   */


  TextTrackButton.prototype.createItems = function createItems() {
    var items = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
    var TrackMenuItem = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : TextTrackMenuItem;


    // Label is an overide for the [track] off label
    // USed to localise captions/subtitles
    var label = void 0;

    if (this.label_) {
      label = this.label_ + ' off';
    }
    // Add an OFF menu item to turn all tracks off
    items.push(new OffTextTrackMenuItem(this.player_, {
      kinds: this.kinds_,
      kind: this.kind_,
      label: label
    }));

    this.hideThreshold_ += 1;

    var tracks = this.player_.textTracks();

    if (!Array.isArray(this.kinds_)) {
      this.kinds_ = [this.kind_];
    }

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      // only add tracks that are of an appropriate kind and have a label
      if (this.kinds_.indexOf(track.kind) > -1) {

        var item = new TrackMenuItem(this.player_, {
          track: track,
          // MenuItem is selectable
          selectable: true,
          // MenuItem is NOT multiSelectable (i.e. only one can be marked "selected" at a time)
          multiSelectable: false
        });

        item.addClass('vjs-' + track.kind + '-menu-item');
        items.push(item);
      }
    }

    return items;
  };

  return TextTrackButton;
}(TrackButton);

Component.registerComponent('TextTrackButton', TextTrackButton);

/**
 * @file chapters-track-menu-item.js
 */
/**
 * The chapter track menu item
 *
 * @extends MenuItem
 */

var ChaptersTrackMenuItem = function (_MenuItem) {
  inherits(ChaptersTrackMenuItem, _MenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function ChaptersTrackMenuItem(player, options) {
    classCallCheck(this, ChaptersTrackMenuItem);

    var track = options.track;
    var cue = options.cue;
    var currentTime = player.currentTime();

    // Modify options for parent MenuItem class's init.
    options.selectable = true;
    options.multiSelectable = false;
    options.label = cue.text;
    options.selected = cue.startTime <= currentTime && currentTime < cue.endTime;

    var _this = possibleConstructorReturn(this, _MenuItem.call(this, player, options));

    _this.track = track;
    _this.cue = cue;
    track.addEventListener('cuechange', bind(_this, _this.update));
    return _this;
  }

  /**
   * This gets called when an `ChaptersTrackMenuItem` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  ChaptersTrackMenuItem.prototype.handleClick = function handleClick(event) {
    _MenuItem.prototype.handleClick.call(this);
    this.player_.currentTime(this.cue.startTime);
    this.update(this.cue.startTime);
  };

  /**
   * Update chapter menu item
   *
   * @param {EventTarget~Event} [event]
   *        The `cuechange` event that caused this function to run.
   *
   * @listens TextTrack#cuechange
   */


  ChaptersTrackMenuItem.prototype.update = function update(event) {
    var cue = this.cue;
    var currentTime = this.player_.currentTime();

    // vjs.log(currentTime, cue.startTime);
    this.selected(cue.startTime <= currentTime && currentTime < cue.endTime);
  };

  return ChaptersTrackMenuItem;
}(MenuItem);

Component.registerComponent('ChaptersTrackMenuItem', ChaptersTrackMenuItem);

/**
 * @file chapters-button.js
 */
/**
 * The button component for toggling and selecting chapters
 * Chapters act much differently than other text tracks
 * Cues are navigation vs. other tracks of alternative languages
 *
 * @extends TextTrackButton
 */

var ChaptersButton = function (_TextTrackButton) {
  inherits(ChaptersButton, _TextTrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function to call when this function is ready.
   */
  function ChaptersButton(player, options, ready) {
    classCallCheck(this, ChaptersButton);
    return possibleConstructorReturn(this, _TextTrackButton.call(this, player, options, ready));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  ChaptersButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-chapters-button ' + _TextTrackButton.prototype.buildCSSClass.call(this);
  };

  ChaptersButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-chapters-button ' + _TextTrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  /**
   * Update the menu based on the current state of its items.
   *
   * @param {EventTarget~Event} [event]
   *        An event that triggered this function to run.
   *
   * @listens TextTrackList#addtrack
   * @listens TextTrackList#removetrack
   * @listens TextTrackList#change
   */


  ChaptersButton.prototype.update = function update(event) {
    if (!this.track_ || event && (event.type === 'addtrack' || event.type === 'removetrack')) {
      this.setTrack(this.findChaptersTrack());
    }
    _TextTrackButton.prototype.update.call(this);
  };

  /**
   * Set the currently selected track for the chapters button.
   *
   * @param {TextTrack} track
   *        The new track to select. Nothing will change if this is the currently selected
   *        track.
   */


  ChaptersButton.prototype.setTrack = function setTrack(track) {
    if (this.track_ === track) {
      return;
    }

    if (!this.updateHandler_) {
      this.updateHandler_ = this.update.bind(this);
    }

    // here this.track_ refers to the old track instance
    if (this.track_) {
      var remoteTextTrackEl = this.player_.remoteTextTrackEls().getTrackElementByTrack_(this.track_);

      if (remoteTextTrackEl) {
        remoteTextTrackEl.removeEventListener('load', this.updateHandler_);
      }

      this.track_ = null;
    }

    this.track_ = track;

    // here this.track_ refers to the new track instance
    if (this.track_) {
      this.track_.mode = 'hidden';

      var _remoteTextTrackEl = this.player_.remoteTextTrackEls().getTrackElementByTrack_(this.track_);

      if (_remoteTextTrackEl) {
        _remoteTextTrackEl.addEventListener('load', this.updateHandler_);
      }
    }
  };

  /**
   * Find the track object that is currently in use by this ChaptersButton
   *
   * @return {TextTrack|undefined}
   *         The current track or undefined if none was found.
   */


  ChaptersButton.prototype.findChaptersTrack = function findChaptersTrack() {
    var tracks = this.player_.textTracks() || [];

    for (var i = tracks.length - 1; i >= 0; i--) {
      // We will always choose the last track as our chaptersTrack
      var track = tracks[i];

      if (track.kind === this.kind_) {
        return track;
      }
    }
  };

  /**
   * Get the caption for the ChaptersButton based on the track label. This will also
   * use the current tracks localized kind as a fallback if a label does not exist.
   *
   * @return {string}
   *         The tracks current label or the localized track kind.
   */


  ChaptersButton.prototype.getMenuCaption = function getMenuCaption() {
    if (this.track_ && this.track_.label) {
      return this.track_.label;
    }
    return this.localize(toTitleCase(this.kind_));
  };

  /**
   * Create menu from chapter track
   *
   * @return {Menu}
   *         New menu for the chapter buttons
   */


  ChaptersButton.prototype.createMenu = function createMenu() {
    this.options_.title = this.getMenuCaption();
    return _TextTrackButton.prototype.createMenu.call(this);
  };

  /**
   * Create a menu item for each text track
   *
   * @return {TextTrackMenuItem[]}
   *         Array of menu items
   */


  ChaptersButton.prototype.createItems = function createItems() {
    var items = [];

    if (!this.track_) {
      return items;
    }

    var cues = this.track_.cues;

    if (!cues) {
      return items;
    }

    for (var i = 0, l = cues.length; i < l; i++) {
      var cue = cues[i];
      var mi = new ChaptersTrackMenuItem(this.player_, { track: this.track_, cue: cue });

      items.push(mi);
    }

    return items;
  };

  return ChaptersButton;
}(TextTrackButton);

/**
 * `kind` of TextTrack to look for to associate it with this menu.
 *
 * @type {string}
 * @private
 */


ChaptersButton.prototype.kind_ = 'chapters';

/**
 * The text that should display over the `ChaptersButton`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */
ChaptersButton.prototype.controlText_ = 'Chapters';

Component.registerComponent('ChaptersButton', ChaptersButton);

/**
 * @file descriptions-button.js
 */
/**
 * The button component for toggling and selecting descriptions
 *
 * @extends TextTrackButton
 */

var DescriptionsButton = function (_TextTrackButton) {
  inherits(DescriptionsButton, _TextTrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function to call when this component is ready.
   */
  function DescriptionsButton(player, options, ready) {
    classCallCheck(this, DescriptionsButton);

    var _this = possibleConstructorReturn(this, _TextTrackButton.call(this, player, options, ready));

    var tracks = player.textTracks();
    var changeHandler = bind(_this, _this.handleTracksChange);

    tracks.addEventListener('change', changeHandler);
    _this.on('dispose', function () {
      tracks.removeEventListener('change', changeHandler);
    });
    return _this;
  }

  /**
   * Handle text track change
   *
   * @param {EventTarget~Event} event
   *        The event that caused this function to run
   *
   * @listens TextTrackList#change
   */


  DescriptionsButton.prototype.handleTracksChange = function handleTracksChange(event) {
    var tracks = this.player().textTracks();
    var disabled = false;

    // Check whether a track of a different kind is showing
    for (var i = 0, l = tracks.length; i < l; i++) {
      var track = tracks[i];

      if (track.kind !== this.kind_ && track.mode === 'showing') {
        disabled = true;
        break;
      }
    }

    // If another track is showing, disable this menu button
    if (disabled) {
      this.disable();
    } else {
      this.enable();
    }
  };

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  DescriptionsButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-descriptions-button ' + _TextTrackButton.prototype.buildCSSClass.call(this);
  };

  DescriptionsButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-descriptions-button ' + _TextTrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  return DescriptionsButton;
}(TextTrackButton);

/**
 * `kind` of TextTrack to look for to associate it with this menu.
 *
 * @type {string}
 * @private
 */


DescriptionsButton.prototype.kind_ = 'descriptions';

/**
 * The text that should display over the `DescriptionsButton`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */
DescriptionsButton.prototype.controlText_ = 'Descriptions';

Component.registerComponent('DescriptionsButton', DescriptionsButton);

/**
 * @file subtitles-button.js
 */
/**
 * The button component for toggling and selecting subtitles
 *
 * @extends TextTrackButton
 */

var SubtitlesButton = function (_TextTrackButton) {
  inherits(SubtitlesButton, _TextTrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function to call when this component is ready.
   */
  function SubtitlesButton(player, options, ready) {
    classCallCheck(this, SubtitlesButton);
    return possibleConstructorReturn(this, _TextTrackButton.call(this, player, options, ready));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  SubtitlesButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-subtitles-button ' + _TextTrackButton.prototype.buildCSSClass.call(this);
  };

  SubtitlesButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-subtitles-button ' + _TextTrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  return SubtitlesButton;
}(TextTrackButton);

/**
 * `kind` of TextTrack to look for to associate it with this menu.
 *
 * @type {string}
 * @private
 */


SubtitlesButton.prototype.kind_ = 'subtitles';

/**
 * The text that should display over the `SubtitlesButton`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */
SubtitlesButton.prototype.controlText_ = 'Subtitles';

Component.registerComponent('SubtitlesButton', SubtitlesButton);

/**
 * @file caption-settings-menu-item.js
 */
/**
 * The menu item for caption track settings menu
 *
 * @extends TextTrackMenuItem
 */

var CaptionSettingsMenuItem = function (_TextTrackMenuItem) {
  inherits(CaptionSettingsMenuItem, _TextTrackMenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function CaptionSettingsMenuItem(player, options) {
    classCallCheck(this, CaptionSettingsMenuItem);

    options.track = {
      player: player,
      kind: options.kind,
      label: options.kind + ' settings',
      selectable: false,
      'default': false,
      mode: 'disabled'
    };

    // CaptionSettingsMenuItem has no concept of 'selected'
    options.selectable = false;

    options.name = 'CaptionSettingsMenuItem';

    var _this = possibleConstructorReturn(this, _TextTrackMenuItem.call(this, player, options));

    _this.addClass('vjs-texttrack-settings');
    _this.controlText(', opens ' + options.kind + ' settings dialog');
    return _this;
  }

  /**
   * This gets called when an `CaptionSettingsMenuItem` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  CaptionSettingsMenuItem.prototype.handleClick = function handleClick(event) {
    this.player().getChild('textTrackSettings').open();
  };

  return CaptionSettingsMenuItem;
}(TextTrackMenuItem);

Component.registerComponent('CaptionSettingsMenuItem', CaptionSettingsMenuItem);

/**
 * @file captions-button.js
 */
/**
 * The button component for toggling and selecting captions
 *
 * @extends TextTrackButton
 */

var CaptionsButton = function (_TextTrackButton) {
  inherits(CaptionsButton, _TextTrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} [ready]
   *        The function to call when this component is ready.
   */
  function CaptionsButton(player, options, ready) {
    classCallCheck(this, CaptionsButton);
    return possibleConstructorReturn(this, _TextTrackButton.call(this, player, options, ready));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  CaptionsButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-captions-button ' + _TextTrackButton.prototype.buildCSSClass.call(this);
  };

  CaptionsButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-captions-button ' + _TextTrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  /**
   * Create caption menu items
   *
   * @return {CaptionSettingsMenuItem[]}
   *         The array of current menu items.
   */


  CaptionsButton.prototype.createItems = function createItems() {
    var items = [];

    if (!(this.player().tech_ && this.player().tech_.featuresNativeTextTracks) && this.player().getChild('textTrackSettings')) {
      items.push(new CaptionSettingsMenuItem(this.player_, { kind: this.kind_ }));

      this.hideThreshold_ += 1;
    }

    return _TextTrackButton.prototype.createItems.call(this, items);
  };

  return CaptionsButton;
}(TextTrackButton);

/**
 * `kind` of TextTrack to look for to associate it with this menu.
 *
 * @type {string}
 * @private
 */


CaptionsButton.prototype.kind_ = 'captions';

/**
 * The text that should display over the `CaptionsButton`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */
CaptionsButton.prototype.controlText_ = 'Captions';

Component.registerComponent('CaptionsButton', CaptionsButton);

/**
 * @file subs-caps-menu-item.js
 */
/**
 * SubsCapsMenuItem has an [cc] icon to distinguish captions from subtitles
 * in the SubsCapsMenu.
 *
 * @extends TextTrackMenuItem
 */

var SubsCapsMenuItem = function (_TextTrackMenuItem) {
  inherits(SubsCapsMenuItem, _TextTrackMenuItem);

  function SubsCapsMenuItem() {
    classCallCheck(this, SubsCapsMenuItem);
    return possibleConstructorReturn(this, _TextTrackMenuItem.apply(this, arguments));
  }

  SubsCapsMenuItem.prototype.createEl = function createEl(type, props, attrs) {
    var innerHTML = '<span class="vjs-menu-item-text">' + this.localize(this.options_.label);

    if (this.options_.track.kind === 'captions') {
      innerHTML += '\n        <span aria-hidden="true" class="vjs-icon-placeholder"></span>\n        <span class="vjs-control-text"> ' + this.localize('Captions') + '</span>\n      ';
    }

    innerHTML += '</span>';

    var el = _TextTrackMenuItem.prototype.createEl.call(this, type, assign({
      innerHTML: innerHTML
    }, props), attrs);

    return el;
  };

  return SubsCapsMenuItem;
}(TextTrackMenuItem);

Component.registerComponent('SubsCapsMenuItem', SubsCapsMenuItem);

/**
 * @file sub-caps-button.js
 */
/**
 * The button component for toggling and selecting captions and/or subtitles
 *
 * @extends TextTrackButton
 */

var SubsCapsButton = function (_TextTrackButton) {
  inherits(SubsCapsButton, _TextTrackButton);

  function SubsCapsButton(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, SubsCapsButton);

    // Although North America uses "captions" in most cases for
    // "captions and subtitles" other locales use "subtitles"
    var _this = possibleConstructorReturn(this, _TextTrackButton.call(this, player, options));

    _this.label_ = 'subtitles';
    if (['en', 'en-us', 'en-ca', 'fr-ca'].indexOf(_this.player_.language_) > -1) {
      _this.label_ = 'captions';
    }
    _this.menuButton_.controlText(toTitleCase(_this.label_));
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  SubsCapsButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-subs-caps-button ' + _TextTrackButton.prototype.buildCSSClass.call(this);
  };

  SubsCapsButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-subs-caps-button ' + _TextTrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  /**
   * Create caption/subtitles menu items
   *
   * @return {CaptionSettingsMenuItem[]}
   *         The array of current menu items.
   */


  SubsCapsButton.prototype.createItems = function createItems() {
    var items = [];

    if (!(this.player().tech_ && this.player().tech_.featuresNativeTextTracks) && this.player().getChild('textTrackSettings')) {
      items.push(new CaptionSettingsMenuItem(this.player_, { kind: this.label_ }));

      this.hideThreshold_ += 1;
    }

    items = _TextTrackButton.prototype.createItems.call(this, items, SubsCapsMenuItem);
    return items;
  };

  return SubsCapsButton;
}(TextTrackButton);

/**
 * `kind`s of TextTrack to look for to associate it with this menu.
 *
 * @type {array}
 * @private
 */


SubsCapsButton.prototype.kinds_ = ['captions', 'subtitles'];

/**
 * The text that should display over the `SubsCapsButton`s controls.
 *
 *
 * @type {string}
 * @private
 */
SubsCapsButton.prototype.controlText_ = 'Subtitles';

Component.registerComponent('SubsCapsButton', SubsCapsButton);

/**
 * @file audio-track-menu-item.js
 */
/**
 * An {@link AudioTrack} {@link MenuItem}
 *
 * @extends MenuItem
 */

var AudioTrackMenuItem = function (_MenuItem) {
  inherits(AudioTrackMenuItem, _MenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function AudioTrackMenuItem(player, options) {
    classCallCheck(this, AudioTrackMenuItem);

    var track = options.track;
    var tracks = player.audioTracks();

    // Modify options for parent MenuItem class's init.
    options.label = track.label || track.language || 'Unknown';
    options.selected = track.enabled;

    var _this = possibleConstructorReturn(this, _MenuItem.call(this, player, options));

    _this.track = track;

    _this.addClass('vjs-' + track.kind + '-menu-item');

    var changeHandler = function changeHandler() {
      for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }

      _this.handleTracksChange.apply(_this, args);
    };

    tracks.addEventListener('change', changeHandler);
    _this.on('dispose', function () {
      tracks.removeEventListener('change', changeHandler);
    });
    return _this;
  }

  AudioTrackMenuItem.prototype.createEl = function createEl(type, props, attrs) {
    var innerHTML = '<span class="vjs-menu-item-text">' + this.localize(this.options_.label);

    if (this.options_.track.kind === 'main-desc') {
      innerHTML += '\n        <span aria-hidden="true" class="vjs-icon-placeholder"></span>\n        <span class="vjs-control-text"> ' + this.localize('Descriptions') + '</span>\n      ';
    }

    innerHTML += '</span>';

    var el = _MenuItem.prototype.createEl.call(this, type, assign({
      innerHTML: innerHTML
    }, props), attrs);

    return el;
  };

  /**
   * This gets called when an `AudioTrackMenuItem is "clicked". See {@link ClickableComponent}
   * for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  AudioTrackMenuItem.prototype.handleClick = function handleClick(event) {
    var tracks = this.player_.audioTracks();

    _MenuItem.prototype.handleClick.call(this, event);

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      track.enabled = track === this.track;
    }
  };

  /**
   * Handle any {@link AudioTrack} change.
   *
   * @param {EventTarget~Event} [event]
   *        The {@link AudioTrackList#change} event that caused this to run.
   *
   * @listens AudioTrackList#change
   */


  AudioTrackMenuItem.prototype.handleTracksChange = function handleTracksChange(event) {
    this.selected(this.track.enabled);
  };

  return AudioTrackMenuItem;
}(MenuItem);

Component.registerComponent('AudioTrackMenuItem', AudioTrackMenuItem);

/**
 * @file audio-track-button.js
 */
/**
 * The base class for buttons that toggle specific {@link AudioTrack} types.
 *
 * @extends TrackButton
 */

var AudioTrackButton = function (_TrackButton) {
  inherits(AudioTrackButton, _TrackButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options={}]
   *        The key/value store of player options.
   */
  function AudioTrackButton(player) {
    var options = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};
    classCallCheck(this, AudioTrackButton);

    options.tracks = player.audioTracks();

    return possibleConstructorReturn(this, _TrackButton.call(this, player, options));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  AudioTrackButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-audio-button ' + _TrackButton.prototype.buildCSSClass.call(this);
  };

  AudioTrackButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-audio-button ' + _TrackButton.prototype.buildWrapperCSSClass.call(this);
  };

  /**
   * Create a menu item for each audio track
   *
   * @param {AudioTrackMenuItem[]} [items=[]]
   *        An array of existing menu items to use.
   *
   * @return {AudioTrackMenuItem[]}
   *         An array of menu items
   */


  AudioTrackButton.prototype.createItems = function createItems() {
    var items = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];

    // if there's only one audio track, there no point in showing it
    this.hideThreshold_ = 1;

    var tracks = this.player_.audioTracks();

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      items.push(new AudioTrackMenuItem(this.player_, {
        track: track,
        // MenuItem is selectable
        selectable: true,
        // MenuItem is NOT multiSelectable (i.e. only one can be marked "selected" at a time)
        multiSelectable: false
      }));
    }

    return items;
  };

  return AudioTrackButton;
}(TrackButton);

/**
 * The text that should display over the `AudioTrackButton`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


AudioTrackButton.prototype.controlText_ = 'Audio Track';
Component.registerComponent('AudioTrackButton', AudioTrackButton);

/**
 * @file playback-rate-menu-item.js
 */
/**
 * The specific menu item type for selecting a playback rate.
 *
 * @extends MenuItem
 */

var PlaybackRateMenuItem = function (_MenuItem) {
  inherits(PlaybackRateMenuItem, _MenuItem);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function PlaybackRateMenuItem(player, options) {
    classCallCheck(this, PlaybackRateMenuItem);

    var label = options.rate;
    var rate = parseFloat(label, 10);

    // Modify options for parent MenuItem class's init.
    options.label = label;
    options.selected = rate === 1;
    options.selectable = true;
    options.multiSelectable = false;

    var _this = possibleConstructorReturn(this, _MenuItem.call(this, player, options));

    _this.label = label;
    _this.rate = rate;

    _this.on(player, 'ratechange', _this.update);
    return _this;
  }

  /**
   * This gets called when an `PlaybackRateMenuItem` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  PlaybackRateMenuItem.prototype.handleClick = function handleClick(event) {
    _MenuItem.prototype.handleClick.call(this);
    this.player().playbackRate(this.rate);
  };

  /**
   * Update the PlaybackRateMenuItem when the playbackrate changes.
   *
   * @param {EventTarget~Event} [event]
   *        The `ratechange` event that caused this function to run.
   *
   * @listens Player#ratechange
   */


  PlaybackRateMenuItem.prototype.update = function update(event) {
    this.selected(this.player().playbackRate() === this.rate);
  };

  return PlaybackRateMenuItem;
}(MenuItem);

/**
 * The text that should display over the `PlaybackRateMenuItem`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


PlaybackRateMenuItem.prototype.contentElType = 'button';

Component.registerComponent('PlaybackRateMenuItem', PlaybackRateMenuItem);

/**
 * @file playback-rate-menu-button.js
 */
/**
 * The component for controlling the playback rate.
 *
 * @extends MenuButton
 */

var PlaybackRateMenuButton = function (_MenuButton) {
  inherits(PlaybackRateMenuButton, _MenuButton);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   */
  function PlaybackRateMenuButton(player, options) {
    classCallCheck(this, PlaybackRateMenuButton);

    var _this = possibleConstructorReturn(this, _MenuButton.call(this, player, options));

    _this.updateVisibility();
    _this.updateLabel();

    _this.on(player, 'loadstart', _this.updateVisibility);
    _this.on(player, 'ratechange', _this.updateLabel);
    return _this;
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  PlaybackRateMenuButton.prototype.createEl = function createEl$$1() {
    var el = _MenuButton.prototype.createEl.call(this);

    this.labelEl_ = createEl('div', {
      className: 'vjs-playback-rate-value',
      innerHTML: '1x'
    });

    el.appendChild(this.labelEl_);

    return el;
  };

  PlaybackRateMenuButton.prototype.dispose = function dispose() {
    this.labelEl_ = null;

    _MenuButton.prototype.dispose.call(this);
  };

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */


  PlaybackRateMenuButton.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-playback-rate ' + _MenuButton.prototype.buildCSSClass.call(this);
  };

  PlaybackRateMenuButton.prototype.buildWrapperCSSClass = function buildWrapperCSSClass() {
    return 'vjs-playback-rate ' + _MenuButton.prototype.buildWrapperCSSClass.call(this);
  };

  /**
   * Create the playback rate menu
   *
   * @return {Menu}
   *         Menu object populated with {@link PlaybackRateMenuItem}s
   */


  PlaybackRateMenuButton.prototype.createMenu = function createMenu() {
    var menu = new Menu(this.player());
    var rates = this.playbackRates();

    if (rates) {
      for (var i = rates.length - 1; i >= 0; i--) {
        menu.addChild(new PlaybackRateMenuItem(this.player(), { rate: rates[i] + 'x' }));
      }
    }

    return menu;
  };

  /**
   * Updates ARIA accessibility attributes
   */


  PlaybackRateMenuButton.prototype.updateARIAAttributes = function updateARIAAttributes() {
    // Current playback rate
    this.el().setAttribute('aria-valuenow', this.player().playbackRate());
  };

  /**
   * This gets called when an `PlaybackRateMenuButton` is "clicked". See
   * {@link ClickableComponent} for more detailed information on what a click can be.
   *
   * @param {EventTarget~Event} [event]
   *        The `keydown`, `tap`, or `click` event that caused this function to be
   *        called.
   *
   * @listens tap
   * @listens click
   */


  PlaybackRateMenuButton.prototype.handleClick = function handleClick(event) {
    // select next rate option
    var currentRate = this.player().playbackRate();
    var rates = this.playbackRates();

    // this will select first one if the last one currently selected
    var newRate = rates[0];

    for (var i = 0; i < rates.length; i++) {
      if (rates[i] > currentRate) {
        newRate = rates[i];
        break;
      }
    }
    this.player().playbackRate(newRate);
  };

  /**
   * Get possible playback rates
   *
   * @return {Array}
   *         All possible playback rates
   */


  PlaybackRateMenuButton.prototype.playbackRates = function playbackRates() {
    return this.options_.playbackRates || this.options_.playerOptions && this.options_.playerOptions.playbackRates;
  };

  /**
   * Get whether playback rates is supported by the tech
   * and an array of playback rates exists
   *
   * @return {boolean}
   *         Whether changing playback rate is supported
   */


  PlaybackRateMenuButton.prototype.playbackRateSupported = function playbackRateSupported() {
    return this.player().tech_ && this.player().tech_.featuresPlaybackRate && this.playbackRates() && this.playbackRates().length > 0;
  };

  /**
   * Hide playback rate controls when they're no playback rate options to select
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#loadstart
   */


  PlaybackRateMenuButton.prototype.updateVisibility = function updateVisibility(event) {
    if (this.playbackRateSupported()) {
      this.removeClass('vjs-hidden');
    } else {
      this.addClass('vjs-hidden');
    }
  };

  /**
   * Update button label when rate changed
   *
   * @param {EventTarget~Event} [event]
   *        The event that caused this function to run.
   *
   * @listens Player#ratechange
   */


  PlaybackRateMenuButton.prototype.updateLabel = function updateLabel(event) {
    if (this.playbackRateSupported()) {
      this.labelEl_.innerHTML = this.player().playbackRate() + 'x';
    }
  };

  return PlaybackRateMenuButton;
}(MenuButton);

/**
 * The text that should display over the `FullscreenToggle`s controls. Added for localization.
 *
 * @type {string}
 * @private
 */


PlaybackRateMenuButton.prototype.controlText_ = 'Playback Rate';

Component.registerComponent('PlaybackRateMenuButton', PlaybackRateMenuButton);

/**
 * @file spacer.js
 */
/**
 * Just an empty spacer element that can be used as an append point for plugins, etc.
 * Also can be used to create space between elements when necessary.
 *
 * @extends Component
 */

var Spacer = function (_Component) {
  inherits(Spacer, _Component);

  function Spacer() {
    classCallCheck(this, Spacer);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */
  Spacer.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-spacer ' + _Component.prototype.buildCSSClass.call(this);
  };

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  Spacer.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: this.buildCSSClass()
    });
  };

  return Spacer;
}(Component);

Component.registerComponent('Spacer', Spacer);

/**
 * @file custom-control-spacer.js
 */
/**
 * Spacer specifically meant to be used as an insertion point for new plugins, etc.
 *
 * @extends Spacer
 */

var CustomControlSpacer = function (_Spacer) {
  inherits(CustomControlSpacer, _Spacer);

  function CustomControlSpacer() {
    classCallCheck(this, CustomControlSpacer);
    return possibleConstructorReturn(this, _Spacer.apply(this, arguments));
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   */
  CustomControlSpacer.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-custom-control-spacer ' + _Spacer.prototype.buildCSSClass.call(this);
  };

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */


  CustomControlSpacer.prototype.createEl = function createEl() {
    var el = _Spacer.prototype.createEl.call(this, {
      className: this.buildCSSClass()
    });

    // No-flex/table-cell mode requires there be some content
    // in the cell to fill the remaining space of the table.
    el.innerHTML = '\xA0';
    return el;
  };

  return CustomControlSpacer;
}(Spacer);

Component.registerComponent('CustomControlSpacer', CustomControlSpacer);

/**
 * @file control-bar.js
 */
// Required children
/**
 * Container of main controls.
 *
 * @extends Component
 */

var ControlBar = function (_Component) {
  inherits(ControlBar, _Component);

  function ControlBar() {
    classCallCheck(this, ControlBar);
    return possibleConstructorReturn(this, _Component.apply(this, arguments));
  }

  /**
   * Create the `Component`'s DOM element
   *
   * @return {Element}
   *         The element that was created.
   */
  ControlBar.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'div', {
      className: 'vjs-control-bar',
      dir: 'ltr'
    });
  };

  return ControlBar;
}(Component);

/**
 * Default options for `ControlBar`
 *
 * @type {Object}
 * @private
 */


ControlBar.prototype.options_ = {
  children: ['playToggle', 'volumePanel', 'currentTimeDisplay', 'timeDivider', 'durationDisplay', 'progressControl', 'liveDisplay', 'remainingTimeDisplay', 'customControlSpacer', 'playbackRateMenuButton', 'chaptersButton', 'descriptionsButton', 'subsCapsButton', 'audioTrackButton', 'fullscreenToggle']
};

Component.registerComponent('ControlBar', ControlBar);

/**
 * @file error-display.js
 */
/**
 * A display that indicates an error has occurred. This means that the video
 * is unplayable.
 *
 * @extends ModalDialog
 */

var ErrorDisplay = function (_ModalDialog) {
  inherits(ErrorDisplay, _ModalDialog);

  /**
   * Creates an instance of this class.
   *
   * @param  {Player} player
   *         The `Player` that this class should be attached to.
   *
   * @param  {Object} [options]
   *         The key/value store of player options.
   */
  function ErrorDisplay(player, options) {
    classCallCheck(this, ErrorDisplay);

    var _this = possibleConstructorReturn(this, _ModalDialog.call(this, player, options));

    _this.on(player, 'error', _this.open);
    return _this;
  }

  /**
   * Builds the default DOM `className`.
   *
   * @return {string}
   *         The DOM `className` for this object.
   *
   * @deprecated Since version 5.
   */


  ErrorDisplay.prototype.buildCSSClass = function buildCSSClass() {
    return 'vjs-error-display ' + _ModalDialog.prototype.buildCSSClass.call(this);
  };

  /**
   * Gets the localized error message based on the `Player`s error.
   *
   * @return {string}
   *         The `Player`s error message localized or an empty string.
   */


  ErrorDisplay.prototype.content = function content() {
    var error = this.player().error();

    return error ? this.localize(error.message) : '';
  };

  return ErrorDisplay;
}(ModalDialog);

/**
 * The default options for an `ErrorDisplay`.
 *
 * @private
 */


ErrorDisplay.prototype.options_ = mergeOptions(ModalDialog.prototype.options_, {
  pauseOnOpen: false,
  fillAlways: true,
  temporary: false,
  uncloseable: true
});

Component.registerComponent('ErrorDisplay', ErrorDisplay);

/**
 * @file text-track-settings.js
 */
var LOCAL_STORAGE_KEY = 'vjs-text-track-settings';

var COLOR_BLACK = ['#000', 'Black'];
var COLOR_BLUE = ['#00F', 'Blue'];
var COLOR_CYAN = ['#0FF', 'Cyan'];
var COLOR_GREEN = ['#0F0', 'Green'];
var COLOR_MAGENTA = ['#F0F', 'Magenta'];
var COLOR_RED = ['#F00', 'Red'];
var COLOR_WHITE = ['#FFF', 'White'];
var COLOR_YELLOW = ['#FF0', 'Yellow'];

var OPACITY_OPAQUE = ['1', 'Opaque'];
var OPACITY_SEMI = ['0.5', 'Semi-Transparent'];
var OPACITY_TRANS = ['0', 'Transparent'];

// Configuration for the various <select> elements in the DOM of this component.
//
// Possible keys include:
//
// `default`:
//   The default option index. Only needs to be provided if not zero.
// `parser`:
//   A function which is used to parse the value from the selected option in
//   a customized way.
// `selector`:
//   The selector used to find the associated <select> element.
var selectConfigs = {
  backgroundColor: {
    selector: '.vjs-bg-color > select',
    id: 'captions-background-color-%s',
    label: 'Color',
    options: [COLOR_BLACK, COLOR_WHITE, COLOR_RED, COLOR_GREEN, COLOR_BLUE, COLOR_YELLOW, COLOR_MAGENTA, COLOR_CYAN]
  },

  backgroundOpacity: {
    selector: '.vjs-bg-opacity > select',
    id: 'captions-background-opacity-%s',
    label: 'Transparency',
    options: [OPACITY_OPAQUE, OPACITY_SEMI, OPACITY_TRANS]
  },

  color: {
    selector: '.vjs-fg-color > select',
    id: 'captions-foreground-color-%s',
    label: 'Color',
    options: [COLOR_WHITE, COLOR_BLACK, COLOR_RED, COLOR_GREEN, COLOR_BLUE, COLOR_YELLOW, COLOR_MAGENTA, COLOR_CYAN]
  },

  edgeStyle: {
    selector: '.vjs-edge-style > select',
    id: '%s',
    label: 'Text Edge Style',
    options: [['none', 'None'], ['raised', 'Raised'], ['depressed', 'Depressed'], ['uniform', 'Uniform'], ['dropshadow', 'Dropshadow']]
  },

  fontFamily: {
    selector: '.vjs-font-family > select',
    id: 'captions-font-family-%s',
    label: 'Font Family',
    options: [['proportionalSansSerif', 'Proportional Sans-Serif'], ['monospaceSansSerif', 'Monospace Sans-Serif'], ['proportionalSerif', 'Proportional Serif'], ['monospaceSerif', 'Monospace Serif'], ['casual', 'Casual'], ['script', 'Script'], ['small-caps', 'Small Caps']]
  },

  fontPercent: {
    selector: '.vjs-font-percent > select',
    id: 'captions-font-size-%s',
    label: 'Font Size',
    options: [['0.50', '50%'], ['0.75', '75%'], ['1.00', '100%'], ['1.25', '125%'], ['1.50', '150%'], ['1.75', '175%'], ['2.00', '200%'], ['3.00', '300%'], ['4.00', '400%']],
    'default': 2,
    parser: function parser(v) {
      return v === '1.00' ? null : Number(v);
    }
  },

  textOpacity: {
    selector: '.vjs-text-opacity > select',
    id: 'captions-foreground-opacity-%s',
    label: 'Transparency',
    options: [OPACITY_OPAQUE, OPACITY_SEMI]
  },

  // Options for this object are defined below.
  windowColor: {
    selector: '.vjs-window-color > select',
    id: 'captions-window-color-%s',
    label: 'Color'
  },

  // Options for this object are defined below.
  windowOpacity: {
    selector: '.vjs-window-opacity > select',
    id: 'captions-window-opacity-%s',
    label: 'Transparency',
    options: [OPACITY_TRANS, OPACITY_SEMI, OPACITY_OPAQUE]
  }
};

selectConfigs.windowColor.options = selectConfigs.backgroundColor.options;

/**
 * Get the actual value of an option.
 *
 * @param  {string} value
 *         The value to get
 *
 * @param  {Function} [parser]
 *         Optional function to adjust the value.
 *
 * @return {Mixed}
 *         - Will be `undefined` if no value exists
 *         - Will be `undefined` if the given value is "none".
 *         - Will be the actual value otherwise.
 *
 * @private
 */
function parseOptionValue(value, parser) {
  if (parser) {
    value = parser(value);
  }

  if (value && value !== 'none') {
    return value;
  }
}

/**
 * Gets the value of the selected <option> element within a <select> element.
 *
 * @param  {Element} el
 *         the element to look in
 *
 * @param  {Function} [parser]
 *         Optional function to adjust the value.
 *
 * @return {Mixed}
 *         - Will be `undefined` if no value exists
 *         - Will be `undefined` if the given value is "none".
 *         - Will be the actual value otherwise.
 *
 * @private
 */
function getSelectedOptionValue(el, parser) {
  var value = el.options[el.options.selectedIndex].value;

  return parseOptionValue(value, parser);
}

/**
 * Sets the selected <option> element within a <select> element based on a
 * given value.
 *
 * @param {Element} el
 *        The element to look in.
 *
 * @param {string} value
 *        the property to look on.
 *
 * @param {Function} [parser]
 *        Optional function to adjust the value before comparing.
 *
 * @private
 */
function setSelectedOption(el, value, parser) {
  if (!value) {
    return;
  }

  for (var i = 0; i < el.options.length; i++) {
    if (parseOptionValue(el.options[i].value, parser) === value) {
      el.selectedIndex = i;
      break;
    }
  }
}

/**
 * Manipulate Text Tracks settings.
 *
 * @extends ModalDialog
 */

var TextTrackSettings = function (_ModalDialog) {
  inherits(TextTrackSettings, _ModalDialog);

  /**
   * Creates an instance of this class.
   *
   * @param {Player} player
   *         The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *         The key/value store of player options.
   */
  function TextTrackSettings(player, options) {
    classCallCheck(this, TextTrackSettings);

    options.temporary = false;

    var _this = possibleConstructorReturn(this, _ModalDialog.call(this, player, options));

    _this.updateDisplay = bind(_this, _this.updateDisplay);

    // fill the modal and pretend we have opened it
    _this.fill();
    _this.hasBeenOpened_ = _this.hasBeenFilled_ = true;

    _this.endDialog = createEl('p', {
      className: 'vjs-control-text',
      textContent: _this.localize('End of dialog window.')
    });
    _this.el().appendChild(_this.endDialog);

    _this.setDefaults();

    // Grab `persistTextTrackSettings` from the player options if not passed in child options
    if (options.persistTextTrackSettings === undefined) {
      _this.options_.persistTextTrackSettings = _this.options_.playerOptions.persistTextTrackSettings;
    }

    _this.on(_this.$('.vjs-done-button'), 'click', function () {
      _this.saveSettings();
      _this.close();
    });

    _this.on(_this.$('.vjs-default-button'), 'click', function () {
      _this.setDefaults();
      _this.updateDisplay();
    });

    each(selectConfigs, function (config) {
      _this.on(_this.$(config.selector), 'change', _this.updateDisplay);
    });

    if (_this.options_.persistTextTrackSettings) {
      _this.restoreSettings();
    }
    return _this;
  }

  TextTrackSettings.prototype.dispose = function dispose() {
    this.endDialog = null;

    _ModalDialog.prototype.dispose.call(this);
  };

  /**
   * Create a <select> element with configured options.
   *
   * @param {string} key
   *        Configuration key to use during creation.
   *
   * @return {string}
   *         An HTML string.
   *
   * @private
   */


  TextTrackSettings.prototype.createElSelect_ = function createElSelect_(key) {
    var _this2 = this;

    var legendId = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : '';
    var type = arguments.length > 2 && arguments[2] !== undefined ? arguments[2] : 'label';

    var config = selectConfigs[key];
    var id = config.id.replace('%s', this.id_);
    var selectLabelledbyIds = [legendId, id].join(' ').trim();

    return ['<' + type + ' id="' + id + '" class="' + (type === 'label' ? 'vjs-label' : '') + '">', this.localize(config.label), '</' + type + '>', '<select aria-labelledby="' + selectLabelledbyIds + '">'].concat(config.options.map(function (o) {
      var optionId = id + '-' + o[1].replace(/\W+/g, '');

      return ['<option id="' + optionId + '" value="' + o[0] + '" ', 'aria-labelledby="' + selectLabelledbyIds + ' ' + optionId + '">', _this2.localize(o[1]), '</option>'].join('');
    })).concat('</select>').join('');
  };

  /**
   * Create foreground color element for the component
   *
   * @return {string}
   *         An HTML string.
   *
   * @private
   */


  TextTrackSettings.prototype.createElFgColor_ = function createElFgColor_() {
    var legendId = 'captions-text-legend-' + this.id_;

    return ['<fieldset class="vjs-fg-color vjs-track-setting">', '<legend id="' + legendId + '">', this.localize('Text'), '</legend>', this.createElSelect_('color', legendId), '<span class="vjs-text-opacity vjs-opacity">', this.createElSelect_('textOpacity', legendId), '</span>', '</fieldset>'].join('');
  };

  /**
   * Create background color element for the component
   *
   * @return {string}
   *         An HTML string.
   *
   * @private
   */


  TextTrackSettings.prototype.createElBgColor_ = function createElBgColor_() {
    var legendId = 'captions-background-' + this.id_;

    return ['<fieldset class="vjs-bg-color vjs-track-setting">', '<legend id="' + legendId + '">', this.localize('Background'), '</legend>', this.createElSelect_('backgroundColor', legendId), '<span class="vjs-bg-opacity vjs-opacity">', this.createElSelect_('backgroundOpacity', legendId), '</span>', '</fieldset>'].join('');
  };

  /**
   * Create window color element for the component
   *
   * @return {string}
   *         An HTML string.
   *
   * @private
   */


  TextTrackSettings.prototype.createElWinColor_ = function createElWinColor_() {
    var legendId = 'captions-window-' + this.id_;

    return ['<fieldset class="vjs-window-color vjs-track-setting">', '<legend id="' + legendId + '">', this.localize('Window'), '</legend>', this.createElSelect_('windowColor', legendId), '<span class="vjs-window-opacity vjs-opacity">', this.createElSelect_('windowOpacity', legendId), '</span>', '</fieldset>'].join('');
  };

  /**
   * Create color elements for the component
   *
   * @return {Element}
   *         The element that was created
   *
   * @private
   */


  TextTrackSettings.prototype.createElColors_ = function createElColors_() {
    return createEl('div', {
      className: 'vjs-track-settings-colors',
      innerHTML: [this.createElFgColor_(), this.createElBgColor_(), this.createElWinColor_()].join('')
    });
  };

  /**
   * Create font elements for the component
   *
   * @return {Element}
   *         The element that was created.
   *
   * @private
   */


  TextTrackSettings.prototype.createElFont_ = function createElFont_() {
    return createEl('div', {
      className: 'vjs-track-settings-font',
      innerHTML: ['<fieldset class="vjs-font-percent vjs-track-setting">', this.createElSelect_('fontPercent', '', 'legend'), '</fieldset>', '<fieldset class="vjs-edge-style vjs-track-setting">', this.createElSelect_('edgeStyle', '', 'legend'), '</fieldset>', '<fieldset class="vjs-font-family vjs-track-setting">', this.createElSelect_('fontFamily', '', 'legend'), '</fieldset>'].join('')
    });
  };

  /**
   * Create controls for the component
   *
   * @return {Element}
   *         The element that was created.
   *
   * @private
   */


  TextTrackSettings.prototype.createElControls_ = function createElControls_() {
    var defaultsDescription = this.localize('restore all settings to the default values');

    return createEl('div', {
      className: 'vjs-track-settings-controls',
      innerHTML: ['<button class="vjs-default-button" title="' + defaultsDescription + '">', this.localize('Reset'), '<span class="vjs-control-text"> ' + defaultsDescription + '</span>', '</button>', '<button class="vjs-done-button">' + this.localize('Done') + '</button>'].join('')
    });
  };

  TextTrackSettings.prototype.content = function content() {
    return [this.createElColors_(), this.createElFont_(), this.createElControls_()];
  };

  TextTrackSettings.prototype.label = function label() {
    return this.localize('Caption Settings Dialog');
  };

  TextTrackSettings.prototype.description = function description() {
    return this.localize('Beginning of dialog window. Escape will cancel and close the window.');
  };

  TextTrackSettings.prototype.buildCSSClass = function buildCSSClass() {
    return _ModalDialog.prototype.buildCSSClass.call(this) + ' vjs-text-track-settings';
  };

  /**
   * Gets an object of text track settings (or null).
   *
   * @return {Object}
   *         An object with config values parsed from the DOM or localStorage.
   */


  TextTrackSettings.prototype.getValues = function getValues() {
    var _this3 = this;

    return reduce(selectConfigs, function (accum, config, key) {
      var value = getSelectedOptionValue(_this3.$(config.selector), config.parser);

      if (value !== undefined) {
        accum[key] = value;
      }

      return accum;
    }, {});
  };

  /**
   * Sets text track settings from an object of values.
   *
   * @param {Object} values
   *        An object with config values parsed from the DOM or localStorage.
   */


  TextTrackSettings.prototype.setValues = function setValues(values) {
    var _this4 = this;

    each(selectConfigs, function (config, key) {
      setSelectedOption(_this4.$(config.selector), values[key], config.parser);
    });
  };

  /**
   * Sets all `<select>` elements to their default values.
   */


  TextTrackSettings.prototype.setDefaults = function setDefaults() {
    var _this5 = this;

    each(selectConfigs, function (config) {
      var index = config.hasOwnProperty('default') ? config['default'] : 0;

      _this5.$(config.selector).selectedIndex = index;
    });
  };

  /**
   * Restore texttrack settings from localStorage
   */


  TextTrackSettings.prototype.restoreSettings = function restoreSettings() {
    var values = void 0;

    try {
      values = JSON.parse(window_1.localStorage.getItem(LOCAL_STORAGE_KEY));
    } catch (err) {
      log$1.warn(err);
    }

    if (values) {
      this.setValues(values);
    }
  };

  /**
   * Save text track settings to localStorage
   */


  TextTrackSettings.prototype.saveSettings = function saveSettings() {
    if (!this.options_.persistTextTrackSettings) {
      return;
    }

    var values = this.getValues();

    try {
      if (Object.keys(values).length) {
        window_1.localStorage.setItem(LOCAL_STORAGE_KEY, JSON.stringify(values));
      } else {
        window_1.localStorage.removeItem(LOCAL_STORAGE_KEY);
      }
    } catch (err) {
      log$1.warn(err);
    }
  };

  /**
   * Update display of text track settings
   */


  TextTrackSettings.prototype.updateDisplay = function updateDisplay() {
    var ttDisplay = this.player_.getChild('textTrackDisplay');

    if (ttDisplay) {
      ttDisplay.updateDisplay();
    }
  };

  /**
   * conditionally blur the element and refocus the captions button
   *
   * @private
   */


  TextTrackSettings.prototype.conditionalBlur_ = function conditionalBlur_() {
    this.previouslyActiveEl_ = null;
    this.off(document_1, 'keydown', this.handleKeyDown);

    var cb = this.player_.controlBar;
    var subsCapsBtn = cb && cb.subsCapsButton;
    var ccBtn = cb && cb.captionsButton;

    if (subsCapsBtn) {
      subsCapsBtn.focus();
    } else if (ccBtn) {
      ccBtn.focus();
    }
  };

  return TextTrackSettings;
}(ModalDialog);

Component.registerComponent('TextTrackSettings', TextTrackSettings);

/**
 * @file resize-manager.js
 */
/**
 * A Resize Manager. It is in charge of triggering `playerresize` on the player in the right conditions.
 *
 * It'll either create an iframe and use a debounced resize handler on it or use the new {@link https://wicg.github.io/ResizeObserver/|ResizeObserver}.
 *
 * If the ResizeObserver is available natively, it will be used. A polyfill can be passed in as an option.
 * If a `playerresize` event is not needed, the ResizeManager component can be removed from the player, see the example below.
 * @example <caption>How to disable the resize manager</caption>
 * const player = videojs('#vid', {
 *   resizeManager: false
 * });
 *
 * @see {@link https://wicg.github.io/ResizeObserver/|ResizeObserver specification}
 *
 * @extends Component
 */

var ResizeManager = function (_Component) {
  inherits(ResizeManager, _Component);

  /**
   * Create the ResizeManager.
   *
   * @param {Object} player
   *        The `Player` that this class should be attached to.
   *
   * @param {Object} [options]
   *        The key/value store of ResizeManager options.
   *
   * @param {Object} [options.ResizeObserver]
   *        A polyfill for ResizeObserver can be passed in here.
   *        If this is set to null it will ignore the native ResizeObserver and fall back to the iframe fallback.
   */
  function ResizeManager(player, options) {
    classCallCheck(this, ResizeManager);

    var RESIZE_OBSERVER_AVAILABLE = options.ResizeObserver || window_1.ResizeObserver;

    // if `null` was passed, we want to disable the ResizeObserver
    if (options.ResizeObserver === null) {
      RESIZE_OBSERVER_AVAILABLE = false;
    }

    // Only create an element when ResizeObserver isn't available
    var options_ = mergeOptions({ createEl: !RESIZE_OBSERVER_AVAILABLE }, options);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options_));

    _this.ResizeObserver = options.ResizeObserver || window_1.ResizeObserver;
    _this.loadListener_ = null;
    _this.resizeObserver_ = null;
    _this.debouncedHandler_ = debounce(function () {
      _this.resizeHandler();
    }, 100, false, player);

    if (RESIZE_OBSERVER_AVAILABLE) {
      _this.resizeObserver_ = new _this.ResizeObserver(_this.debouncedHandler_);
      _this.resizeObserver_.observe(player.el());
    } else {
      _this.loadListener_ = function () {
        if (_this.el_.contentWindow) {
          on(_this.el_.contentWindow, 'resize', _this.debouncedHandler_);
        }
        _this.off('load', _this.loadListener_);
      };

      _this.on('load', _this.loadListener_);
    }
    return _this;
  }

  ResizeManager.prototype.createEl = function createEl() {
    return _Component.prototype.createEl.call(this, 'iframe', {
      className: 'vjs-resize-manager'
    });
  };

  /**
   * Called when a resize is triggered on the iframe or a resize is observed via the ResizeObserver
   *
   * @fires Player#playerresize
   */


  ResizeManager.prototype.resizeHandler = function resizeHandler() {
    /**
     * Called when the player size has changed
     *
     * @event Player#playerresize
     * @type {EventTarget~Event}
     */
    this.player_.trigger('playerresize');
  };

  ResizeManager.prototype.dispose = function dispose() {
    if (this.resizeObserver_) {
      if (this.player_.el()) {
        this.resizeObserver_.unobserve(this.player_.el());
      }
      this.resizeObserver_.disconnect();
    }

    if (this.el_ && this.el_.contentWindow) {
      off(this.el_.contentWindow, 'resize', this.debouncedHandler_);
    }

    if (this.loadListener_) {
      this.off('load', this.loadListener_);
    }

    this.ResizeObserver = null;
    this.resizeObserver = null;
    this.debouncedHandler_ = null;
    this.loadListener_ = null;
  };

  return ResizeManager;
}(Component);

Component.registerComponent('ResizeManager', ResizeManager);

/**
 * This function is used to fire a sourceset when there is something
 * similar to `mediaEl.load()` being called. It will try to find the source via
 * the `src` attribute and then the `<source>` elements. It will then fire `sourceset`
 * with the source that was found or empty string if we cannot know. If it cannot
 * find a source then `sourceset` will not be fired.
 *
 * @param {Html5} tech
 *        The tech object that sourceset was setup on
 *
 * @return {boolean}
 *         returns false if the sourceset was not fired and true otherwise.
 */
var sourcesetLoad = function sourcesetLoad(tech) {
  var el = tech.el();

  // if `el.src` is set, that source will be loaded.
  if (el.hasAttribute('src')) {
    tech.triggerSourceset(el.src);
    return true;
  }

  /**
   * Since there isn't a src property on the media element, source elements will be used for
   * implementing the source selection algorithm. This happens asynchronously and
   * for most cases were there is more than one source we cannot tell what source will
   * be loaded, without re-implementing the source selection algorithm. At this time we are not
   * going to do that. There are three special cases that we do handle here though:
   *
   * 1. If there are no sources, do not fire `sourceset`.
   * 2. If there is only one `<source>` with a `src` property/attribute that is our `src`
   * 3. If there is more than one `<source>` but all of them have the same `src` url.
   *    That will be our src.
   */
  var sources = tech.$$('source');
  var srcUrls = [];
  var src = '';

  // if there are no sources, do not fire sourceset
  if (!sources.length) {
    return false;
  }

  // only count valid/non-duplicate source elements
  for (var i = 0; i < sources.length; i++) {
    var url = sources[i].src;

    if (url && srcUrls.indexOf(url) === -1) {
      srcUrls.push(url);
    }
  }

  // there were no valid sources
  if (!srcUrls.length) {
    return false;
  }

  // there is only one valid source element url
  // use that
  if (srcUrls.length === 1) {
    src = srcUrls[0];
  }

  tech.triggerSourceset(src);
  return true;
};

/**
 * our implementation of an `innerHTML` descriptor for browsers
 * that do not have one.
 */
var innerHTMLDescriptorPolyfill = {};

if (!IS_IE8) {
  innerHTMLDescriptorPolyfill = Object.defineProperty({}, 'innerHTML', {
    get: function get() {
      return this.cloneNode(true).innerHTML;
    },
    set: function set(v) {
      // make a dummy node to use innerHTML on
      var dummy = document_1.createElement(this.nodeName.toLowerCase());

      // set innerHTML to the value provided
      dummy.innerHTML = v;

      // make a document fragment to hold the nodes from dummy
      var docFrag = document_1.createDocumentFragment();

      // copy all of the nodes created by the innerHTML on dummy
      // to the document fragment
      while (dummy.childNodes.length) {
        docFrag.appendChild(dummy.childNodes[0]);
      }

      // remove content
      this.innerText = '';

      // now we add all of that html in one by appending the
      // document fragment. This is how innerHTML does it.
      window_1.Element.prototype.appendChild.call(this, docFrag);

      // then return the result that innerHTML's setter would
      return this.innerHTML;
    }
  });
}
/**
 * Get a property descriptor given a list of priorities and the
 * property to get.
 */
var getDescriptor = function getDescriptor(priority, prop) {
  var descriptor = {};

  for (var i = 0; i < priority.length; i++) {
    descriptor = Object.getOwnPropertyDescriptor(priority[i], prop);

    if (descriptor && descriptor.set && descriptor.get) {
      break;
    }
  }

  descriptor.enumerable = true;
  descriptor.configurable = true;

  return descriptor;
};

var getInnerHTMLDescriptor = function getInnerHTMLDescriptor(tech) {
  return getDescriptor([tech.el(), window_1.HTMLMediaElement.prototype, window_1.Element.prototype, innerHTMLDescriptorPolyfill], 'innerHTML');
};

/**
 * Patches browser internal functions so that we can tell syncronously
 * if a `<source>` was appended to the media element. For some reason this
 * causes a `sourceset` if the the media element is ready and has no source.
 * This happens when:
 * - The page has just loaded and the media element does not have a source.
 * - The media element was emptied of all sources, then `load()` was called.
 *
 * It does this by patching the following functions/properties when they are supported:
 *
 * - `append()` - can be used to add a `<source>` element to the media element
 * - `appendChild()` - can be used to add a `<source>` element to the media element
 * - `insertAdjacentHTML()` -  can be used to add a `<source>` element to the media element
 * - `innerHTML` -  can be used to add a `<source>` element to the media element
 *
 * @param {Html5} tech
 *        The tech object that sourceset is being setup on.
 */
var firstSourceWatch = function firstSourceWatch(tech) {
  var el = tech.el();

  // make sure firstSourceWatch isn't setup twice.
  if (el.resetSourceWatch_) {
    return;
  }

  var old = {};
  var innerDescriptor = getInnerHTMLDescriptor(tech);
  var appendWrapper = function appendWrapper(appendFn) {
    return function () {
      for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
        args[_key] = arguments[_key];
      }

      var retval = appendFn.apply(el, args);

      sourcesetLoad(tech);

      return retval;
    };
  };

  ['append', 'appendChild', 'insertAdjacentHTML'].forEach(function (k) {
    if (!el[k]) {
      return;
    }

    // store the old function
    old[k] = el[k];

    // call the old function with a sourceset if a source
    // was loaded
    el[k] = appendWrapper(old[k]);
  });

  Object.defineProperty(el, 'innerHTML', mergeOptions(innerDescriptor, {
    set: appendWrapper(innerDescriptor.set)
  }));

  el.resetSourceWatch_ = function () {
    el.resetSourceWatch_ = null;
    Object.keys(old).forEach(function (k) {
      el[k] = old[k];
    });

    Object.defineProperty(el, 'innerHTML', innerDescriptor);
  };

  // on the first sourceset, we need to revert our changes
  tech.one('sourceset', el.resetSourceWatch_);
};

/**
 * our implementation of a `src` descriptor for browsers
 * that do not have one.
 */

var srcDescriptorPolyfill = {};

if (!IS_IE8) {
  srcDescriptorPolyfill = Object.defineProperty({}, 'src', {
    get: function get() {
      if (this.hasAttribute('src')) {
        return getAbsoluteURL(window_1.Element.prototype.getAttribute.call(this, 'src'));
      }

      return '';
    },
    set: function set(v) {
      window_1.Element.prototype.setAttribute.call(this, 'src', v);

      return v;
    }
  });
}

var getSrcDescriptor = function getSrcDescriptor(tech) {
  return getDescriptor([tech.el(), window_1.HTMLMediaElement.prototype, srcDescriptorPolyfill], 'src');
};

/**
 * setup `sourceset` handling on the `Html5` tech. This function
 * patches the following element properties/functions:
 *
 * - `src` - to determine when `src` is set
 * - `setAttribute()` - to determine when `src` is set
 * - `load()` - this re-triggers the source selection algorithm, and can
 *              cause a sourceset.
 *
 * If there is no source when we are adding `sourceset` support or during a `load()`
 * we also patch the functions listed in `firstSourceWatch`.
 *
 * @param {Html5} tech
 *        The tech to patch
 */
var setupSourceset = function setupSourceset(tech) {
  if (!tech.featuresSourceset) {
    return;
  }

  var el = tech.el();

  // make sure sourceset isn't setup twice.
  if (el.resetSourceset_) {
    return;
  }

  var srcDescriptor = getSrcDescriptor(tech);
  var oldSetAttribute = el.setAttribute;
  var oldLoad = el.load;

  Object.defineProperty(el, 'src', mergeOptions(srcDescriptor, {
    set: function set(v) {
      var retval = srcDescriptor.set.call(el, v);

      // we use the getter here to get the actual value set on src
      tech.triggerSourceset(el.src);

      return retval;
    }
  }));

  el.setAttribute = function (n, v) {
    var retval = oldSetAttribute.call(el, n, v);

    if (/src/i.test(n)) {
      tech.triggerSourceset(el.src);
    }

    return retval;
  };

  el.load = function () {
    var retval = oldLoad.call(el);

    // if load was called, but there was no source to fire
    // sourceset on. We have to watch for a source append
    // as that can trigger a `sourceset` when the media element
    // has no source
    if (!sourcesetLoad(tech)) {
      tech.triggerSourceset('');
      firstSourceWatch(tech);
    }

    return retval;
  };

  if (el.currentSrc) {
    tech.triggerSourceset(el.currentSrc);
  } else if (!sourcesetLoad(tech)) {
    firstSourceWatch(tech);
  }

  el.resetSourceset_ = function () {
    el.resetSourceset_ = null;
    el.load = oldLoad;
    el.setAttribute = oldSetAttribute;
    Object.defineProperty(el, 'src', srcDescriptor);
    if (el.resetSourceWatch_) {
      el.resetSourceWatch_();
    }
  };
};

var _templateObject$2 = taggedTemplateLiteralLoose(['Text Tracks are being loaded from another origin but the crossorigin attribute isn\'t used.\n            This may prevent text tracks from loading.'], ['Text Tracks are being loaded from another origin but the crossorigin attribute isn\'t used.\n            This may prevent text tracks from loading.']);

/**
 * @file html5.js
 */
/**
 * HTML5 Media Controller - Wrapper for HTML5 Media API
 *
 * @mixes Tech~SouceHandlerAdditions
 * @extends Tech
 */

var Html5 = function (_Tech) {
  inherits(Html5, _Tech);

  /**
   * Create an instance of this Tech.
   *
   * @param {Object} [options]
   *        The key/value store of player options.
   *
   * @param {Component~ReadyCallback} ready
   *        Callback function to call when the `HTML5` Tech is ready.
   */
  function Html5(options, ready) {
    classCallCheck(this, Html5);

    var _this = possibleConstructorReturn(this, _Tech.call(this, options, ready));

    var source = options.source;
    var crossoriginTracks = false;

    // Set the source if one is provided
    // 1) Check if the source is new (if not, we want to keep the original so playback isn't interrupted)
    // 2) Check to see if the network state of the tag was failed at init, and if so, reset the source
    // anyway so the error gets fired.
    if (source && (_this.el_.currentSrc !== source.src || options.tag && options.tag.initNetworkState_ === 3)) {
      _this.setSource(source);
    } else {
      _this.handleLateInit_(_this.el_);
    }

    // setup sourceset after late sourceset/init
    if (options.enableSourceset) {
      _this.setupSourcesetHandling_();
    }

    if (_this.el_.hasChildNodes()) {

      var nodes = _this.el_.childNodes;
      var nodesLength = nodes.length;
      var removeNodes = [];

      while (nodesLength--) {
        var node = nodes[nodesLength];
        var nodeName = node.nodeName.toLowerCase();

        if (nodeName === 'track') {
          if (!_this.featuresNativeTextTracks) {
            // Empty video tag tracks so the built-in player doesn't use them also.
            // This may not be fast enough to stop HTML5 browsers from reading the tags
            // so we'll need to turn off any default tracks if we're manually doing
            // captions and subtitles. videoElement.textTracks
            removeNodes.push(node);
          } else {
            // store HTMLTrackElement and TextTrack to remote list
            _this.remoteTextTrackEls().addTrackElement_(node);
            _this.remoteTextTracks().addTrack(node.track);
            _this.textTracks().addTrack(node.track);
            if (!crossoriginTracks && !_this.el_.hasAttribute('crossorigin') && isCrossOrigin(node.src)) {
              crossoriginTracks = true;
            }
          }
        }
      }

      for (var i = 0; i < removeNodes.length; i++) {
        _this.el_.removeChild(removeNodes[i]);
      }
    }

    _this.proxyNativeTracks_();
    if (_this.featuresNativeTextTracks && crossoriginTracks) {
      log$1.warn(tsml(_templateObject$2));
    }

    // prevent iOS Safari from disabling metadata text tracks during native playback
    _this.restoreMetadataTracksInIOSNativePlayer_();

    // Determine if native controls should be used
    // Our goal should be to get the custom controls on mobile solid everywhere
    // so we can remove this all together. Right now this will block custom
    // controls on touch enabled laptops like the Chrome Pixel
    if ((TOUCH_ENABLED || IS_IPHONE || IS_NATIVE_ANDROID) && options.nativeControlsForTouch === true) {
      _this.setControls(true);
    }

    // on iOS, we want to proxy `webkitbeginfullscreen` and `webkitendfullscreen`
    // into a `fullscreenchange` event
    _this.proxyWebkitFullscreen_();

    _this.triggerReady();
    return _this;
  }

  /**
   * Dispose of `HTML5` media element and remove all tracks.
   */


  Html5.prototype.dispose = function dispose() {
    if (this.el_ && this.el_.resetSourceset_) {
      this.el_.resetSourceset_();
    }
    Html5.disposeMediaElement(this.el_);
    this.options_ = null;

    // tech will handle clearing of the emulated track list
    _Tech.prototype.dispose.call(this);
  };

  /**
   * Modify the media element so that we can detect when
   * the source is changed. Fires `sourceset` just after the source has changed
   */


  Html5.prototype.setupSourcesetHandling_ = function setupSourcesetHandling_() {
    setupSourceset(this);
  };

  /**
   * When a captions track is enabled in the iOS Safari native player, all other
   * tracks are disabled (including metadata tracks), which nulls all of their
   * associated cue points. This will restore metadata tracks to their pre-fullscreen
   * state in those cases so that cue points are not needlessly lost.
   *
   * @private
   */


  Html5.prototype.restoreMetadataTracksInIOSNativePlayer_ = function restoreMetadataTracksInIOSNativePlayer_() {
    var textTracks = this.textTracks();
    var metadataTracksPreFullscreenState = void 0;

    // captures a snapshot of every metadata track's current state
    var takeMetadataTrackSnapshot = function takeMetadataTrackSnapshot() {
      metadataTracksPreFullscreenState = [];

      for (var i = 0; i < textTracks.length; i++) {
        var track = textTracks[i];

        if (track.kind === 'metadata') {
          metadataTracksPreFullscreenState.push({
            track: track,
            storedMode: track.mode
          });
        }
      }
    };

    // snapshot each metadata track's initial state, and update the snapshot
    // each time there is a track 'change' event
    takeMetadataTrackSnapshot();
    textTracks.addEventListener('change', takeMetadataTrackSnapshot);

    this.on('dispose', function () {
      return textTracks.removeEventListener('change', takeMetadataTrackSnapshot);
    });

    var restoreTrackMode = function restoreTrackMode() {
      for (var i = 0; i < metadataTracksPreFullscreenState.length; i++) {
        var storedTrack = metadataTracksPreFullscreenState[i];

        if (storedTrack.track.mode === 'disabled' && storedTrack.track.mode !== storedTrack.storedMode) {
          storedTrack.track.mode = storedTrack.storedMode;
        }
      }
      // we only want this handler to be executed on the first 'change' event
      textTracks.removeEventListener('change', restoreTrackMode);
    };

    // when we enter fullscreen playback, stop updating the snapshot and
    // restore all track modes to their pre-fullscreen state
    this.on('webkitbeginfullscreen', function () {
      textTracks.removeEventListener('change', takeMetadataTrackSnapshot);

      // remove the listener before adding it just in case it wasn't previously removed
      textTracks.removeEventListener('change', restoreTrackMode);
      textTracks.addEventListener('change', restoreTrackMode);
    });

    // start updating the snapshot again after leaving fullscreen
    this.on('webkitendfullscreen', function () {
      // remove the listener before adding it just in case it wasn't previously removed
      textTracks.removeEventListener('change', takeMetadataTrackSnapshot);
      textTracks.addEventListener('change', takeMetadataTrackSnapshot);

      // remove the restoreTrackMode handler in case it wasn't triggered during fullscreen playback
      textTracks.removeEventListener('change', restoreTrackMode);
    });
  };

  /**
   * Proxy all native track list events to our track lists if the browser we are playing
   * in supports that type of track list.
   *
   * @private
   */


  Html5.prototype.proxyNativeTracks_ = function proxyNativeTracks_() {
    var _this2 = this;

    NORMAL.names.forEach(function (name) {
      var props = NORMAL[name];
      var elTracks = _this2.el()[props.getterName];
      var techTracks = _this2[props.getterName]();

      if (!_this2['featuresNative' + props.capitalName + 'Tracks'] || !elTracks || !elTracks.addEventListener) {
        return;
      }
      var listeners = {
        change: function change(e) {
          techTracks.trigger({
            type: 'change',
            target: techTracks,
            currentTarget: techTracks,
            srcElement: techTracks
          });
        },
        addtrack: function addtrack(e) {
          techTracks.addTrack(e.track);
        },
        removetrack: function removetrack(e) {
          techTracks.removeTrack(e.track);
        }
      };
      var removeOldTracks = function removeOldTracks() {
        var removeTracks = [];

        for (var i = 0; i < techTracks.length; i++) {
          var found = false;

          for (var j = 0; j < elTracks.length; j++) {
            if (elTracks[j] === techTracks[i]) {
              found = true;
              break;
            }
          }

          if (!found) {
            removeTracks.push(techTracks[i]);
          }
        }

        while (removeTracks.length) {
          techTracks.removeTrack(removeTracks.shift());
        }
      };

      Object.keys(listeners).forEach(function (eventName) {
        var listener = listeners[eventName];

        elTracks.addEventListener(eventName, listener);
        _this2.on('dispose', function (e) {
          return elTracks.removeEventListener(eventName, listener);
        });
      });

      // Remove (native) tracks that are not used anymore
      _this2.on('loadstart', removeOldTracks);
      _this2.on('dispose', function (e) {
        return _this2.off('loadstart', removeOldTracks);
      });
    });
  };

  /**
   * Create the `Html5` Tech's DOM element.
   *
   * @return {Element}
   *         The element that gets created.
   */


  Html5.prototype.createEl = function createEl$$1() {
    var el = this.options_.tag;

    // Check if this browser supports moving the element into the box.
    // On the iPhone video will break if you move the element,
    // So we have to create a brand new element.
    // If we ingested the player div, we do not need to move the media element.
    if (!el || !(this.options_.playerElIngest || this.movingMediaElementInDOM)) {

      // If the original tag is still there, clone and remove it.
      if (el) {
        var clone = el.cloneNode(true);

        if (el.parentNode) {
          el.parentNode.insertBefore(clone, el);
        }
        Html5.disposeMediaElement(el);
        el = clone;
      } else {
        el = document_1.createElement('video');

        // determine if native controls should be used
        var tagAttributes = this.options_.tag && getAttributes(this.options_.tag);
        var attributes = mergeOptions({}, tagAttributes);

        if (!TOUCH_ENABLED || this.options_.nativeControlsForTouch !== true) {
          delete attributes.controls;
        }

        setAttributes(el, assign(attributes, {
          id: this.options_.techId,
          'class': 'vjs-tech'
        }));
      }

      el.playerId = this.options_.playerId;
    }

    if (typeof this.options_.preload !== 'undefined') {
      setAttribute(el, 'preload', this.options_.preload);
    }

    // Update specific tag settings, in case they were overridden
    // `autoplay` has to be *last* so that `muted` and `playsinline` are present
    // when iOS/Safari or other browsers attempt to autoplay.
    var settingsAttrs = ['loop', 'muted', 'playsinline', 'autoplay'];

    for (var i = 0; i < settingsAttrs.length; i++) {
      var attr = settingsAttrs[i];
      var value = this.options_[attr];

      if (typeof value !== 'undefined') {
        if (value) {
          setAttribute(el, attr, attr);
        } else {
          removeAttribute(el, attr);
        }
        el[attr] = value;
      }
    }

    return el;
  };

  /**
   * This will be triggered if the loadstart event has already fired, before videojs was
   * ready. Two known examples of when this can happen are:
   * 1. If we're loading the playback object after it has started loading
   * 2. The media is already playing the (often with autoplay on) then
   *
   * This function will fire another loadstart so that videojs can catchup.
   *
   * @fires Tech#loadstart
   *
   * @return {undefined}
   *         returns nothing.
   */


  Html5.prototype.handleLateInit_ = function handleLateInit_(el) {
    if (el.networkState === 0 || el.networkState === 3) {
      // The video element hasn't started loading the source yet
      // or didn't find a source
      return;
    }

    if (el.readyState === 0) {
      // NetworkState is set synchronously BUT loadstart is fired at the
      // end of the current stack, usually before setInterval(fn, 0).
      // So at this point we know loadstart may have already fired or is
      // about to fire, and either way the player hasn't seen it yet.
      // We don't want to fire loadstart prematurely here and cause a
      // double loadstart so we'll wait and see if it happens between now
      // and the next loop, and fire it if not.
      // HOWEVER, we also want to make sure it fires before loadedmetadata
      // which could also happen between now and the next loop, so we'll
      // watch for that also.
      var loadstartFired = false;
      var setLoadstartFired = function setLoadstartFired() {
        loadstartFired = true;
      };

      this.on('loadstart', setLoadstartFired);

      var triggerLoadstart = function triggerLoadstart() {
        // We did miss the original loadstart. Make sure the player
        // sees loadstart before loadedmetadata
        if (!loadstartFired) {
          this.trigger('loadstart');
        }
      };

      this.on('loadedmetadata', triggerLoadstart);

      this.ready(function () {
        this.off('loadstart', setLoadstartFired);
        this.off('loadedmetadata', triggerLoadstart);

        if (!loadstartFired) {
          // We did miss the original native loadstart. Fire it now.
          this.trigger('loadstart');
        }
      });

      return;
    }

    // From here on we know that loadstart already fired and we missed it.
    // The other readyState events aren't as much of a problem if we double
    // them, so not going to go to as much trouble as loadstart to prevent
    // that unless we find reason to.
    var eventsToTrigger = ['loadstart'];

    // loadedmetadata: newly equal to HAVE_METADATA (1) or greater
    eventsToTrigger.push('loadedmetadata');

    // loadeddata: newly increased to HAVE_CURRENT_DATA (2) or greater
    if (el.readyState >= 2) {
      eventsToTrigger.push('loadeddata');
    }

    // canplay: newly increased to HAVE_FUTURE_DATA (3) or greater
    if (el.readyState >= 3) {
      eventsToTrigger.push('canplay');
    }

    // canplaythrough: newly equal to HAVE_ENOUGH_DATA (4)
    if (el.readyState >= 4) {
      eventsToTrigger.push('canplaythrough');
    }

    // We still need to give the player time to add event listeners
    this.ready(function () {
      eventsToTrigger.forEach(function (type) {
        this.trigger(type);
      }, this);
    });
  };

  /**
   * Set current time for the `HTML5` tech.
   *
   * @param {number} seconds
   *        Set the current time of the media to this.
   */


  Html5.prototype.setCurrentTime = function setCurrentTime(seconds) {
    try {
      this.el_.currentTime = seconds;
    } catch (e) {
      log$1(e, 'Video is not ready. (Video.js)');
      // this.warning(VideoJS.warnings.videoNotReady);
    }
  };

  /**
   * Get the current duration of the HTML5 media element.
   *
   * @return {number}
   *         The duration of the media or 0 if there is no duration.
   */


  Html5.prototype.duration = function duration() {
    var _this3 = this;

    // Android Chrome will report duration as Infinity for VOD HLS until after
    // playback has started, which triggers the live display erroneously.
    // Return NaN if playback has not started and trigger a durationupdate once
    // the duration can be reliably known.
    if (this.el_.duration === Infinity && IS_ANDROID && IS_CHROME && this.el_.currentTime === 0) {
      // Wait for the first `timeupdate` with currentTime > 0 - there may be
      // several with 0
      var checkProgress = function checkProgress() {
        if (_this3.el_.currentTime > 0) {
          // Trigger durationchange for genuinely live video
          if (_this3.el_.duration === Infinity) {
            _this3.trigger('durationchange');
          }
          _this3.off('timeupdate', checkProgress);
        }
      };

      this.on('timeupdate', checkProgress);
      return NaN;
    }
    return this.el_.duration || NaN;
  };

  /**
   * Get the current width of the HTML5 media element.
   *
   * @return {number}
   *         The width of the HTML5 media element.
   */


  Html5.prototype.width = function width() {
    return this.el_.offsetWidth;
  };

  /**
   * Get the current height of the HTML5 media element.
   *
   * @return {number}
   *         The heigth of the HTML5 media element.
   */


  Html5.prototype.height = function height() {
    return this.el_.offsetHeight;
  };

  /**
   * Proxy iOS `webkitbeginfullscreen` and `webkitendfullscreen` into
   * `fullscreenchange` event.
   *
   * @private
   * @fires fullscreenchange
   * @listens webkitendfullscreen
   * @listens webkitbeginfullscreen
   * @listens webkitbeginfullscreen
   */


  Html5.prototype.proxyWebkitFullscreen_ = function proxyWebkitFullscreen_() {
    var _this4 = this;

    if (!('webkitDisplayingFullscreen' in this.el_)) {
      return;
    }

    var endFn = function endFn() {
      this.trigger('fullscreenchange', { isFullscreen: false });
    };

    var beginFn = function beginFn() {
      if ('webkitPresentationMode' in this.el_ && this.el_.webkitPresentationMode !== 'picture-in-picture') {
        this.one('webkitendfullscreen', endFn);

        this.trigger('fullscreenchange', { isFullscreen: true });
      }
    };

    this.on('webkitbeginfullscreen', beginFn);
    this.on('dispose', function () {
      _this4.off('webkitbeginfullscreen', beginFn);
      _this4.off('webkitendfullscreen', endFn);
    });
  };

  /**
   * Check if fullscreen is supported on the current playback device.
   *
   * @return {boolean}
   *         - True if fullscreen is supported.
   *         - False if fullscreen is not supported.
   */


  Html5.prototype.supportsFullScreen = function supportsFullScreen() {
    if (typeof this.el_.webkitEnterFullScreen === 'function') {
      var userAgent = window_1.navigator && window_1.navigator.userAgent || '';

      // Seems to be broken in Chromium/Chrome && Safari in Leopard
      if (/Android/.test(userAgent) || !/Chrome|Mac OS X 10.5/.test(userAgent)) {
        return true;
      }
    }
    return false;
  };

  /**
   * Request that the `HTML5` Tech enter fullscreen.
   */


  Html5.prototype.enterFullScreen = function enterFullScreen() {
    var video = this.el_;

    if (video.paused && video.networkState <= video.HAVE_METADATA) {
      // attempt to prime the video element for programmatic access
      // this isn't necessary on the desktop but shouldn't hurt
      this.el_.play();

      // playing and pausing synchronously during the transition to fullscreen
      // can get iOS ~6.1 devices into a play/pause loop
      this.setTimeout(function () {
        video.pause();
        video.webkitEnterFullScreen();
      }, 0);
    } else {
      video.webkitEnterFullScreen();
    }
  };

  /**
   * Request that the `HTML5` Tech exit fullscreen.
   */


  Html5.prototype.exitFullScreen = function exitFullScreen() {
    this.el_.webkitExitFullScreen();
  };

  /**
   * A getter/setter for the `Html5` Tech's source object.
   * > Note: Please use {@link Html5#setSource}
   *
   * @param {Tech~SourceObject} [src]
   *        The source object you want to set on the `HTML5` techs element.
   *
   * @return {Tech~SourceObject|undefined}
   *         - The current source object when a source is not passed in.
   *         - undefined when setting
   *
   * @deprecated Since version 5.
   */


  Html5.prototype.src = function src(_src) {
    if (_src === undefined) {
      return this.el_.src;
    }

    // Setting src through `src` instead of `setSrc` will be deprecated
    this.setSrc(_src);
  };

  /**
   * Reset the tech by removing all sources and then calling
   * {@link Html5.resetMediaElement}.
   */


  Html5.prototype.reset = function reset() {
    Html5.resetMediaElement(this.el_);
  };

  /**
   * Get the current source on the `HTML5` Tech. Falls back to returning the source from
   * the HTML5 media element.
   *
   * @return {Tech~SourceObject}
   *         The current source object from the HTML5 tech. With a fallback to the
   *         elements source.
   */


  Html5.prototype.currentSrc = function currentSrc() {
    if (this.currentSource_) {
      return this.currentSource_.src;
    }
    return this.el_.currentSrc;
  };

  /**
   * Set controls attribute for the HTML5 media Element.
   *
   * @param {string} val
   *        Value to set the controls attribute to
   */


  Html5.prototype.setControls = function setControls(val) {
    this.el_.controls = !!val;
  };

  /**
   * Create and returns a remote {@link TextTrack} object.
   *
   * @param {string} kind
   *        `TextTrack` kind (subtitles, captions, descriptions, chapters, or metadata)
   *
   * @param {string} [label]
   *        Label to identify the text track
   *
   * @param {string} [language]
   *        Two letter language abbreviation
   *
   * @return {TextTrack}
   *         The TextTrack that gets created.
   */


  Html5.prototype.addTextTrack = function addTextTrack(kind, label, language) {
    if (!this.featuresNativeTextTracks) {
      return _Tech.prototype.addTextTrack.call(this, kind, label, language);
    }

    return this.el_.addTextTrack(kind, label, language);
  };

  /**
   * Creates either native TextTrack or an emulated TextTrack depending
   * on the value of `featuresNativeTextTracks`
   *
   * @param {Object} options
   *        The object should contain the options to intialize the TextTrack with.
   *
   * @param {string} [options.kind]
   *        `TextTrack` kind (subtitles, captions, descriptions, chapters, or metadata).
   *
   * @param {string} [options.label].
   *        Label to identify the text track
   *
   * @param {string} [options.language]
   *        Two letter language abbreviation.
   *
   * @param {boolean} [options.default]
   *        Default this track to on.
   *
   * @param {string} [options.id]
   *        The internal id to assign this track.
   *
   * @param {string} [options.src]
   *        A source url for the track.
   *
   * @return {HTMLTrackElement}
   *         The track element that gets created.
   */


  Html5.prototype.createRemoteTextTrack = function createRemoteTextTrack(options) {
    if (!this.featuresNativeTextTracks) {
      return _Tech.prototype.createRemoteTextTrack.call(this, options);
    }
    var htmlTrackElement = document_1.createElement('track');

    if (options.kind) {
      htmlTrackElement.kind = options.kind;
    }
    if (options.label) {
      htmlTrackElement.label = options.label;
    }
    if (options.language || options.srclang) {
      htmlTrackElement.srclang = options.language || options.srclang;
    }
    if (options['default']) {
      htmlTrackElement['default'] = options['default'];
    }
    if (options.id) {
      htmlTrackElement.id = options.id;
    }
    if (options.src) {
      htmlTrackElement.src = options.src;
    }

    return htmlTrackElement;
  };

  /**
   * Creates a remote text track object and returns an html track element.
   *
   * @param {Object} options The object should contain values for
   * kind, language, label, and src (location of the WebVTT file)
   * @param {Boolean} [manualCleanup=true] if set to false, the TextTrack will be
   * automatically removed from the video element whenever the source changes
   * @return {HTMLTrackElement} An Html Track Element.
   * This can be an emulated {@link HTMLTrackElement} or a native one.
   * @deprecated The default value of the "manualCleanup" parameter will default
   * to "false" in upcoming versions of Video.js
   */


  Html5.prototype.addRemoteTextTrack = function addRemoteTextTrack(options, manualCleanup) {
    var htmlTrackElement = _Tech.prototype.addRemoteTextTrack.call(this, options, manualCleanup);

    if (this.featuresNativeTextTracks) {
      this.el().appendChild(htmlTrackElement);
    }

    return htmlTrackElement;
  };

  /**
   * Remove remote `TextTrack` from `TextTrackList` object
   *
   * @param {TextTrack} track
   *        `TextTrack` object to remove
   */


  Html5.prototype.removeRemoteTextTrack = function removeRemoteTextTrack(track) {
    _Tech.prototype.removeRemoteTextTrack.call(this, track);

    if (this.featuresNativeTextTracks) {
      var tracks = this.$$('track');

      var i = tracks.length;

      while (i--) {
        if (track === tracks[i] || track === tracks[i].track) {
          this.el().removeChild(tracks[i]);
        }
      }
    }
  };

  /**
   * Gets available media playback quality metrics as specified by the W3C's Media
   * Playback Quality API.
   *
   * @see [Spec]{@link https://wicg.github.io/media-playback-quality}
   *
   * @return {Object}
   *         An object with supported media playback quality metrics
   */


  Html5.prototype.getVideoPlaybackQuality = function getVideoPlaybackQuality() {
    if (typeof this.el().getVideoPlaybackQuality === 'function') {
      return this.el().getVideoPlaybackQuality();
    }

    var videoPlaybackQuality = {};

    if (typeof this.el().webkitDroppedFrameCount !== 'undefined' && typeof this.el().webkitDecodedFrameCount !== 'undefined') {
      videoPlaybackQuality.droppedVideoFrames = this.el().webkitDroppedFrameCount;
      videoPlaybackQuality.totalVideoFrames = this.el().webkitDecodedFrameCount;
    }

    if (window_1.performance && typeof window_1.performance.now === 'function') {
      videoPlaybackQuality.creationTime = window_1.performance.now();
    } else if (window_1.performance && window_1.performance.timing && typeof window_1.performance.timing.navigationStart === 'number') {
      videoPlaybackQuality.creationTime = window_1.Date.now() - window_1.performance.timing.navigationStart;
    }

    return videoPlaybackQuality;
  };

  return Html5;
}(Tech);

/* HTML5 Support Testing ---------------------------------------------------- */

if (isReal()) {

  /**
   * Element for testing browser HTML5 media capabilities
   *
   * @type {Element}
   * @constant
   * @private
   */
  Html5.TEST_VID = document_1.createElement('video');
  var track = document_1.createElement('track');

  track.kind = 'captions';
  track.srclang = 'en';
  track.label = 'English';
  Html5.TEST_VID.appendChild(track);
}

/**
 * Check if HTML5 media is supported by this browser/device.
 *
 * @return {boolean}
 *         - True if HTML5 media is supported.
 *         - False if HTML5 media is not supported.
 */
Html5.isSupported = function () {
  // IE9 with no Media Player is a LIAR! (#984)
  try {
    Html5.TEST_VID.volume = 0.5;
  } catch (e) {
    return false;
  }

  return !!(Html5.TEST_VID && Html5.TEST_VID.canPlayType);
};

/**
 * Check if the tech can support the given type
 *
 * @param {string} type
 *        The mimetype to check
 * @return {string} 'probably', 'maybe', or '' (empty string)
 */
Html5.canPlayType = function (type) {
  return Html5.TEST_VID.canPlayType(type);
};

/**
 * Check if the tech can support the given source
 * @param {Object} srcObj
 *        The source object
 * @param {Object} options
 *        The options passed to the tech
 * @return {string} 'probably', 'maybe', or '' (empty string)
 */
Html5.canPlaySource = function (srcObj, options) {
  return Html5.canPlayType(srcObj.type);
};

/**
 * Check if the volume can be changed in this browser/device.
 * Volume cannot be changed in a lot of mobile devices.
 * Specifically, it can't be changed from 1 on iOS.
 *
 * @return {boolean}
 *         - True if volume can be controlled
 *         - False otherwise
 */
Html5.canControlVolume = function () {
  // IE will error if Windows Media Player not installed #3315
  try {
    var volume = Html5.TEST_VID.volume;

    Html5.TEST_VID.volume = volume / 2 + 0.1;
    return volume !== Html5.TEST_VID.volume;
  } catch (e) {
    return false;
  }
};

/**
 * Check if the volume can be muted in this browser/device.
 * Some devices, e.g. iOS, don't allow changing volume
 * but permits muting/unmuting.
 *
 * @return {bolean}
 *      - True if volume can be muted
 *      - False otherwise
 */
Html5.canMuteVolume = function () {
  try {
    var muted = Html5.TEST_VID.muted;

    // in some versions of iOS muted property doesn't always
    // work, so we want to set both property and attribute
    Html5.TEST_VID.muted = !muted;
    if (Html5.TEST_VID.muted) {
      setAttribute(Html5.TEST_VID, 'muted', 'muted');
    } else {
      removeAttribute(Html5.TEST_VID, 'muted', 'muted');
    }
    return muted !== Html5.TEST_VID.muted;
  } catch (e) {
    return false;
  }
};

/**
 * Check if the playback rate can be changed in this browser/device.
 *
 * @return {boolean}
 *         - True if playback rate can be controlled
 *         - False otherwise
 */
Html5.canControlPlaybackRate = function () {
  // Playback rate API is implemented in Android Chrome, but doesn't do anything
  // https://github.com/videojs/video.js/issues/3180
  if (IS_ANDROID && IS_CHROME && CHROME_VERSION < 58) {
    return false;
  }
  // IE will error if Windows Media Player not installed #3315
  try {
    var playbackRate = Html5.TEST_VID.playbackRate;

    Html5.TEST_VID.playbackRate = playbackRate / 2 + 0.1;
    return playbackRate !== Html5.TEST_VID.playbackRate;
  } catch (e) {
    return false;
  }
};

/**
 * Check if we can override a video/audio elements attributes, with
 * Object.defineProperty.
 *
 * @return {boolean}
 *         - True if builtin attributes can be overriden
 *         - False otherwise
 */
Html5.canOverrideAttributes = function () {
  if (IS_IE8) {
    return false;
  }
  // if we cannot overwrite the src/innerHTML property, there is no support
  // iOS 7 safari for instance cannot do this.
  try {
    var noop = function noop() {};

    Object.defineProperty(document_1.createElement('video'), 'src', { get: noop, set: noop });
    Object.defineProperty(document_1.createElement('audio'), 'src', { get: noop, set: noop });
    Object.defineProperty(document_1.createElement('video'), 'innerHTML', { get: noop, set: noop });
    Object.defineProperty(document_1.createElement('audio'), 'innerHTML', { get: noop, set: noop });
  } catch (e) {
    return false;
  }

  return true;
};

/**
 * Check to see if native `TextTrack`s are supported by this browser/device.
 *
 * @return {boolean}
 *         - True if native `TextTrack`s are supported.
 *         - False otherwise
 */
Html5.supportsNativeTextTracks = function () {
  return IS_ANY_SAFARI || IS_IOS && IS_CHROME;
};

/**
 * Check to see if native `VideoTrack`s are supported by this browser/device
 *
 * @return {boolean}
 *        - True if native `VideoTrack`s are supported.
 *        - False otherwise
 */
Html5.supportsNativeVideoTracks = function () {
  return !!(Html5.TEST_VID && Html5.TEST_VID.videoTracks);
};

/**
 * Check to see if native `AudioTrack`s are supported by this browser/device
 *
 * @return {boolean}
 *        - True if native `AudioTrack`s are supported.
 *        - False otherwise
 */
Html5.supportsNativeAudioTracks = function () {
  return !!(Html5.TEST_VID && Html5.TEST_VID.audioTracks);
};

/**
 * An array of events available on the Html5 tech.
 *
 * @private
 * @type {Array}
 */
Html5.Events = ['loadstart', 'suspend', 'abort', 'error', 'emptied', 'stalled', 'loadedmetadata', 'loadeddata', 'canplay', 'canplaythrough', 'playing', 'waiting', 'seeking', 'seeked', 'ended', 'durationchange', 'timeupdate', 'progress', 'play', 'pause', 'ratechange', 'resize', 'volumechange'];

/**
 * Boolean indicating whether the `Tech` supports volume control.
 *
 * @type {boolean}
 * @default {@link Html5.canControlVolume}
 */
Html5.prototype.featuresVolumeControl = Html5.canControlVolume();

/**
 * Boolean indicating whether the `Tech` supports muting volume.
 *
 * @type {bolean}
 * @default {@link Html5.canMuteVolume}
 */
Html5.prototype.featuresMuteControl = Html5.canMuteVolume();

/**
 * Boolean indicating whether the `Tech` supports changing the speed at which the media
 * plays. Examples:
 *   - Set player to play 2x (twice) as fast
 *   - Set player to play 0.5x (half) as fast
 *
 * @type {boolean}
 * @default {@link Html5.canControlPlaybackRate}
 */
Html5.prototype.featuresPlaybackRate = Html5.canControlPlaybackRate();

/**
 * Boolean indicating wether the `Tech` supports the `sourceset` event.
 *
 * @type {boolean}
 * @default
 */
Html5.prototype.featuresSourceset = Html5.canOverrideAttributes();

/**
 * Boolean indicating whether the `HTML5` tech currently supports the media element
 * moving in the DOM. iOS breaks if you move the media element, so this is set this to
 * false there. Everywhere else this should be true.
 *
 * @type {boolean}
 * @default
 */
Html5.prototype.movingMediaElementInDOM = !IS_IOS;

// TODO: Previous comment: No longer appears to be used. Can probably be removed.
//       Is this true?
/**
 * Boolean indicating whether the `HTML5` tech currently supports automatic media resize
 * when going into fullscreen.
 *
 * @type {boolean}
 * @default
 */
Html5.prototype.featuresFullscreenResize = true;

/**
 * Boolean indicating whether the `HTML5` tech currently supports the progress event.
 * If this is false, manual `progress` events will be triggred instead.
 *
 * @type {boolean}
 * @default
 */
Html5.prototype.featuresProgressEvents = true;

/**
 * Boolean indicating whether the `HTML5` tech currently supports the timeupdate event.
 * If this is false, manual `timeupdate` events will be triggred instead.
 *
 * @default
 */
Html5.prototype.featuresTimeupdateEvents = true;

/**
 * Boolean indicating whether the `HTML5` tech currently supports native `TextTrack`s.
 *
 * @type {boolean}
 * @default {@link Html5.supportsNativeTextTracks}
 */
Html5.prototype.featuresNativeTextTracks = Html5.supportsNativeTextTracks();

/**
 * Boolean indicating whether the `HTML5` tech currently supports native `VideoTrack`s.
 *
 * @type {boolean}
 * @default {@link Html5.supportsNativeVideoTracks}
 */
Html5.prototype.featuresNativeVideoTracks = Html5.supportsNativeVideoTracks();

/**
 * Boolean indicating whether the `HTML5` tech currently supports native `AudioTrack`s.
 *
 * @type {boolean}
 * @default {@link Html5.supportsNativeAudioTracks}
 */
Html5.prototype.featuresNativeAudioTracks = Html5.supportsNativeAudioTracks();

// HTML5 Feature detection and Device Fixes --------------------------------- //
var canPlayType = Html5.TEST_VID && Html5.TEST_VID.constructor.prototype.canPlayType;
var mpegurlRE = /^application\/(?:x-|vnd\.apple\.)mpegurl/i;
var mp4RE = /^video\/mp4/i;

Html5.patchCanPlayType = function () {

  // Android 4.0 and above can play HLS to some extent but it reports being unable to do so
  // Firefox and Chrome report correctly
  if (ANDROID_VERSION >= 4.0 && !IS_FIREFOX && !IS_CHROME) {
    Html5.TEST_VID.constructor.prototype.canPlayType = function (type) {
      if (type && mpegurlRE.test(type)) {
        return 'maybe';
      }
      return canPlayType.call(this, type);
    };

    // Override Android 2.2 and less canPlayType method which is broken
  } else if (IS_OLD_ANDROID) {
    Html5.TEST_VID.constructor.prototype.canPlayType = function (type) {
      if (type && mp4RE.test(type)) {
        return 'maybe';
      }
      return canPlayType.call(this, type);
    };
  }
};

Html5.unpatchCanPlayType = function () {
  var r = Html5.TEST_VID.constructor.prototype.canPlayType;

  Html5.TEST_VID.constructor.prototype.canPlayType = canPlayType;
  return r;
};

// by default, patch the media element
Html5.patchCanPlayType();

Html5.disposeMediaElement = function (el) {
  if (!el) {
    return;
  }

  if (el.parentNode) {
    el.parentNode.removeChild(el);
  }

  // remove any child track or source nodes to prevent their loading
  while (el.hasChildNodes()) {
    el.removeChild(el.firstChild);
  }

  // remove any src reference. not setting `src=''` because that causes a warning
  // in firefox
  el.removeAttribute('src');

  // force the media element to update its loading state by calling load()
  // however IE on Windows 7N has a bug that throws an error so need a try/catch (#793)
  if (typeof el.load === 'function') {
    // wrapping in an iife so it's not deoptimized (#1060#discussion_r10324473)
    (function () {
      try {
        el.load();
      } catch (e) {
        // not supported
      }
    })();
  }
};

Html5.resetMediaElement = function (el) {
  if (!el) {
    return;
  }

  var sources = el.querySelectorAll('source');
  var i = sources.length;

  while (i--) {
    el.removeChild(sources[i]);
  }

  // remove any src reference.
  // not setting `src=''` because that throws an error
  el.removeAttribute('src');

  if (typeof el.load === 'function') {
    // wrapping in an iife so it's not deoptimized (#1060#discussion_r10324473)
    (function () {
      try {
        el.load();
      } catch (e) {
        // satisfy linter
      }
    })();
  }
};

/* Native HTML5 element property wrapping ----------------------------------- */
// Wrap native boolean attributes with getters that check both property and attribute
// The list is as followed:
// muted, defaultMuted, autoplay, controls, loop, playsinline
[
/**
 * Get the value of `muted` from the media element. `muted` indicates
 * that the volume for the media should be set to silent. This does not actually change
 * the `volume` attribute.
 *
 * @method Html5#muted
 * @return {boolean}
 *         - True if the value of `volume` should be ignored and the audio set to silent.
 *         - False if the value of `volume` should be used.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-muted}
 */
'muted',

/**
 * Get the value of `defaultMuted` from the media element. `defaultMuted` indicates
 * whether the media should start muted or not. Only changes the default state of the
 * media. `muted` and `defaultMuted` can have different values. {@link Html5#muted} indicates the
 * current state.
 *
 * @method Html5#defaultMuted
 * @return {boolean}
 *         - The value of `defaultMuted` from the media element.
 *         - True indicates that the media should start muted.
 *         - False indicates that the media should not start muted
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-defaultmuted}
 */
'defaultMuted',

/**
 * Get the value of `autoplay` from the media element. `autoplay` indicates
 * that the media should start to play as soon as the page is ready.
 *
 * @method Html5#autoplay
 * @return {boolean}
 *         - The value of `autoplay` from the media element.
 *         - True indicates that the media should start as soon as the page loads.
 *         - False indicates that the media should not start as soon as the page loads.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-autoplay}
 */
'autoplay',

/**
 * Get the value of `controls` from the media element. `controls` indicates
 * whether the native media controls should be shown or hidden.
 *
 * @method Html5#controls
 * @return {boolean}
 *         - The value of `controls` from the media element.
 *         - True indicates that native controls should be showing.
 *         - False indicates that native controls should be hidden.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-controls}
 */
'controls',

/**
 * Get the value of `loop` from the media element. `loop` indicates
 * that the media should return to the start of the media and continue playing once
 * it reaches the end.
 *
 * @method Html5#loop
 * @return {boolean}
 *         - The value of `loop` from the media element.
 *         - True indicates that playback should seek back to start once
 *           the end of a media is reached.
 *         - False indicates that playback should not loop back to the start when the
 *           end of the media is reached.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-loop}
 */
'loop',

/**
 * Get the value of `playsinline` from the media element. `playsinline` indicates
 * to the browser that non-fullscreen playback is preferred when fullscreen
 * playback is the native default, such as in iOS Safari.
 *
 * @method Html5#playsinline
 * @return {boolean}
 *         - The value of `playsinline` from the media element.
 *         - True indicates that the media should play inline.
 *         - False indicates that the media should not play inline.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/#attr-video-playsinline}
 */
'playsinline'].forEach(function (prop) {
  Html5.prototype[prop] = function () {
    return this.el_[prop] || this.el_.hasAttribute(prop);
  };
});

// Wrap native boolean attributes with setters that set both property and attribute
// The list is as followed:
// setMuted, setDefaultMuted, setAutoplay, setLoop, setPlaysinline
// setControls is special-cased above
[
/**
 * Set the value of `muted` on the media element. `muted` indicates that the current
 * audio level should be silent.
 *
 * @method Html5#setMuted
 * @param {boolean} muted
 *        - True if the audio should be set to silent
 *        - False otherwise
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-muted}
 */
'muted',

/**
 * Set the value of `defaultMuted` on the media element. `defaultMuted` indicates that the current
 * audio level should be silent, but will only effect the muted level on intial playback..
 *
 * @method Html5.prototype.setDefaultMuted
 * @param {boolean} defaultMuted
 *        - True if the audio should be set to silent
 *        - False otherwise
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-defaultmuted}
 */
'defaultMuted',

/**
 * Set the value of `autoplay` on the media element. `autoplay` indicates
 * that the media should start to play as soon as the page is ready.
 *
 * @method Html5#setAutoplay
 * @param {boolean} autoplay
 *         - True indicates that the media should start as soon as the page loads.
 *         - False indicates that the media should not start as soon as the page loads.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-autoplay}
 */
'autoplay',

/**
 * Set the value of `loop` on the media element. `loop` indicates
 * that the media should return to the start of the media and continue playing once
 * it reaches the end.
 *
 * @method Html5#setLoop
 * @param {boolean} loop
 *         - True indicates that playback should seek back to start once
 *           the end of a media is reached.
 *         - False indicates that playback should not loop back to the start when the
 *           end of the media is reached.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-loop}
 */
'loop',

/**
 * Set the value of `playsinline` from the media element. `playsinline` indicates
 * to the browser that non-fullscreen playback is preferred when fullscreen
 * playback is the native default, such as in iOS Safari.
 *
 * @method Html5#setPlaysinline
 * @param {boolean} playsinline
 *         - True indicates that the media should play inline.
 *         - False indicates that the media should not play inline.
 *
 * @see [Spec]{@link https://html.spec.whatwg.org/#attr-video-playsinline}
 */
'playsinline'].forEach(function (prop) {
  Html5.prototype['set' + toTitleCase(prop)] = function (v) {
    this.el_[prop] = v;

    if (v) {
      this.el_.setAttribute(prop, prop);
    } else {
      this.el_.removeAttribute(prop);
    }
  };
});

// Wrap native properties with a getter
// The list is as followed
// paused, currentTime, buffered, volume, poster, preload, error, seeking
// seekable, ended, playbackRate, defaultPlaybackRate, played, networkState
// readyState, videoWidth, videoHeight
[
/**
 * Get the value of `paused` from the media element. `paused` indicates whether the media element
 * is currently paused or not.
 *
 * @method Html5#paused
 * @return {boolean}
 *         The value of `paused` from the media element.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-paused}
 */
'paused',

/**
 * Get the value of `currentTime` from the media element. `currentTime` indicates
 * the current second that the media is at in playback.
 *
 * @method Html5#currentTime
 * @return {number}
 *         The value of `currentTime` from the media element.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-currenttime}
 */
'currentTime',

/**
 * Get the value of `buffered` from the media element. `buffered` is a `TimeRange`
 * object that represents the parts of the media that are already downloaded and
 * available for playback.
 *
 * @method Html5#buffered
 * @return {TimeRange}
 *         The value of `buffered` from the media element.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-buffered}
 */
'buffered',

/**
 * Get the value of `volume` from the media element. `volume` indicates
 * the current playback volume of audio for a media. `volume` will be a value from 0
 * (silent) to 1 (loudest and default).
 *
 * @method Html5#volume
 * @return {number}
 *         The value of `volume` from the media element. Value will be between 0-1.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-a-volume}
 */
'volume',

/**
 * Get the value of `poster` from the media element. `poster` indicates
 * that the url of an image file that can/will be shown when no media data is available.
 *
 * @method Html5#poster
 * @return {string}
 *         The value of `poster` from the media element. Value will be a url to an
 *         image.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-video-poster}
 */
'poster',

/**
 * Get the value of `preload` from the media element. `preload` indicates
 * what should download before the media is interacted with. It can have the following
 * values:
 * - none: nothing should be downloaded
 * - metadata: poster and the first few frames of the media may be downloaded to get
 *   media dimensions and other metadata
 * - auto: allow the media and metadata for the media to be downloaded before
 *    interaction
 *
 * @method Html5#preload
 * @return {string}
 *         The value of `preload` from the media element. Will be 'none', 'metadata',
 *         or 'auto'.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-preload}
 */
'preload',

/**
 * Get the value of the `error` from the media element. `error` indicates any
 * MediaError that may have occured during playback. If error returns null there is no
 * current error.
 *
 * @method Html5#error
 * @return {MediaError|null}
 *         The value of `error` from the media element. Will be `MediaError` if there
 *         is a current error and null otherwise.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-error}
 */
'error',

/**
 * Get the value of `seeking` from the media element. `seeking` indicates whether the
 * media is currently seeking to a new position or not.
 *
 * @method Html5#seeking
 * @return {boolean}
 *         - The value of `seeking` from the media element.
 *         - True indicates that the media is currently seeking to a new position.
 *         - Flase indicates that the media is not seeking to a new position at this time.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-seeking}
 */
'seeking',

/**
 * Get the value of `seekable` from the media element. `seekable` returns a
 * `TimeRange` object indicating ranges of time that can currently be `seeked` to.
 *
 * @method Html5#seekable
 * @return {TimeRange}
 *         The value of `seekable` from the media element. A `TimeRange` object
 *         indicating the current ranges of time that can be seeked to.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-seekable}
 */
'seekable',

/**
 * Get the value of `ended` from the media element. `ended` indicates whether
 * the media has reached the end or not.
 *
 * @method Html5#ended
 * @return {boolean}
 *         - The value of `ended` from the media element.
 *         - True indicates that the media has ended.
 *         - False indicates that the media has not ended.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-ended}
 */
'ended',

/**
 * Get the value of `playbackRate` from the media element. `playbackRate` indicates
 * the rate at which the media is currently playing back. Examples:
 *   - if playbackRate is set to 2, media will play twice as fast.
 *   - if playbackRate is set to 0.5, media will play half as fast.
 *
 * @method Html5#playbackRate
 * @return {number}
 *         The value of `playbackRate` from the media element. A number indicating
 *         the current playback speed of the media, where 1 is normal speed.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-playbackrate}
 */
'playbackRate',

/**
 * Get the value of `defaultPlaybackRate` from the media element. `defaultPlaybackRate` indicates
 * the rate at which the media is currently playing back. This value will not indicate the current
 * `playbackRate` after playback has started, use {@link Html5#playbackRate} for that.
 *
 * Examples:
 *   - if defaultPlaybackRate is set to 2, media will play twice as fast.
 *   - if defaultPlaybackRate is set to 0.5, media will play half as fast.
 *
 * @method Html5.prototype.defaultPlaybackRate
 * @return {number}
 *         The value of `defaultPlaybackRate` from the media element. A number indicating
 *         the current playback speed of the media, where 1 is normal speed.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-playbackrate}
 */
'defaultPlaybackRate',

/**
 * Get the value of `played` from the media element. `played` returns a `TimeRange`
 * object representing points in the media timeline that have been played.
 *
 * @method Html5#played
 * @return {TimeRange}
 *         The value of `played` from the media element. A `TimeRange` object indicating
 *         the ranges of time that have been played.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-played}
 */
'played',

/**
 * Get the value of `networkState` from the media element. `networkState` indicates
 * the current network state. It returns an enumeration from the following list:
 * - 0: NETWORK_EMPTY
 * - 1: NEWORK_IDLE
 * - 2: NETWORK_LOADING
 * - 3: NETWORK_NO_SOURCE
 *
 * @method Html5#networkState
 * @return {number}
 *         The value of `networkState` from the media element. This will be a number
 *         from the list in the description.
 *
 * @see [Spec] {@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-networkstate}
 */
'networkState',

/**
 * Get the value of `readyState` from the media element. `readyState` indicates
 * the current state of the media element. It returns an enumeration from the
 * following list:
 * - 0: HAVE_NOTHING
 * - 1: HAVE_METADATA
 * - 2: HAVE_CURRENT_DATA
 * - 3: HAVE_FUTURE_DATA
 * - 4: HAVE_ENOUGH_DATA
 *
 * @method Html5#readyState
 * @return {number}
 *         The value of `readyState` from the media element. This will be a number
 *         from the list in the description.
 *
 * @see [Spec] {@link https://www.w3.org/TR/html5/embedded-content-0.html#ready-states}
 */
'readyState',

/**
 * Get the value of `videoWidth` from the video element. `videoWidth` indicates
 * the current width of the video in css pixels.
 *
 * @method Html5#videoWidth
 * @return {number}
 *         The value of `videoWidth` from the video element. This will be a number
 *         in css pixels.
 *
 * @see [Spec] {@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-video-videowidth}
 */
'videoWidth',

/**
 * Get the value of `videoHeight` from the video element. `videoHeigth` indicates
 * the current height of the video in css pixels.
 *
 * @method Html5#videoHeight
 * @return {number}
 *         The value of `videoHeight` from the video element. This will be a number
 *         in css pixels.
 *
 * @see [Spec] {@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-video-videowidth}
 */
'videoHeight'].forEach(function (prop) {
  Html5.prototype[prop] = function () {
    return this.el_[prop];
  };
});

// Wrap native properties with a setter in this format:
// set + toTitleCase(name)
// The list is as follows:
// setVolume, setSrc, setPoster, setPreload, setPlaybackRate, setDefaultPlaybackRate
[
/**
 * Set the value of `volume` on the media element. `volume` indicates the current
 * audio level as a percentage in decimal form. This means that 1 is 100%, 0.5 is 50%, and
 * so on.
 *
 * @method Html5#setVolume
 * @param {number} percentAsDecimal
 *        The volume percent as a decimal. Valid range is from 0-1.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-a-volume}
 */
'volume',

/**
 * Set the value of `src` on the media element. `src` indicates the current
 * {@link Tech~SourceObject} for the media.
 *
 * @method Html5#setSrc
 * @param {Tech~SourceObject} src
 *        The source object to set as the current source.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-src}
 */
'src',

/**
 * Set the value of `poster` on the media element. `poster` is the url to
 * an image file that can/will be shown when no media data is available.
 *
 * @method Html5#setPoster
 * @param {string} poster
 *        The url to an image that should be used as the `poster` for the media
 *        element.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-poster}
 */
'poster',

/**
 * Set the value of `preload` on the media element. `preload` indicates
 * what should download before the media is interacted with. It can have the following
 * values:
 * - none: nothing should be downloaded
 * - metadata: poster and the first few frames of the media may be downloaded to get
 *   media dimensions and other metadata
 * - auto: allow the media and metadata for the media to be downloaded before
 *    interaction
 *
 * @method Html5#setPreload
 * @param {string} preload
 *         The value of `preload` to set on the media element. Must be 'none', 'metadata',
 *         or 'auto'.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#attr-media-preload}
 */
'preload',

/**
 * Set the value of `playbackRate` on the media element. `playbackRate` indicates
 * the rate at which the media should play back. Examples:
 *   - if playbackRate is set to 2, media will play twice as fast.
 *   - if playbackRate is set to 0.5, media will play half as fast.
 *
 * @method Html5#setPlaybackRate
 * @return {number}
 *         The value of `playbackRate` from the media element. A number indicating
 *         the current playback speed of the media, where 1 is normal speed.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-playbackrate}
 */
'playbackRate',

/**
 * Set the value of `defaultPlaybackRate` on the media element. `defaultPlaybackRate` indicates
 * the rate at which the media should play back upon initial startup. Changing this value
 * after a video has started will do nothing. Instead you should used {@link Html5#setPlaybackRate}.
 *
 * Example Values:
 *   - if playbackRate is set to 2, media will play twice as fast.
 *   - if playbackRate is set to 0.5, media will play half as fast.
 *
 * @method Html5.prototype.setDefaultPlaybackRate
 * @return {number}
 *         The value of `defaultPlaybackRate` from the media element. A number indicating
 *         the current playback speed of the media, where 1 is normal speed.
 *
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-defaultplaybackrate}
 */
'defaultPlaybackRate'].forEach(function (prop) {
  Html5.prototype['set' + toTitleCase(prop)] = function (v) {
    this.el_[prop] = v;
  };
});

// wrap native functions with a function
// The list is as follows:
// pause, load play
[
/**
 * A wrapper around the media elements `pause` function. This will call the `HTML5`
 * media elements `pause` function.
 *
 * @method Html5#pause
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-pause}
 */
'pause',

/**
 * A wrapper around the media elements `load` function. This will call the `HTML5`s
 * media element `load` function.
 *
 * @method Html5#load
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-load}
 */
'load',

/**
 * A wrapper around the media elements `play` function. This will call the `HTML5`s
 * media element `play` function.
 *
 * @method Html5#play
 * @see [Spec]{@link https://www.w3.org/TR/html5/embedded-content-0.html#dom-media-play}
 */
'play'].forEach(function (prop) {
  Html5.prototype[prop] = function () {
    return this.el_[prop]();
  };
});

Tech.withSourceHandlers(Html5);

/**
 * Native source handler for Html5, simply passes the source to the media element.
 *
 * @proprety {Tech~SourceObject} source
 *        The source object
 *
 * @proprety {Html5} tech
 *        The instance of the HTML5 tech.
 */
Html5.nativeSourceHandler = {};

/**
 * Check if the media element can play the given mime type.
 *
 * @param {string} type
 *        The mimetype to check
 *
 * @return {string}
 *         'probably', 'maybe', or '' (empty string)
 */
Html5.nativeSourceHandler.canPlayType = function (type) {
  // IE9 on Windows 7 without MediaPlayer throws an error here
  // https://github.com/videojs/video.js/issues/519
  try {
    return Html5.TEST_VID.canPlayType(type);
  } catch (e) {
    return '';
  }
};

/**
 * Check if the media element can handle a source natively.
 *
 * @param {Tech~SourceObject} source
 *         The source object
 *
 * @param {Object} [options]
 *         Options to be passed to the tech.
 *
 * @return {string}
 *         'probably', 'maybe', or '' (empty string).
 */
Html5.nativeSourceHandler.canHandleSource = function (source, options) {

  // If a type was provided we should rely on that
  if (source.type) {
    return Html5.nativeSourceHandler.canPlayType(source.type);

    // If no type, fall back to checking 'video/[EXTENSION]'
  } else if (source.src) {
    var ext = getFileExtension(source.src);

    return Html5.nativeSourceHandler.canPlayType('video/' + ext);
  }

  return '';
};

/**
 * Pass the source to the native media element.
 *
 * @param {Tech~SourceObject} source
 *        The source object
 *
 * @param {Html5} tech
 *        The instance of the Html5 tech
 *
 * @param {Object} [options]
 *        The options to pass to the source
 */
Html5.nativeSourceHandler.handleSource = function (source, tech, options) {
  tech.setSrc(source.src);
};

/**
 * A noop for the native dispose function, as cleanup is not needed.
 */
Html5.nativeSourceHandler.dispose = function () {};

// Register the native source handler
Html5.registerSourceHandler(Html5.nativeSourceHandler);

Tech.registerTech('Html5', Html5);

var _templateObject$1 = taggedTemplateLiteralLoose(['\n        Using the tech directly can be dangerous. I hope you know what you\'re doing.\n        See https://github.com/videojs/video.js/issues/2617 for more info.\n      '], ['\n        Using the tech directly can be dangerous. I hope you know what you\'re doing.\n        See https://github.com/videojs/video.js/issues/2617 for more info.\n      ']);

/**
 * @file player.js
 */
// Subclasses Component
// The following imports are used only to ensure that the corresponding modules
// are always included in the video.js package. Importing the modules will
// execute them and they will register themselves with video.js.
// Import Html5 tech, at least for disposing the original video tag.
// The following tech events are simply re-triggered
// on the player when they happen
var TECH_EVENTS_RETRIGGER = [
/**
 * Fired while the user agent is downloading media data.
 *
 * @event Player#progress
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `progress` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechProgress_
 * @fires Player#progress
 * @listens Tech#progress
 */
'progress',

/**
 * Fires when the loading of an audio/video is aborted.
 *
 * @event Player#abort
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `abort` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechAbort_
 * @fires Player#abort
 * @listens Tech#abort
 */
'abort',

/**
 * Fires when the browser is intentionally not getting media data.
 *
 * @event Player#suspend
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `suspend` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechSuspend_
 * @fires Player#suspend
 * @listens Tech#suspend
 */
'suspend',

/**
 * Fires when the current playlist is empty.
 *
 * @event Player#emptied
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `emptied` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechEmptied_
 * @fires Player#emptied
 * @listens Tech#emptied
 */
'emptied',
/**
 * Fires when the browser is trying to get media data, but data is not available.
 *
 * @event Player#stalled
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `stalled` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechStalled_
 * @fires Player#stalled
 * @listens Tech#stalled
 */
'stalled',

/**
 * Fires when the browser has loaded meta data for the audio/video.
 *
 * @event Player#loadedmetadata
 * @type {EventTarget~Event}
 */
/**
 * Retrigger the `stalled` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechLoadedmetadata_
 * @fires Player#loadedmetadata
 * @listens Tech#loadedmetadata
 */
'loadedmetadata',

/**
 * Fires when the browser has loaded the current frame of the audio/video.
 *
 * @event Player#loadeddata
 * @type {event}
 */
/**
 * Retrigger the `loadeddata` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechLoaddeddata_
 * @fires Player#loadeddata
 * @listens Tech#loadeddata
 */
'loadeddata',

/**
 * Fires when the current playback position has changed.
 *
 * @event Player#timeupdate
 * @type {event}
 */
/**
 * Retrigger the `timeupdate` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechTimeUpdate_
 * @fires Player#timeupdate
 * @listens Tech#timeupdate
 */
'timeupdate',

/**
 * Fires when the video's intrinsic dimensions change
 *
 * @event Player#resize
 * @type {event}
 */
/**
 * Retrigger the `resize` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechResize_
 * @fires Player#resize
 * @listens Tech#resize
 */
'resize',

/**
 * Fires when the volume has been changed
 *
 * @event Player#volumechange
 * @type {event}
 */
/**
 * Retrigger the `volumechange` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechVolumechange_
 * @fires Player#volumechange
 * @listens Tech#volumechange
 */
'volumechange',

/**
 * Fires when the text track has been changed
 *
 * @event Player#texttrackchange
 * @type {event}
 */
/**
 * Retrigger the `texttrackchange` event that was triggered by the {@link Tech}.
 *
 * @private
 * @method Player#handleTechTexttrackchange_
 * @fires Player#texttrackchange
 * @listens Tech#texttrackchange
 */
'texttrackchange'];

// events to queue when playback rate is zero
// this is a hash for the sole purpose of mapping non-camel-cased event names
// to camel-cased function names
var TECH_EVENTS_QUEUE = {
  canplay: 'CanPlay',
  canplaythrough: 'CanPlayThrough',
  playing: 'Playing',
  seeked: 'Seeked'
};

/**
 * An instance of the `Player` class is created when any of the Video.js setup methods
 * are used to initialize a video.
 *
 * After an instance has been created it can be accessed globally in two ways:
 * 1. By calling `videojs('example_video_1');`
 * 2. By using it directly via  `videojs.players.example_video_1;`
 *
 * @extends Component
 */

var Player = function (_Component) {
  inherits(Player, _Component);

  /**
   * Create an instance of this class.
   *
   * @param {Element} tag
   *        The original video DOM element used for configuring options.
   *
   * @param {Object} [options]
   *        Object of option names and values.
   *
   * @param {Component~ReadyCallback} [ready]
   *        Ready callback function.
   */
  function Player(tag, options, ready) {
    classCallCheck(this, Player);

    // Make sure tag ID exists
    tag.id = tag.id || options.id || 'vjs_video_' + newGUID();

    // Set Options
    // The options argument overrides options set in the video tag
    // which overrides globally set options.
    // This latter part coincides with the load order
    // (tag must exist before Player)
    options = assign(Player.getTagSettings(tag), options);

    // Delay the initialization of children because we need to set up
    // player properties first, and can't use `this` before `super()`
    options.initChildren = false;

    // Same with creating the element
    options.createEl = false;

    // don't auto mixin the evented mixin
    options.evented = false;

    // we don't want the player to report touch activity on itself
    // see enableTouchActivity in Component
    options.reportTouchActivity = false;

    // If language is not set, get the closest lang attribute
    if (!options.language) {
      if (typeof tag.closest === 'function') {
        var closest = tag.closest('[lang]');

        if (closest && closest.getAttribute) {
          options.language = closest.getAttribute('lang');
        }
      } else {
        var element = tag;

        while (element && element.nodeType === 1) {
          if (getAttributes(element).hasOwnProperty('lang')) {
            options.language = element.getAttribute('lang');
            break;
          }
          element = element.parentNode;
        }
      }
    }

    // Run base component initializing with new options

    // Tracks when a tech changes the poster
    var _this = possibleConstructorReturn(this, _Component.call(this, null, options, ready));

    _this.isPosterFromTech_ = false;

    // Holds callback info that gets queued when playback rate is zero
    // and a seek is happening
    _this.queuedCallbacks_ = [];

    // Turn off API access because we're loading a new tech that might load asynchronously
    _this.isReady_ = false;

    // Init state hasStarted_
    _this.hasStarted_ = false;

    // Init state userActive_
    _this.userActive_ = false;

    // if the global option object was accidentally blown away by
    // someone, bail early with an informative error
    if (!_this.options_ || !_this.options_.techOrder || !_this.options_.techOrder.length) {
      throw new Error('No techOrder specified. Did you overwrite ' + 'videojs.options instead of just changing the ' + 'properties you want to override?');
    }

    // Store the original tag used to set options
    _this.tag = tag;

    // Store the tag attributes used to restore html5 element
    _this.tagAttributes = tag && getAttributes(tag);

    // Update current language
    _this.language(_this.options_.language);

    // Update Supported Languages
    if (options.languages) {
      // Normalise player option languages to lowercase
      var languagesToLower = {};

      Object.getOwnPropertyNames(options.languages).forEach(function (name$$1) {
        languagesToLower[name$$1.toLowerCase()] = options.languages[name$$1];
      });
      _this.languages_ = languagesToLower;
    } else {
      _this.languages_ = Player.prototype.options_.languages;
    }

    // Cache for video property values.
    _this.cache_ = {};

    // Set poster
    _this.poster_ = options.poster || '';

    // Set controls
    _this.controls_ = !!options.controls;

    // Set default values for lastVolume
    _this.cache_.lastVolume = 1;

    // Original tag settings stored in options
    // now remove immediately so native controls don't flash.
    // May be turned back on by HTML5 tech if nativeControlsForTouch is true
    tag.controls = false;
    tag.removeAttribute('controls');

    // the attribute overrides the option
    if (tag.hasAttribute('autoplay')) {
      _this.options_.autoplay = true;
    } else {
      // otherwise use the setter to validate and
      // set the correct value.
      _this.autoplay(_this.options_.autoplay);
    }

    /*
     * Store the internal state of scrubbing
     *
     * @private
     * @return {Boolean} True if the user is scrubbing
     */
    _this.scrubbing_ = false;

    _this.el_ = _this.createEl();

    // Set default value for lastPlaybackRate
    _this.cache_.lastPlaybackRate = _this.defaultPlaybackRate();

    // Make this an evented object and use `el_` as its event bus.
    evented(_this, { eventBusKey: 'el_' });

    // We also want to pass the original player options to each component and plugin
    // as well so they don't need to reach back into the player for options later.
    // We also need to do another copy of this.options_ so we don't end up with
    // an infinite loop.
    var playerOptionsCopy = mergeOptions(_this.options_);

    // Load plugins
    if (options.plugins) {
      var plugins = options.plugins;

      Object.keys(plugins).forEach(function (name$$1) {
        if (typeof this[name$$1] === 'function') {
          this[name$$1](plugins[name$$1]);
        } else {
          throw new Error('plugin "' + name$$1 + '" does not exist');
        }
      }, _this);
    }

    _this.options_.playerOptions = playerOptionsCopy;

    _this.middleware_ = [];

    _this.initChildren();

    // Set isAudio based on whether or not an audio tag was used
    _this.isAudio(tag.nodeName.toLowerCase() === 'audio');

    // Update controls className. Can't do this when the controls are initially
    // set because the element doesn't exist yet.
    if (_this.controls()) {
      _this.addClass('vjs-controls-enabled');
    } else {
      _this.addClass('vjs-controls-disabled');
    }

    // Set ARIA label and region role depending on player type
    _this.el_.setAttribute('role', 'region');
    if (_this.isAudio()) {
      _this.el_.setAttribute('aria-label', _this.localize('Audio Player'));
    } else {
      _this.el_.setAttribute('aria-label', _this.localize('Video Player'));
    }

    if (_this.isAudio()) {
      _this.addClass('vjs-audio');
    }

    if (_this.flexNotSupported_()) {
      _this.addClass('vjs-no-flex');
    }

    // TODO: Make this smarter. Toggle user state between touching/mousing
    // using events, since devices can have both touch and mouse events.
    // if (browser.TOUCH_ENABLED) {
    //   this.addClass('vjs-touch-enabled');
    // }

    // iOS Safari has broken hover handling
    if (!IS_IOS) {
      _this.addClass('vjs-workinghover');
    }

    // Make player easily findable by ID
    Player.players[_this.id_] = _this;

    // Add a major version class to aid css in plugins
    var majorVersion = version.split('.')[0];

    _this.addClass('vjs-v' + majorVersion);

    // When the player is first initialized, trigger activity so components
    // like the control bar show themselves if needed
    _this.userActive(true);
    _this.reportUserActivity();

    _this.one('play', _this.listenForUserActivity_);
    _this.on('fullscreenchange', _this.handleFullscreenChange_);
    _this.on('stageclick', _this.handleStageClick_);

    _this.changingSrc_ = false;
    _this.playWaitingForReady_ = false;
    _this.playOnLoadstart_ = null;
    return _this;
  }

  /**
   * Destroys the video player and does any necessary cleanup.
   *
   * This is especially helpful if you are dynamically adding and removing videos
   * to/from the DOM.
   *
   * @fires Player#dispose
   */


  Player.prototype.dispose = function dispose() {
    /**
     * Called when the player is being disposed of.
     *
     * @event Player#dispose
     * @type {EventTarget~Event}
     */
    this.trigger('dispose');
    // prevent dispose from being called twice
    this.off('dispose');

    if (this.styleEl_ && this.styleEl_.parentNode) {
      this.styleEl_.parentNode.removeChild(this.styleEl_);
      this.styleEl_ = null;
    }

    // Kill reference to this player
    Player.players[this.id_] = null;

    if (this.tag && this.tag.player) {
      this.tag.player = null;
    }

    if (this.el_ && this.el_.player) {
      this.el_.player = null;
    }

    if (this.tech_) {
      this.tech_.dispose();
      this.isPosterFromTech_ = false;
      this.poster_ = '';
    }

    if (this.playerElIngest_) {
      this.playerElIngest_ = null;
    }

    if (this.tag) {
      this.tag = null;
    }

    clearCacheForPlayer(this);

    // the actual .el_ is removed here
    _Component.prototype.dispose.call(this);
  };

  /**
   * Create the `Player`'s DOM element.
   *
   * @return {Element}
   *         The DOM element that gets created.
   */


  Player.prototype.createEl = function createEl$$1() {
    var tag = this.tag;
    var el = void 0;
    var playerElIngest = this.playerElIngest_ = tag.parentNode && tag.parentNode.hasAttribute && tag.parentNode.hasAttribute('data-vjs-player');
    var divEmbed = this.tag.tagName.toLowerCase() === 'video-js';

    if (playerElIngest) {
      el = this.el_ = tag.parentNode;
    } else if (!divEmbed) {
      el = this.el_ = _Component.prototype.createEl.call(this, 'div');
    }

    // Copy over all the attributes from the tag, including ID and class
    // ID will now reference player box, not the video tag
    var attrs = getAttributes(tag);

    if (divEmbed) {
      el = this.el_ = tag;
      tag = this.tag = document_1.createElement('video');
      while (el.children.length) {
        tag.appendChild(el.firstChild);
      }

      if (!hasClass(el, 'video-js')) {
        addClass(el, 'video-js');
      }

      el.appendChild(tag);

      playerElIngest = this.playerElIngest_ = el;

      // copy over properties from the video-js element
      // ie8 doesn't support Object.keys nor hasOwnProperty
      // on dom elements so we have to specify properties individually
      ['autoplay', 'controls', 'crossOrigin', 'defaultMuted', 'defaultPlaybackRate', 'loop', 'muted', 'playbackRate', 'src', 'volume'].forEach(function (prop) {
        if (typeof el[prop] !== 'undefined') {
          tag[prop] = el[prop];
        }
      });
    }

    // set tabindex to -1 to remove the video element from the focus order
    tag.setAttribute('tabindex', '-1');
    // Workaround for #4583 (JAWS+IE doesn't announce BPB or play button)
    // See https://github.com/FreedomScientific/VFO-standards-support/issues/78
    // Note that we can't detect if JAWS is being used, but this ARIA attribute
    //  doesn't change behavior of IE11 if JAWS is not being used
    if (IE_VERSION) {
      tag.setAttribute('role', 'application');
    }

    // Remove width/height attrs from tag so CSS can make it 100% width/height
    tag.removeAttribute('width');
    tag.removeAttribute('height');

    Object.getOwnPropertyNames(attrs).forEach(function (attr) {
      // workaround so we don't totally break IE7
      // http://stackoverflow.com/questions/3653444/css-styles-not-applied-on-dynamic-elements-in-internet-explorer-7
      if (attr === 'class') {
        el.className += ' ' + attrs[attr];

        if (divEmbed) {
          tag.className += ' ' + attrs[attr];
        }
      } else {
        el.setAttribute(attr, attrs[attr]);

        if (divEmbed) {
          tag.setAttribute(attr, attrs[attr]);
        }
      }
    });

    // Update tag id/class for use as HTML5 playback tech
    // Might think we should do this after embedding in container so .vjs-tech class
    // doesn't flash 100% width/height, but class only applies with .video-js parent
    tag.playerId = tag.id;
    tag.id += '_html5_api';
    tag.className = 'vjs-tech';

    // Make player findable on elements
    tag.player = el.player = this;
    // Default state of video is paused
    this.addClass('vjs-paused');

    // Add a style element in the player that we'll use to set the width/height
    // of the player in a way that's still overrideable by CSS, just like the
    // video element
    if (window_1.VIDEOJS_NO_DYNAMIC_STYLE !== true) {
      this.styleEl_ = createStyleElement('vjs-styles-dimensions');
      var defaultsStyleEl = $('.vjs-styles-defaults');
      var head = $('head');

      head.insertBefore(this.styleEl_, defaultsStyleEl ? defaultsStyleEl.nextSibling : head.firstChild);
    }

    // Pass in the width/height/aspectRatio options which will update the style el
    this.width(this.options_.width);
    this.height(this.options_.height);
    this.fluid(this.options_.fluid);
    this.aspectRatio(this.options_.aspectRatio);

    // Hide any links within the video/audio tag, because IE doesn't hide them completely.
    var links = tag.getElementsByTagName('a');

    for (var i = 0; i < links.length; i++) {
      var linkEl = links.item(i);

      addClass(linkEl, 'vjs-hidden');
      linkEl.setAttribute('hidden', 'hidden');
    }

    // insertElFirst seems to cause the networkState to flicker from 3 to 2, so
    // keep track of the original for later so we can know if the source originally failed
    tag.initNetworkState_ = tag.networkState;

    // Wrap video tag in div (el/box) container
    if (tag.parentNode && !playerElIngest) {
      tag.parentNode.insertBefore(el, tag);
    }

    // insert the tag as the first child of the player element
    // then manually add it to the children array so that this.addChild
    // will work properly for other components
    //
    // Breaks iPhone, fixed in HTML5 setup.
    prependTo(tag, el);
    this.children_.unshift(tag);

    // Set lang attr on player to ensure CSS :lang() in consistent with player
    // if it's been set to something different to the doc
    this.el_.setAttribute('lang', this.language_);

    this.el_ = el;

    return el;
  };

  /**
   * A getter/setter for the `Player`'s width. Returns the player's configured value.
   * To get the current width use `currentWidth()`.
   *
   * @param {number} [value]
   *        The value to set the `Player`'s width to.
   *
   * @return {number}
   *         The current width of the `Player` when getting.
   */


  Player.prototype.width = function width(value) {
    return this.dimension('width', value);
  };

  /**
   * A getter/setter for the `Player`'s height. Returns the player's configured value.
   * To get the current height use `currentheight()`.
   *
   * @param {number} [value]
   *        The value to set the `Player`'s heigth to.
   *
   * @return {number}
   *         The current height of the `Player` when getting.
   */


  Player.prototype.height = function height(value) {
    return this.dimension('height', value);
  };

  /**
   * A getter/setter for the `Player`'s width & height.
   *
   * @param {string} dimension
   *        This string can be:
   *        - 'width'
   *        - 'height'
   *
   * @param {number} [value]
   *        Value for dimension specified in the first argument.
   *
   * @return {number}
   *         The dimension arguments value when getting (width/height).
   */


  Player.prototype.dimension = function dimension(_dimension, value) {
    var privDimension = _dimension + '_';

    if (value === undefined) {
      return this[privDimension] || 0;
    }

    if (value === '') {
      // If an empty string is given, reset the dimension to be automatic
      this[privDimension] = undefined;
      this.updateStyleEl_();
      return;
    }

    var parsedVal = parseFloat(value);

    if (isNaN(parsedVal)) {
      log$1.error('Improper value "' + value + '" supplied for for ' + _dimension);
      return;
    }

    this[privDimension] = parsedVal;
    this.updateStyleEl_();
  };

  /**
   * A getter/setter/toggler for the vjs-fluid `className` on the `Player`.
   *
   * @param {boolean} [bool]
   *        - A value of true adds the class.
   *        - A value of false removes the class.
   *        - No value will toggle the fluid class.
   *
   * @return {boolean|undefined}
   *         - The value of fluid when getting.
   *         - `undefined` when setting.
   */


  Player.prototype.fluid = function fluid(bool) {
    if (bool === undefined) {
      return !!this.fluid_;
    }

    this.fluid_ = !!bool;

    if (bool) {
      this.addClass('vjs-fluid');
    } else {
      this.removeClass('vjs-fluid');
    }

    this.updateStyleEl_();
  };

  /**
   * Get/Set the aspect ratio
   *
   * @param {string} [ratio]
   *        Aspect ratio for player
   *
   * @return {string|undefined}
   *         returns the current aspect ratio when getting
   */

  /**
   * A getter/setter for the `Player`'s aspect ratio.
   *
   * @param {string} [ratio]
   *        The value to set the `Player's aspect ratio to.
   *
   * @return {string|undefined}
   *         - The current aspect ratio of the `Player` when getting.
   *         - undefined when setting
   */


  Player.prototype.aspectRatio = function aspectRatio(ratio) {
    if (ratio === undefined) {
      return this.aspectRatio_;
    }

    // Check for width:height format
    if (!/^\d+\:\d+$/.test(ratio)) {
      throw new Error('Improper value supplied for aspect ratio. The format should be width:height, for example 16:9.');
    }
    this.aspectRatio_ = ratio;

    // We're assuming if you set an aspect ratio you want fluid mode,
    // because in fixed mode you could calculate width and height yourself.
    this.fluid(true);

    this.updateStyleEl_();
  };

  /**
   * Update styles of the `Player` element (height, width and aspect ratio).
   *
   * @private
   * @listens Tech#loadedmetadata
   */


  Player.prototype.updateStyleEl_ = function updateStyleEl_() {
    if (window_1.VIDEOJS_NO_DYNAMIC_STYLE === true) {
      var _width = typeof this.width_ === 'number' ? this.width_ : this.options_.width;
      var _height = typeof this.height_ === 'number' ? this.height_ : this.options_.height;
      var techEl = this.tech_ && this.tech_.el();

      if (techEl) {
        if (_width >= 0) {
          techEl.width = _width;
        }
        if (_height >= 0) {
          techEl.height = _height;
        }
      }

      return;
    }

    var width = void 0;
    var height = void 0;
    var aspectRatio = void 0;
    var idClass = void 0;

    // The aspect ratio is either used directly or to calculate width and height.
    if (this.aspectRatio_ !== undefined && this.aspectRatio_ !== 'auto') {
      // Use any aspectRatio that's been specifically set
      aspectRatio = this.aspectRatio_;
    } else if (this.videoWidth() > 0) {
      // Otherwise try to get the aspect ratio from the video metadata
      aspectRatio = this.videoWidth() + ':' + this.videoHeight();
    } else {
      // Or use a default. The video element's is 2:1, but 16:9 is more common.
      aspectRatio = '16:9';
    }

    // Get the ratio as a decimal we can use to calculate dimensions
    var ratioParts = aspectRatio.split(':');
    var ratioMultiplier = ratioParts[1] / ratioParts[0];

    if (this.width_ !== undefined) {
      // Use any width that's been specifically set
      width = this.width_;
    } else if (this.height_ !== undefined) {
      // Or calulate the width from the aspect ratio if a height has been set
      width = this.height_ / ratioMultiplier;
    } else {
      // Or use the video's metadata, or use the video el's default of 300
      width = this.videoWidth() || 300;
    }

    if (this.height_ !== undefined) {
      // Use any height that's been specifically set
      height = this.height_;
    } else {
      // Otherwise calculate the height from the ratio and the width
      height = width * ratioMultiplier;
    }

    // Ensure the CSS class is valid by starting with an alpha character
    if (/^[^a-zA-Z]/.test(this.id())) {
      idClass = 'dimensions-' + this.id();
    } else {
      idClass = this.id() + '-dimensions';
    }

    // Ensure the right class is still on the player for the style element
    this.addClass(idClass);

    setTextContent(this.styleEl_, '\n      .' + idClass + ' {\n        width: ' + width + 'px;\n        height: ' + height + 'px;\n      }\n\n      .' + idClass + '.vjs-fluid {\n        padding-top: ' + ratioMultiplier * 100 + '%;\n      }\n    ');
  };

  /**
   * Load/Create an instance of playback {@link Tech} including element
   * and API methods. Then append the `Tech` element in `Player` as a child.
   *
   * @param {string} techName
   *        name of the playback technology
   *
   * @param {string} source
   *        video source
   *
   * @private
   */


  Player.prototype.loadTech_ = function loadTech_(techName, source) {
    var _this2 = this;

    // Pause and remove current playback technology
    if (this.tech_) {
      this.unloadTech_();
    }

    var titleTechName = toTitleCase(techName);
    var camelTechName = techName.charAt(0).toLowerCase() + techName.slice(1);

    // get rid of the HTML5 video tag as soon as we are using another tech
    if (titleTechName !== 'Html5' && this.tag) {
      Tech.getTech('Html5').disposeMediaElement(this.tag);
      this.tag.player = null;
      this.tag = null;
    }

    this.techName_ = titleTechName;

    // Turn off API access because we're loading a new tech that might load asynchronously
    this.isReady_ = false;

    // if autoplay is a string we pass false to the tech
    // because the player is going to handle autoplay on `loadstart`
    var autoplay = typeof this.autoplay() === 'string' ? false : this.autoplay();

    // Grab tech-specific options from player options and add source and parent element to use.
    var techOptions = {
      source: source,
      autoplay: autoplay,
      'nativeControlsForTouch': this.options_.nativeControlsForTouch,
      'playerId': this.id(),
      'techId': this.id() + '_' + titleTechName + '_api',
      'playsinline': this.options_.playsinline,
      'preload': this.options_.preload,
      'loop': this.options_.loop,
      'muted': this.options_.muted,
      'poster': this.poster(),
      'language': this.language(),
      'playerElIngest': this.playerElIngest_ || false,
      'vtt.js': this.options_['vtt.js'],
      'canOverridePoster': !!this.options_.techCanOverridePoster,
      'enableSourceset': this.options_.enableSourceset
    };

    ALL.names.forEach(function (name$$1) {
      var props = ALL[name$$1];

      techOptions[props.getterName] = _this2[props.privateName];
    });

    assign(techOptions, this.options_[titleTechName]);
    assign(techOptions, this.options_[camelTechName]);
    assign(techOptions, this.options_[techName.toLowerCase()]);

    if (this.tag) {
      techOptions.tag = this.tag;
    }

    if (source && source.src === this.cache_.src && this.cache_.currentTime > 0) {
      techOptions.startTime = this.cache_.currentTime;
    }

    // Initialize tech instance
    var TechClass = Tech.getTech(techName);

    if (!TechClass) {
      throw new Error('No Tech named \'' + titleTechName + '\' exists! \'' + titleTechName + '\' should be registered using videojs.registerTech()\'');
    }

    this.tech_ = new TechClass(techOptions);

    // player.triggerReady is always async, so don't need this to be async
    this.tech_.ready(bind(this, this.handleTechReady_), true);

    textTrackConverter.jsonToTextTracks(this.textTracksJson_ || [], this.tech_);

    // Listen to all HTML5-defined events and trigger them on the player
    TECH_EVENTS_RETRIGGER.forEach(function (event) {
      _this2.on(_this2.tech_, event, _this2['handleTech' + toTitleCase(event) + '_']);
    });

    Object.keys(TECH_EVENTS_QUEUE).forEach(function (event) {
      _this2.on(_this2.tech_, event, function (eventObj) {
        if (_this2.tech_.playbackRate() === 0 && _this2.tech_.seeking()) {
          _this2.queuedCallbacks_.push({
            callback: _this2['handleTech' + TECH_EVENTS_QUEUE[event] + '_'].bind(_this2),
            event: eventObj
          });
          return;
        }
        _this2['handleTech' + TECH_EVENTS_QUEUE[event] + '_'](eventObj);
      });
    });

    this.on(this.tech_, 'loadstart', this.handleTechLoadStart_);
    this.on(this.tech_, 'sourceset', this.handleTechSourceset_);
    this.on(this.tech_, 'waiting', this.handleTechWaiting_);
    this.on(this.tech_, 'ended', this.handleTechEnded_);
    this.on(this.tech_, 'seeking', this.handleTechSeeking_);
    this.on(this.tech_, 'play', this.handleTechPlay_);
    this.on(this.tech_, 'firstplay', this.handleTechFirstPlay_);
    this.on(this.tech_, 'pause', this.handleTechPause_);
    this.on(this.tech_, 'durationchange', this.handleTechDurationChange_);
    this.on(this.tech_, 'fullscreenchange', this.handleTechFullscreenChange_);
    this.on(this.tech_, 'error', this.handleTechError_);
    this.on(this.tech_, 'loadedmetadata', this.updateStyleEl_);
    this.on(this.tech_, 'posterchange', this.handleTechPosterChange_);
    this.on(this.tech_, 'textdata', this.handleTechTextData_);
    this.on(this.tech_, 'ratechange', this.handleTechRateChange_);

    this.usingNativeControls(this.techGet_('controls'));

    if (this.controls() && !this.usingNativeControls()) {
      this.addTechControlsListeners_();
    }

    // Add the tech element in the DOM if it was not already there
    // Make sure to not insert the original video element if using Html5
    if (this.tech_.el().parentNode !== this.el() && (titleTechName !== 'Html5' || !this.tag)) {
      prependTo(this.tech_.el(), this.el());
    }

    // Get rid of the original video tag reference after the first tech is loaded
    if (this.tag) {
      this.tag.player = null;
      this.tag = null;
    }
  };

  /**
   * Unload and dispose of the current playback {@link Tech}.
   *
   * @private
   */


  Player.prototype.unloadTech_ = function unloadTech_() {
    var _this3 = this;

    // Save the current text tracks so that we can reuse the same text tracks with the next tech
    ALL.names.forEach(function (name$$1) {
      var props = ALL[name$$1];

      _this3[props.privateName] = _this3[props.getterName]();
    });
    this.textTracksJson_ = textTrackConverter.textTracksToJson(this.tech_);

    this.isReady_ = false;

    this.tech_.dispose();

    this.tech_ = false;

    if (this.isPosterFromTech_) {
      this.poster_ = '';
      this.trigger('posterchange');
    }

    this.isPosterFromTech_ = false;
  };

  /**
   * Return a reference to the current {@link Tech}.
   * It will print a warning by default about the danger of using the tech directly
   * but any argument that is passed in will silence the warning.
   *
   * @param {*} [safety]
   *        Anything passed in to silence the warning
   *
   * @return {Tech}
   *         The Tech
   */


  Player.prototype.tech = function tech(safety) {
    if (safety === undefined) {
      log$1.warn(tsml(_templateObject$1));
    }

    return this.tech_;
  };

  /**
   * Set up click and touch listeners for the playback element
   *
   * - On desktops: a click on the video itself will toggle playback
   * - On mobile devices: a click on the video toggles controls
   *   which is done by toggling the user state between active and
   *   inactive
   * - A tap can signal that a user has become active or has become inactive
   *   e.g. a quick tap on an iPhone movie should reveal the controls. Another
   *   quick tap should hide them again (signaling the user is in an inactive
   *   viewing state)
   * - In addition to this, we still want the user to be considered inactive after
   *   a few seconds of inactivity.
   *
   * > Note: the only part of iOS interaction we can't mimic with this setup
   * is a touch and hold on the video element counting as activity in order to
   * keep the controls showing, but that shouldn't be an issue. A touch and hold
   * on any controls will still keep the user active
   *
   * @private
   */


  Player.prototype.addTechControlsListeners_ = function addTechControlsListeners_() {
    // Make sure to remove all the previous listeners in case we are called multiple times.
    this.removeTechControlsListeners_();

    // Some browsers (Chrome & IE) don't trigger a click on a flash swf, but do
    // trigger mousedown/up.
    // http://stackoverflow.com/questions/1444562/javascript-onclick-event-over-flash-object
    // Any touch events are set to block the mousedown event from happening
    this.on(this.tech_, 'mousedown', this.handleTechClick_);

    // If the controls were hidden we don't want that to change without a tap event
    // so we'll check if the controls were already showing before reporting user
    // activity
    this.on(this.tech_, 'touchstart', this.handleTechTouchStart_);
    this.on(this.tech_, 'touchmove', this.handleTechTouchMove_);
    this.on(this.tech_, 'touchend', this.handleTechTouchEnd_);

    // The tap listener needs to come after the touchend listener because the tap
    // listener cancels out any reportedUserActivity when setting userActive(false)
    this.on(this.tech_, 'tap', this.handleTechTap_);
  };

  /**
   * Remove the listeners used for click and tap controls. This is needed for
   * toggling to controls disabled, where a tap/touch should do nothing.
   *
   * @private
   */


  Player.prototype.removeTechControlsListeners_ = function removeTechControlsListeners_() {
    // We don't want to just use `this.off()` because there might be other needed
    // listeners added by techs that extend this.
    this.off(this.tech_, 'tap', this.handleTechTap_);
    this.off(this.tech_, 'touchstart', this.handleTechTouchStart_);
    this.off(this.tech_, 'touchmove', this.handleTechTouchMove_);
    this.off(this.tech_, 'touchend', this.handleTechTouchEnd_);
    this.off(this.tech_, 'mousedown', this.handleTechClick_);
  };

  /**
   * Player waits for the tech to be ready
   *
   * @private
   */


  Player.prototype.handleTechReady_ = function handleTechReady_() {
    this.triggerReady();

    // Keep the same volume as before
    if (this.cache_.volume) {
      this.techCall_('setVolume', this.cache_.volume);
    }

    // Look if the tech found a higher resolution poster while loading
    this.handleTechPosterChange_();

    // Update the duration if available
    this.handleTechDurationChange_();

    // Chrome and Safari both have issues with autoplay.
    // In Safari (5.1.1), when we move the video element into the container div, autoplay doesn't work.
    // In Chrome (15), if you have autoplay + a poster + no controls, the video gets hidden (but audio plays)
    // This fixes both issues. Need to wait for API, so it updates displays correctly
    if ((this.src() || this.currentSrc()) && this.tag && this.options_.autoplay && this.paused()) {
      try {
        // Chrome Fix. Fixed in Chrome v16.
        delete this.tag.poster;
      } catch (e) {
        log$1('deleting tag.poster throws in some browsers', e);
      }
    }
  };

  /**
   * Retrigger the `loadstart` event that was triggered by the {@link Tech}. This
   * function will also trigger {@link Player#firstplay} if it is the first loadstart
   * for a video.
   *
   * @fires Player#loadstart
   * @fires Player#firstplay
   * @listens Tech#loadstart
   * @private
   */


  Player.prototype.handleTechLoadStart_ = function handleTechLoadStart_() {
    // TODO: Update to use `emptied` event instead. See #1277.

    this.removeClass('vjs-ended');
    this.removeClass('vjs-seeking');

    // reset the error state
    this.error(null);

    // If it's already playing we want to trigger a firstplay event now.
    // The firstplay event relies on both the play and loadstart events
    // which can happen in any order for a new source
    if (!this.paused()) {
      /**
       * Fired when the user agent begins looking for media data
       *
       * @event Player#loadstart
       * @type {EventTarget~Event}
       */
      this.trigger('loadstart');
      this.trigger('firstplay');
    } else {
      // reset the hasStarted state
      this.hasStarted(false);
      this.trigger('loadstart');
    }

    // autoplay happens after loadstart for the browser,
    // so we mimic that behavior
    this.manualAutoplay_(this.autoplay());
  };

  /**
   * Handle autoplay string values, rather than the typical boolean
   * values that should be handled by the tech. Note that this is not
   * part of any specification. Valid values and what they do can be
   * found on the autoplay getter at Player#autoplay()
   */


  Player.prototype.manualAutoplay_ = function manualAutoplay_(type) {
    var _this4 = this;

    if (!this.tech_ || typeof type !== 'string') {
      return;
    }

    var muted = function muted() {
      var previouslyMuted = _this4.muted();

      _this4.muted(true);

      var playPromise = _this4.play();

      if (!playPromise || !playPromise.then || !playPromise['catch']) {
        return;
      }

      return playPromise['catch'](function (e) {
        // restore old value of muted on failure
        _this4.muted(previouslyMuted);
      });
    };

    var promise = void 0;

    if (type === 'any') {
      promise = this.play();

      if (promise && promise.then && promise['catch']) {
        promise['catch'](function () {
          return muted();
        });
      }
    } else if (type === 'muted') {
      promise = muted();
    } else {
      promise = this.play();
    }

    if (!promise || !promise.then || !promise['catch']) {
      return;
    }

    return promise.then(function () {
      _this4.trigger({ type: 'autoplay-success', autoplay: type });
    })['catch'](function (e) {
      _this4.trigger({ type: 'autoplay-failure', autoplay: type });
    });
  };

  /**
   * Update the internal source caches so that we return the correct source from
   * `src()`, `currentSource()`, and `currentSources()`.
   *
   * > Note: `currentSources` will not be updated if the source that is passed in exists
   *         in the current `currentSources` cache.
   *
   *
   * @param {Tech~SourceObject} srcObj
   *        A string or object source to update our caches to.
   */


  Player.prototype.updateSourceCaches_ = function updateSourceCaches_() {
    var srcObj = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : '';


    var src = srcObj;
    var type = '';

    if (typeof src !== 'string') {
      src = srcObj.src;
      type = srcObj.type;
    }

    // if we are a blob url, don't update the source cache
    // blob urls can arise when playback is done via Media Source Extension (MSE)
    // such as m3u8 sources with @videojs/http-streaming (VHS)
    if (/^blob:/.test(src)) {
      return;
    }

    // make sure all the caches are set to default values
    // to prevent null checking
    this.cache_.source = this.cache_.source || {};
    this.cache_.sources = this.cache_.sources || [];

    // try to get the type of the src that was passed in
    if (src && !type) {
      type = findMimetype(this, src);
    }

    // update `currentSource` cache always
    this.cache_.source = mergeOptions({}, srcObj, { src: src, type: type });

    var matchingSources = this.cache_.sources.filter(function (s) {
      return s.src && s.src === src;
    });
    var sourceElSources = [];
    var sourceEls = this.$$('source');
    var matchingSourceEls = [];

    for (var i = 0; i < sourceEls.length; i++) {
      var sourceObj = getAttributes(sourceEls[i]);

      sourceElSources.push(sourceObj);

      if (sourceObj.src && sourceObj.src === src) {
        matchingSourceEls.push(sourceObj.src);
      }
    }

    // if we have matching source els but not matching sources
    // the current source cache is not up to date
    if (matchingSourceEls.length && !matchingSources.length) {
      this.cache_.sources = sourceElSources;
      // if we don't have matching source or source els set the
      // sources cache to the `currentSource` cache
    } else if (!matchingSources.length) {
      this.cache_.sources = [this.cache_.source];
    }

    // update the tech `src` cache
    this.cache_.src = src;
  };

  /**
   * *EXPERIMENTAL* Fired when the source is set or changed on the {@link Tech}
   * causing the media element to reload.
   *
   * It will fire for the initial source and each subsequent source.
   * This event is a custom event from Video.js and is triggered by the {@link Tech}.
   *
   * The event object for this event contains a `src` property that will contain the source
   * that was available when the event was triggered. This is generally only necessary if Video.js
   * is switching techs while the source was being changed.
   *
   * It is also fired when `load` is called on the player (or media element)
   * because the {@link https://html.spec.whatwg.org/multipage/media.html#dom-media-load|specification for `load`}
   * says that the resource selection algorithm needs to be aborted and restarted.
   * In this case, it is very likely that the `src` property will be set to the
   * empty string `""` to indicate we do not know what the source will be but
   * that it is changing.
   *
   * *This event is currently still experimental and may change in minor releases.*
   * __To use this, pass `enableSourceset` option to the player.__
   *
   * @event Player#sourceset
   * @type {EventTarget~Event}
   * @prop {string} src
   *                The source url available when the `sourceset` was triggered.
   *                It will be an empty string if we cannot know what the source is
   *                but know that the source will change.
   */
  /**
   * Retrigger the `sourceset` event that was triggered by the {@link Tech}.
   *
   * @fires Player#sourceset
   * @listens Tech#sourceset
   * @private
   */


  Player.prototype.handleTechSourceset_ = function handleTechSourceset_(event) {
    var _this5 = this;

    // only update the source cache when the source
    // was not updated using the player api
    if (!this.changingSrc_) {
      // update the source to the intial source right away
      // in some cases this will be empty string
      this.updateSourceCaches_(event.src);

      // if the `sourceset` `src` was an empty string
      // wait for a `loadstart` to update the cache to `currentSrc`.
      // If a sourceset happens before a `loadstart`, we reset the state
      // as this function will be called again.
      if (!event.src) {
        var updateCache = function updateCache(e) {
          if (e.type !== 'sourceset') {
            _this5.updateSourceCaches_(_this5.techGet_('currentSrc'));
          }

          _this5.tech_.off(['sourceset', 'loadstart'], updateCache);
        };

        this.tech_.one(['sourceset', 'loadstart'], updateCache);
      }
    }

    this.trigger({
      src: event.src,
      type: 'sourceset'
    });
  };

  /**
   * Add/remove the vjs-has-started class
   *
   * @fires Player#firstplay
   *
   * @param {boolean} request
   *        - true: adds the class
   *        - false: remove the class
   *
   * @return {boolean}
   *         the boolean value of hasStarted_
   */


  Player.prototype.hasStarted = function hasStarted(request) {
    if (request === undefined) {
      // act as getter, if we have no request to change
      return this.hasStarted_;
    }

    if (request === this.hasStarted_) {
      return;
    }

    this.hasStarted_ = request;

    if (this.hasStarted_) {
      this.addClass('vjs-has-started');
      this.trigger('firstplay');
    } else {
      this.removeClass('vjs-has-started');
    }
  };

  /**
   * Fired whenever the media begins or resumes playback
   *
   * @see [Spec]{@link https://html.spec.whatwg.org/multipage/embedded-content.html#dom-media-play}
   * @fires Player#play
   * @listens Tech#play
   * @private
   */


  Player.prototype.handleTechPlay_ = function handleTechPlay_() {
    this.removeClass('vjs-ended');
    this.removeClass('vjs-paused');
    this.addClass('vjs-playing');

    // hide the poster when the user hits play
    this.hasStarted(true);
    /**
     * Triggered whenever an {@link Tech#play} event happens. Indicates that
     * playback has started or resumed.
     *
     * @event Player#play
     * @type {EventTarget~Event}
     */
    this.trigger('play');
  };

  /**
   * Retrigger the `ratechange` event that was triggered by the {@link Tech}.
   *
   * If there were any events queued while the playback rate was zero, fire
   * those events now.
   *
   * @private
   * @method Player#handleTechRateChange_
   * @fires Player#ratechange
   * @listens Tech#ratechange
   */


  Player.prototype.handleTechRateChange_ = function handleTechRateChange_() {
    if (this.tech_.playbackRate() > 0 && this.cache_.lastPlaybackRate === 0) {
      this.queuedCallbacks_.forEach(function (queued) {
        return queued.callback(queued.event);
      });
      this.queuedCallbacks_ = [];
    }
    this.cache_.lastPlaybackRate = this.tech_.playbackRate();
    /**
     * Fires when the playing speed of the audio/video is changed
     *
     * @event Player#ratechange
     * @type {event}
     */
    this.trigger('ratechange');
  };

  /**
   * Retrigger the `waiting` event that was triggered by the {@link Tech}.
   *
   * @fires Player#waiting
   * @listens Tech#waiting
   * @private
   */


  Player.prototype.handleTechWaiting_ = function handleTechWaiting_() {
    var _this6 = this;

    this.addClass('vjs-waiting');
    /**
     * A readyState change on the DOM element has caused playback to stop.
     *
     * @event Player#waiting
     * @type {EventTarget~Event}
     */
    this.trigger('waiting');
    this.one('timeupdate', function () {
      return _this6.removeClass('vjs-waiting');
    });
  };

  /**
   * Retrigger the `canplay` event that was triggered by the {@link Tech}.
   * > Note: This is not consistent between browsers. See #1351
   *
   * @fires Player#canplay
   * @listens Tech#canplay
   * @private
   */


  Player.prototype.handleTechCanPlay_ = function handleTechCanPlay_() {
    this.removeClass('vjs-waiting');
    /**
     * The media has a readyState of HAVE_FUTURE_DATA or greater.
     *
     * @event Player#canplay
     * @type {EventTarget~Event}
     */
    this.trigger('canplay');
  };

  /**
   * Retrigger the `canplaythrough` event that was triggered by the {@link Tech}.
   *
   * @fires Player#canplaythrough
   * @listens Tech#canplaythrough
   * @private
   */


  Player.prototype.handleTechCanPlayThrough_ = function handleTechCanPlayThrough_() {
    this.removeClass('vjs-waiting');
    /**
     * The media has a readyState of HAVE_ENOUGH_DATA or greater. This means that the
     * entire media file can be played without buffering.
     *
     * @event Player#canplaythrough
     * @type {EventTarget~Event}
     */
    this.trigger('canplaythrough');
  };

  /**
   * Retrigger the `playing` event that was triggered by the {@link Tech}.
   *
   * @fires Player#playing
   * @listens Tech#playing
   * @private
   */


  Player.prototype.handleTechPlaying_ = function handleTechPlaying_() {
    this.removeClass('vjs-waiting');
    /**
     * The media is no longer blocked from playback, and has started playing.
     *
     * @event Player#playing
     * @type {EventTarget~Event}
     */
    this.trigger('playing');
  };

  /**
   * Retrigger the `seeking` event that was triggered by the {@link Tech}.
   *
   * @fires Player#seeking
   * @listens Tech#seeking
   * @private
   */


  Player.prototype.handleTechSeeking_ = function handleTechSeeking_() {
    this.addClass('vjs-seeking');
    /**
     * Fired whenever the player is jumping to a new time
     *
     * @event Player#seeking
     * @type {EventTarget~Event}
     */
    this.trigger('seeking');
  };

  /**
   * Retrigger the `seeked` event that was triggered by the {@link Tech}.
   *
   * @fires Player#seeked
   * @listens Tech#seeked
   * @private
   */


  Player.prototype.handleTechSeeked_ = function handleTechSeeked_() {
    this.removeClass('vjs-seeking');
    /**
     * Fired when the player has finished jumping to a new time
     *
     * @event Player#seeked
     * @type {EventTarget~Event}
     */
    this.trigger('seeked');
  };

  /**
   * Retrigger the `firstplay` event that was triggered by the {@link Tech}.
   *
   * @fires Player#firstplay
   * @listens Tech#firstplay
   * @deprecated As of 6.0 firstplay event is deprecated.
   *             As of 6.0 passing the `starttime` option to the player and the firstplay event are deprecated.
   * @private
   */


  Player.prototype.handleTechFirstPlay_ = function handleTechFirstPlay_() {
    // If the first starttime attribute is specified
    // then we will start at the given offset in seconds
    if (this.options_.starttime) {
      log$1.warn('Passing the `starttime` option to the player will be deprecated in 6.0');
      this.currentTime(this.options_.starttime);
    }

    this.addClass('vjs-has-started');
    /**
     * Fired the first time a video is played. Not part of the HLS spec, and this is
     * probably not the best implementation yet, so use sparingly. If you don't have a
     * reason to prevent playback, use `myPlayer.one('play');` instead.
     *
     * @event Player#firstplay
     * @deprecated As of 6.0 firstplay event is deprecated.
     * @type {EventTarget~Event}
     */
    this.trigger('firstplay');
  };

  /**
   * Retrigger the `pause` event that was triggered by the {@link Tech}.
   *
   * @fires Player#pause
   * @listens Tech#pause
   * @private
   */


  Player.prototype.handleTechPause_ = function handleTechPause_() {
    this.removeClass('vjs-playing');
    this.addClass('vjs-paused');
    /**
     * Fired whenever the media has been paused
     *
     * @event Player#pause
     * @type {EventTarget~Event}
     */
    this.trigger('pause');
  };

  /**
   * Retrigger the `ended` event that was triggered by the {@link Tech}.
   *
   * @fires Player#ended
   * @listens Tech#ended
   * @private
   */


  Player.prototype.handleTechEnded_ = function handleTechEnded_() {
    this.addClass('vjs-ended');
    if (this.options_.loop) {
      this.currentTime(0);
      this.play();
    } else if (!this.paused()) {
      this.pause();
    }

    /**
     * Fired when the end of the media resource is reached (currentTime == duration)
     *
     * @event Player#ended
     * @type {EventTarget~Event}
     */
    this.trigger('ended');
  };

  /**
   * Fired when the duration of the media resource is first known or changed
   *
   * @listens Tech#durationchange
   * @private
   */


  Player.prototype.handleTechDurationChange_ = function handleTechDurationChange_() {
    this.duration(this.techGet_('duration'));
  };

  /**
   * Handle a click on the media element to play/pause
   *
   * @param {EventTarget~Event} event
   *        the event that caused this function to trigger
   *
   * @listens Tech#mousedown
   * @private
   */


  Player.prototype.handleTechClick_ = function handleTechClick_(event) {
    if (!isSingleLeftClick(event)) {
      return;
    }

    // When controls are disabled a click should not toggle playback because
    // the click is considered a control
    if (!this.controls_) {
      return;
    }

    if (this.paused()) {
      silencePromise(this.play());
    } else {
      this.pause();
    }
  };

  /**
   * Handle a tap on the media element. It will toggle the user
   * activity state, which hides and shows the controls.
   *
   * @listens Tech#tap
   * @private
   */


  Player.prototype.handleTechTap_ = function handleTechTap_() {
    this.userActive(!this.userActive());
  };

  /**
   * Handle touch to start
   *
   * @listens Tech#touchstart
   * @private
   */


  Player.prototype.handleTechTouchStart_ = function handleTechTouchStart_() {
    this.userWasActive = this.userActive();
  };

  /**
   * Handle touch to move
   *
   * @listens Tech#touchmove
   * @private
   */


  Player.prototype.handleTechTouchMove_ = function handleTechTouchMove_() {
    if (this.userWasActive) {
      this.reportUserActivity();
    }
  };

  /**
   * Handle touch to end
   *
   * @param {EventTarget~Event} event
   *        the touchend event that triggered
   *        this function
   *
   * @listens Tech#touchend
   * @private
   */


  Player.prototype.handleTechTouchEnd_ = function handleTechTouchEnd_(event) {
    // Stop the mouse events from also happening
    event.preventDefault();
  };

  /**
   * Fired when the player switches in or out of fullscreen mode
   *
   * @private
   * @listens Player#fullscreenchange
   */


  Player.prototype.handleFullscreenChange_ = function handleFullscreenChange_() {
    if (this.isFullscreen()) {
      this.addClass('vjs-fullscreen');
    } else {
      this.removeClass('vjs-fullscreen');
    }
  };

  /**
   * native click events on the SWF aren't triggered on IE11, Win8.1RT
   * use stageclick events triggered from inside the SWF instead
   *
   * @private
   * @listens stageclick
   */


  Player.prototype.handleStageClick_ = function handleStageClick_() {
    this.reportUserActivity();
  };

  /**
   * Handle Tech Fullscreen Change
   *
   * @param {EventTarget~Event} event
   *        the fullscreenchange event that triggered this function
   *
   * @param {Object} data
   *        the data that was sent with the event
   *
   * @private
   * @listens Tech#fullscreenchange
   * @fires Player#fullscreenchange
   */


  Player.prototype.handleTechFullscreenChange_ = function handleTechFullscreenChange_(event, data) {
    if (data) {
      this.isFullscreen(data.isFullscreen);
    }
    /**
     * Fired when going in and out of fullscreen.
     *
     * @event Player#fullscreenchange
     * @type {EventTarget~Event}
     */
    this.trigger('fullscreenchange');
  };

  /**
   * Fires when an error occurred during the loading of an audio/video.
   *
   * @private
   * @listens Tech#error
   */


  Player.prototype.handleTechError_ = function handleTechError_() {
    var error = this.tech_.error();

    this.error(error);
  };

  /**
   * Retrigger the `textdata` event that was triggered by the {@link Tech}.
   *
   * @fires Player#textdata
   * @listens Tech#textdata
   * @private
   */


  Player.prototype.handleTechTextData_ = function handleTechTextData_() {
    var data = null;

    if (arguments.length > 1) {
      data = arguments[1];
    }

    /**
     * Fires when we get a textdata event from tech
     *
     * @event Player#textdata
     * @type {EventTarget~Event}
     */
    this.trigger('textdata', data);
  };

  /**
   * Get object for cached values.
   *
   * @return {Object}
   *         get the current object cache
   */


  Player.prototype.getCache = function getCache() {
    return this.cache_;
  };

  /**
   * Pass values to the playback tech
   *
   * @param {string} [method]
   *        the method to call
   *
   * @param {Object} arg
   *        the argument to pass
   *
   * @private
   */


  Player.prototype.techCall_ = function techCall_(method, arg) {
    // If it's not ready yet, call method when it is

    this.ready(function () {
      if (method in allowedSetters) {
        return set$1(this.middleware_, this.tech_, method, arg);
      } else if (method in allowedMediators) {
        return mediate(this.middleware_, this.tech_, method, arg);
      }

      try {
        if (this.tech_) {
          this.tech_[method](arg);
        }
      } catch (e) {
        log$1(e);
        throw e;
      }
    }, true);
  };

  /**
   * Get calls can't wait for the tech, and sometimes don't need to.
   *
   * @param {string} method
   *        Tech method
   *
   * @return {Function|undefined}
   *         the method or undefined
   *
   * @private
   */


  Player.prototype.techGet_ = function techGet_(method) {
    if (!this.tech_ || !this.tech_.isReady_) {
      return;
    }

    if (method in allowedGetters) {
      return get$1(this.middleware_, this.tech_, method);
    } else if (method in allowedMediators) {
      return mediate(this.middleware_, this.tech_, method);
    }

    // Flash likes to die and reload when you hide or reposition it.
    // In these cases the object methods go away and we get errors.
    // When that happens we'll catch the errors and inform tech that it's not ready any more.
    try {
      return this.tech_[method]();
    } catch (e) {

      // When building additional tech libs, an expected method may not be defined yet
      if (this.tech_[method] === undefined) {
        log$1('Video.js: ' + method + ' method not defined for ' + this.techName_ + ' playback technology.', e);
        throw e;
      }

      // When a method isn't available on the object it throws a TypeError
      if (e.name === 'TypeError') {
        log$1('Video.js: ' + method + ' unavailable on ' + this.techName_ + ' playback technology element.', e);
        this.tech_.isReady_ = false;
        throw e;
      }

      // If error unknown, just log and throw
      log$1(e);
      throw e;
    }
  };

  /**
   * Attempt to begin playback at the first opportunity.
   *
   * @return {Promise|undefined}
   *         Returns a promise if the browser supports Promises (or one
   *         was passed in as an option). This promise will be resolved on
   *         the return value of play. If this is undefined it will fulfill the
   *         promise chain otherwise the promise chain will be fulfilled when
   *         the promise from play is fulfilled.
   */


  Player.prototype.play = function play() {
    var _this7 = this;

    var PromiseClass = this.options_.Promise || window_1.Promise;

    if (PromiseClass) {
      return new PromiseClass(function (resolve) {
        _this7.play_(resolve);
      });
    }

    return this.play_();
  };

  /**
   * The actual logic for play, takes a callback that will be resolved on the
   * return value of play. This allows us to resolve to the play promise if there
   * is one on modern browsers.
   *
   * @private
   * @param {Function} [callback]
   *        The callback that should be called when the techs play is actually called
   */


  Player.prototype.play_ = function play_() {
    var _this8 = this;

    var callback = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : silencePromise;

    // If this is called while we have a play queued up on a loadstart, remove
    // that listener to avoid getting in a potentially bad state.
    if (this.playOnLoadstart_) {
      this.off('loadstart', this.playOnLoadstart_);
    }

    // If the player/tech is not ready, queue up another call to `play()` for
    // when it is. This will loop back into this method for another attempt at
    // playback when the tech is ready.
    if (!this.isReady_) {

      // Bail out if we're already waiting for `ready`!
      if (this.playWaitingForReady_) {
        return;
      }

      this.playWaitingForReady_ = true;
      this.ready(function () {
        _this8.playWaitingForReady_ = false;
        callback(_this8.play());
      });

      // If the player/tech is ready and we have a source, we can attempt playback.
    } else if (!this.changingSrc_ && (this.src() || this.currentSrc())) {
      callback(this.techGet_('play'));
      return;

      // If the tech is ready, but we do not have a source, we'll need to wait
      // for both the `ready` and a `loadstart` when the source is finally
      // resolved by middleware and set on the player.
      //
      // This can happen if `play()` is called while changing sources or before
      // one has been set on the player.
    } else {

      this.playOnLoadstart_ = function () {
        _this8.playOnLoadstart_ = null;
        callback(_this8.play());
      };

      this.one('loadstart', this.playOnLoadstart_);
    }
  };

  /**
   * Pause the video playback
   *
   * @return {Player}
   *         A reference to the player object this function was called on
   */


  Player.prototype.pause = function pause() {
    this.techCall_('pause');
  };

  /**
   * Check if the player is paused or has yet to play
   *
   * @return {boolean}
   *         - false: if the media is currently playing
   *         - true: if media is not currently playing
   */


  Player.prototype.paused = function paused() {
    // The initial state of paused should be true (in Safari it's actually false)
    return this.techGet_('paused') === false ? false : true;
  };

  /**
   * Get a TimeRange object representing the current ranges of time that the user
   * has played.
   *
   * @return {TimeRange}
   *         A time range object that represents all the increments of time that have
   *         been played.
   */


  Player.prototype.played = function played() {
    return this.techGet_('played') || createTimeRanges(0, 0);
  };

  /**
   * Returns whether or not the user is "scrubbing". Scrubbing is
   * when the user has clicked the progress bar handle and is
   * dragging it along the progress bar.
   *
   * @param {boolean} [isScrubbing]
   *        wether the user is or is not scrubbing
   *
   * @return {boolean}
   *         The value of scrubbing when getting
   */


  Player.prototype.scrubbing = function scrubbing(isScrubbing) {
    if (typeof isScrubbing === 'undefined') {
      return this.scrubbing_;
    }
    this.scrubbing_ = !!isScrubbing;

    if (isScrubbing) {
      this.addClass('vjs-scrubbing');
    } else {
      this.removeClass('vjs-scrubbing');
    }
  };

  /**
   * Get or set the current time (in seconds)
   *
   * @param {number|string} [seconds]
   *        The time to seek to in seconds
   *
   * @return {number}
   *         - the current time in seconds when getting
   */


  Player.prototype.currentTime = function currentTime(seconds) {
    if (typeof seconds !== 'undefined') {
      if (seconds < 0) {
        seconds = 0;
      }
      this.techCall_('setCurrentTime', seconds);
      return;
    }

    // cache last currentTime and return. default to 0 seconds
    //
    // Caching the currentTime is meant to prevent a massive amount of reads on the tech's
    // currentTime when scrubbing, but may not provide much performance benefit afterall.
    // Should be tested. Also something has to read the actual current time or the cache will
    // never get updated.
    this.cache_.currentTime = this.techGet_('currentTime') || 0;
    return this.cache_.currentTime;
  };

  /**
   * Normally gets the length in time of the video in seconds;
   * in all but the rarest use cases an argument will NOT be passed to the method
   *
   * > **NOTE**: The video must have started loading before the duration can be
   * known, and in the case of Flash, may not be known until the video starts
   * playing.
   *
   * @fires Player#durationchange
   *
   * @param {number} [seconds]
   *        The duration of the video to set in seconds
   *
   * @return {number}
   *         - The duration of the video in seconds when getting
   */


  Player.prototype.duration = function duration(seconds) {
    if (seconds === undefined) {
      // return NaN if the duration is not known
      return this.cache_.duration !== undefined ? this.cache_.duration : NaN;
    }

    seconds = parseFloat(seconds);

    // Standardize on Inifity for signaling video is live
    if (seconds < 0) {
      seconds = Infinity;
    }

    if (seconds !== this.cache_.duration) {
      // Cache the last set value for optimized scrubbing (esp. Flash)
      this.cache_.duration = seconds;

      if (seconds === Infinity) {
        this.addClass('vjs-live');
      } else {
        this.removeClass('vjs-live');
      }
      /**
       * @event Player#durationchange
       * @type {EventTarget~Event}
       */
      this.trigger('durationchange');
    }
  };

  /**
   * Calculates how much time is left in the video. Not part
   * of the native video API.
   *
   * @return {number}
   *         The time remaining in seconds
   */


  Player.prototype.remainingTime = function remainingTime() {
    return this.duration() - this.currentTime();
  };

  /**
   * A remaining time function that is intented to be used when
   * the time is to be displayed directly to the user.
   *
   * @return {number}
   *         The rounded time remaining in seconds
   */


  Player.prototype.remainingTimeDisplay = function remainingTimeDisplay() {
    return Math.floor(this.duration()) - Math.floor(this.currentTime());
  };

  //
  // Kind of like an array of portions of the video that have been downloaded.

  /**
   * Get a TimeRange object with an array of the times of the video
   * that have been downloaded. If you just want the percent of the
   * video that's been downloaded, use bufferedPercent.
   *
   * @see [Buffered Spec]{@link http://dev.w3.org/html5/spec/video.html#dom-media-buffered}
   *
   * @return {TimeRange}
   *         A mock TimeRange object (following HTML spec)
   */


  Player.prototype.buffered = function buffered() {
    var buffered = this.techGet_('buffered');

    if (!buffered || !buffered.length) {
      buffered = createTimeRanges(0, 0);
    }

    return buffered;
  };

  /**
   * Get the percent (as a decimal) of the video that's been downloaded.
   * This method is not a part of the native HTML video API.
   *
   * @return {number}
   *         A decimal between 0 and 1 representing the percent
   *         that is bufferred 0 being 0% and 1 being 100%
   */


  Player.prototype.bufferedPercent = function bufferedPercent$$1() {
    return bufferedPercent(this.buffered(), this.duration());
  };

  /**
   * Get the ending time of the last buffered time range
   * This is used in the progress bar to encapsulate all time ranges.
   *
   * @return {number}
   *         The end of the last buffered time range
   */


  Player.prototype.bufferedEnd = function bufferedEnd() {
    var buffered = this.buffered();
    var duration = this.duration();
    var end = buffered.end(buffered.length - 1);

    if (end > duration) {
      end = duration;
    }

    return end;
  };

  /**
   * Get or set the current volume of the media
   *
   * @param  {number} [percentAsDecimal]
   *         The new volume as a decimal percent:
   *         - 0 is muted/0%/off
   *         - 1.0 is 100%/full
   *         - 0.5 is half volume or 50%
   *
   * @return {number}
   *         The current volume as a percent when getting
   */


  Player.prototype.volume = function volume(percentAsDecimal) {
    var vol = void 0;

    if (percentAsDecimal !== undefined) {
      // Force value to between 0 and 1
      vol = Math.max(0, Math.min(1, parseFloat(percentAsDecimal)));
      this.cache_.volume = vol;
      this.techCall_('setVolume', vol);

      if (vol > 0) {
        this.lastVolume_(vol);
      }

      return;
    }

    // Default to 1 when returning current volume.
    vol = parseFloat(this.techGet_('volume'));
    return isNaN(vol) ? 1 : vol;
  };

  /**
   * Get the current muted state, or turn mute on or off
   *
   * @param {boolean} [muted]
   *        - true to mute
   *        - false to unmute
   *
   * @return {boolean}
   *         - true if mute is on and getting
   *         - false if mute is off and getting
   */


  Player.prototype.muted = function muted(_muted) {
    if (_muted !== undefined) {
      this.techCall_('setMuted', _muted);
      return;
    }
    return this.techGet_('muted') || false;
  };

  /**
   * Get the current defaultMuted state, or turn defaultMuted on or off. defaultMuted
   * indicates the state of muted on intial playback.
   *
   * ```js
   *   var myPlayer = videojs('some-player-id');
   *
   *   myPlayer.src("http://www.example.com/path/to/video.mp4");
   *
   *   // get, should be false
   *   console.log(myPlayer.defaultMuted());
   *   // set to true
   *   myPlayer.defaultMuted(true);
   *   // get should be true
   *   console.log(myPlayer.defaultMuted());
   * ```
   *
   * @param {boolean} [defaultMuted]
   *        - true to mute
   *        - false to unmute
   *
   * @return {boolean|Player}
   *         - true if defaultMuted is on and getting
   *         - false if defaultMuted is off and getting
   *         - A reference to the current player when setting
   */


  Player.prototype.defaultMuted = function defaultMuted(_defaultMuted) {
    if (_defaultMuted !== undefined) {
      return this.techCall_('setDefaultMuted', _defaultMuted);
    }
    return this.techGet_('defaultMuted') || false;
  };

  /**
   * Get the last volume, or set it
   *
   * @param  {number} [percentAsDecimal]
   *         The new last volume as a decimal percent:
   *         - 0 is muted/0%/off
   *         - 1.0 is 100%/full
   *         - 0.5 is half volume or 50%
   *
   * @return {number}
   *         the current value of lastVolume as a percent when getting
   *
   * @private
   */


  Player.prototype.lastVolume_ = function lastVolume_(percentAsDecimal) {
    if (percentAsDecimal !== undefined && percentAsDecimal !== 0) {
      this.cache_.lastVolume = percentAsDecimal;
      return;
    }
    return this.cache_.lastVolume;
  };

  /**
   * Check if current tech can support native fullscreen
   * (e.g. with built in controls like iOS, so not our flash swf)
   *
   * @return {boolean}
   *         if native fullscreen is supported
   */


  Player.prototype.supportsFullScreen = function supportsFullScreen() {
    return this.techGet_('supportsFullScreen') || false;
  };

  /**
   * Check if the player is in fullscreen mode or tell the player that it
   * is or is not in fullscreen mode.
   *
   * > NOTE: As of the latest HTML5 spec, isFullscreen is no longer an official
   * property and instead document.fullscreenElement is used. But isFullscreen is
   * still a valuable property for internal player workings.
   *
   * @param  {boolean} [isFS]
   *         Set the players current fullscreen state
   *
   * @return {boolean}
   *         - true if fullscreen is on and getting
   *         - false if fullscreen is off and getting
   */


  Player.prototype.isFullscreen = function isFullscreen(isFS) {
    if (isFS !== undefined) {
      this.isFullscreen_ = !!isFS;
      return;
    }
    return !!this.isFullscreen_;
  };

  /**
   * Increase the size of the video to full screen
   * In some browsers, full screen is not supported natively, so it enters
   * "full window mode", where the video fills the browser window.
   * In browsers and devices that support native full screen, sometimes the
   * browser's default controls will be shown, and not the Video.js custom skin.
   * This includes most mobile devices (iOS, Android) and older versions of
   * Safari.
   *
   * @fires Player#fullscreenchange
   */


  Player.prototype.requestFullscreen = function requestFullscreen() {
    var fsApi = FullscreenApi;

    this.isFullscreen(true);

    if (fsApi.requestFullscreen) {
      // the browser supports going fullscreen at the element level so we can
      // take the controls fullscreen as well as the video

      // Trigger fullscreenchange event after change
      // We have to specifically add this each time, and remove
      // when canceling fullscreen. Otherwise if there's multiple
      // players on a page, they would all be reacting to the same fullscreen
      // events
      on(document_1, fsApi.fullscreenchange, bind(this, function documentFullscreenChange(e) {
        this.isFullscreen(document_1[fsApi.fullscreenElement]);

        // If cancelling fullscreen, remove event listener.
        if (this.isFullscreen() === false) {
          off(document_1, fsApi.fullscreenchange, documentFullscreenChange);
        }
        /**
         * @event Player#fullscreenchange
         * @type {EventTarget~Event}
         */
        this.trigger('fullscreenchange');
      }));

      this.el_[fsApi.requestFullscreen]();
    } else if (this.tech_.supportsFullScreen()) {
      // we can't take the video.js controls fullscreen but we can go fullscreen
      // with native controls
      this.techCall_('enterFullScreen');
    } else {
      // fullscreen isn't supported so we'll just stretch the video element to
      // fill the viewport
      this.enterFullWindow();
      /**
       * @event Player#fullscreenchange
       * @type {EventTarget~Event}
       */
      this.trigger('fullscreenchange');
    }
  };

  /**
   * Return the video to its normal size after having been in full screen mode
   *
   * @fires Player#fullscreenchange
   */


  Player.prototype.exitFullscreen = function exitFullscreen() {
    var fsApi = FullscreenApi;

    this.isFullscreen(false);

    // Check for browser element fullscreen support
    if (fsApi.requestFullscreen) {
      document_1[fsApi.exitFullscreen]();
    } else if (this.tech_.supportsFullScreen()) {
      this.techCall_('exitFullScreen');
    } else {
      this.exitFullWindow();
      /**
       * @event Player#fullscreenchange
       * @type {EventTarget~Event}
       */
      this.trigger('fullscreenchange');
    }
  };

  /**
   * When fullscreen isn't supported we can stretch the
   * video container to as wide as the browser will let us.
   *
   * @fires Player#enterFullWindow
   */


  Player.prototype.enterFullWindow = function enterFullWindow() {
    this.isFullWindow = true;

    // Storing original doc overflow value to return to when fullscreen is off
    this.docOrigOverflow = document_1.documentElement.style.overflow;

    // Add listener for esc key to exit fullscreen
    on(document_1, 'keydown', bind(this, this.fullWindowOnEscKey));

    // Hide any scroll bars
    document_1.documentElement.style.overflow = 'hidden';

    // Apply fullscreen styles
    addClass(document_1.body, 'vjs-full-window');

    /**
     * @event Player#enterFullWindow
     * @type {EventTarget~Event}
     */
    this.trigger('enterFullWindow');
  };

  /**
   * Check for call to either exit full window or
   * full screen on ESC key
   *
   * @param {string} event
   *        Event to check for key press
   */


  Player.prototype.fullWindowOnEscKey = function fullWindowOnEscKey(event) {
    if (event.keyCode === 27) {
      if (this.isFullscreen() === true) {
        this.exitFullscreen();
      } else {
        this.exitFullWindow();
      }
    }
  };

  /**
   * Exit full window
   *
   * @fires Player#exitFullWindow
   */


  Player.prototype.exitFullWindow = function exitFullWindow() {
    this.isFullWindow = false;
    off(document_1, 'keydown', this.fullWindowOnEscKey);

    // Unhide scroll bars.
    document_1.documentElement.style.overflow = this.docOrigOverflow;

    // Remove fullscreen styles
    removeClass(document_1.body, 'vjs-full-window');

    // Resize the box, controller, and poster to original sizes
    // this.positionAll();
    /**
     * @event Player#exitFullWindow
     * @type {EventTarget~Event}
     */
    this.trigger('exitFullWindow');
  };

  /**
   * Check whether the player can play a given mimetype
   *
   * @see https://www.w3.org/TR/2011/WD-html5-20110113/video.html#dom-navigator-canplaytype
   *
   * @param {string} type
   *        The mimetype to check
   *
   * @return {string}
   *         'probably', 'maybe', or '' (empty string)
   */


  Player.prototype.canPlayType = function canPlayType(type) {
    var can = void 0;

    // Loop through each playback technology in the options order
    for (var i = 0, j = this.options_.techOrder; i < j.length; i++) {
      var techName = j[i];
      var tech = Tech.getTech(techName);

      // Support old behavior of techs being registered as components.
      // Remove once that deprecated behavior is removed.
      if (!tech) {
        tech = Component.getComponent(techName);
      }

      // Check if the current tech is defined before continuing
      if (!tech) {
        log$1.error('The "' + techName + '" tech is undefined. Skipped browser support check for that tech.');
        continue;
      }

      // Check if the browser supports this technology
      if (tech.isSupported()) {
        can = tech.canPlayType(type);

        if (can) {
          return can;
        }
      }
    }

    return '';
  };

  /**
   * Select source based on tech-order or source-order
   * Uses source-order selection if `options.sourceOrder` is truthy. Otherwise,
   * defaults to tech-order selection
   *
   * @param {Array} sources
   *        The sources for a media asset
   *
   * @return {Object|boolean}
   *         Object of source and tech order or false
   */


  Player.prototype.selectSource = function selectSource(sources) {
    var _this9 = this;

    // Get only the techs specified in `techOrder` that exist and are supported by the
    // current platform
    var techs = this.options_.techOrder.map(function (techName) {
      return [techName, Tech.getTech(techName)];
    }).filter(function (_ref) {
      var techName = _ref[0],
          tech = _ref[1];

      // Check if the current tech is defined before continuing
      if (tech) {
        // Check if the browser supports this technology
        return tech.isSupported();
      }

      log$1.error('The "' + techName + '" tech is undefined. Skipped browser support check for that tech.');
      return false;
    });

    // Iterate over each `innerArray` element once per `outerArray` element and execute
    // `tester` with both. If `tester` returns a non-falsy value, exit early and return
    // that value.
    var findFirstPassingTechSourcePair = function findFirstPassingTechSourcePair(outerArray, innerArray, tester) {
      var found = void 0;

      outerArray.some(function (outerChoice) {
        return innerArray.some(function (innerChoice) {
          found = tester(outerChoice, innerChoice);

          if (found) {
            return true;
          }
        });
      });

      return found;
    };

    var foundSourceAndTech = void 0;
    var flip = function flip(fn) {
      return function (a, b) {
        return fn(b, a);
      };
    };
    var finder = function finder(_ref2, source) {
      var techName = _ref2[0],
          tech = _ref2[1];

      if (tech.canPlaySource(source, _this9.options_[techName.toLowerCase()])) {
        return { source: source, tech: techName };
      }
    };

    // Depending on the truthiness of `options.sourceOrder`, we swap the order of techs and sources
    // to select from them based on their priority.
    if (this.options_.sourceOrder) {
      // Source-first ordering
      foundSourceAndTech = findFirstPassingTechSourcePair(sources, techs, flip(finder));
    } else {
      // Tech-first ordering
      foundSourceAndTech = findFirstPassingTechSourcePair(techs, sources, finder);
    }

    return foundSourceAndTech || false;
  };

  /**
   * Get or set the video source.
   *
   * @param {Tech~SourceObject|Tech~SourceObject[]|string} [source]
   *        A SourceObject, an array of SourceObjects, or a string referencing
   *        a URL to a media source. It is _highly recommended_ that an object
   *        or array of objects is used here, so that source selection
   *        algorithms can take the `type` into account.
   *
   *        If not provided, this method acts as a getter.
   *
   * @return {string|undefined}
   *         If the `source` argument is missing, returns the current source
   *         URL. Otherwise, returns nothing/undefined.
   */


  Player.prototype.src = function src(source) {
    var _this10 = this;

    // getter usage
    if (typeof source === 'undefined') {
      return this.cache_.src || '';
    }
    // filter out invalid sources and turn our source into
    // an array of source objects
    var sources = filterSource(source);

    // if a source was passed in then it is invalid because
    // it was filtered to a zero length Array. So we have to
    // show an error
    if (!sources.length) {
      this.setTimeout(function () {
        this.error({ code: 4, message: this.localize(this.options_.notSupportedMessage) });
      }, 0);
      return;
    }

    // intial sources
    this.changingSrc_ = true;

    this.cache_.sources = sources;
    this.updateSourceCaches_(sources[0]);

    // middlewareSource is the source after it has been changed by middleware
    setSource(this, sources[0], function (middlewareSource, mws) {
      _this10.middleware_ = mws;

      // since sourceSet is async we have to update the cache again after we select a source since
      // the source that is selected could be out of order from the cache update above this callback.
      _this10.cache_.sources = sources;
      _this10.updateSourceCaches_(middlewareSource);

      var err = _this10.src_(middlewareSource);

      if (err) {
        if (sources.length > 1) {
          return _this10.src(sources.slice(1));
        }

        _this10.changingSrc_ = false;

        // We need to wrap this in a timeout to give folks a chance to add error event handlers
        _this10.setTimeout(function () {
          this.error({ code: 4, message: this.localize(this.options_.notSupportedMessage) });
        }, 0);

        // we could not find an appropriate tech, but let's still notify the delegate that this is it
        // this needs a better comment about why this is needed
        _this10.triggerReady();

        return;
      }

      setTech(mws, _this10.tech_);
    });
  };

  /**
   * Set the source object on the tech, returns a boolean that indicates wether
   * there is a tech that can play the source or not
   *
   * @param {Tech~SourceObject} source
   *        The source object to set on the Tech
   *
   * @return {Boolean}
   *         - True if there is no Tech to playback this source
   *         - False otherwise
   *
   * @private
   */


  Player.prototype.src_ = function src_(source) {
    var _this11 = this;

    var sourceTech = this.selectSource([source]);

    if (!sourceTech) {
      return true;
    }

    if (!titleCaseEquals(sourceTech.tech, this.techName_)) {
      this.changingSrc_ = true;
      // load this technology with the chosen source
      this.loadTech_(sourceTech.tech, sourceTech.source);
      this.tech_.ready(function () {
        _this11.changingSrc_ = false;
      });
      return false;
    }

    // wait until the tech is ready to set the source
    // and set it synchronously if possible (#2326)
    this.ready(function () {

      // The setSource tech method was added with source handlers
      // so older techs won't support it
      // We need to check the direct prototype for the case where subclasses
      // of the tech do not support source handlers
      if (this.tech_.constructor.prototype.hasOwnProperty('setSource')) {
        this.techCall_('setSource', source);
      } else {
        this.techCall_('src', source.src);
      }

      this.changingSrc_ = false;
    }, true);

    return false;
  };

  /**
   * Begin loading the src data.
   */


  Player.prototype.load = function load() {
    this.techCall_('load');
  };

  /**
   * Reset the player. Loads the first tech in the techOrder,
   * and calls `reset` on the tech`.
   */


  Player.prototype.reset = function reset() {
    if (this.tech_) {
      this.tech_.clearTracks('text');
    }
    this.loadTech_(this.options_.techOrder[0], null);
    this.techCall_('reset');
  };

  /**
   * Returns all of the current source objects.
   *
   * @return {Tech~SourceObject[]}
   *         The current source objects
   */


  Player.prototype.currentSources = function currentSources() {
    var source = this.currentSource();
    var sources = [];

    // assume `{}` or `{ src }`
    if (Object.keys(source).length !== 0) {
      sources.push(source);
    }

    return this.cache_.sources || sources;
  };

  /**
   * Returns the current source object.
   *
   * @return {Tech~SourceObject}
   *         The current source object
   */


  Player.prototype.currentSource = function currentSource() {
    return this.cache_.source || {};
  };

  /**
   * Returns the fully qualified URL of the current source value e.g. http://mysite.com/video.mp4
   * Can be used in conjuction with `currentType` to assist in rebuilding the current source object.
   *
   * @return {string}
   *         The current source
   */


  Player.prototype.currentSrc = function currentSrc() {
    return this.currentSource() && this.currentSource().src || '';
  };

  /**
   * Get the current source type e.g. video/mp4
   * This can allow you rebuild the current source object so that you could load the same
   * source and tech later
   *
   * @return {string}
   *         The source MIME type
   */


  Player.prototype.currentType = function currentType() {
    return this.currentSource() && this.currentSource().type || '';
  };

  /**
   * Get or set the preload attribute
   *
   * @param {boolean} [value]
   *        - true means that we should preload
   *        - false maens that we should not preload
   *
   * @return {string}
   *         The preload attribute value when getting
   */


  Player.prototype.preload = function preload(value) {
    if (value !== undefined) {
      this.techCall_('setPreload', value);
      this.options_.preload = value;
      return;
    }
    return this.techGet_('preload');
  };

  /**
   * Get or set the autoplay option. When this is a boolean it will
   * modify the attribute on the tech. When this is a string the attribute on
   * the tech will be removed and `Player` will handle autoplay on loadstarts.
   *
   * @param {boolean|string} [value]
   *        - true: autoplay using the browser behavior
   *        - false: do not autoplay
   *        - 'play': call play() on every loadstart
   *        - 'muted': call muted() then play() on every loadstart
   *        - 'any': call play() on every loadstart. if that fails call muted() then play().
   *        - *: values other than those listed here will be set `autoplay` to true
   *
   * @return {boolean|string}
   *         The current value of autoplay when getting
   */


  Player.prototype.autoplay = function autoplay(value) {
    // getter usage
    if (value === undefined) {
      return this.options_.autoplay || false;
    }

    var techAutoplay = void 0;

    // if the value is a valid string set it to that
    if (typeof value === 'string' && /(any|play|muted)/.test(value)) {
      this.options_.autoplay = value;
      this.manualAutoplay_(value);
      techAutoplay = false;

      // any falsy value sets autoplay to false in the browser,
      // lets do the same
    } else if (!value) {
      this.options_.autoplay = false;

      // any other value (ie truthy) sets autoplay to true
    } else {
      this.options_.autoplay = true;
    }

    techAutoplay = techAutoplay || this.options_.autoplay;

    // if we don't have a tech then we do not queue up
    // a setAutoplay call on tech ready. We do this because the
    // autoplay option will be passed in the constructor and we
    // do not need to set it twice
    if (this.tech_) {
      this.techCall_('setAutoplay', techAutoplay);
    }
  };

  /**
   * Set or unset the playsinline attribute.
   * Playsinline tells the browser that non-fullscreen playback is preferred.
   *
   * @param {boolean} [value]
   *        - true means that we should try to play inline by default
   *        - false means that we should use the browser's default playback mode,
   *          which in most cases is inline. iOS Safari is a notable exception
   *          and plays fullscreen by default.
   *
   * @return {string|Player}
   *         - the current value of playsinline
   *         - the player when setting
   *
   * @see [Spec]{@link https://html.spec.whatwg.org/#attr-video-playsinline}
   */


  Player.prototype.playsinline = function playsinline(value) {
    if (value !== undefined) {
      this.techCall_('setPlaysinline', value);
      this.options_.playsinline = value;
      return this;
    }
    return this.techGet_('playsinline');
  };

  /**
   * Get or set the loop attribute on the video element.
   *
   * @param {boolean} [value]
   *        - true means that we should loop the video
   *        - false means that we should not loop the video
   *
   * @return {string}
   *         The current value of loop when getting
   */


  Player.prototype.loop = function loop(value) {
    if (value !== undefined) {
      this.techCall_('setLoop', value);
      this.options_.loop = value;
      return;
    }
    return this.techGet_('loop');
  };

  /**
   * Get or set the poster image source url
   *
   * @fires Player#posterchange
   *
   * @param {string} [src]
   *        Poster image source URL
   *
   * @return {string}
   *         The current value of poster when getting
   */


  Player.prototype.poster = function poster(src) {
    if (src === undefined) {
      return this.poster_;
    }

    // The correct way to remove a poster is to set as an empty string
    // other falsey values will throw errors
    if (!src) {
      src = '';
    }

    if (src === this.poster_) {
      return;
    }

    // update the internal poster variable
    this.poster_ = src;

    // update the tech's poster
    this.techCall_('setPoster', src);

    this.isPosterFromTech_ = false;

    // alert components that the poster has been set
    /**
     * This event fires when the poster image is changed on the player.
     *
     * @event Player#posterchange
     * @type {EventTarget~Event}
     */
    this.trigger('posterchange');
  };

  /**
   * Some techs (e.g. YouTube) can provide a poster source in an
   * asynchronous way. We want the poster component to use this
   * poster source so that it covers up the tech's controls.
   * (YouTube's play button). However we only want to use this
   * source if the player user hasn't set a poster through
   * the normal APIs.
   *
   * @fires Player#posterchange
   * @listens Tech#posterchange
   * @private
   */


  Player.prototype.handleTechPosterChange_ = function handleTechPosterChange_() {
    if ((!this.poster_ || this.options_.techCanOverridePoster) && this.tech_ && this.tech_.poster) {
      var newPoster = this.tech_.poster() || '';

      if (newPoster !== this.poster_) {
        this.poster_ = newPoster;
        this.isPosterFromTech_ = true;

        // Let components know the poster has changed
        this.trigger('posterchange');
      }
    }
  };

  /**
   * Get or set whether or not the controls are showing.
   *
   * @fires Player#controlsenabled
   *
   * @param {boolean} [bool]
   *        - true to turn controls on
   *        - false to turn controls off
   *
   * @return {boolean}
   *         The current value of controls when getting
   */


  Player.prototype.controls = function controls(bool) {
    if (bool === undefined) {
      return !!this.controls_;
    }

    bool = !!bool;

    // Don't trigger a change event unless it actually changed
    if (this.controls_ === bool) {
      return;
    }

    this.controls_ = bool;

    if (this.usingNativeControls()) {
      this.techCall_('setControls', bool);
    }

    if (this.controls_) {
      this.removeClass('vjs-controls-disabled');
      this.addClass('vjs-controls-enabled');
      /**
       * @event Player#controlsenabled
       * @type {EventTarget~Event}
       */
      this.trigger('controlsenabled');
      if (!this.usingNativeControls()) {
        this.addTechControlsListeners_();
      }
    } else {
      this.removeClass('vjs-controls-enabled');
      this.addClass('vjs-controls-disabled');
      /**
       * @event Player#controlsdisabled
       * @type {EventTarget~Event}
       */
      this.trigger('controlsdisabled');
      if (!this.usingNativeControls()) {
        this.removeTechControlsListeners_();
      }
    }
  };

  /**
   * Toggle native controls on/off. Native controls are the controls built into
   * devices (e.g. default iPhone controls), Flash, or other techs
   * (e.g. Vimeo Controls)
   * **This should only be set by the current tech, because only the tech knows
   * if it can support native controls**
   *
   * @fires Player#usingnativecontrols
   * @fires Player#usingcustomcontrols
   *
   * @param {boolean} [bool]
   *        - true to turn native controls on
   *        - false to turn native controls off
   *
   * @return {boolean}
   *         The current value of native controls when getting
   */


  Player.prototype.usingNativeControls = function usingNativeControls(bool) {
    if (bool === undefined) {
      return !!this.usingNativeControls_;
    }

    bool = !!bool;

    // Don't trigger a change event unless it actually changed
    if (this.usingNativeControls_ === bool) {
      return;
    }

    this.usingNativeControls_ = bool;

    if (this.usingNativeControls_) {
      this.addClass('vjs-using-native-controls');

      /**
       * player is using the native device controls
       *
       * @event Player#usingnativecontrols
       * @type {EventTarget~Event}
       */
      this.trigger('usingnativecontrols');
    } else {
      this.removeClass('vjs-using-native-controls');

      /**
       * player is using the custom HTML controls
       *
       * @event Player#usingcustomcontrols
       * @type {EventTarget~Event}
       */
      this.trigger('usingcustomcontrols');
    }
  };

  /**
   * Set or get the current MediaError
   *
   * @fires Player#error
   *
   * @param  {MediaError|string|number} [err]
   *         A MediaError or a string/number to be turned
   *         into a MediaError
   *
   * @return {MediaError|null}
   *         The current MediaError when getting (or null)
   */


  Player.prototype.error = function error(err) {
    if (err === undefined) {
      return this.error_ || null;
    }

    // restoring to default
    if (err === null) {
      this.error_ = err;
      this.removeClass('vjs-error');
      if (this.errorDisplay) {
        this.errorDisplay.close();
      }
      return;
    }

    this.error_ = new MediaError(err);

    // add the vjs-error classname to the player
    this.addClass('vjs-error');

    // log the name of the error type and any message
    // ie8 just logs "[object object]" if you just log the error object
    log$1.error('(CODE:' + this.error_.code + ' ' + MediaError.errorTypes[this.error_.code] + ')', this.error_.message, this.error_);

    /**
     * @event Player#error
     * @type {EventTarget~Event}
     */
    this.trigger('error');

    return;
  };

  /**
   * Report user activity
   *
   * @param {Object} event
   *        Event object
   */


  Player.prototype.reportUserActivity = function reportUserActivity(event) {
    this.userActivity_ = true;
  };

  /**
   * Get/set if user is active
   *
   * @fires Player#useractive
   * @fires Player#userinactive
   *
   * @param {boolean} [bool]
   *        - true if the user is active
   *        - false if the user is inactive
   *
   * @return {boolean}
   *         The current value of userActive when getting
   */


  Player.prototype.userActive = function userActive(bool) {
    if (bool === undefined) {
      return this.userActive_;
    }

    bool = !!bool;

    if (bool === this.userActive_) {
      return;
    }

    this.userActive_ = bool;

    if (this.userActive_) {
      this.userActivity_ = true;
      this.removeClass('vjs-user-inactive');
      this.addClass('vjs-user-active');
      /**
       * @event Player#useractive
       * @type {EventTarget~Event}
       */
      this.trigger('useractive');
      return;
    }

    // Chrome/Safari/IE have bugs where when you change the cursor it can
    // trigger a mousemove event. This causes an issue when you're hiding
    // the cursor when the user is inactive, and a mousemove signals user
    // activity. Making it impossible to go into inactive mode. Specifically
    // this happens in fullscreen when we really need to hide the cursor.
    //
    // When this gets resolved in ALL browsers it can be removed
    // https://code.google.com/p/chromium/issues/detail?id=103041
    if (this.tech_) {
      this.tech_.one('mousemove', function (e) {
        e.stopPropagation();
        e.preventDefault();
      });
    }

    this.userActivity_ = false;
    this.removeClass('vjs-user-active');
    this.addClass('vjs-user-inactive');
    /**
     * @event Player#userinactive
     * @type {EventTarget~Event}
     */
    this.trigger('userinactive');
  };

  /**
   * Listen for user activity based on timeout value
   *
   * @private
   */


  Player.prototype.listenForUserActivity_ = function listenForUserActivity_() {
    var mouseInProgress = void 0;
    var lastMoveX = void 0;
    var lastMoveY = void 0;
    var handleActivity = bind(this, this.reportUserActivity);

    var handleMouseMove = function handleMouseMove(e) {
      // #1068 - Prevent mousemove spamming
      // Chrome Bug: https://code.google.com/p/chromium/issues/detail?id=366970
      if (e.screenX !== lastMoveX || e.screenY !== lastMoveY) {
        lastMoveX = e.screenX;
        lastMoveY = e.screenY;
        handleActivity();
      }
    };

    var handleMouseDown = function handleMouseDown() {
      handleActivity();
      // For as long as the they are touching the device or have their mouse down,
      // we consider them active even if they're not moving their finger or mouse.
      // So we want to continue to update that they are active
      this.clearInterval(mouseInProgress);
      // Setting userActivity=true now and setting the interval to the same time
      // as the activityCheck interval (250) should ensure we never miss the
      // next activityCheck
      mouseInProgress = this.setInterval(handleActivity, 250);
    };

    var handleMouseUp = function handleMouseUp(event) {
      handleActivity();
      // Stop the interval that maintains activity if the mouse/touch is down
      this.clearInterval(mouseInProgress);
    };

    // Any mouse movement will be considered user activity
    this.on('mousedown', handleMouseDown);
    this.on('mousemove', handleMouseMove);
    this.on('mouseup', handleMouseUp);

    // Listen for keyboard navigation
    // Shouldn't need to use inProgress interval because of key repeat
    this.on('keydown', handleActivity);
    this.on('keyup', handleActivity);

    // Run an interval every 250 milliseconds instead of stuffing everything into
    // the mousemove/touchmove function itself, to prevent performance degradation.
    // `this.reportUserActivity` simply sets this.userActivity_ to true, which
    // then gets picked up by this loop
    // http://ejohn.org/blog/learning-from-twitter/
    var inactivityTimeout = void 0;

    this.setInterval(function () {
      // Check to see if mouse/touch activity has happened
      if (!this.userActivity_) {
        return;
      }

      // Reset the activity tracker
      this.userActivity_ = false;

      // If the user state was inactive, set the state to active
      this.userActive(true);

      // Clear any existing inactivity timeout to start the timer over
      this.clearTimeout(inactivityTimeout);

      var timeout = this.options_.inactivityTimeout;

      if (timeout <= 0) {
        return;
      }

      // In <timeout> milliseconds, if no more activity has occurred the
      // user will be considered inactive
      inactivityTimeout = this.setTimeout(function () {
        // Protect against the case where the inactivityTimeout can trigger just
        // before the next user activity is picked up by the activity check loop
        // causing a flicker
        if (!this.userActivity_) {
          this.userActive(false);
        }
      }, timeout);
    }, 250);
  };

  /**
   * Gets or sets the current playback rate. A playback rate of
   * 1.0 represents normal speed and 0.5 would indicate half-speed
   * playback, for instance.
   *
   * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-media-playbackrate
   *
   * @param {number} [rate]
   *       New playback rate to set.
   *
   * @return {number}
   *         The current playback rate when getting or 1.0
   */


  Player.prototype.playbackRate = function playbackRate(rate) {
    if (rate !== undefined) {
      // NOTE: this.cache_.lastPlaybackRate is set from the tech handler
      // that is registered above
      this.techCall_('setPlaybackRate', rate);
      return;
    }

    if (this.tech_ && this.tech_.featuresPlaybackRate) {
      return this.cache_.lastPlaybackRate || this.techGet_('playbackRate');
    }
    return 1.0;
  };

  /**
   * Gets or sets the current default playback rate. A default playback rate of
   * 1.0 represents normal speed and 0.5 would indicate half-speed playback, for instance.
   * defaultPlaybackRate will only represent what the intial playbackRate of a video was, not
   * not the current playbackRate.
   *
   * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-media-defaultplaybackrate
   *
   * @param {number} [rate]
   *       New default playback rate to set.
   *
   * @return {number|Player}
   *         - The default playback rate when getting or 1.0
   *         - the player when setting
   */


  Player.prototype.defaultPlaybackRate = function defaultPlaybackRate(rate) {
    if (rate !== undefined) {
      return this.techCall_('setDefaultPlaybackRate', rate);
    }

    if (this.tech_ && this.tech_.featuresPlaybackRate) {
      return this.techGet_('defaultPlaybackRate');
    }
    return 1.0;
  };

  /**
   * Gets or sets the audio flag
   *
   * @param {boolean} bool
   *        - true signals that this is an audio player
   *        - false signals that this is not an audio player
   *
   * @return {boolean}
   *         The current value of isAudio when getting
   */


  Player.prototype.isAudio = function isAudio(bool) {
    if (bool !== undefined) {
      this.isAudio_ = !!bool;
      return;
    }

    return !!this.isAudio_;
  };

  /**
   * A helper method for adding a {@link TextTrack} to our
   * {@link TextTrackList}.
   *
   * In addition to the W3C settings we allow adding additional info through options.
   *
   * @see http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#dom-media-addtexttrack
   *
   * @param {string} [kind]
   *        the kind of TextTrack you are adding
   *
   * @param {string} [label]
   *        the label to give the TextTrack label
   *
   * @param {string} [language]
   *        the language to set on the TextTrack
   *
   * @return {TextTrack|undefined}
   *         the TextTrack that was added or undefined
   *         if there is no tech
   */


  Player.prototype.addTextTrack = function addTextTrack(kind, label, language) {
    if (this.tech_) {
      return this.tech_.addTextTrack(kind, label, language);
    }
  };

  /**
   * Create a remote {@link TextTrack} and an {@link HTMLTrackElement}. It will
   * automatically removed from the video element whenever the source changes, unless
   * manualCleanup is set to false.
   *
   * @param {Object} options
   *        Options to pass to {@link HTMLTrackElement} during creation. See
   *        {@link HTMLTrackElement} for object properties that you should use.
   *
   * @param {boolean} [manualCleanup=true] if set to false, the TextTrack will be
   *
   * @return {HtmlTrackElement}
   *         the HTMLTrackElement that was created and added
   *         to the HtmlTrackElementList and the remote
   *         TextTrackList
   *
   * @deprecated The default value of the "manualCleanup" parameter will default
   *             to "false" in upcoming versions of Video.js
   */


  Player.prototype.addRemoteTextTrack = function addRemoteTextTrack(options, manualCleanup) {
    if (this.tech_) {
      return this.tech_.addRemoteTextTrack(options, manualCleanup);
    }
  };

  /**
   * Remove a remote {@link TextTrack} from the respective
   * {@link TextTrackList} and {@link HtmlTrackElementList}.
   *
   * @param {Object} track
   *        Remote {@link TextTrack} to remove
   *
   * @return {undefined}
   *         does not return anything
   */


  Player.prototype.removeRemoteTextTrack = function removeRemoteTextTrack() {
    var _ref3 = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {},
        _ref3$track = _ref3.track,
        track = _ref3$track === undefined ? arguments[0] : _ref3$track;

    // destructure the input into an object with a track argument, defaulting to arguments[0]
    // default the whole argument to an empty object if nothing was passed in

    if (this.tech_) {
      return this.tech_.removeRemoteTextTrack(track);
    }
  };

  /**
   * Gets available media playback quality metrics as specified by the W3C's Media
   * Playback Quality API.
   *
   * @see [Spec]{@link https://wicg.github.io/media-playback-quality}
   *
   * @return {Object|undefined}
   *         An object with supported media playback quality metrics or undefined if there
   *         is no tech or the tech does not support it.
   */


  Player.prototype.getVideoPlaybackQuality = function getVideoPlaybackQuality() {
    return this.techGet_('getVideoPlaybackQuality');
  };

  /**
   * Get video width
   *
   * @return {number}
   *         current video width
   */


  Player.prototype.videoWidth = function videoWidth() {
    return this.tech_ && this.tech_.videoWidth && this.tech_.videoWidth() || 0;
  };

  /**
   * Get video height
   *
   * @return {number}
   *         current video height
   */


  Player.prototype.videoHeight = function videoHeight() {
    return this.tech_ && this.tech_.videoHeight && this.tech_.videoHeight() || 0;
  };

  /**
   * The player's language code
   * NOTE: The language should be set in the player options if you want the
   * the controls to be built with a specific language. Changing the lanugage
   * later will not update controls text.
   *
   * @param {string} [code]
   *        the language code to set the player to
   *
   * @return {string}
   *         The current language code when getting
   */


  Player.prototype.language = function language(code) {
    if (code === undefined) {
      return this.language_;
    }

    this.language_ = String(code).toLowerCase();
  };

  /**
   * Get the player's language dictionary
   * Merge every time, because a newly added plugin might call videojs.addLanguage() at any time
   * Languages specified directly in the player options have precedence
   *
   * @return {Array}
   *         An array of of supported languages
   */


  Player.prototype.languages = function languages() {
    return mergeOptions(Player.prototype.options_.languages, this.languages_);
  };

  /**
   * returns a JavaScript object reperesenting the current track
   * information. **DOES not return it as JSON**
   *
   * @return {Object}
   *         Object representing the current of track info
   */


  Player.prototype.toJSON = function toJSON() {
    var options = mergeOptions(this.options_);
    var tracks = options.tracks;

    options.tracks = [];

    for (var i = 0; i < tracks.length; i++) {
      var track = tracks[i];

      // deep merge tracks and null out player so no circular references
      track = mergeOptions(track);
      track.player = undefined;
      options.tracks[i] = track;
    }

    return options;
  };

  /**
   * Creates a simple modal dialog (an instance of the {@link ModalDialog}
   * component) that immediately overlays the player with arbitrary
   * content and removes itself when closed.
   *
   * @param {string|Function|Element|Array|null} content
   *        Same as {@link ModalDialog#content}'s param of the same name.
   *        The most straight-forward usage is to provide a string or DOM
   *        element.
   *
   * @param {Object} [options]
   *        Extra options which will be passed on to the {@link ModalDialog}.
   *
   * @return {ModalDialog}
   *         the {@link ModalDialog} that was created
   */


  Player.prototype.createModal = function createModal(content, options) {
    var _this12 = this;

    options = options || {};
    options.content = content || '';

    var modal = new ModalDialog(this, options);

    this.addChild(modal);
    modal.on('dispose', function () {
      _this12.removeChild(modal);
    });

    modal.open();
    return modal;
  };

  /**
   * Gets tag settings
   *
   * @param {Element} tag
   *        The player tag
   *
   * @return {Object}
   *         An object containing all of the settings
   *         for a player tag
   */


  Player.getTagSettings = function getTagSettings(tag) {
    var baseOptions = {
      sources: [],
      tracks: []
    };

    var tagOptions = getAttributes(tag);
    var dataSetup = tagOptions['data-setup'];

    if (hasClass(tag, 'vjs-fluid')) {
      tagOptions.fluid = true;
    }

    // Check if data-setup attr exists.
    if (dataSetup !== null) {
      // Parse options JSON
      // If empty string, make it a parsable json object.
      var _safeParseTuple = tuple(dataSetup || '{}'),
          err = _safeParseTuple[0],
          data = _safeParseTuple[1];

      if (err) {
        log$1.error(err);
      }
      assign(tagOptions, data);
    }

    assign(baseOptions, tagOptions);

    // Get tag children settings
    if (tag.hasChildNodes()) {
      var children = tag.childNodes;

      for (var i = 0, j = children.length; i < j; i++) {
        var child = children[i];
        // Change case needed: http://ejohn.org/blog/nodename-case-sensitivity/
        var childName = child.nodeName.toLowerCase();

        if (childName === 'source') {
          baseOptions.sources.push(getAttributes(child));
        } else if (childName === 'track') {
          baseOptions.tracks.push(getAttributes(child));
        }
      }
    }

    return baseOptions;
  };

  /**
   * Determine wether or not flexbox is supported
   *
   * @return {boolean}
   *         - true if flexbox is supported
   *         - false if flexbox is not supported
   */


  Player.prototype.flexNotSupported_ = function flexNotSupported_() {
    var elem = document_1.createElement('i');

    // Note: We don't actually use flexBasis (or flexOrder), but it's one of the more
    // common flex features that we can rely on when checking for flex support.
    return !('flexBasis' in elem.style || 'webkitFlexBasis' in elem.style || 'mozFlexBasis' in elem.style || 'msFlexBasis' in elem.style ||
    // IE10-specific (2012 flex spec)
    'msFlexOrder' in elem.style);
  };

  return Player;
}(Component);

/**
 * Get the {@link VideoTrackList}
 * @link https://html.spec.whatwg.org/multipage/embedded-content.html#videotracklist
 *
 * @return {VideoTrackList}
 *         the current video track list
 *
 * @method Player.prototype.videoTracks
 */

/**
 * Get the {@link AudioTrackList}
 * @link https://html.spec.whatwg.org/multipage/embedded-content.html#audiotracklist
 *
 * @return {AudioTrackList}
 *         the current audio track list
 *
 * @method Player.prototype.audioTracks
 */

/**
 * Get the {@link TextTrackList}
 *
 * @link http://www.w3.org/html/wg/drafts/html/master/embedded-content-0.html#dom-media-texttracks
 *
 * @return {TextTrackList}
 *         the current text track list
 *
 * @method Player.prototype.textTracks
 */

/**
 * Get the remote {@link TextTrackList}
 *
 * @return {TextTrackList}
 *         The current remote text track list
 *
 * @method Player.prototype.remoteTextTracks
 */

/**
 * Get the remote {@link HtmlTrackElementList} tracks.
 *
 * @return {HtmlTrackElementList}
 *         The current remote text track element list
 *
 * @method Player.prototype.remoteTextTrackEls
 */

ALL.names.forEach(function (name$$1) {
  var props = ALL[name$$1];

  Player.prototype[props.getterName] = function () {
    if (this.tech_) {
      return this.tech_[props.getterName]();
    }

    // if we have not yet loadTech_, we create {video,audio,text}Tracks_
    // these will be passed to the tech during loading
    this[props.privateName] = this[props.privateName] || new props.ListClass();
    return this[props.privateName];
  };
});

/**
 * Global player list
 *
 * @type {Object}
 */
Player.players = {};

var navigator$1 = window_1.navigator;

/*
 * Player instance options, surfaced using options
 * options = Player.prototype.options_
 * Make changes in options, not here.
 *
 * @type {Object}
 * @private
 */
Player.prototype.options_ = {
  // Default order of fallback technology
  techOrder: Tech.defaultTechOrder_,

  html5: {},
  flash: {},

  // default inactivity timeout
  inactivityTimeout: 2000,

  // default playback rates
  playbackRates: [],
  // Add playback rate selection by adding rates
  // 'playbackRates': [0.5, 1, 1.5, 2],

  // Included control sets
  children: ['mediaLoader', 'posterImage', 'textTrackDisplay', 'loadingSpinner', 'bigPlayButton', 'controlBar', 'errorDisplay', 'textTrackSettings'],

  language: navigator$1 && (navigator$1.languages && navigator$1.languages[0] || navigator$1.userLanguage || navigator$1.language) || 'en',

  // locales and their language translations
  languages: {},

  // Default message to show when a video cannot be played.
  notSupportedMessage: 'No compatible source was found for this media.'
};

if (!IS_IE8) {
  Player.prototype.options_.children.push('resizeManager');
}

[
/**
 * Returns whether or not the player is in the "ended" state.
 *
 * @return {Boolean} True if the player is in the ended state, false if not.
 * @method Player#ended
 */
'ended',
/**
 * Returns whether or not the player is in the "seeking" state.
 *
 * @return {Boolean} True if the player is in the seeking state, false if not.
 * @method Player#seeking
 */
'seeking',
/**
 * Returns the TimeRanges of the media that are currently available
 * for seeking to.
 *
 * @return {TimeRanges} the seekable intervals of the media timeline
 * @method Player#seekable
 */
'seekable',
/**
 * Returns the current state of network activity for the element, from
 * the codes in the list below.
 * - NETWORK_EMPTY (numeric value 0)
 *   The element has not yet been initialised. All attributes are in
 *   their initial states.
 * - NETWORK_IDLE (numeric value 1)
 *   The element's resource selection algorithm is active and has
 *   selected a resource, but it is not actually using the network at
 *   this time.
 * - NETWORK_LOADING (numeric value 2)
 *   The user agent is actively trying to download data.
 * - NETWORK_NO_SOURCE (numeric value 3)
 *   The element's resource selection algorithm is active, but it has
 *   not yet found a resource to use.
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#network-states
 * @return {number} the current network activity state
 * @method Player#networkState
 */
'networkState',
/**
 * Returns a value that expresses the current state of the element
 * with respect to rendering the current playback position, from the
 * codes in the list below.
 * - HAVE_NOTHING (numeric value 0)
 *   No information regarding the media resource is available.
 * - HAVE_METADATA (numeric value 1)
 *   Enough of the resource has been obtained that the duration of the
 *   resource is available.
 * - HAVE_CURRENT_DATA (numeric value 2)
 *   Data for the immediate current playback position is available.
 * - HAVE_FUTURE_DATA (numeric value 3)
 *   Data for the immediate current playback position is available, as
 *   well as enough data for the user agent to advance the current
 *   playback position in the direction of playback.
 * - HAVE_ENOUGH_DATA (numeric value 4)
 *   The user agent estimates that enough data is available for
 *   playback to proceed uninterrupted.
 *
 * @see https://html.spec.whatwg.org/multipage/embedded-content.html#dom-media-readystate
 * @return {number} the current playback rendering state
 * @method Player#readyState
 */
'readyState'].forEach(function (fn) {
  Player.prototype[fn] = function () {
    return this.techGet_(fn);
  };
});

TECH_EVENTS_RETRIGGER.forEach(function (event) {
  Player.prototype['handleTech' + toTitleCase(event) + '_'] = function () {
    return this.trigger(event);
  };
});

/**
 * Fired when the player has initial duration and dimension information
 *
 * @event Player#loadedmetadata
 * @type {EventTarget~Event}
 */

/**
 * Fired when the player has downloaded data at the current playback position
 *
 * @event Player#loadeddata
 * @type {EventTarget~Event}
 */

/**
 * Fired when the current playback position has changed *
 * During playback this is fired every 15-250 milliseconds, depending on the
 * playback technology in use.
 *
 * @event Player#timeupdate
 * @type {EventTarget~Event}
 */

/**
 * Fired when the volume changes
 *
 * @event Player#volumechange
 * @type {EventTarget~Event}
 */

/**
 * Reports whether or not a player has a plugin available.
 *
 * This does not report whether or not the plugin has ever been initialized
 * on this player. For that, [usingPlugin]{@link Player#usingPlugin}.
 *
 * @method Player#hasPlugin
 * @param  {string}  name
 *         The name of a plugin.
 *
 * @return {boolean}
 *         Whether or not this player has the requested plugin available.
 */

/**
 * Reports whether or not a player is using a plugin by name.
 *
 * For basic plugins, this only reports whether the plugin has _ever_ been
 * initialized on this player.
 *
 * @method Player#usingPlugin
 * @param  {string} name
 *         The name of a plugin.
 *
 * @return {boolean}
 *         Whether or not this player is using the requested plugin.
 */

Component.registerComponent('Player', Player);

/**
 * @file plugin.js
 */
/**
 * The base plugin name.
 *
 * @private
 * @constant
 * @type {string}
 */
var BASE_PLUGIN_NAME = 'plugin';

/**
 * The key on which a player's active plugins cache is stored.
 *
 * @private
 * @constant
 * @type     {string}
 */
var PLUGIN_CACHE_KEY = 'activePlugins_';

/**
 * Stores registered plugins in a private space.
 *
 * @private
 * @type    {Object}
 */
var pluginStorage = {};

/**
 * Reports whether or not a plugin has been registered.
 *
 * @private
 * @param   {string} name
 *          The name of a plugin.
 *
 * @returns {boolean}
 *          Whether or not the plugin has been registered.
 */
var pluginExists = function pluginExists(name) {
  return pluginStorage.hasOwnProperty(name);
};

/**
 * Get a single registered plugin by name.
 *
 * @private
 * @param   {string} name
 *          The name of a plugin.
 *
 * @returns {Function|undefined}
 *          The plugin (or undefined).
 */
var getPlugin = function getPlugin(name) {
  return pluginExists(name) ? pluginStorage[name] : undefined;
};

/**
 * Marks a plugin as "active" on a player.
 *
 * Also, ensures that the player has an object for tracking active plugins.
 *
 * @private
 * @param   {Player} player
 *          A Video.js player instance.
 *
 * @param   {string} name
 *          The name of a plugin.
 */
var markPluginAsActive = function markPluginAsActive(player, name) {
  player[PLUGIN_CACHE_KEY] = player[PLUGIN_CACHE_KEY] || {};
  player[PLUGIN_CACHE_KEY][name] = true;
};

/**
 * Triggers a pair of plugin setup events.
 *
 * @private
 * @param  {Player} player
 *         A Video.js player instance.
 *
 * @param  {Plugin~PluginEventHash} hash
 *         A plugin event hash.
 *
 * @param  {Boolean} [before]
 *         If true, prefixes the event name with "before". In other words,
 *         use this to trigger "beforepluginsetup" instead of "pluginsetup".
 */
var triggerSetupEvent = function triggerSetupEvent(player, hash, before) {
  var eventName = (before ? 'before' : '') + 'pluginsetup';

  player.trigger(eventName, hash);
  player.trigger(eventName + ':' + hash.name, hash);
};

/**
 * Takes a basic plugin function and returns a wrapper function which marks
 * on the player that the plugin has been activated.
 *
 * @private
 * @param   {string} name
 *          The name of the plugin.
 *
 * @param   {Function} plugin
 *          The basic plugin.
 *
 * @returns {Function}
 *          A wrapper function for the given plugin.
 */
var createBasicPlugin = function createBasicPlugin(name, plugin) {
  var basicPluginWrapper = function basicPluginWrapper() {

    // We trigger the "beforepluginsetup" and "pluginsetup" events on the player
    // regardless, but we want the hash to be consistent with the hash provided
    // for advanced plugins.
    //
    // The only potentially counter-intuitive thing here is the `instance` in
    // the "pluginsetup" event is the value returned by the `plugin` function.
    triggerSetupEvent(this, { name: name, plugin: plugin, instance: null }, true);

    var instance = plugin.apply(this, arguments);

    markPluginAsActive(this, name);
    triggerSetupEvent(this, { name: name, plugin: plugin, instance: instance });

    return instance;
  };

  Object.keys(plugin).forEach(function (prop) {
    basicPluginWrapper[prop] = plugin[prop];
  });

  return basicPluginWrapper;
};

/**
 * Takes a plugin sub-class and returns a factory function for generating
 * instances of it.
 *
 * This factory function will replace itself with an instance of the requested
 * sub-class of Plugin.
 *
 * @private
 * @param   {string} name
 *          The name of the plugin.
 *
 * @param   {Plugin} PluginSubClass
 *          The advanced plugin.
 *
 * @returns {Function}
 */
var createPluginFactory = function createPluginFactory(name, PluginSubClass) {

  // Add a `name` property to the plugin prototype so that each plugin can
  // refer to itself by name.
  PluginSubClass.prototype.name = name;

  return function () {
    triggerSetupEvent(this, { name: name, plugin: PluginSubClass, instance: null }, true);

    for (var _len = arguments.length, args = Array(_len), _key = 0; _key < _len; _key++) {
      args[_key] = arguments[_key];
    }

    var instance = new (Function.prototype.bind.apply(PluginSubClass, [null].concat([this].concat(args))))();

    // The plugin is replaced by a function that returns the current instance.
    this[name] = function () {
      return instance;
    };

    triggerSetupEvent(this, instance.getEventHash());

    return instance;
  };
};

/**
 * Parent class for all advanced plugins.
 *
 * @mixes   module:evented~EventedMixin
 * @mixes   module:stateful~StatefulMixin
 * @fires   Player#beforepluginsetup
 * @fires   Player#beforepluginsetup:$name
 * @fires   Player#pluginsetup
 * @fires   Player#pluginsetup:$name
 * @listens Player#dispose
 * @throws  {Error}
 *          If attempting to instantiate the base {@link Plugin} class
 *          directly instead of via a sub-class.
 */

var Plugin = function () {

  /**
   * Creates an instance of this class.
   *
   * Sub-classes should call `super` to ensure plugins are properly initialized.
   *
   * @param {Player} player
   *        A Video.js player instance.
   */
  function Plugin(player) {
    classCallCheck(this, Plugin);

    if (this.constructor === Plugin) {
      throw new Error('Plugin must be sub-classed; not directly instantiated.');
    }

    this.player = player;

    // Make this object evented, but remove the added `trigger` method so we
    // use the prototype version instead.
    evented(this);
    delete this.trigger;

    stateful(this, this.constructor.defaultState);
    markPluginAsActive(player, this.name);

    // Auto-bind the dispose method so we can use it as a listener and unbind
    // it later easily.
    this.dispose = bind(this, this.dispose);

    // If the player is disposed, dispose the plugin.
    player.on('dispose', this.dispose);
  }

  /**
   * Get the version of the plugin that was set on <pluginName>.VERSION
   */


  Plugin.prototype.version = function version() {
    return this.constructor.VERSION;
  };

  /**
   * Each event triggered by plugins includes a hash of additional data with
   * conventional properties.
   *
   * This returns that object or mutates an existing hash.
   *
   * @param   {Object} [hash={}]
   *          An object to be used as event an event hash.
   *
   * @returns {Plugin~PluginEventHash}
   *          An event hash object with provided properties mixed-in.
   */


  Plugin.prototype.getEventHash = function getEventHash() {
    var hash = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};

    hash.name = this.name;
    hash.plugin = this.constructor;
    hash.instance = this;
    return hash;
  };

  /**
   * Triggers an event on the plugin object and overrides
   * {@link module:evented~EventedMixin.trigger|EventedMixin.trigger}.
   *
   * @param   {string|Object} event
   *          An event type or an object with a type property.
   *
   * @param   {Object} [hash={}]
   *          Additional data hash to merge with a
   *          {@link Plugin~PluginEventHash|PluginEventHash}.
   *
   * @returns {boolean}
   *          Whether or not default was prevented.
   */


  Plugin.prototype.trigger = function trigger$$1(event) {
    var hash = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};

    return trigger(this.eventBusEl_, event, this.getEventHash(hash));
  };

  /**
   * Handles "statechanged" events on the plugin. No-op by default, override by
   * subclassing.
   *
   * @abstract
   * @param    {Event} e
   *           An event object provided by a "statechanged" event.
   *
   * @param    {Object} e.changes
   *           An object describing changes that occurred with the "statechanged"
   *           event.
   */


  Plugin.prototype.handleStateChanged = function handleStateChanged(e) {};

  /**
   * Disposes a plugin.
   *
   * Subclasses can override this if they want, but for the sake of safety,
   * it's probably best to subscribe the "dispose" event.
   *
   * @fires Plugin#dispose
   */


  Plugin.prototype.dispose = function dispose() {
    var name = this.name,
        player = this.player;

    /**
     * Signals that a advanced plugin is about to be disposed.
     *
     * @event Plugin#dispose
     * @type  {EventTarget~Event}
     */

    this.trigger('dispose');
    this.off();
    player.off('dispose', this.dispose);

    // Eliminate any possible sources of leaking memory by clearing up
    // references between the player and the plugin instance and nulling out
    // the plugin's state and replacing methods with a function that throws.
    player[PLUGIN_CACHE_KEY][name] = false;
    this.player = this.state = null;

    // Finally, replace the plugin name on the player with a new factory
    // function, so that the plugin is ready to be set up again.
    player[name] = createPluginFactory(name, pluginStorage[name]);
  };

  /**
   * Determines if a plugin is a basic plugin (i.e. not a sub-class of `Plugin`).
   *
   * @param   {string|Function} plugin
   *          If a string, matches the name of a plugin. If a function, will be
   *          tested directly.
   *
   * @returns {boolean}
   *          Whether or not a plugin is a basic plugin.
   */


  Plugin.isBasic = function isBasic(plugin) {
    var p = typeof plugin === 'string' ? getPlugin(plugin) : plugin;

    return typeof p === 'function' && !Plugin.prototype.isPrototypeOf(p.prototype);
  };

  /**
   * Register a Video.js plugin.
   *
   * @param   {string} name
   *          The name of the plugin to be registered. Must be a string and
   *          must not match an existing plugin or a method on the `Player`
   *          prototype.
   *
   * @param   {Function} plugin
   *          A sub-class of `Plugin` or a function for basic plugins.
   *
   * @returns {Function}
   *          For advanced plugins, a factory function for that plugin. For
   *          basic plugins, a wrapper function that initializes the plugin.
   */


  Plugin.registerPlugin = function registerPlugin(name, plugin) {
    if (typeof name !== 'string') {
      throw new Error('Illegal plugin name, "' + name + '", must be a string, was ' + (typeof name === 'undefined' ? 'undefined' : _typeof(name)) + '.');
    }

    if (pluginExists(name)) {
      log$1.warn('A plugin named "' + name + '" already exists. You may want to avoid re-registering plugins!');
    } else if (Player.prototype.hasOwnProperty(name)) {
      throw new Error('Illegal plugin name, "' + name + '", cannot share a name with an existing player method!');
    }

    if (typeof plugin !== 'function') {
      throw new Error('Illegal plugin for "' + name + '", must be a function, was ' + (typeof plugin === 'undefined' ? 'undefined' : _typeof(plugin)) + '.');
    }

    pluginStorage[name] = plugin;

    // Add a player prototype method for all sub-classed plugins (but not for
    // the base Plugin class).
    if (name !== BASE_PLUGIN_NAME) {
      if (Plugin.isBasic(plugin)) {
        Player.prototype[name] = createBasicPlugin(name, plugin);
      } else {
        Player.prototype[name] = createPluginFactory(name, plugin);
      }
    }

    return plugin;
  };

  /**
   * De-register a Video.js plugin.
   *
   * @param {string} name
   *        The name of the plugin to be deregistered.
   */


  Plugin.deregisterPlugin = function deregisterPlugin(name) {
    if (name === BASE_PLUGIN_NAME) {
      throw new Error('Cannot de-register base plugin.');
    }
    if (pluginExists(name)) {
      delete pluginStorage[name];
      delete Player.prototype[name];
    }
  };

  /**
   * Gets an object containing multiple Video.js plugins.
   *
   * @param   {Array} [names]
   *          If provided, should be an array of plugin names. Defaults to _all_
   *          plugin names.
   *
   * @returns {Object|undefined}
   *          An object containing plugin(s) associated with their name(s) or
   *          `undefined` if no matching plugins exist).
   */


  Plugin.getPlugins = function getPlugins() {
    var names = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : Object.keys(pluginStorage);

    var result = void 0;

    names.forEach(function (name) {
      var plugin = getPlugin(name);

      if (plugin) {
        result = result || {};
        result[name] = plugin;
      }
    });

    return result;
  };

  /**
   * Gets a plugin's version, if available
   *
   * @param   {string} name
   *          The name of a plugin.
   *
   * @returns {string}
   *          The plugin's version or an empty string.
   */


  Plugin.getPluginVersion = function getPluginVersion(name) {
    var plugin = getPlugin(name);

    return plugin && plugin.VERSION || '';
  };

  return Plugin;
}();

/**
 * Gets a plugin by name if it exists.
 *
 * @static
 * @method   getPlugin
 * @memberOf Plugin
 * @param    {string} name
 *           The name of a plugin.
 *
 * @returns  {Function|undefined}
 *           The plugin (or `undefined`).
 */


Plugin.getPlugin = getPlugin;

/**
 * The name of the base plugin class as it is registered.
 *
 * @type {string}
 */
Plugin.BASE_PLUGIN_NAME = BASE_PLUGIN_NAME;

Plugin.registerPlugin(BASE_PLUGIN_NAME, Plugin);

/**
 * Documented in player.js
 *
 * @ignore
 */
Player.prototype.usingPlugin = function (name) {
  return !!this[PLUGIN_CACHE_KEY] && this[PLUGIN_CACHE_KEY][name] === true;
};

/**
 * Documented in player.js
 *
 * @ignore
 */
Player.prototype.hasPlugin = function (name) {
  return !!pluginExists(name);
};

/**
 * Signals that a plugin is about to be set up on a player.
 *
 * @event    Player#beforepluginsetup
 * @type     {Plugin~PluginEventHash}
 */

/**
 * Signals that a plugin is about to be set up on a player - by name. The name
 * is the name of the plugin.
 *
 * @event    Player#beforepluginsetup:$name
 * @type     {Plugin~PluginEventHash}
 */

/**
 * Signals that a plugin has just been set up on a player.
 *
 * @event    Player#pluginsetup
 * @type     {Plugin~PluginEventHash}
 */

/**
 * Signals that a plugin has just been set up on a player - by name. The name
 * is the name of the plugin.
 *
 * @event    Player#pluginsetup:$name
 * @type     {Plugin~PluginEventHash}
 */

/**
 * @typedef  {Object} Plugin~PluginEventHash
 *
 * @property {string} instance
 *           For basic plugins, the return value of the plugin function. For
 *           advanced plugins, the plugin instance on which the event is fired.
 *
 * @property {string} name
 *           The name of the plugin.
 *
 * @property {string} plugin
 *           For basic plugins, the plugin function. For advanced plugins, the
 *           plugin class/constructor.
 */

/**
 * @file extend.js
 * @module extend
 */

/**
 * A combination of node inherits and babel's inherits (after transpile).
 * Both work the same but node adds `super_` to the subClass
 * and Bable adds the superClass as __proto__. Both seem useful.
 *
 * @param {Object} subClass
 *        The class to inherit to
 *
 * @param {Object} superClass
 *        The class to inherit from
 *
 * @private
 */
var _inherits = function _inherits(subClass, superClass) {
  if (typeof superClass !== 'function' && superClass !== null) {
    throw new TypeError('Super expression must either be null or a function, not ' + (typeof superClass === 'undefined' ? 'undefined' : _typeof(superClass)));
  }

  subClass.prototype = Object.create(superClass && superClass.prototype, {
    constructor: {
      value: subClass,
      enumerable: false,
      writable: true,
      configurable: true
    }
  });

  if (superClass) {
    // node
    subClass.super_ = superClass;
  }
};

/**
 * Function for subclassing using the same inheritance that
 * videojs uses internally
 *
 * @static
 * @const
 *
 * @param {Object} superClass
 *        The class to inherit from
 *
 * @param {Object} [subClassMethods={}]
 *        The class to inherit to
 *
 * @return {Object}
 *         The new object with subClassMethods that inherited superClass.
 */
var extendFn = function extendFn(superClass) {
  var subClassMethods = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : {};

  var subClass = function subClass() {
    superClass.apply(this, arguments);
  };

  var methods = {};

  if ((typeof subClassMethods === 'undefined' ? 'undefined' : _typeof(subClassMethods)) === 'object') {
    if (subClassMethods.constructor !== Object.prototype.constructor) {
      subClass = subClassMethods.constructor;
    }
    methods = subClassMethods;
  } else if (typeof subClassMethods === 'function') {
    subClass = subClassMethods;
  }

  _inherits(subClass, superClass);

  // Extend subObj's prototype with functions and other properties from props
  for (var name in methods) {
    if (methods.hasOwnProperty(name)) {
      subClass.prototype[name] = methods[name];
    }
  }

  return subClass;
};

/**
 * @file video.js
 * @module videojs
 */
// Include the built-in techs
// HTML5 Element Shim for IE8
if (typeof HTMLVideoElement === 'undefined' && isReal()) {
  document_1.createElement('video');
  document_1.createElement('audio');
  document_1.createElement('track');
  document_1.createElement('video-js');
}

/**
 * Normalize an `id` value by trimming off a leading `#`
 *
 * @param   {string} id
 *          A string, maybe with a leading `#`.
 *
 * @returns {string}
 *          The string, without any leading `#`.
 */
var normalizeId = function normalizeId(id) {
  return id.indexOf('#') === 0 ? id.slice(1) : id;
};

/**
 * Doubles as the main function for users to create a player instance and also
 * the main library object.
 * The `videojs` function can be used to initialize or retrieve a player.
  *
 * @param {string|Element} id
 *        Video element or video element ID
 *
 * @param {Object} [options]
 *        Optional options object for config/settings
 *
 * @param {Component~ReadyCallback} [ready]
 *        Optional ready callback
 *
 * @return {Player}
 *         A player instance
 */
function videojs(id, options, ready) {
  var player = videojs.getPlayer(id);

  if (player) {
    if (options) {
      log$1.warn('Player "' + id + '" is already initialised. Options will not be applied.');
    }
    if (ready) {
      player.ready(ready);
    }
    return player;
  }

  var el = typeof id === 'string' ? $('#' + normalizeId(id)) : id;

  if (!isEl(el)) {
    throw new TypeError('The element or ID supplied is not valid. (videojs)');
  }

  if (!document_1.body.contains(el)) {
    log$1.warn('The element supplied is not included in the DOM');
  }

  options = options || {};

  videojs.hooks('beforesetup').forEach(function (hookFunction) {
    var opts = hookFunction(el, mergeOptions(options));

    if (!isObject(opts) || Array.isArray(opts)) {
      log$1.error('please return an object in beforesetup hooks');
      return;
    }

    options = mergeOptions(options, opts);
  });

  // We get the current "Player" component here in case an integration has
  // replaced it with a custom player.
  var PlayerComponent = Component.getComponent('Player');

  player = new PlayerComponent(el, options, ready);

  videojs.hooks('setup').forEach(function (hookFunction) {
    return hookFunction(player);
  });

  return player;
}

/**
 * An Object that contains lifecycle hooks as keys which point to an array
 * of functions that are run when a lifecycle is triggered
 */
videojs.hooks_ = {};

/**
 * Get a list of hooks for a specific lifecycle
 * @function videojs.hooks
 *
 * @param {string} type
 *        the lifecyle to get hooks from
 *
 * @param {Function|Function[]} [fn]
 *        Optionally add a hook (or hooks) to the lifecycle that your are getting.
 *
 * @return {Array}
 *         an array of hooks, or an empty array if there are none.
 */
videojs.hooks = function (type, fn) {
  videojs.hooks_[type] = videojs.hooks_[type] || [];
  if (fn) {
    videojs.hooks_[type] = videojs.hooks_[type].concat(fn);
  }
  return videojs.hooks_[type];
};

/**
 * Add a function hook to a specific videojs lifecycle.
 *
 * @param {string} type
 *        the lifecycle to hook the function to.
 *
 * @param {Function|Function[]}
 *        The function or array of functions to attach.
 */
videojs.hook = function (type, fn) {
  videojs.hooks(type, fn);
};

/**
 * Add a function hook that will only run once to a specific videojs lifecycle.
 *
 * @param {string} type
 *        the lifecycle to hook the function to.
 *
 * @param {Function|Function[]}
 *        The function or array of functions to attach.
 */
videojs.hookOnce = function (type, fn) {
  videojs.hooks(type, [].concat(fn).map(function (original) {
    var wrapper = function wrapper() {
      videojs.removeHook(type, wrapper);
      return original.apply(undefined, arguments);
    };

    return wrapper;
  }));
};

/**
 * Remove a hook from a specific videojs lifecycle.
 *
 * @param {string} type
 *        the lifecycle that the function hooked to
 *
 * @param {Function} fn
 *        The hooked function to remove
 *
 * @return {boolean}
 *         The function that was removed or undef
 */
videojs.removeHook = function (type, fn) {
  var index = videojs.hooks(type).indexOf(fn);

  if (index <= -1) {
    return false;
  }

  videojs.hooks_[type] = videojs.hooks_[type].slice();
  videojs.hooks_[type].splice(index, 1);

  return true;
};

// Add default styles
if (window_1.VIDEOJS_NO_DYNAMIC_STYLE !== true && isReal()) {
  var style = $('.vjs-styles-defaults');

  if (!style) {
    style = createStyleElement('vjs-styles-defaults');
    var head = $('head');

    if (head) {
      head.insertBefore(style, head.firstChild);
    }
    setTextContent(style, '\n      .video-js {\n        width: 300px;\n        height: 150px;\n      }\n\n      .vjs-fluid {\n        padding-top: 56.25%\n      }\n    ');
  }
}

// Run Auto-load players
// You have to wait at least once in case this script is loaded after your
// video in the DOM (weird behavior only with minified version)
autoSetupTimeout(1, videojs);

/**
 * Current software version. Follows semver.
 *
 * @type {string}
 */
videojs.VERSION = version;

/**
 * The global options object. These are the settings that take effect
 * if no overrides are specified when the player is created.
 *
 * @type {Object}
 */
videojs.options = Player.prototype.options_;

/**
 * Get an object with the currently created players, keyed by player ID
 *
 * @return {Object}
 *         The created players
 */
videojs.getPlayers = function () {
  return Player.players;
};

/**
 * Get a single player based on an ID or DOM element.
 *
 * This is useful if you want to check if an element or ID has an associated
 * Video.js player, but not create one if it doesn't.
 *
 * @param   {string|Element} id
 *          An HTML element - `<video>`, `<audio>`, or `<video-js>` -
 *          or a string matching the `id` of such an element.
 *
 * @returns {Player|undefined}
 *          A player instance or `undefined` if there is no player instance
 *          matching the argument.
 */
videojs.getPlayer = function (id) {
  var players = Player.players;
  var tag = void 0;

  if (typeof id === 'string') {
    var nId = normalizeId(id);
    var player = players[nId];

    if (player) {
      return player;
    }

    tag = $('#' + nId);
  } else {
    tag = id;
  }

  if (isEl(tag)) {
    var _tag = tag,
        _player = _tag.player,
        playerId = _tag.playerId;

    // Element may have a `player` property referring to an already created
    // player instance. If so, return that.

    if (_player || players[playerId]) {
      return _player || players[playerId];
    }
  }
};

/**
 * Returns an array of all current players.
 *
 * @return {Array}
 *         An array of all players. The array will be in the order that
 *         `Object.keys` provides, which could potentially vary between
 *         JavaScript engines.
 *
 */
videojs.getAllPlayers = function () {
  return (

    // Disposed players leave a key with a `null` value, so we need to make sure
    // we filter those out.
    Object.keys(Player.players).map(function (k) {
      return Player.players[k];
    }).filter(Boolean)
  );
};

/**
 * Expose players object.
 *
 * @memberOf videojs
 * @property {Object} players
 */
videojs.players = Player.players;

/**
 * Get a component class object by name
 *
 * @borrows Component.getComponent as videojs.getComponent
 */
videojs.getComponent = Component.getComponent;

/**
 * Register a component so it can referred to by name. Used when adding to other
 * components, either through addChild `component.addChild('myComponent')` or through
 * default children options  `{ children: ['myComponent'] }`.
 *
 * > NOTE: You could also just initialize the component before adding.
 * `component.addChild(new MyComponent());`
 *
 * @param {string} name
 *        The class name of the component
 *
 * @param {Component} comp
 *        The component class
 *
 * @return {Component}
 *         The newly registered component
 */
videojs.registerComponent = function (name$$1, comp) {
  if (Tech.isTech(comp)) {
    log$1.warn('The ' + name$$1 + ' tech was registered as a component. It should instead be registered using videojs.registerTech(name, tech)');
  }

  Component.registerComponent.call(Component, name$$1, comp);
};

/**
 * Get a Tech class object by name
 *
 * @borrows Tech.getTech as videojs.getTech
 */
videojs.getTech = Tech.getTech;

/**
 * Register a Tech so it can referred to by name.
 * This is used in the tech order for the player.
 *
 * @borrows Tech.registerTech as videojs.registerTech
 */
videojs.registerTech = Tech.registerTech;

/**
 * Register a middleware to a source type.
 *
 * @param {String} type A string representing a MIME type.
 * @param {function(player):object} middleware A middleware factory that takes a player.
 */
videojs.use = use;

/**
 * An object that can be returned by a middleware to signify
 * that the middleware is being terminated.
 *
 * @type {object}
 * @memberOf {videojs}
 * @property {object} middleware.TERMINATOR
 */
// Object.defineProperty is not available in IE8
if (!IS_IE8 && Object.defineProperty) {
  Object.defineProperty(videojs, 'middleware', {
    value: {},
    writeable: false,
    enumerable: true
  });

  Object.defineProperty(videojs.middleware, 'TERMINATOR', {
    value: TERMINATOR,
    writeable: false,
    enumerable: true
  });
} else {
  videojs.middleware = { TERMINATOR: TERMINATOR };
}

/**
 * A suite of browser and device tests from {@link browser}.
 *
 * @type {Object}
 * @private
 */
videojs.browser = browser;

/**
 * Whether or not the browser supports touch events. Included for backward
 * compatibility with 4.x, but deprecated. Use `videojs.browser.TOUCH_ENABLED`
 * instead going forward.
 *
 * @deprecated since version 5.0
 * @type {boolean}
 */
videojs.TOUCH_ENABLED = TOUCH_ENABLED;

/**
 * Subclass an existing class
 * Mimics ES6 subclassing with the `extend` keyword
 *
 * @borrows extend:extendFn as videojs.extend
 */
videojs.extend = extendFn;

/**
 * Merge two options objects recursively
 * Performs a deep merge like lodash.merge but **only merges plain objects**
 * (not arrays, elements, anything else)
 * Other values will be copied directly from the second object.
 *
 * @borrows merge-options:mergeOptions as videojs.mergeOptions
 */
videojs.mergeOptions = mergeOptions;

/**
 * Change the context (this) of a function
 *
 * > NOTE: as of v5.0 we require an ES5 shim, so you should use the native
 * `function() {}.bind(newContext);` instead of this.
 *
 * @borrows fn:bind as videojs.bind
 */
videojs.bind = bind;

/**
 * Register a Video.js plugin.
 *
 * @borrows plugin:registerPlugin as videojs.registerPlugin
 * @method registerPlugin
 *
 * @param  {string} name
 *         The name of the plugin to be registered. Must be a string and
 *         must not match an existing plugin or a method on the `Player`
 *         prototype.
 *
 * @param  {Function} plugin
 *         A sub-class of `Plugin` or a function for basic plugins.
 *
 * @return {Function}
 *         For advanced plugins, a factory function for that plugin. For
 *         basic plugins, a wrapper function that initializes the plugin.
 */
videojs.registerPlugin = Plugin.registerPlugin;

/**
 * Deregister a Video.js plugin.
 *
 * @borrows plugin:deregisterPlugin as videojs.deregisterPlugin
 * @method deregisterPlugin
 *
 * @param  {string} name
 *         The name of the plugin to be deregistered. Must be a string and
 *         must match an existing plugin or a method on the `Player`
 *         prototype.
 *
 */
videojs.deregisterPlugin = Plugin.deregisterPlugin;

/**
 * Deprecated method to register a plugin with Video.js
 *
 * @deprecated
 *        videojs.plugin() is deprecated; use videojs.registerPlugin() instead
 *
 * @param {string} name
 *        The plugin name
 *
 * @param {Plugin|Function} plugin
 *         The plugin sub-class or function
 */
videojs.plugin = function (name$$1, plugin) {
  log$1.warn('videojs.plugin() is deprecated; use videojs.registerPlugin() instead');
  return Plugin.registerPlugin(name$$1, plugin);
};

/**
 * Gets an object containing multiple Video.js plugins.
 *
 * @param  {Array} [names]
 *         If provided, should be an array of plugin names. Defaults to _all_
 *         plugin names.
 *
 * @return {Object|undefined}
 *         An object containing plugin(s) associated with their name(s) or
 *         `undefined` if no matching plugins exist).
 */
videojs.getPlugins = Plugin.getPlugins;

/**
 * Gets a plugin by name if it exists.
 *
 * @param  {string} name
 *         The name of a plugin.
 *
 * @return {Function|undefined}
 *         The plugin (or `undefined`).
 */
videojs.getPlugin = Plugin.getPlugin;

/**
 * Gets a plugin's version, if available
 *
 * @param  {string} name
 *         The name of a plugin.
 *
 * @return {string}
 *         The plugin's version or an empty string.
 */
videojs.getPluginVersion = Plugin.getPluginVersion;

/**
 * Adding languages so that they're available to all players.
 * Example: `videojs.addLanguage('es', { 'Hello': 'Hola' });`
 *
 * @param {string} code
 *        The language code or dictionary property
 *
 * @param {Object} data
 *        The data values to be translated
 *
 * @return {Object}
 *         The resulting language dictionary object
 */
videojs.addLanguage = function (code, data) {
  var _mergeOptions;

  code = ('' + code).toLowerCase();

  videojs.options.languages = mergeOptions(videojs.options.languages, (_mergeOptions = {}, _mergeOptions[code] = data, _mergeOptions));

  return videojs.options.languages[code];
};

/**
 * Log messages
 *
 * @borrows log:log as videojs.log
 */
videojs.log = log$1;

/**
 * Creates an emulated TimeRange object.
 *
 * @borrows time-ranges:createTimeRanges as videojs.createTimeRange
 */
/**
 * @borrows time-ranges:createTimeRanges as videojs.createTimeRanges
 */
videojs.createTimeRange = videojs.createTimeRanges = createTimeRanges;

/**
 * Format seconds as a time string, H:MM:SS or M:SS
 * Supplying a guide (in seconds) will force a number of leading zeros
 * to cover the length of the guide
 *
 * @borrows format-time:formatTime as videojs.formatTime
 */
videojs.formatTime = formatTime;

/**
 * Replaces format-time with a custom implementation, to be used in place of the default.
 *
 * @borrows format-time:setFormatTime as videojs.setFormatTime
 *
 * @method setFormatTime
 *
 * @param {Function} customFn
 *        A custom format-time function which will be called with the current time and guide (in seconds) as arguments.
 *        Passed fn should return a string.
 */
videojs.setFormatTime = setFormatTime;

/**
 * Resets format-time to the default implementation.
 *
 * @borrows format-time:resetFormatTime as videojs.resetFormatTime
 *
 * @method resetFormatTime
 */
videojs.resetFormatTime = resetFormatTime;

/**
 * Resolve and parse the elements of a URL
 *
 * @borrows url:parseUrl as videojs.parseUrl
 *
 */
videojs.parseUrl = parseUrl;

/**
 * Returns whether the url passed is a cross domain request or not.
 *
 * @borrows url:isCrossOrigin as videojs.isCrossOrigin
 */
videojs.isCrossOrigin = isCrossOrigin;

/**
 * Event target class.
 *
 * @borrows EventTarget as videojs.EventTarget
 */
videojs.EventTarget = EventTarget;

/**
 * Add an event listener to element
 * It stores the handler function in a separate cache object
 * and adds a generic handler to the element's event,
 * along with a unique id (guid) to the element.
 *
 * @borrows events:on as videojs.on
 */
videojs.on = on;

/**
 * Trigger a listener only once for an event
 *
 * @borrows events:one as videojs.one
 */
videojs.one = one;

/**
 * Removes event listeners from an element
 *
 * @borrows events:off as videojs.off
 */
videojs.off = off;

/**
 * Trigger an event for an element
 *
 * @borrows events:trigger as videojs.trigger
 */
videojs.trigger = trigger;

/**
 * A cross-browser XMLHttpRequest wrapper. Here's a simple example:
 *
 * @param {Object} options
 *        settings for the request.
 *
 * @return {XMLHttpRequest|XDomainRequest}
 *         The request object.
 *
 * @see https://github.com/Raynos/xhr
 */
videojs.xhr = xhr;

/**
 * TextTrack class
 *
 * @borrows TextTrack as videojs.TextTrack
 */
videojs.TextTrack = TextTrack;

/**
 * export the AudioTrack class so that source handlers can create
 * AudioTracks and then add them to the players AudioTrackList
 *
 * @borrows AudioTrack as videojs.AudioTrack
 */
videojs.AudioTrack = AudioTrack;

/**
 * export the VideoTrack class so that source handlers can create
 * VideoTracks and then add them to the players VideoTrackList
 *
 * @borrows VideoTrack as videojs.VideoTrack
 */
videojs.VideoTrack = VideoTrack;

/**
 * Determines, via duck typing, whether or not a value is a DOM element.
 *
 * @borrows dom:isEl as videojs.isEl
 * @deprecated Use videojs.dom.isEl() instead
 */

/**
 * Determines, via duck typing, whether or not a value is a text node.
 *
 * @borrows dom:isTextNode as videojs.isTextNode
 * @deprecated Use videojs.dom.isTextNode() instead
 */

/**
 * Creates an element and applies properties.
 *
 * @borrows dom:createEl as videojs.createEl
 * @deprecated Use videojs.dom.createEl() instead
 */

/**
 * Check if an element has a CSS class
 *
 * @borrows dom:hasElClass as videojs.hasClass
 * @deprecated Use videojs.dom.hasClass() instead
 */

/**
 * Add a CSS class name to an element
 *
 * @borrows dom:addElClass as videojs.addClass
 * @deprecated Use videojs.dom.addClass() instead
 */

/**
 * Remove a CSS class name from an element
 *
 * @borrows dom:removeElClass as videojs.removeClass
 * @deprecated Use videojs.dom.removeClass() instead
 */

/**
 * Adds or removes a CSS class name on an element depending on an optional
 * condition or the presence/absence of the class name.
 *
 * @borrows dom:toggleElClass as videojs.toggleClass
 * @deprecated Use videojs.dom.toggleClass() instead
 */

/**
 * Apply attributes to an HTML element.
 *
 * @borrows dom:setElAttributes as videojs.setAttribute
 * @deprecated Use videojs.dom.setAttributes() instead
 */

/**
 * Get an element's attribute values, as defined on the HTML tag
 * Attributes are not the same as properties. They're defined on the tag
 * or with setAttribute (which shouldn't be used with HTML)
 * This will return true or false for boolean attributes.
 *
 * @borrows dom:getElAttributes as videojs.getAttributes
 * @deprecated Use videojs.dom.getAttributes() instead
 */

/**
 * Empties the contents of an element.
 *
 * @borrows dom:emptyEl as videojs.emptyEl
 * @deprecated Use videojs.dom.emptyEl() instead
 */

/**
 * Normalizes and appends content to an element.
 *
 * The content for an element can be passed in multiple types and
 * combinations, whose behavior is as follows:
 *
 * - String
 *   Normalized into a text node.
 *
 * - Element, TextNode
 *   Passed through.
 *
 * - Array
 *   A one-dimensional array of strings, elements, nodes, or functions (which
 *   return single strings, elements, or nodes).
 *
 * - Function
 *   If the sole argument, is expected to produce a string, element,
 *   node, or array.
 *
 * @borrows dom:appendContents as videojs.appendContet
 * @deprecated Use videojs.dom.appendContent() instead
 */

/**
 * Normalizes and inserts content into an element; this is identical to
 * `appendContent()`, except it empties the element first.
 *
 * The content for an element can be passed in multiple types and
 * combinations, whose behavior is as follows:
 *
 * - String
 *   Normalized into a text node.
 *
 * - Element, TextNode
 *   Passed through.
 *
 * - Array
 *   A one-dimensional array of strings, elements, nodes, or functions (which
 *   return single strings, elements, or nodes).
 *
 * - Function
 *   If the sole argument, is expected to produce a string, element,
 *   node, or array.
 *
 * @borrows dom:insertContent as videojs.insertContent
 * @deprecated Use videojs.dom.insertContent() instead
 */
['isEl', 'isTextNode', 'createEl', 'hasClass', 'addClass', 'removeClass', 'toggleClass', 'setAttributes', 'getAttributes', 'emptyEl', 'appendContent', 'insertContent'].forEach(function (k) {
  videojs[k] = function () {
    log$1.warn('videojs.' + k + '() is deprecated; use videojs.dom.' + k + '() instead');
    return Dom[k].apply(null, arguments);
  };
});

/**
 * A safe getComputedStyle with an IE8 fallback.
 *
 * This is because in Firefox, if the player is loaded in an iframe with `display:none`,
 * then `getComputedStyle` returns `null`, so, we do a null-check to make sure
 * that the player doesn't break in these cases.
 * See https://bugzilla.mozilla.org/show_bug.cgi?id=548397 for more details.
 *
 * @borrows computed-style:computedStyle as videojs.computedStyle
 */
videojs.computedStyle = computedStyle;

/**
 * Export the Dom utilities for use in external plugins
 * and Tech's
 */
videojs.dom = Dom;

/**
 * Export the Url utilities for use in external plugins
 * and Tech's
 */
videojs.url = Url;

return videojs;

})));
