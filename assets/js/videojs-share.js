/**
 * videojs-share
 * @version 2.0.1
 * @copyright 2018 Mikhail Khazov <mkhazov.work@gmail.com>
 * @license MIT
 */
(function (global, factory) {
	typeof exports === 'object' && typeof module !== 'undefined' ? module.exports = factory(require('video.js')) :
	typeof define === 'function' && define.amd ? define(['video.js'], factory) :
	(global.videojsShare = factory(global.videojs));
}(this, (function (videojs$1) { 'use strict';

videojs$1 = 'default' in videojs$1 ? videojs$1['default'] : videojs$1;

var version = "2.0.1";

var url = getUrl();

function getUrl() {
  return window.location.href;
}

function getRedirectUri() {
  return url + '#close_window';
}

function getEmbedCode() {
  return '<iframe src=\'' + url + '\' width=\'560\' height=\'315\' frameborder=\'0\' allowfullscreen></iframe>';
}

function getSocials() {
  return ['fbFeed', 'tw', 'reddit', 'gp', 'messenger', 'linkedin', 'vk', 'ok', 'mail', 'telegram', 'whatsapp', 'viber'];
}

var defaults = {
  mobileVerification: true,
  title: 'Video',
  url: url,
  socials: getSocials(),
  embedCode: getEmbedCode(),
  redirectUri: getRedirectUri()
};

var classCallCheck = function (instance, Constructor) {
  if (!(instance instanceof Constructor)) {
    throw new TypeError("Cannot call a class as a function");
  }
};

var createClass = function () {
  function defineProperties(target, props) {
    for (var i = 0; i < props.length; i++) {
      var descriptor = props[i];
      descriptor.enumerable = descriptor.enumerable || false;
      descriptor.configurable = true;
      if ("value" in descriptor) descriptor.writable = true;
      Object.defineProperty(target, descriptor.key, descriptor);
    }
  }

  return function (Constructor, protoProps, staticProps) {
    if (protoProps) defineProperties(Constructor.prototype, protoProps);
    if (staticProps) defineProperties(Constructor, staticProps);
    return Constructor;
  };
}();









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

var Button = videojs.getComponent('Button');

/**
 * Share button.
 */

var ShareButton = function (_Button) {
  inherits(ShareButton, _Button);

  function ShareButton(player, options) {
    classCallCheck(this, ShareButton);

    var _this = possibleConstructorReturn(this, _Button.call(this, player, options));

    _this.addClass('vjs-menu-button');
    _this.addClass('vjs-share-control');
    _this.addClass('vjs-icon-share');
    _this.controlText(player.localize('Share'));
    return _this;
  }

  ShareButton.prototype.handleClick = function handleClick() {
    this.player().getChild('ShareOverlay').open();
  };

  return ShareButton;
}(Button);

var ModalDialog = videojs.getComponent('ModalDialog');

/**
 * Share modal.
 */

var ShareModal = function (_ModalDialog) {
  inherits(ShareModal, _ModalDialog);

  function ShareModal(player, options) {
    classCallCheck(this, ShareModal);

    var _this = possibleConstructorReturn(this, _ModalDialog.call(this, player, options));

    _this.playerClassName = 'vjs-videojs-share_open';
    return _this;
  }

  ShareModal.prototype.open = function open() {
    var player = this.player();

    player.addClass(this.playerClassName);
    _ModalDialog.prototype.open.call(this);
    player.trigger('sharing:opened');
  };

  ShareModal.prototype.close = function close() {
    var player = this.player();

    player.removeClass(this.playerClassName);
    _ModalDialog.prototype.close.call(this);
    player.trigger('sharing:closed');
  };

  return ShareModal;
}(ModalDialog);

var commonjsGlobal = typeof window !== 'undefined' ? window : typeof global !== 'undefined' ? global : typeof self !== 'undefined' ? self : {};



function unwrapExports (x) {
	return x && x.__esModule ? x['default'] : x;
}

function createCommonjsModule(fn, module) {
	return module = { exports: {} }, fn(module, module.exports), module.exports;
}

function select(element) {
    var selectedText;

    if (element.nodeName === 'SELECT') {
        element.focus();

        selectedText = element.value;
    }
    else if (element.nodeName === 'INPUT' || element.nodeName === 'TEXTAREA') {
        var isReadOnly = element.hasAttribute('readonly');

        if (!isReadOnly) {
            element.setAttribute('readonly', '');
        }

        element.select();
        element.setSelectionRange(0, element.value.length);

        if (!isReadOnly) {
            element.removeAttribute('readonly');
        }

        selectedText = element.value;
    }
    else {
        if (element.hasAttribute('contenteditable')) {
            element.focus();
        }

        var selection = window.getSelection();
        var range = document.createRange();

        range.selectNodeContents(element);
        selection.removeAllRanges();
        selection.addRange(range);

        selectedText = selection.toString();
    }

    return selectedText;
}

var select_1 = select;

var clipboardAction = createCommonjsModule(function (module, exports) {
(function (global, factory) {
    if (typeof undefined === "function" && undefined.amd) {
        undefined(['module', 'select'], factory);
    } else {
        factory(module, select_1);
    }
})(commonjsGlobal, function (module, _select) {
    'use strict';

    var _select2 = _interopRequireDefault(_select);

    function _interopRequireDefault(obj) {
        return obj && obj.__esModule ? obj : {
            default: obj
        };
    }

    var _typeof = typeof Symbol === "function" && typeof Symbol.iterator === "symbol" ? function (obj) {
        return typeof obj;
    } : function (obj) {
        return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj;
    };

    function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
            throw new TypeError("Cannot call a class as a function");
        }
    }

    var _createClass = function () {
        function defineProperties(target, props) {
            for (var i = 0; i < props.length; i++) {
                var descriptor = props[i];
                descriptor.enumerable = descriptor.enumerable || false;
                descriptor.configurable = true;
                if ("value" in descriptor) descriptor.writable = true;
                Object.defineProperty(target, descriptor.key, descriptor);
            }
        }

        return function (Constructor, protoProps, staticProps) {
            if (protoProps) defineProperties(Constructor.prototype, protoProps);
            if (staticProps) defineProperties(Constructor, staticProps);
            return Constructor;
        };
    }();

    var ClipboardAction = function () {
        /**
         * @param {Object} options
         */
        function ClipboardAction(options) {
            _classCallCheck(this, ClipboardAction);

            this.resolveOptions(options);
            this.initSelection();
        }

        /**
         * Defines base properties passed from constructor.
         * @param {Object} options
         */


        _createClass(ClipboardAction, [{
            key: 'resolveOptions',
            value: function resolveOptions() {
                var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};

                this.action = options.action;
                this.container = options.container;
                this.emitter = options.emitter;
                this.target = options.target;
                this.text = options.text;
                this.trigger = options.trigger;

                this.selectedText = '';
            }
        }, {
            key: 'initSelection',
            value: function initSelection() {
                if (this.text) {
                    this.selectFake();
                } else if (this.target) {
                    this.selectTarget();
                }
            }
        }, {
            key: 'selectFake',
            value: function selectFake() {
                var _this = this;

                var isRTL = document.documentElement.getAttribute('dir') == 'rtl';

                this.removeFake();

                this.fakeHandlerCallback = function () {
                    return _this.removeFake();
                };
                this.fakeHandler = this.container.addEventListener('click', this.fakeHandlerCallback) || true;

                this.fakeElem = document.createElement('textarea');
                // Prevent zooming on iOS
                this.fakeElem.style.fontSize = '12pt';
                // Reset box model
                this.fakeElem.style.border = '0';
                this.fakeElem.style.padding = '0';
                this.fakeElem.style.margin = '0';
                // Move element out of screen horizontally
                this.fakeElem.style.position = 'absolute';
                this.fakeElem.style[isRTL ? 'right' : 'left'] = '-9999px';
                // Move element to the same position vertically
                var yPosition = window.pageYOffset || document.documentElement.scrollTop;
                this.fakeElem.style.top = yPosition + 'px';

                this.fakeElem.setAttribute('readonly', '');
                this.fakeElem.value = this.text;

                this.container.appendChild(this.fakeElem);

                this.selectedText = (0, _select2.default)(this.fakeElem);
                this.copyText();
            }
        }, {
            key: 'removeFake',
            value: function removeFake() {
                if (this.fakeHandler) {
                    this.container.removeEventListener('click', this.fakeHandlerCallback);
                    this.fakeHandler = null;
                    this.fakeHandlerCallback = null;
                }

                if (this.fakeElem) {
                    this.container.removeChild(this.fakeElem);
                    this.fakeElem = null;
                }
            }
        }, {
            key: 'selectTarget',
            value: function selectTarget() {
                this.selectedText = (0, _select2.default)(this.target);
                this.copyText();
            }
        }, {
            key: 'copyText',
            value: function copyText() {
                var succeeded = void 0;

                try {
                    succeeded = document.execCommand(this.action);
                } catch (err) {
                    succeeded = false;
                }

                this.handleResult(succeeded);
            }
        }, {
            key: 'handleResult',
            value: function handleResult(succeeded) {
                this.emitter.emit(succeeded ? 'success' : 'error', {
                    action: this.action,
                    text: this.selectedText,
                    trigger: this.trigger,
                    clearSelection: this.clearSelection.bind(this)
                });
            }
        }, {
            key: 'clearSelection',
            value: function clearSelection() {
                if (this.trigger) {
                    this.trigger.focus();
                }

                window.getSelection().removeAllRanges();
            }
        }, {
            key: 'destroy',
            value: function destroy() {
                this.removeFake();
            }
        }, {
            key: 'action',
            set: function set() {
                var action = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : 'copy';

                this._action = action;

                if (this._action !== 'copy' && this._action !== 'cut') {
                    throw new Error('Invalid "action" value, use either "copy" or "cut"');
                }
            },
            get: function get() {
                return this._action;
            }
        }, {
            key: 'target',
            set: function set(target) {
                if (target !== undefined) {
                    if (target && (typeof target === 'undefined' ? 'undefined' : _typeof(target)) === 'object' && target.nodeType === 1) {
                        if (this.action === 'copy' && target.hasAttribute('disabled')) {
                            throw new Error('Invalid "target" attribute. Please use "readonly" instead of "disabled" attribute');
                        }

                        if (this.action === 'cut' && (target.hasAttribute('readonly') || target.hasAttribute('disabled'))) {
                            throw new Error('Invalid "target" attribute. You can\'t cut text from elements with "readonly" or "disabled" attributes');
                        }

                        this._target = target;
                    } else {
                        throw new Error('Invalid "target" value, use a valid Element');
                    }
                }
            },
            get: function get() {
                return this._target;
            }
        }]);

        return ClipboardAction;
    }();

    module.exports = ClipboardAction;
});
});

function E () {
  // Keep this empty so it's easier to inherit from
  // (via https://github.com/lipsmack from https://github.com/scottcorgan/tiny-emitter/issues/3)
}

E.prototype = {
  on: function (name, callback, ctx) {
    var e = this.e || (this.e = {});

    (e[name] || (e[name] = [])).push({
      fn: callback,
      ctx: ctx
    });

    return this;
  },

  once: function (name, callback, ctx) {
    var self = this;
    function listener () {
      self.off(name, listener);
      callback.apply(ctx, arguments);
    }

    listener._ = callback;
    return this.on(name, listener, ctx);
  },

  emit: function (name) {
    var data = [].slice.call(arguments, 1);
    var evtArr = ((this.e || (this.e = {}))[name] || []).slice();
    var i = 0;
    var len = evtArr.length;

    for (i; i < len; i++) {
      evtArr[i].fn.apply(evtArr[i].ctx, data);
    }

    return this;
  },

  off: function (name, callback) {
    var e = this.e || (this.e = {});
    var evts = e[name];
    var liveEvents = [];

    if (evts && callback) {
      for (var i = 0, len = evts.length; i < len; i++) {
        if (evts[i].fn !== callback && evts[i].fn._ !== callback)
          liveEvents.push(evts[i]);
      }
    }

    // Remove event from queue to prevent memory leak
    // Suggested by https://github.com/lazd
    // Ref: https://github.com/scottcorgan/tiny-emitter/commit/c6ebfaa9bc973b33d110a84a307742b7cf94c953#commitcomment-5024910

    (liveEvents.length)
      ? e[name] = liveEvents
      : delete e[name];

    return this;
  }
};

var index = E;

var is = createCommonjsModule(function (module, exports) {
/**
 * Check if argument is a HTML element.
 *
 * @param {Object} value
 * @return {Boolean}
 */
exports.node = function(value) {
    return value !== undefined
        && value instanceof HTMLElement
        && value.nodeType === 1;
};

/**
 * Check if argument is a list of HTML elements.
 *
 * @param {Object} value
 * @return {Boolean}
 */
exports.nodeList = function(value) {
    var type = Object.prototype.toString.call(value);

    return value !== undefined
        && (type === '[object NodeList]' || type === '[object HTMLCollection]')
        && ('length' in value)
        && (value.length === 0 || exports.node(value[0]));
};

/**
 * Check if argument is a string.
 *
 * @param {Object} value
 * @return {Boolean}
 */
exports.string = function(value) {
    return typeof value === 'string'
        || value instanceof String;
};

/**
 * Check if argument is a function.
 *
 * @param {Object} value
 * @return {Boolean}
 */
exports.fn = function(value) {
    var type = Object.prototype.toString.call(value);

    return type === '[object Function]';
};
});

var DOCUMENT_NODE_TYPE = 9;

/**
 * A polyfill for Element.matches()
 */
if (typeof Element !== 'undefined' && !Element.prototype.matches) {
    var proto = Element.prototype;

    proto.matches = proto.matchesSelector ||
                    proto.mozMatchesSelector ||
                    proto.msMatchesSelector ||
                    proto.oMatchesSelector ||
                    proto.webkitMatchesSelector;
}

/**
 * Finds the closest parent that matches a selector.
 *
 * @param {Element} element
 * @param {String} selector
 * @return {Function}
 */
function closest (element, selector) {
    while (element && element.nodeType !== DOCUMENT_NODE_TYPE) {
        if (typeof element.matches === 'function' &&
            element.matches(selector)) {
          return element;
        }
        element = element.parentNode;
    }
}

var closest_1 = closest;

/**
 * Delegates event to a selector.
 *
 * @param {Element} element
 * @param {String} selector
 * @param {String} type
 * @param {Function} callback
 * @param {Boolean} useCapture
 * @return {Object}
 */
function _delegate(element, selector, type, callback, useCapture) {
    var listenerFn = listener.apply(this, arguments);

    element.addEventListener(type, listenerFn, useCapture);

    return {
        destroy: function() {
            element.removeEventListener(type, listenerFn, useCapture);
        }
    }
}

/**
 * Delegates event to a selector.
 *
 * @param {Element|String|Array} [elements]
 * @param {String} selector
 * @param {String} type
 * @param {Function} callback
 * @param {Boolean} useCapture
 * @return {Object}
 */
function delegate(elements, selector, type, callback, useCapture) {
    // Handle the regular Element usage
    if (typeof elements.addEventListener === 'function') {
        return _delegate.apply(null, arguments);
    }

    // Handle Element-less usage, it defaults to global delegation
    if (typeof type === 'function') {
        // Use `document` as the first parameter, then apply arguments
        // This is a short way to .unshift `arguments` without running into deoptimizations
        return _delegate.bind(null, document).apply(null, arguments);
    }

    // Handle Selector-based usage
    if (typeof elements === 'string') {
        elements = document.querySelectorAll(elements);
    }

    // Handle Array-like based usage
    return Array.prototype.map.call(elements, function (element) {
        return _delegate(element, selector, type, callback, useCapture);
    });
}

/**
 * Finds closest match and invokes callback.
 *
 * @param {Element} element
 * @param {String} selector
 * @param {String} type
 * @param {Function} callback
 * @return {Function}
 */
function listener(element, selector, type, callback) {
    return function(e) {
        e.delegateTarget = closest_1(e.target, selector);

        if (e.delegateTarget) {
            callback.call(element, e);
        }
    }
}

var delegate_1 = delegate;

/**
 * Validates all params and calls the right
 * listener function based on its target type.
 *
 * @param {String|HTMLElement|HTMLCollection|NodeList} target
 * @param {String} type
 * @param {Function} callback
 * @return {Object}
 */
function listen(target, type, callback) {
    if (!target && !type && !callback) {
        throw new Error('Missing required arguments');
    }

    if (!is.string(type)) {
        throw new TypeError('Second argument must be a String');
    }

    if (!is.fn(callback)) {
        throw new TypeError('Third argument must be a Function');
    }

    if (is.node(target)) {
        return listenNode(target, type, callback);
    }
    else if (is.nodeList(target)) {
        return listenNodeList(target, type, callback);
    }
    else if (is.string(target)) {
        return listenSelector(target, type, callback);
    }
    else {
        throw new TypeError('First argument must be a String, HTMLElement, HTMLCollection, or NodeList');
    }
}

/**
 * Adds an event listener to a HTML element
 * and returns a remove listener function.
 *
 * @param {HTMLElement} node
 * @param {String} type
 * @param {Function} callback
 * @return {Object}
 */
function listenNode(node, type, callback) {
    node.addEventListener(type, callback);

    return {
        destroy: function() {
            node.removeEventListener(type, callback);
        }
    }
}

/**
 * Add an event listener to a list of HTML elements
 * and returns a remove listener function.
 *
 * @param {NodeList|HTMLCollection} nodeList
 * @param {String} type
 * @param {Function} callback
 * @return {Object}
 */
function listenNodeList(nodeList, type, callback) {
    Array.prototype.forEach.call(nodeList, function(node) {
        node.addEventListener(type, callback);
    });

    return {
        destroy: function() {
            Array.prototype.forEach.call(nodeList, function(node) {
                node.removeEventListener(type, callback);
            });
        }
    }
}

/**
 * Add an event listener to a selector
 * and returns a remove listener function.
 *
 * @param {String} selector
 * @param {String} type
 * @param {Function} callback
 * @return {Object}
 */
function listenSelector(selector, type, callback) {
    return delegate_1(document.body, selector, type, callback);
}

var listen_1 = listen;

var clipboard = createCommonjsModule(function (module, exports) {
(function (global, factory) {
    if (typeof undefined === "function" && undefined.amd) {
        undefined(['module', './clipboard-action', 'tiny-emitter', 'good-listener'], factory);
    } else {
        factory(module, clipboardAction, index, listen_1);
    }
})(commonjsGlobal, function (module, _clipboardAction, _tinyEmitter, _goodListener) {
    'use strict';

    var _clipboardAction2 = _interopRequireDefault(_clipboardAction);

    var _tinyEmitter2 = _interopRequireDefault(_tinyEmitter);

    var _goodListener2 = _interopRequireDefault(_goodListener);

    function _interopRequireDefault(obj) {
        return obj && obj.__esModule ? obj : {
            default: obj
        };
    }

    var _typeof = typeof Symbol === "function" && typeof Symbol.iterator === "symbol" ? function (obj) {
        return typeof obj;
    } : function (obj) {
        return obj && typeof Symbol === "function" && obj.constructor === Symbol && obj !== Symbol.prototype ? "symbol" : typeof obj;
    };

    function _classCallCheck(instance, Constructor) {
        if (!(instance instanceof Constructor)) {
            throw new TypeError("Cannot call a class as a function");
        }
    }

    var _createClass = function () {
        function defineProperties(target, props) {
            for (var i = 0; i < props.length; i++) {
                var descriptor = props[i];
                descriptor.enumerable = descriptor.enumerable || false;
                descriptor.configurable = true;
                if ("value" in descriptor) descriptor.writable = true;
                Object.defineProperty(target, descriptor.key, descriptor);
            }
        }

        return function (Constructor, protoProps, staticProps) {
            if (protoProps) defineProperties(Constructor.prototype, protoProps);
            if (staticProps) defineProperties(Constructor, staticProps);
            return Constructor;
        };
    }();

    function _possibleConstructorReturn(self, call) {
        if (!self) {
            throw new ReferenceError("this hasn't been initialised - super() hasn't been called");
        }

        return call && (typeof call === "object" || typeof call === "function") ? call : self;
    }

    function _inherits(subClass, superClass) {
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
    }

    var Clipboard = function (_Emitter) {
        _inherits(Clipboard, _Emitter);

        /**
         * @param {String|HTMLElement|HTMLCollection|NodeList} trigger
         * @param {Object} options
         */
        function Clipboard(trigger, options) {
            _classCallCheck(this, Clipboard);

            var _this = _possibleConstructorReturn(this, (Clipboard.__proto__ || Object.getPrototypeOf(Clipboard)).call(this));

            _this.resolveOptions(options);
            _this.listenClick(trigger);
            return _this;
        }

        /**
         * Defines if attributes would be resolved using internal setter functions
         * or custom functions that were passed in the constructor.
         * @param {Object} options
         */


        _createClass(Clipboard, [{
            key: 'resolveOptions',
            value: function resolveOptions() {
                var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};

                this.action = typeof options.action === 'function' ? options.action : this.defaultAction;
                this.target = typeof options.target === 'function' ? options.target : this.defaultTarget;
                this.text = typeof options.text === 'function' ? options.text : this.defaultText;
                this.container = _typeof(options.container) === 'object' ? options.container : document.body;
            }
        }, {
            key: 'listenClick',
            value: function listenClick(trigger) {
                var _this2 = this;

                this.listener = (0, _goodListener2.default)(trigger, 'click', function (e) {
                    return _this2.onClick(e);
                });
            }
        }, {
            key: 'onClick',
            value: function onClick(e) {
                var trigger = e.delegateTarget || e.currentTarget;

                if (this.clipboardAction) {
                    this.clipboardAction = null;
                }

                this.clipboardAction = new _clipboardAction2.default({
                    action: this.action(trigger),
                    target: this.target(trigger),
                    text: this.text(trigger),
                    container: this.container,
                    trigger: trigger,
                    emitter: this
                });
            }
        }, {
            key: 'defaultAction',
            value: function defaultAction(trigger) {
                return getAttributeValue('action', trigger);
            }
        }, {
            key: 'defaultTarget',
            value: function defaultTarget(trigger) {
                var selector = getAttributeValue('target', trigger);

                if (selector) {
                    return document.querySelector(selector);
                }
            }
        }, {
            key: 'defaultText',
            value: function defaultText(trigger) {
                return getAttributeValue('text', trigger);
            }
        }, {
            key: 'destroy',
            value: function destroy() {
                this.listener.destroy();

                if (this.clipboardAction) {
                    this.clipboardAction.destroy();
                    this.clipboardAction = null;
                }
            }
        }], [{
            key: 'isSupported',
            value: function isSupported() {
                var action = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : ['copy', 'cut'];

                var actions = typeof action === 'string' ? [action] : action;
                var support = !!document.queryCommandSupported;

                actions.forEach(function (action) {
                    support = support && !!document.queryCommandSupported(action);
                });

                return support;
            }
        }]);

        return Clipboard;
    }(_tinyEmitter2.default);

    /**
     * Helper function to retrieve attribute value.
     * @param {String} suffix
     * @param {Element} element
     */
    function getAttributeValue(suffix, element) {
        var attribute = 'data-clipboard-' + suffix;

        if (!element.hasAttribute(attribute)) {
            return;
        }

        return element.getAttribute(attribute);
    }

    module.exports = Clipboard;
});
});

