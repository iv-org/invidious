'use strict';
var player_data = JSON.parse(document.getElementById('player_data').textContent);
var video_data = JSON.parse(document.getElementById('video_data').textContent);

var options = {
    preload: 'auto',
    liveui: true,
    playbackRates: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0],
    controlBar: {
        children: [
            'playToggle',
            'volumePanel',
            'currentTimeDisplay',
            'timeDivider',
            'durationDisplay',
            'progressControl',
            'remainingTimeDisplay',
            'Spacer',
            'captionsButton',
            'audioTrackButton',
            'qualitySelector',
            'playbackRateMenuButton',
            'fullscreenToggle'
        ]
    },
    html5: {
        preloadTextTracks: false,
        vhs: {
            overrideNative: true
        }
    }
};

if (player_data.aspect_ratio) {
    options.aspectRatio = player_data.aspect_ratio;
}

var embed_url = new URL(location);
embed_url.searchParams.delete('v');
var short_url = location.origin + '/' + video_data.id + embed_url.search;
embed_url = location.origin + '/embed/' + video_data.id + embed_url.search;

var save_player_pos_key = 'save_player_pos';

videojs.Vhs.xhr.beforeRequest = function(options) {
    // set local if requested not videoplayback
    if (!options.uri.includes('videoplayback')) {
        if (!options.uri.includes('local=true'))
            options.uri += '?local=true';
    }
    return options;
};

var player = videojs('player', options);

player.on('error', function () {
    if (video_data.params.quality === 'dash') return;

    var localNotDisabled = (
        !player.currentSrc().includes('local=true') && !video_data.local_disabled
    );
    var reloadMakesSense = (
        player.error().code === MediaError.MEDIA_ERR_NETWORK ||
        player.error().code === MediaError.MEDIA_ERR_SRC_NOT_SUPPORTED
    );

    if (localNotDisabled) {
        // add local=true to all current sources
        player.src(player.currentSources().map(function (source) {
            source.src += '&local=true';
            return source;
        }));
    } else if (reloadMakesSense) {
        setTimeout(function () {
            console.warn('An error occurred in the player, reloading...');

            // After load() all parameters are reset. Save them
            var currentTime = player.currentTime();
            var playbackRate = player.playbackRate();
            var paused = player.paused();

            player.load();

            if (currentTime > 0.5) currentTime -= 0.5;

            player.currentTime(currentTime);
            player.playbackRate(playbackRate);
            if (!paused) player.play();
        }, 5000);
    }
});

if (video_data.params.quality === 'dash') {
    player.reloadSourceOnError({
        errorInterval: 10
    });
}

/**
 * Function for add time argument to url
 * @param {String} url
 * @returns {URL} urlWithTimeArg
 */
function addCurrentTimeToURL(url) {
    var urlUsed = new URL(url);
    urlUsed.searchParams.delete('start');
    var currentTime = Math.ceil(player.currentTime());
    if (currentTime > 0)
        urlUsed.searchParams.set('t', currentTime);
    else if (urlUsed.searchParams.has('t'))
        urlUsed.searchParams.delete('t');
    return urlUsed;
}

var shareOptions = {
    socials: ['fbFeed', 'tw', 'reddit', 'email'],

    get url() {
        return addCurrentTimeToURL(short_url);
    },
    title: player_data.title,
    description: player_data.description,
    image: player_data.thumbnail,
    get embedCode() {
        // Single quotes inside here required. HTML inserted as is into value attribute of input
        return "<iframe id='ivplayer' width='640' height='360' src='" +
            addCurrentTimeToURL(embed_url) + "' style='border:none;'></iframe>";
    }
};

if (location.pathname.startsWith('/embed/')) {
    var overlay_content = '<h1><a rel="noopener" target="_blank" href="' + location.origin + '/watch?v=' + video_data.id + '">' + player_data.title + '</a></h1>';
    player.overlay({
        overlays: [
            { start: 'loadstart', content: overlay_content, end: 'playing', align: 'top'},
            { start: 'pause',     content: overlay_content, end: 'playing', align: 'top'}
        ]
    });
}

// Detect mobile users and initialize mobileUi for better UX
// Detection code taken from https://stackoverflow.com/a/20293441

function isMobile() {
  try{ document.createEvent('TouchEvent'); return true; }
  catch(e){ return false; }
}

