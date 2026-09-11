const { test } = require('node:test');
const assert = require('node:assert/strict');
const install = require('../assets/js/player-gestures.js');

class Target {
    constructor() { this.listeners = {}; this.hidden = false; }
    addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn); }
    removeEventListener(type, fn) { this.listeners[type] = (this.listeners[type] || []).filter(f => f !== fn); }
    emit(type, extra = {}) {
        const e = { target: surface, button: 0, pointerType: 'mouse', pointerId: 1,
            clientX: 10, clientY: 10, preventDefault() { this.prevented = true; },
            stopImmediatePropagation() { this.stopped = true; }, ...extra };
        for (const fn of this.listeners[type] || []) fn(e);
        return e;
    }
}
const surface = { closest: () => null };
const control = { closest: selector => ['.vjs-play-control, .vjs-big-play-button', '.vjs-control-bar'].includes(selector) ? null : ({}) };
function setup(paused = false, speed = 1.75) {
    const win = new Target(), doc = new Target(), el = new Target();
    el.contains = target => target === surface;
    doc.activeElement = surface;
    el.focus = () => { doc.activeElement = surface; };
    const tasks = new Map(); let next = 0, time = 40, indicator = false;
    const player = { el: () => el, paused: () => paused,
        playbackRate(v) { if (v !== undefined) speed = v; return speed; },
        currentTime(v) { if (v !== undefined) time = v; return time; }, duration: () => 100,
        play() { paused = false; return Promise.resolve(); }, pause() { paused = true; },
        controls: () => true };
    const gesture = install(player, { window: win, document: doc,
        setTimeout(fn) { const id = ++next; tasks.set(id, fn); return id; },
        clearTimeout(id) { tasks.delete(id); }, onHold(active) { indicator = active; } });
    return { win, doc, el, player, gesture, indicator: () => indicator,
        advance() { const callbacks = [...tasks.values()]; tasks.clear(); callbacks.forEach(fn => fn()); } };
}
test('Space tap toggles once on release, including repeated keydown', () => {
    const h = setup(); h.win.emit('keydown', {key:' '}); h.win.emit('keydown', {key:' ',repeat:true});
    assert.equal(h.player.paused(), false); h.win.emit('keyup',{key:' '}); assert.equal(h.player.paused(),true);
});
test('Space hold temporarily plays at 2× and restores 1.75× without toggling', () => {
    const h=setup(); h.win.emit('keydown',{key:' '});h.advance();assert.equal(h.player.playbackRate(),2);assert.equal(h.indicator(),true);
    h.win.emit('keyup',{key:' '});assert.equal(h.player.playbackRate(),1.75);assert.equal(h.player.paused(),false);assert.equal(h.indicator(),false);
});
test('hold from paused state restores paused state and original rate', () => {
    const h=setup(true,.75);h.win.emit('keydown',{key:' '});h.advance();assert.equal(h.player.paused(),false);
    h.win.emit('keyup',{key:' '});assert.equal(h.player.paused(),true);assert.equal(h.player.playbackRate(),.75);
});
test('mouse hold restores on release outside video and suppresses following click', () => {
    const h=setup();h.el.emit('pointerdown');h.advance();assert.equal(h.player.playbackRate(),2);
    h.win.emit('pointerup',{target:control});assert.equal(h.player.playbackRate(),1.75);
    assert.equal(h.el.emit('click').prevented,true);
});
test('short mouse click is left to the native Video.js click behavior', () => {
    const h=setup();h.el.emit('pointerdown');h.win.emit('pointerup');assert.equal(h.el.emit('click').prevented,undefined);assert.equal(h.player.paused(),false);
});
test('controls, editing, modifiers and touch do not start a hold', () => {
    const h=setup();h.win.emit('keydown',{key:' ',target:control});h.win.emit('keydown',{key:' ',ctrlKey:true});h.el.emit('pointerdown',{target:control});h.el.emit('pointerdown',{pointerType:'touch'});h.advance();assert.equal(h.gesture.isHolding(),false);assert.equal(h.player.playbackRate(),1.75);
});
test('pointer movement cancels pending hold', () => {
    const h=setup();h.el.emit('pointerdown');h.win.emit('pointermove',{clientX:50});h.advance();assert.equal(h.player.playbackRate(),1.75);
});
for(const event of ['blur','pointercancel']) test(event+' restores hold state',()=>{
    const h=setup();h.el.emit('pointerdown');h.advance();h.win.emit(event);assert.equal(h.player.playbackRate(),1.75);assert.equal(h.gesture.isHolding(),false);
});
test('hidden document cancels Space hold without pausing playback',()=>{
    const h=setup();h.win.emit('keydown',{key:' '});h.advance();h.doc.hidden=true;h.doc.emit('visibilitychange');assert.equal(h.player.playbackRate(),1.75);assert.equal(h.player.paused(),false);
});
test('J/L seek fixed ten seconds at 1.75× and clamp to duration',()=>{
    const h=setup();h.win.emit('keydown',{key:'l'});assert.equal(h.player.currentTime(),50);h.win.emit('keydown',{key:'j'});assert.equal(h.player.currentTime(),40);h.player.currentTime(98);h.win.emit('keydown',{key:'l'});assert.equal(h.player.currentTime(),100);
});
test('K toggles once and held-key repeats are ignored',()=>{
    const h=setup();h.win.emit('keydown',{key:'k'});h.win.emit('keydown',{key:'k',repeat:true});assert.equal(h.player.paused(),true);
});
test('overlapping inputs do not replace the original saved speed',()=>{
    const h=setup();h.win.emit('keydown',{key:' '});h.advance();h.el.emit('pointerdown');h.win.emit('pointerup');assert.equal(h.player.playbackRate(),2);h.win.emit('keyup',{key:' '});assert.equal(h.player.playbackRate(),1.75);
});
test('dispose restores state and detaches handlers',()=>{
    const h=setup();h.win.emit('keydown',{key:' '});h.advance();h.gesture.dispose();assert.equal(h.player.playbackRate(),1.75);h.win.emit('keydown',{key:'k'});assert.equal(h.player.paused(),false);
});
test('post-hold click remains suppressed across event-loop turns; next deliberate click works', () => {
    const h=setup(true);h.el.emit('pointerdown');h.advance();h.win.emit('pointerup');
    h.advance();assert.equal(h.el.emit('click',{detail:1}).prevented,true);
    h.el.emit('pointerdown');h.win.emit('pointerup');assert.equal(h.el.emit('click',{detail:1}).prevented,undefined);
});
test('release outside does not suppress the next deliberate pointer or keyboard click', () => {
    const h=setup();h.el.emit('pointerdown');h.advance();h.win.emit('pointerup',{target:control});
    assert.equal(h.el.emit('click',{detail:0,target:control}).prevented,undefined);
    h.el.emit('pointerdown');h.win.emit('pointerup');assert.equal(h.el.emit('click',{detail:1}).prevented,undefined);
});
test('held mouse consumes Video.js mouseup as well as the browser click', () => {
    const h=setup(true);h.el.emit('pointerdown');h.advance();h.win.emit('pointerup');
    assert.equal(h.el.emit('mouseup').prevented,true);
    assert.equal(h.el.emit('click',{detail:1}).prevented,true);
});