var Clipboard = unwrapExports(clipboard);

var WIN_PARAMS = 'scrollbars=0, resizable=1, menubar=0, left=100, top=100, width=550, height=440, toolbar=0, status=0'; // eslint-disable-line import/prefer-default-export

function encodeParams(obj) {
  return Object.keys(obj).filter(function (k) {
    return typeof obj[k] !== 'undefined' && obj[k] !== '';
  }).map(function (k) {
    return encodeURIComponent(k) + '=' + encodeURIComponent(obj[k]);
  }).join('&');
}

function fbFeed() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var fbAppId = options.fbAppId,
      url = options.url,
      redirectUri = options.redirectUri;


  if (!fbAppId) {
    throw new Error('fbAppId is not defined');
  }

  var params = encodeParams({
    app_id: fbAppId,
    display: 'popup',
    redirect_uri: redirectUri,
    link: url
  });

  return window.open('https://www.facebook.com/dialog/feed?' + params, '_blank', WIN_PARAMS);
}

function fbShare() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var fbAppId = options.fbAppId,
      url = options.url,
      hashtag = options.hashtag,
      redirectUri = options.redirectUri;


  if (!fbAppId) {
    throw new Error('fbAppId is not defined');
  }

  var params = encodeParams({
    app_id: fbAppId,
    display: 'popup',
    redirect_uri: redirectUri,
    href: url,
    hashtag: hashtag
  });

  return window.open('https://www.facebook.com/dialog/share?' + params, '_blank', WIN_PARAMS);
}