if (isMobile()) {
    player.mobileUi({ touchControls: { seekSeconds: 5 * player.playbackRate() } });

    var buttons = ['playToggle', 'volumePanel', 'captionsButton'];

    if (!video_data.params.listen && video_data.params.quality === 'dash') buttons.push('audioTrackButton');
    if (video_data.params.listen || video_data.params.quality !== 'dash') buttons.push('qualitySelector');

    // Create new control bar object for operation buttons
    const ControlBar = videojs.getComponent('controlBar');
    let operations_bar = new ControlBar(player, {
      children: [],
      playbackRates: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0]
    });
    buttons.slice(1).forEach(function (child) {operations_bar.addChild(child);});

    // Remove operation buttons from primary control bar
    var primary_control_bar = player.getChild('controlBar');
    buttons.forEach(function (child) {primary_control_bar.removeChild(child);});

    var operations_bar_element = operations_bar.el();
    operations_bar_element.classList.add('mobile-operations-bar');
    player.addChild(operations_bar);

    // Playback menu doesn't work when it's initialized outside of the primary control bar
    var playback_element = document.getElementsByClassName('vjs-playback-rate')[0];
    operations_bar_element.append(playback_element);

    // The share and http source selector element can't be fetched till the players ready.
    player.one('playing', function () {
        var share_element = document.getElementsByClassName('vjs-share-control')[0];
        operations_bar_element.append(share_element);

        if (!video_data.params.listen && video_data.params.quality === 'dash') {
            var http_source_selector = document.getElementsByClassName('vjs-http-source-selector vjs-menu-button')[0];
            operations_bar_element.append(http_source_selector);
        }
    });
}

// Enable VR video support
if (!video_data.params.listen && video_data.vr && video_data.params.vr_mode) {
    player.crossOrigin('anonymous');
    switch (video_data.projection_type) {
        case 'EQUIRECTANGULAR':
            player.vr({projection: 'equirectangular'});
        default: // Should only be 'MESH' but we'll use this as a fallback.
            player.vr({projection: 'EAC'});
    }
}

// Add markers
if (video_data.params.video_start > 0 || video_data.params.video_end > 0) {
    var markers = [{ time: video_data.params.video_start, text: 'Start' }];

    if (video_data.params.video_end < 0) {
        markers.push({ time: video_data.length_seconds - 0.5, text: 'End' });
    } else {
        markers.push({ time: video_data.params.video_end, text: 'End' });
    }

    player.markers({
        onMarkerReached: function (marker) {
            if (marker.text === 'End')
                player.loop() ? player.markers.prev('Start') : player.pause();
        },
        markers: markers
    });

    player.currentTime(video_data.params.video_start);
}

player.volume(video_data.params.volume / 100);
player.playbackRate(video_data.params.speed);

/**
 * Method for getting the contents of a cookie
 *
 * @param {String} name Name of cookie
 * @returns {String|null} cookieValue
 */
function getCookieValue(name) {
    var cookiePrefix = name + '=';
    var matchedCookie = document.cookie.split(';').find(function (item) {return item.includes(cookiePrefix);});
    if (matchedCookie)
        return matchedCookie.replace(cookiePrefix, '');
    return null;
}

/**
 * Method for updating the 'PREFS' cookie (or creating it if missing)
 *
 * @param {number} newVolume New volume defined (null if unchanged)
 * @param {number} newSpeed New speed defined (null if unchanged)
 */
function updateCookie(newVolume, newSpeed) {
    var volumeValue = newVolume !== null ? newVolume : video_data.params.volume;
    var speedValue = newSpeed !== null ? newSpeed : video_data.params.speed;

    var cookieValue = getCookieValue('PREFS');
    var cookieData;

    if (cookieValue !== null) {
        var cookieJson = JSON.parse(decodeURIComponent(cookieValue));
        cookieJson.volume = volumeValue;
        cookieJson.speed = speedValue;
        cookieData = encodeURIComponent(JSON.stringify(cookieJson));
    } else {
        cookieData = encodeURIComponent(JSON.stringify({ 'volume': volumeValue, 'speed': speedValue }));
    }

    // Set expiration in 2 year
    var date = new Date();
    date.setFullYear(date.getFullYear() + 2);

    var ipRegex = /^((\d+\.){3}\d+|[\dA-Fa-f]*:[\d:A-Fa-f]*:[\d:A-Fa-f]+)$/;
    var domainUsed = location.hostname;

    // Fix for a bug in FF where the leading dot in the FQDN is not ignored
    if (domainUsed.charAt(0) !== '.' && !ipRegex.test(domainUsed) && domainUsed !== 'localhost')
        domainUsed = '.' + location.hostname;

    var secure = location.protocol.startsWith("https") ? " Secure;" : "";

    document.cookie = 'PREFS=' + cookieData + '; SameSite=Lax; path=/; domain=' +
        domainUsed + '; expires=' + date.toGMTString() + ';' + secure;

    video_data.params.volume = volumeValue;
    video_data.params.speed = speedValue;
}

