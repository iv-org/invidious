'use strict';

// Optional enhancements: native media controls remain available without this script.
(function (root, factory) {
    if (typeof module === 'object' && module.exports) module.exports = factory;
    else root.installPlayerGestures = factory;
})(typeof window === 'undefined' ? globalThis : window, function (player, environment) {
    var env = environment || {};
    var win = env.window || window;
    var doc = env.document || document;
    var later = env.setTimeout || win.setTimeout.bind(win);
    var cancelTimer = env.clearTimeout || win.clearTimeout.bind(win);
    var el = player.el();
    var session = null;
    var suppressClick = false;
    var listeners = [];

    function blocked(event) {
        return event.altKey || event.ctrlKey || event.metaKey || event.shiftKey ||
            !player.controls() || (event.target && event.target.closest &&
            event.target.closest('input, textarea, select, button, a, summary, [role="button"], [role="slider"], [role="textbox"], [contenteditable]:not([contenteditable="false"]), .vjs-control-bar, .vjs-menu'));
    }

    function consume(event) {
        event.preventDefault();
        event.stopImmediatePropagation();
    }

    function play() {
        var result = player.play();
        if (result && result.catch) result.catch(function () { finish(false); });
    }

    function toggle() {
        if (player.paused()) play();
        else player.pause();
    }

    function showHold(active) {
        if (env.onHold) env.onHold(active);
        else el.classList.toggle('vjs-speed-hold', active);
    }

    function begin(kind, event) {
        if (session) return;
        session = { kind: kind, pointerId: event.pointerId, x: event.clientX, y: event.clientY,
            active: false, speed: player.playbackRate(), paused: player.paused() };
        session.timer = later(function () {
            if (!session) return;
            session.active = true;
            showHold(true);
            player.playbackRate(2);
            play();
        }, 350);
    }

    function finish(tap) {
        if (!session) return false;
        var current = session;
        cancelTimer(current.timer);
        // Keep the hold marked active while ratechange handlers restore preferences.
        if (current.active) {
            player.playbackRate(current.speed);
            if (current.paused) player.pause();
            showHold(false);
        }
        session = null;
        if (tap && !current.active && current.kind === 'keyboard') toggle();
        return current.active;
    }

    function listen(target, type, handler) {
        target.addEventListener(type, handler, true);
        listeners.push([target, type, handler]);
    }

    listen(win, 'keydown', function (event) {
        var playButton = event.target && event.target.closest &&
            event.target.closest('.vjs-play-control, .vjs-big-play-button');
        var playerControl = event.key !== ' ' && event.target && event.target.closest &&
            event.target.closest('.vjs-control-bar') &&
            !event.target.closest('.vjs-menu, input, select, [role="slider"]');
        if (!el.contains(doc.activeElement) || (!playButton && !playerControl && blocked(event)) ||
            event.altKey || event.ctrlKey || event.metaKey || event.shiftKey) return;
        if (event.key === ' ') {
            consume(event);
            if (!event.repeat) begin('keyboard', event);
        } else if (event.key === 'k') {
            consume(event);
            if (!event.repeat && !session) toggle();
        } else if (event.key === 'j' || event.key === 'l') {
            consume(event);
            var time = Math.max(0, player.currentTime() + (event.key === 'j' ? -10 : 10));
            var duration = player.duration();
            player.currentTime(Number.isFinite(duration) ? Math.min(duration, time) : time);
        }
    });

    listen(win, 'keyup', function (event) {
        if (event.key === ' ' && session && session.kind === 'keyboard') {
            consume(event);
            finish(el.contains(doc.activeElement));
        }
    });

    listen(el, 'pointerdown', function (event) {
        suppressClick = false;
        if (event.button !== 0 || event.pointerType !== 'mouse' || blocked(event)) return;
        el.focus({ preventScroll: true });
        begin('pointer', event);
    });

    listen(win, 'pointermove', function (event) {
        if (!session || session.kind !== 'pointer' || session.active || event.pointerId !== session.pointerId) return;
        if (Math.abs(event.clientX - session.x) + Math.abs(event.clientY - session.y) > 12) finish(false);
    });

    listen(win, 'pointerup', function (event) {
        if (!session || session.kind !== 'pointer' || event.pointerId !== session.pointerId) return;
        if (finish(false)) {
            // Browsers may deliver click in a later task. A new pointerdown clears
            // this flag, so releasing outside cannot consume the next deliberate click.
            suppressClick = true;
        }
    });

    // Video.js toggles on mouseup; the subsequent browser click must also be
    // consumed so other click handlers cannot turn a completed hold into a tap.
    listen(el, 'mouseup', function (event) {
        if (suppressClick && !blocked(event)) consume(event);
    });

    listen(el, 'click', function (event) {
        if (suppressClick && event.detail !== 0 && !blocked(event)) {
            consume(event);
            suppressClick = false;
        }
    });

    listen(win, 'pointercancel', function () { finish(false); });
    listen(win, 'blur', function () { finish(false); });
    listen(doc, 'visibilitychange', function () { if (doc.hidden) finish(false); });
    listen(doc, 'focusin', function (event) { if (!el.contains(event.target) || blocked(event)) finish(false); });

    return {
        isHolding: function () { return !!(session && session.active); },
        dispose: function () {
            finish(false);
            listeners.forEach(function (entry) { entry[0].removeEventListener(entry[1], entry[2], true); });
        }
    };
});