function fbButton() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url;


  if (!url) {
    throw new Error('url is not defined');
  }

  var params = encodeParams({
    kid_directed_site: '0',
    sdk: 'joey',
    u: url,
    display: 'popup',
    ref: 'plugin',
    src: 'share_button'
  });

  return window.open('https://www.facebook.com/sharer/sharer.php?' + params, '_blank', WIN_PARAMS);
}

function gp() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url;


  var params = encodeParams({ url: url });

  return window.open('https://plus.google.com/share?' + params, '_blank', WIN_PARAMS);
}

function mail() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title,
      description = options.description,
      image = options.image;


  var params = encodeParams({
    share_url: url,
    title: title,
    description: description,
    imageurl: image
  });

  return window.open('http://connect.mail.ru/share?' + params, '_blank', WIN_PARAMS);
}

function email() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title,
      description = options.description;


  var body = (title || '') + '\r\n' + (description || '') + '\r\n' + (url || '');
  var uri = 'mailto:?body=' + encodeURIComponent(body);
  return window.location.assign(uri);
}

function ok() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title;


  var params = encodeParams({
    'st.cmd': 'addShare',
    'st._surl': url,
    title: title
  });

  return window.open('https://ok.ru/dk?' + params, '_blank', WIN_PARAMS);
}