player.on('ratechange', function () {
    updateCookie(null, player.playbackRate());
    if (isMobile()) {
        player.mobileUi({ touchControls: { seekSeconds: 5 * player.playbackRate() } });
    }
});

player.on('volumechange', function () {
    updateCookie(Math.ceil(player.volume() * 100), null);
});

player.on('waiting', function () {
    if (player.playbackRate() > 1 && player.liveTracker.isLive() && player.liveTracker.atLiveEdge()) {
        console.info('Player has caught up to source, resetting playbackRate');
        player.playbackRate(1);
    }
});

if (video_data.premiere_timestamp && Math.round(new Date() / 1000) < video_data.premiere_timestamp) {
    player.getChild('bigPlayButton').hide();
}

if (video_data.params.save_player_pos) {
    const url = new URL(location);
    const hasTimeParam = url.searchParams.has('t');
    const rememberedTime = get_video_time();
    let lastUpdated = 0;

    if(!hasTimeParam) set_seconds_after_start(rememberedTime);

    player.on('timeupdate', function () {
        const raw = player.currentTime();
        const time = Math.floor(raw);

        if(lastUpdated !== time && raw <= video_data.length_seconds - 15) {
            save_video_time(time);
            lastUpdated = time;
        }
    });
}
else remove_all_video_times();

if (video_data.params.autoplay) {
    var bpb = player.getChild('bigPlayButton');
    bpb.hide();

    player.ready(function () {
        new Promise(function (resolve, reject) {
            setTimeout(function () {resolve(1);}, 1);
        }).then(function (result) {
            var promise = player.play();

            if (promise !== undefined) {
                promise.then(function () {
                }).catch(function (error) {
                    bpb.show();
                });
            }
        });
    });
}

if (!video_data.params.listen && video_data.params.quality === 'dash') {
    player.httpSourceSelector();

    if (video_data.params.quality_dash !== 'auto') {
        player.ready(function () {
            player.on('loadedmetadata', function () {
                const qualityLevels = Array.from(player.qualityLevels()).sort(function (a, b) {return a.height - b.height;});
                let targetQualityLevel;
                switch (video_data.params.quality_dash) {
                    case 'best':
                        targetQualityLevel = qualityLevels.length - 1;
                        break;
                    case 'worst':
                        targetQualityLevel = 0;
                        break;
                    default:
                        const targetHeight = parseInt(video_data.params.quality_dash);
                        for (let i = 0; i < qualityLevels.length; i++) {
                            if (qualityLevels[i].height <= targetHeight)
                                targetQualityLevel = i;
                            else
                                break;
                        }
                }
                qualityLevels.forEach(function (level, index) {
                    level.enabled = (index === targetQualityLevel);
                });
            });
        });
    }
}

player.vttThumbnails({
    src: '/api/v1/storyboards/' + video_data.id + '?height=90',
    showTimestamp: true
});

// Enable annotations
if (!video_data.params.listen && video_data.params.annotations) {
    addEventListener('load', function (e) {
        addEventListener('__ar_annotation_click', function (e) {
            const url = e.detail.url,
                  target = e.detail.target,
                  seconds = e.detail.seconds;
            var path = new URL(url);

            if (path.href.startsWith('https://www.youtube.com/watch?') && seconds) {
                path.search += '&t=' + seconds;
            }

            path = path.pathname + path.search;

            if (target === 'current') {
                location.href = path;
            } else if (target === 'new') {
                open(path, '_blank');
            }
        });

        helpers.xhr('GET', '/api/v1/annotations/' + video_data.id, {
            responseType: 'text',
            timeout: 60000
        }, {
            on200: function (response) {
                var video_container = document.getElementById('player');
                videojs.registerPlugin('youtubeAnnotationsPlugin', youtubeAnnotationsPlugin);
                if (player.paused()) {
                    player.one('play', function (event) {
                        player.youtubeAnnotationsPlugin({ annotationXml: response, videoContainer: video_container });
                    });
                } else {
                    player.youtubeAnnotationsPlugin({ annotationXml: response, videoContainer: video_container });
                }
            }
        });

    });
}

function change_volume(delta) {
    const curVolume = player.volume();
    let newVolume = curVolume + delta;
    newVolume = helpers.clamp(newVolume, 0, 1);
    player.volume(newVolume);
}

function toggle_muted() {
    player.muted(!player.muted());
}

function skip_seconds(delta) {
    const duration = player.duration();
    const curTime = player.currentTime();
    let newTime = curTime + delta;
    newTime = helpers.clamp(newTime, 0, duration);
    player.currentTime(newTime);
}