test('shortcuts do not capture keys outside the player, even after playback starts', () => {
    const h = setup(); h.doc.activeElement = control;
    for (const key of ['j', 'k', 'l', ' ']) {
        assert.equal(h.win.emit('keydown', {key, target: control}).prevented, undefined);
    }
    h.doc.activeElement = {};
    assert.equal(h.win.emit('keydown', {key:'k'}).prevented, undefined);
    assert.equal(h.player.paused(), false);
    assert.equal(h.player.currentTime(), 40);
});
test('moving focus outside during Space hold restores speed without toggling', () => {
    const h=setup(); h.win.emit('keydown',{key:' '}); h.advance();
    h.doc.activeElement={}; h.doc.emit('focusin',{target:h.doc.activeElement});
    assert.equal(h.player.playbackRate(),1.75);
    assert.equal(h.player.paused(),false);
});

test('Play button focus accepts K/J/L and Space after clicking Play', () => {
    const h=setup();
    const button={closest: selector => selector === '.vjs-play-control, .vjs-big-play-button' ? button : control};
    h.el.contains=target=>target===button;h.doc.activeElement=button;
    h.win.emit('keydown',{key:'j',target:button});assert.equal(h.player.currentTime(),30);
    h.win.emit('keydown',{key:'l',target:button});assert.equal(h.player.currentTime(),40);
    h.win.emit('keydown',{key:'k',target:button});assert.equal(h.player.paused(),true);
    h.win.emit('keydown',{key:' ',target:button});h.win.emit('keyup',{key:' ',target:button});assert.equal(h.player.paused(),false);
});