function telegram() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title;


  var params = encodeParams({
    url: url,
    text: title
  });

  return window.open('https://t.me/share/url?' + params, '_blank', WIN_PARAMS);
}

function tw() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var title = options.title,
      url = options.url,
      _options$hashtags = options.hashtags,
      hashtags = _options$hashtags === undefined ? [] : _options$hashtags;


  var params = encodeParams({
    text: title,
    url: url,
    hashtags: hashtags.join(',')
  });

  return window.open('https://twitter.com/intent/tweet?' + params, '_blank', WIN_PARAMS);
}

function reddit() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title;

  var params = encodeParams({ url: url, title: title });

  return window.open('https://www.reddit.com/submit?' + params, '_blank', WIN_PARAMS);
}

function pinterest() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var description = options.description,
      url = options.url,
      media = options.media;


  var params = encodeParams({ url: url, description: description, media: media });

  return window.open('https://pinterest.com/pin/create/button/?' + params, '_blank', WIN_PARAMS);
}

function tumblr() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title,
      caption = options.caption,
      _options$tags = options.tags,
      tags = _options$tags === undefined ? [] : _options$tags,
      _options$posttype = options.posttype,
      posttype = _options$posttype === undefined ? 'link' : _options$posttype;


  var params = encodeParams({
    canonicalUrl: url,
    title: title,
    caption: caption,
    tags: tags.join(','),
    posttype: posttype
  });

  return window.open('https://www.tumblr.com/widgets/share/tool?' + params, '_blank', WIN_PARAMS);
}