function set_seconds_after_start(delta) {
    const start = video_data.params.video_start;
    player.currentTime(start + delta);
}

function save_video_time(seconds) {
    const all_video_times = get_all_video_times();
    all_video_times[video_data.id] = seconds;
    helpers.storage.set(save_player_pos_key, all_video_times);
}

function get_video_time() {
    return get_all_video_times()[video_data.id] || 0;
}

function get_all_video_times() {
    return helpers.storage.get(save_player_pos_key) || {};
}

function remove_all_video_times() {
    helpers.storage.remove(save_player_pos_key);
}

function set_time_percent(percent) {
    const duration = player.duration();
    const newTime = duration * (percent / 100);
    player.currentTime(newTime);
}

function play()  { player.play(); }
function pause() { player.pause(); }
function stop()  { player.pause(); player.currentTime(0); }
function toggle_play() { player.paused() ? play() : pause(); }

const toggle_captions = (function () {
    let toggledTrack = null;

    function bindChange(onOrOff) {
        player.textTracks()[onOrOff]('change', function (e) {
            toggledTrack = null;
        });
    }

    // Wrapper function to ignore our own emitted events and only listen
    // to events emitted by Video.js on click on the captions menu items.
    function setMode(track, mode) {
        bindChange('off');
        track.mode = mode;
        setTimeout(function () {
            bindChange('on');
        }, 0);
    }

    bindChange('on');
    return function () {
        if (toggledTrack !== null) {
            if (toggledTrack.mode !== 'showing') {
                setMode(toggledTrack, 'showing');
            } else {
                setMode(toggledTrack, 'disabled');
            }
            toggledTrack = null;
            return;
        }

        // Used as a fallback if no captions are currently active.
        // TODO: Make this more intelligent by e.g. relying on browser language.
        let fallbackCaptionsTrack = null;

        const tracks = player.textTracks();
        for (let i = 0; i < tracks.length; i++) {
            const track = tracks[i];
            if (track.kind !== 'captions') continue;

            if (fallbackCaptionsTrack === null) {
                fallbackCaptionsTrack = track;
            }
            if (track.mode === 'showing') {
                setMode(track, 'disabled');
                toggledTrack = track;
                return;
            }
        }

        // Fallback if no captions are currently active.
        if (fallbackCaptionsTrack !== null) {
            setMode(fallbackCaptionsTrack, 'showing');
            toggledTrack = fallbackCaptionsTrack;
        }
    };
})();

function toggle_fullscreen() {
    player.isFullscreen() ? player.exitFullscreen() : player.requestFullscreen();
}

function increase_playback_rate(steps) {
    const maxIndex = options.playbackRates.length - 1;
    const curIndex = options.playbackRates.indexOf(player.playbackRate());
    let newIndex = curIndex + steps;
    newIndex = helpers.clamp(newIndex, 0, maxIndex);
    player.playbackRate(options.playbackRates[newIndex]);
}

addEventListener('keydown', function (e) {
    if (e.target.tagName.toLowerCase() === 'input') {
        // Ignore input when focus is on certain elements, e.g. form fields.
        return;
    }
    // See https://github.com/ctd1500/videojs-hotkeys/blob/bb4a158b2e214ccab87c2e7b95f42bc45c6bfd87/videojs.hotkeys.js#L310-L313
    const isPlayerFocused = false
        || e.target === document.querySelector('.video-js')
        || e.target === document.querySelector('.vjs-tech')
        || e.target === document.querySelector('.iframeblocker')
        || e.target === document.querySelector('.vjs-control-bar')
        ;
    let action = null;

    const code = e.keyCode;
    const decoratedKey =
        e.key
        + (e.altKey ? '+alt' : '')
        + (e.ctrlKey ? '+ctrl' : '')
        + (e.metaKey ? '+meta' : '')
        ;
    switch (decoratedKey) {
        case ' ':
        case 'k':
        case 'MediaPlayPause':
            action = toggle_play;
            break;

        case 'MediaPlay':  action = play; break;
        case 'MediaPause': action = pause; break;
        case 'MediaStop':  action = stop; break;

        case 'ArrowUp':
            if (isPlayerFocused) action = change_volume.bind(this, 0.1);
            break;
        case 'ArrowDown':
            if (isPlayerFocused) action = change_volume.bind(this, -0.1);
            break;

        case 'm':
            action = toggle_muted;
            break;

        case 'ArrowRight':
        case 'MediaFastForward':
            action = skip_seconds.bind(this, 5 * player.playbackRate());
            break;
        case 'ArrowLeft':
        case 'MediaTrackPrevious':
            action = skip_seconds.bind(this, -5 * player.playbackRate());
            break;
        case 'l':
            action = skip_seconds.bind(this, 10 * player.playbackRate());
            break;
        case 'j':
            action = skip_seconds.bind(this, -10 * player.playbackRate());
            break;

        case '0':
        case '1':
        case '2':
        case '3':
        case '4':
        case '5':
        case '6':
        case '7':
        case '8':
        case '9':
            // Ignore numpad numbers
            if (code > 57) break;

            const percent = (code - 48) * 10;
            action = set_time_percent.bind(this, percent);
            break;

        case 'c': action = toggle_captions; break;
        case 'f': action = toggle_fullscreen; break;

        case 'N':
        case 'MediaTrackNext':
            action = next_video;
            break;
        case 'P':
        case 'MediaTrackPrevious':
            // TODO: Add support to play back previous video.
            break;

        // TODO: More precise step. Now FPS is taken equal to 29.97
        // Common FPS: https://forum.videohelp.com/threads/81868#post323588
        // Possible solution is new HTMLVideoElement.requestVideoFrameCallback() https://wicg.github.io/video-rvfc/
        case ',': action = function () { pause(); skip_seconds(-1/29.97); }; break;
        case '.': action = function () { pause(); skip_seconds( 1/29.97); }; break;

        case '>': action = increase_playback_rate.bind(this, 1); break;
        case '<': action = increase_playback_rate.bind(this, -1); break;

        default:
            console.info('Unhandled key down event: %s:', decoratedKey, e);
            break;
    }

    if (action) {
        e.preventDefault();
        action();
    }
}, false);