function isMobileSafari() {
  return !!window.navigator.userAgent.match(/Version\/[\d.]+.*Safari/);
}

function mobileShare(link) {
  return isMobileSafari() ? window.open(link) : window.location.assign(link);
}

function viber() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      title = options.title;

  if (!url && !title) {
    throw new Error('url and title not specified');
  }

  var params = encodeParams({
    text: [title, url].filter(function (item) {
      return item;
    }).join(' ')
  });

  return mobileShare('viber://forward?' + params);
}

var VK_MAX_LENGTH = 80;

function getUrl$1() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var url = options.url,
      image = options.image,
      isVkParse = options.isVkParse;
  var description = options.description,
      title = options.title;


  if (description && description.length > VK_MAX_LENGTH) {
    description = description.substr(0, VK_MAX_LENGTH) + '...';
  }

  if (title && title.length > VK_MAX_LENGTH) {
    title = title.substr(0, VK_MAX_LENGTH) + '...';
  }

  var params = void 0;
  if (isVkParse) {
    params = encodeParams({ url: url });
  } else {
    params = encodeParams({
      url: url, title: title, description: description, image: image, noparse: true
    });
  }

  return 'https://vk.com/share.php?' + params;
}

function share() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};

  return window.open(getUrl$1(options), '_blank', WIN_PARAMS);
}

function whatsapp() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var phone = options.phone,
      title = options.title,
      url = options.url;


  var params = encodeParams({
    text: [title, url].filter(function (item) {
      return item;
    }).join(' '),
    phone: phone
  });

  return window.open('https://api.whatsapp.com/send?' + params, '_blank', WIN_PARAMS);
}

function linkedin() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var title = options.title,
      url = options.url,
      description = options.description;


  var params = encodeParams({
    title: title,
    summary: description,
    url: url
  });

  return window.open('https://www.linkedin.com/shareArticle?mini=true&' + params, '_blank', WIN_PARAMS);
}

function messenger() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var fbAppId = options.fbAppId,
      url = options.url;


  if (!fbAppId) {
    throw new Error('fbAppId is not defined');
  }

  var params = encodeParams({
    app_id: fbAppId,
    link: url
  });

  return window.location.assign('fb-messenger://share?' + params);
}

function line() {
  var options = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : {};
  var title = options.title,
      url = options.url;


  if (!url) {
    throw new Error('url is not defined');
  }

  var params = encodeURIComponent('' + url);

  if (title) {
    params = '' + encodeURIComponent(title + ' ') + params;
  }

  return window.open('https://line.me/R/msg/text/?' + params, '_blank', WIN_PARAMS);
}




var sharing = (Object.freeze || Object)({
	fbFeed: fbFeed,
	fbShare: fbShare,
	fbButton: fbButton,
	gp: gp,
	mail: mail,
	email: email,
	ok: ok,
	telegram: telegram,
	tw: tw,
	reddit: reddit,
	pinterest: pinterest,
	tumblr: tumblr,
	viber: viber,
	getVkUrl: getUrl$1,
	vk: share,
	whatsapp: whatsapp,
	linkedin: linkedin,
	messenger: messenger,
	line: line
});

/**
 * @return {boolean}
 */
function isTouchDevice() {
  return 'ontouchstart' in window || navigator.MaxTouchPoints > 0 || navigator.msMaxTouchPoints > 0;
}

/**
 * Checks if the player opened on iOS or Android device.
 *
 * @return {boolean}
 */
function isMobileDevice() {
  return (/Android/.test(window.navigator.userAgent) || /iP(hone|ad|od)/i.test(window.navigator.userAgent)
  );
}

var EXCLUDED_SOCIALS = ['whatsapp', 'viber', 'messenger'];

/**
 * Filters socials list depending on platform.
 *
 * @param  {Array} socials
 *         List of socials to filter.
 * @return {Array}
 *         Filtered list of socials.
 */
function filterSocials() {
  var socials = arguments.length > 0 && arguments[0] !== undefined ? arguments[0] : [];
  var mobileVerification = arguments.length > 1 && arguments[1] !== undefined ? arguments[1] : true;

  return mobileVerification ? isMobileDevice() ? socials : socials.filter(function (social) {
    return !EXCLUDED_SOCIALS.includes(social);
  }) : socials;
}

var fbFeed$1 = "<svg width=\"8\" height=\"16\" viewbox=\"0 0 8 16\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M5.937 2.752h1.891V.01L5.223 0c-2.893 0-3.55 2.047-3.55 3.353v1.829H0v2.824h1.673V16H5.19V8.006h2.375l.308-2.824H5.19v-1.66c0-.624.44-.77.747-.77\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var tw$1 = "<svg width=\"18\" height=\"15\" viewbox=\"0 0 18 15\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M0 12.616a10.657 10.657 0 0 0 5.661 1.615c6.793 0 10.507-5.476 10.507-10.223 0-.156-.003-.31-.01-.464A7.38 7.38 0 0 0 18 1.684a7.461 7.461 0 0 1-2.12.564A3.621 3.621 0 0 0 17.503.262c-.713.411-1.505.71-2.345.871A3.739 3.739 0 0 0 12.462 0C10.422 0 8.77 1.607 8.77 3.59c0 .283.033.556.096.82A10.578 10.578 0 0 1 1.254.656a3.506 3.506 0 0 0-.5 1.807c0 1.246.65 2.346 1.642 2.99a3.731 3.731 0 0 1-1.673-.45v.046c0 1.74 1.274 3.193 2.962 3.523a3.756 3.756 0 0 1-.972.126c-.239 0-.47-.022-.695-.064.469 1.428 1.833 2.467 3.449 2.494A7.531 7.531 0 0 1 .88 12.665c-.298 0-.591-.014-.881-.049\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var reddit$1 = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\" viewbox=\"0 0 24 24\">\n  <path d=\"M24 11.779a2.654 2.654 0 0 0-4.497-1.899c-1.81-1.191-4.259-1.949-6.971-2.046l1.483-4.669 4.016.941-.006.058a2.17 2.17 0 0 0 2.174 2.163c1.198 0 2.172-.97 2.172-2.163a2.171 2.171 0 0 0-4.193-.785l-4.329-1.015a.37.37 0 0 0-.44.249L11.755 7.82c-2.838.034-5.409.798-7.3 2.025a2.643 2.643 0 0 0-1.799-.712A2.654 2.654 0 0 0 0 11.779c0 .97.533 1.811 1.317 2.271a4.716 4.716 0 0 0-.086.857C1.231 18.818 6.039 22 11.95 22s10.72-3.182 10.72-7.093c0-.274-.029-.544-.075-.81A2.633 2.633 0 0 0 24 11.779zM6.776 13.595c0-.868.71-1.575 1.582-1.575.872 0 1.581.707 1.581 1.575s-.709 1.574-1.581 1.574-1.582-.706-1.582-1.574zm9.061 4.669c-.797.793-2.048 1.179-3.824 1.179L12 19.44l-.013.003c-1.777 0-3.028-.386-3.824-1.179a.369.369 0 0 1 0-.523.372.372 0 0 1 .526 0c.65.647 1.729.961 3.298.961l.013.003.013-.003c1.569 0 2.648-.315 3.298-.962a.373.373 0 0 1 .526 0 .37.37 0 0 1 0 .524zm-.189-3.095a1.58 1.58 0 0 1-1.581-1.574c0-.868.709-1.575 1.581-1.575s1.581.707 1.581 1.575-.709 1.574-1.581 1.574z\" fill=\"#FFF\" fill-rule=\"evenodd\"/>\n</svg>\n";

var gp$1 = "<svg width=\"21\" height=\"14\" viewbox=\"0 0 21 14\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M6.816.006C8.5-.071 10.08.646 11.37 1.655a24.11 24.11 0 0 1-1.728 1.754C8.091 2.36 5.89 2.06 4.34 3.272c-2.217 1.503-2.317 5.05-.186 6.668 2.073 1.843 5.991.928 6.564-1.895-1.298-.02-2.6 0-3.899-.042-.003-.76-.006-1.518-.003-2.278 2.17-.006 4.341-.01 6.516.007.13 1.786-.11 3.688-1.23 5.164-1.696 2.34-5.1 3.022-7.756 2.02C1.681 11.921-.207 9.161.018 6.348.077 2.905 3.305-.11 6.816.006zm10.375 3.812h1.893c.004.634.007 1.27.014 1.903.632.007 1.27.007 1.902.013v1.893l-1.902.016c-.007.636-.01 1.27-.014 1.902h-1.896c-.006-.632-.006-1.266-.013-1.899l-1.902-.02V5.735c.633-.006 1.266-.01 1.902-.013.004-.636.01-1.27.016-1.903z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var messenger$1 = "<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 223 223\" width=\"512\" height=\"512\">\n  <path d=\"M111.5 0C50.5 0 0.8 47 0.8 104.7c0 31.1 14.5 60.3 39.7 80.3 3.3 2.6 8 2 10.5-1.2 2.6-3.2 2-8-1.2-10.5 -21.6-17.1-34-42.1-34-68.5C15.8 55.2 58.7 15 111.5 15c52.8 0 95.7 40.2 95.7 89.7 0 49.4-42.9 89.7-95.7 89.7 -9.2 0-18.3-1.2-27.1-3.6 -1.9-0.5-4-0.3-5.7 0.7l-31.1 17.6c-3.6 2-4.9 6.6-2.8 10.2 1.4 2.4 3.9 3.8 6.5 3.8 1.3 0 2.5-0.3 3.7-1l28.4-16.1c9.1 2.2 18.5 3.4 28 3.4 61.1 0 110.7-47 110.7-104.7C222.3 47 172.6 0 111.5 0z\" fill=\"#FFF\" fill-rule=\"evenodd\"/>\n  <path d=\"M114.7 71.9c-2.6-1.2-5.8-0.8-8 1.1l-57.9 49.1c-3.2 2.7-3.6 7.4-0.9 10.6 2.7 3.2 7.4 3.6 10.6 0.9l45.5-38.6v35.9c0 2.9 1.7 5.6 4.3 6.8 1 0.5 2.1 0.7 3.2 0.7 1.7 0 3.5-0.6 4.9-1.8l57.9-49.1c3.2-2.7 3.6-7.4 0.9-10.6   -2.7-3.2-7.4-3.6-10.6-0.9l-45.5 38.6V78.7C119 75.7 117.3 73.1 114.7 71.9z\" fill=\"#FFF\" fill-rule=\"evenodd\"/>\n</svg>\n";

var linkedin$1 = "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"24\" height=\"24\">\n  <path fill=\"#FFF\" fill-rule=\"evenodd\" d=\"M4.98 3.5C4.98 4.881 3.87 6 2.5 6S.02 4.881.02 3.5C.02 2.12 1.13 1 2.5 1s2.48 1.12 2.48 2.5zM5 8H0v16h5V8zm7.982 0H8.014v16h4.969v-8.399c0-4.67 6.029-5.052 6.029 0V24H24V13.869c0-7.88-8.922-7.593-11.018-3.714V8z\"/>\n</svg>\n";