// Add support for controlling the player volume by scrolling over it. Adapted from
// https://github.com/ctd1500/videojs-hotkeys/blob/bb4a158b2e214ccab87c2e7b95f42bc45c6bfd87/videojs.hotkeys.js#L292-L328
(function () {
    const pEl = document.getElementById('player');

    var volumeHover = false;
    var volumeSelector = pEl.querySelector('.vjs-volume-menu-button') || pEl.querySelector('.vjs-volume-panel');
    if (volumeSelector !== null) {
        volumeSelector.onmouseover = function () { volumeHover = true; };
        volumeSelector.onmouseout = function () { volumeHover = false; };
    }

    function mouseScroll(event) {
        // When controls are disabled, hotkeys will be disabled as well
        if (!player.controls() || !volumeHover) return;

        event.preventDefault();
        var wheelMove = event.wheelDelta || -event.detail;
        var volumeSign = Math.sign(wheelMove);

        change_volume(volumeSign * 0.05); // decrease/increase by 5%
    }

    player.on('mousewheel', mouseScroll);
    player.on('DOMMouseScroll', mouseScroll);
}());

// Since videojs-share can sometimes be blocked, we defer it until last
if (player.share) player.share(shareOptions);

// show the preferred caption by default
if (player_data.preferred_caption_found) {
    player.ready(function () {
        if (!video_data.params.listen && video_data.params.quality === 'dash') {
            // play.textTracks()[0] on DASH mode is showing some debug messages
            player.textTracks()[1].mode = 'showing';
        } else {
            player.textTracks()[0].mode = 'showing';
        }
    });
}

// Safari audio double duration fix
if (navigator.vendor === 'Apple Computer, Inc.' && video_data.params.listen) {
    player.on('loadedmetadata', function () {
        player.on('timeupdate', function () {
            if (player.remainingTime() < player.duration() / 2 && player.remainingTime() >= 2) {
                player.currentTime(player.duration() - 1);
            }
        });
    });
}

// Watch on Invidious link
if (location.pathname.startsWith('/embed/')) {
    const Button = videojs.getComponent('Button');
    let watch_on_invidious_button = new Button(player);

    // Create hyperlink for current instance
    var redirect_element = document.createElement('a');
    redirect_element.setAttribute('href', location.pathname.replace('/embed/', '/watch?v='));
    redirect_element.appendChild(document.createTextNode('Invidious'));

    watch_on_invidious_button.el().appendChild(redirect_element);
    watch_on_invidious_button.addClass('watch-on-invidious');

    var cb = player.getChild('ControlBar');
    cb.addChild(watch_on_invidious_button);
}

addEventListener('DOMContentLoaded', function () {
    // Save time during redirection on another instance
    const changeInstanceLink = document.querySelector('#watch-on-another-invidious-instance > a');
    if (changeInstanceLink) changeInstanceLink.addEventListener('click', function () {
        changeInstanceLink.href = addCurrentTimeToURL(changeInstanceLink.href);
    });
});