var vk = "<svg width=\"22\" height=\"12\" viewbox=\"0 0 22 12\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M10.764 11.94h1.315s.397-.042.6-.251c.187-.192.18-.552.18-.552s-.025-1.685.794-1.934c.807-.245 1.844 1.629 2.942 2.35.832.545 1.463.425 1.463.425l2.938-.039s1.537-.09.808-1.244c-.06-.095-.425-.855-2.184-2.415-1.843-1.633-1.596-1.37.623-4.195 1.351-1.72 1.892-2.771 1.722-3.22-.16-.43-1.154-.316-1.154-.316l-3.308.02s-.246-.033-.427.071c-.178.102-.292.34-.292.34s-.524 1.33-1.222 2.463C14.09 5.833 13.5 5.96 13.26 5.81c-.56-.346-.42-1.388-.42-2.13 0-2.315.368-3.28-.716-3.531-.36-.082-.624-.137-1.544-.146C9.4-.01 8.4.006 7.835.27c-.377.176-.668.568-.49.59.218.029.713.128.976.47.339.44.327 1.43.327 1.43s.195 2.725-.455 3.064c-.446.232-1.057-.242-2.371-2.41-.673-1.11-1.18-2.338-1.18-2.338S4.542.848 4.368.725C4.157.576 3.86.529 3.86.529L.717.549S.245.562.072.757c-.155.175-.012.536-.012.536s2.46 5.5 5.247 8.271c2.556 2.542 5.457 2.375 5.457 2.375\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var ok$1 = "<svg width=\"12\" height=\"18\" viewbox=\"0 0 12 18\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M6.843 8.83c2.17-.468 4.162-2.626 3.521-5.3C9.863 1.442 7.561-.599 4.742.161c-6.148 1.662-3.661 9.912 2.1 8.668zm-1.6-6.458c1.39-.375 2.504.554 2.788 1.57.363 1.305-.592 2.394-1.618 2.657-2.913.747-4.16-3.43-1.17-4.227zM9.05 9.536c.41-.23.748-.608 1.367-.577.832.044 2.514 1.404-.445 2.824-1.624.778-1.699.558-2.972.926.22.411 2.55 2.453 3.214 3.082 1.103 1.046.164 2.234-.967 2.115-.718-.077-2.971-2.352-3.38-2.82-.92.438-2.541 2.674-3.431 2.81-1.175.182-2.155-1.091-.96-2.19L4.65 12.73c-.287-.145-1.171-.261-1.59-.389C-1.57 10.93.08 8.838 1.405 8.963c.478.046.907.42 1.274.621 1.931 1.05 4.463 1.029 6.37-.048z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var mail$1 = "<svg width=\"17\" height=\"16\" viewbox=\"0 0 17 16\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M8.205 3.322c1.3 0 2.521.563 3.418 1.445v.003c0-.423.29-.742.694-.742l.101-.001c.631 0 .76.586.76.771l.004 6.584c-.045.431.454.653.73.377 1.077-1.086 2.366-5.585-.67-8.192-2.831-2.43-6.629-2.03-8.649-.664-2.146 1.453-3.52 4.668-2.185 7.688 1.455 3.294 5.617 4.276 8.091 3.296 1.253-.496 1.832 1.165.53 1.708-1.965.822-7.438.74-9.994-3.605C-.692 9.057-.6 3.896 3.98 1.222c3.505-2.046 8.125-1.48 10.91 1.374 2.913 2.985 2.743 8.572-.097 10.745-1.288.986-3.199.025-3.187-1.413l-.013-.47a4.827 4.827 0 0 1-3.388 1.381c-2.566 0-4.825-2.215-4.825-4.733 0-2.543 2.259-4.784 4.825-4.784zm3.231 4.602C11.34 6.08 9.944 4.97 8.26 4.97h-.063c-1.945 0-3.023 1.5-3.023 3.204 0 1.908 1.305 3.113 3.015 3.113 1.907 0 3.162-1.37 3.252-2.992l-.004-.372z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var telegram$1 = "<svg width=\"21\" height=\"17\" viewbox=\"0 0 21 17\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M10.873 13.323c-.784.757-1.56 1.501-2.329 2.252-.268.262-.57.407-.956.387-.263-.014-.41-.13-.49-.378-.589-1.814-1.187-3.626-1.773-5.44a.425.425 0 0 0-.322-.317A417.257 417.257 0 0 1 .85 8.541a2.37 2.37 0 0 1-.59-.265c-.309-.203-.353-.527-.07-.762.26-.216.57-.397.886-.522C2.828 6.304 4.59 5.638 6.35 4.964L19.039.101c.812-.311 1.442.12 1.366.988-.05.572-.2 1.137-.32 1.702-.938 4.398-1.88 8.794-2.82 13.191l-.003.026c-.23 1.006-.966 1.28-1.806.668-1.457-1.065-2.91-2.134-4.366-3.201-.068-.05-.14-.098-.217-.152zm-3.22 1.385c.023-.103.038-.151.043-.2.092-.989.189-1.977.27-2.967a.732.732 0 0 1 .256-.534c2.208-1.968 4.41-3.943 6.613-5.917.626-.561 1.256-1.12 1.876-1.688.065-.06.08-.174.117-.263-.095-.027-.203-.095-.285-.072-.189.052-.38.127-.545.23C12.722 5.343 9.45 7.395 6.175 9.44c-.167.104-.214.19-.147.389.518 1.547 1.022 3.098 1.531 4.648.02.061.048.12.094.23z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var whatsapp$1 = "<svg width=\"22\" height=\"22\" viewbox=\"0 0 22 22\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M7.926 5.587c-.213-.51-.375-.53-.698-.543a6.234 6.234 0 0 0-.369-.013c-.42 0-.86.123-1.125.395-.323.33-1.125 1.1-1.125 2.677 0 1.578 1.15 3.104 1.306 3.318.162.213 2.244 3.498 5.476 4.837 2.528 1.048 3.278.95 3.853.828.84-.181 1.894-.802 2.16-1.552.265-.75.265-1.39.187-1.527-.078-.135-.291-.213-.614-.375-.323-.161-1.894-.937-2.192-1.04-.29-.11-.569-.072-.788.239-.31.433-.614.873-.86 1.138-.194.207-.511.233-.776.123-.356-.149-1.351-.498-2.58-1.591-.95-.847-1.596-1.901-1.784-2.218-.187-.323-.02-.511.13-.685.161-.201.316-.343.478-.53.161-.188.252-.285.355-.505.11-.214.033-.434-.045-.595-.078-.162-.724-1.74-.99-2.38zM10.996 0C4.934 0 0 4.934 0 11c0 2.405.776 4.636 2.095 6.447L.724 21.534l4.228-1.351A10.913 10.913 0 0 0 11.003 22C17.067 22 22 17.066 22 11S17.067 0 11.003 0h-.006z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var viber$1 = "<svg width=\"21\" height=\"21\" viewbox=\"0 0 21 21\" xmlns=\"http://www.w3.org/2000/svg\">\n  <path d=\"M18.639 14.904c-.628-.506-1.3-.96-1.96-1.423-1.318-.926-2.523-.997-3.506.491-.552.836-1.325.873-2.133.506-2.228-1.01-3.949-2.567-4.956-4.831-.446-1.002-.44-1.9.603-2.609.552-.375 1.108-.818 1.064-1.637C7.693 4.334 5.1.765 4.077.39 3.653.233 3.23.243 2.8.388.4 1.195-.594 3.169.358 5.507c2.84 6.974 7.84 11.829 14.721 14.792.392.169.828.236 1.049.297 1.567.015 3.402-1.494 3.932-2.992.51-1.441-.568-2.013-1.421-2.7zm-7.716-13.8c-.417-.064-1.052.026-1.02-.525.046-.817.8-.513 1.165-.565 4.833.163 8.994 4.587 8.935 9.359-.006.468.162 1.162-.536 1.149-.668-.013-.493-.717-.553-1.185-.64-5.067-2.96-7.46-7.991-8.233zm.984 1.39c3.104.372 5.64 3.065 5.615 6.024-.047.35.157.95-.409 1.036-.764.116-.615-.583-.69-1.033-.511-3.082-1.593-4.213-4.7-4.907-.458-.102-1.17-.03-1.052-.736.113-.671.752-.443 1.236-.385zm.285 2.419c1.377-.034 2.992 1.616 2.969 3.044.014.39-.028.802-.49.857-.333.04-.552-.24-.586-.585-.128-1.272-.798-2.023-2.073-2.228-.382-.061-.757-.184-.579-.7.12-.345.436-.38.76-.388z\" fill=\"#FFF\" fill-rule=\"evenodd\"></path>\n</svg>\n";

var icons = {
  fbFeed: fbFeed$1,
  tw: tw$1,
  reddit: reddit$1,
  gp: gp$1,
  messenger: messenger$1,
  linkedin: linkedin$1,
  vk: vk,
  ok: ok$1,
  mail: mail$1,
  telegram: telegram$1,
  whatsapp: whatsapp$1,
  viber: viber$1
};

var ShareModalContent = function () {
  function ShareModalContent(player, options) {
    classCallCheck(this, ShareModalContent);

    this.player = player;

    this.options = options;
    this.socials = filterSocials(options.socials, options.mobileVerification);

    this.copyBtnTextClass = 'vjs-share__btn-text';
    this.socialBtnClass = 'vjs-share__social';

    this._createContent();
    this._initToggle();
    this._initClipboard();
    this._initSharing();
  }

  ShareModalContent.prototype.getContent = function getContent() {
    return this.content;
  };

  ShareModalContent.prototype._createContent = function _createContent() {
    var copyBtn = '\n      <svg xmlns="http://www.w3.org/2000/svg" width="18" height="20">\n        <path fill="#FFF" fill-rule="evenodd" d="M10.07 20H1.318A1.325 1.325 0 0 1 0 18.67V6.025c0-.712.542-1.21 1.318-1.21h7.294l2.776 2.656v11.2c0 .734-.59 1.33-1.318 1.33zm6.46-15.926v9.63h-3.673v1.48h3.825c.727 0 1.318-.595 1.318-1.328v-11.2L15.225 0H7.93c-.776 0-1.318.497-1.318 1.21v2.123h1.47V1.48h5.877v2.594h2.57zm-.73-1.48l-.37-.357v.356h.37zM9.918 8.888v9.63H1.47V6.295h5.878V8.89h2.57zm-.73-1.483l-.372-.355v.355h.37z"></path>\n      </svg>\n      <span class="' + this.copyBtnTextClass + '">' + this.player.localize('Copy') + '</span>\n    ';
    var wrapper = document.createElement('div');

    wrapper.innerHTML = '<div class="vjs-share">\n      <div class="vjs-share__top hidden-sm">\n        <div class="vjs-share__title">' + this.player.localize('Share') + '</div>\n      </div>\n\n      <div class="vjs-share__middle">\n        <div class="vjs-share__subtitle hidden-xs">' + this.player.localize('Direct Link') + ':</div>\n        <div class="vjs-share__short-link-wrapper">\n          <input class="vjs-share__short-link" type="text" readonly="true" value="' + this.options.url + '">\n          <div class="vjs-share__btn">\n            ' + copyBtn + '\n          </div>\n        </div>\n\n        <div class="vjs-share__subtitle hidden-xs">' + this.player.localize('Embed Code') + ':</div>\n        <div class="vjs-share__short-link-wrapper hidden-xs">\n          <input class="vjs-share__short-link" type="text" readonly="true" value="' + this.options.embedCode + '">\n          <div class="vjs-share__btn">\n            ' + copyBtn + '\n          </div>\n        </div>\n      </div>\n\n      <div class="vjs-share__bottom">\n        <div class="vjs-share__socials">\n          ' + this._getSocialItems().join('') + '\n        </div>\n      </div>\n    </div>';

    this.content = wrapper.firstChild;
  };

  ShareModalContent.prototype._initClipboard = function _initClipboard() {
    var _this = this;

    var clipboard = new Clipboard('.vjs-share__btn', {
      target: function target(trigger) {
        return trigger.previousElementSibling;
      }
    });

    clipboard.on('success', function (e) {
      var textContainer = e.trigger.querySelector('.' + _this.copyBtnTextClass);
      var restore = function restore() {
        textContainer.innerText = _this.player.localize('Copy');
        e.clearSelection();
      };

      textContainer.innerText = _this.player.localize('Copied');

      if (isTouchDevice()) {
        setTimeout(restore, 1000);
      } else {
        textContainer.parentElement.addEventListener('mouseleave', function () {
          setTimeout(restore, 300);
        });
      }
    });
  };

  ShareModalContent.prototype._initSharing = function _initSharing() {
    var _this2 = this;

    var btns = this.content.querySelectorAll('.' + this.socialBtnClass);

    Array.from(btns).forEach(function (btn) {
      btn.addEventListener('click', function (e) {
        var social = e.currentTarget.getAttribute('data-social');

        if (typeof sharing[social] === 'function') {
          sharing[social](_this2.socialOptions);
        }
      });
    });
  };

  ShareModalContent.prototype._initToggle = function _initToggle() {
    var iconsList = this.content.querySelector('.vjs-share__socials');

    if (this.socials.length > 10 || window.innerWidth <= 180 && this.socials.length > 6) {
      iconsList.style.height = 'calc((2em + 5px) * 2)';
    } else {
      iconsList.classList.add('horizontal');
    }
  };

  ShareModalContent.prototype._getSocialItems = function _getSocialItems() {
    var socialItems = [];

    this.socials.forEach(function (social) {
      if (icons[social]) {
        socialItems.push('\n          <button class="vjs-share__social vjs-share__social_' + social + '" data-social="' + social + '">\n            ' + icons[social] + '\n          </button>\n        ');
      }
    });

    return socialItems;
  };

  createClass(ShareModalContent, [{
    key: 'socialOptions',
    get: function get$$1() {
      var _options = this.options,
          url = _options.url,
          title = _options.title,
          description = _options.description,
          image = _options.image,
          fbAppId = _options.fbAppId,
          isVkParse = _options.isVkParse,
          redirectUri = _options.redirectUri;


      return {
        url: url,
        title: title,
        description: description,
        image: image,
        fbAppId: fbAppId,
        isVkParse: isVkParse,
        redirectUri: redirectUri
      };
    }
  }]);
  return ShareModalContent;
}();

var Component = videojs.getComponent('Component');

/**
 * Share overlay.
 */

var ShareOverlay = function (_Component) {
  inherits(ShareOverlay, _Component);

  function ShareOverlay(player, options) {
    classCallCheck(this, ShareOverlay);

    var _this = possibleConstructorReturn(this, _Component.call(this, player, options));

    _this.player = player;
    _this.options = options;
    return _this;
  }

  ShareOverlay.prototype._createModal = function _createModal() {
    var content = new ShareModalContent(this.player, this.options).getContent();

    this.modal = new ShareModal(this.player, {
      content: content,
      temporary: true
    });

    this.el = this.modal.contentEl();

    this.player.addChild(this.modal);
  };

  ShareOverlay.prototype.open = function open() {
    this._createModal();
    this.modal.open();
  };

  return ShareOverlay;
}(Component);

var Plugin = videojs$1.getPlugin('plugin');

// Default options for the plugin.
/**
 * An advanced Video.js plugin. For more information on the API
 *
 * See: https://blog.videojs.com/feature-spotlight-advanced-plugins/
 */

var Share = function (_Plugin) {
  inherits(Share, _Plugin);

  /**
   * Create a Share plugin instance.
   *
   * @param  {Player} player
   *         A Video.js Player instance.
   *
   * @param  {Object} [options]
   *         An optional options object.
   *
   *         While not a core part of the Video.js plugin architecture, a
   *         second argument of options is a convenient way to accept inputs
   *         from your plugin's caller.
   */
  function Share(player, options) {
    classCallCheck(this, Share);

    var _this = possibleConstructorReturn(this, _Plugin.call(this, player));
    // the parent class will add player under this.player


    _this.options = videojs$1.mergeOptions(defaults, options);

    _this.player.ready(function () {
      _this.player.addClass('vjs-share');
      player.addClass('vjs-videojs-share');
      player.getChild('controlBar').addChild('ShareButton', options);
      player.addChild('ShareOverlay', options);
    });
    return _this;
  }

  return Share;
}(Plugin);

// Define default values for the plugin's `state` object here.


Share.defaultState = {};

// Include the version number.
Share.VERSION = version;

// Register the plugin with video.js.
videojs$1.registerComponent('ShareButton', ShareButton);
videojs$1.registerComponent('ShareOverlay', ShareOverlay);
videojs$1.registerPlugin('share', Share);

return Share;

})));
