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
    if (options.uri.indexOf('videoplayback') === -1 && options.uri.indexOf('local=true') === -1) {
        options.uri = options.uri + '?local=true';
    }
    return options;
};

var player = videojs('player', options);

player.on('error', () => {
    if (video_data.params.quality !== 'dash') {
        if (!player.currentSrc().includes("local=true") && !video_data.local_disabled) {
            var currentSources = player.currentSources();
            for (var i = 0; i < currentSources.length; i++) {
                currentSources[i]["src"] += "&local=true"
            }
            player.src(currentSources)
        }
        else if (player.error().code === 2 || player.error().code === 4) {
            setTimeout(function (event) {
                console.log('An error occurred in the player, reloading...');
    
                var currentTime = player.currentTime();
                var playbackRate = player.playbackRate();
                var paused = player.paused();
    
                player.load();
    
                if (currentTime > 0.5) currentTime -= 0.5;
    
                player.currentTime(currentTime);
                player.playbackRate(playbackRate);
    
                if (!paused) player.play();
            }, 10000);
        }
    }
});

if (video_data.params.quality == 'dash') {
    player.reloadSourceOnError({
        errorInterval: 10
    });
}

/**
 * Function for add time argument to url
 * @param {String} url
 * @returns urlWithTimeArg
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
        return '<iframe id="ivplayer" width="640" height="360" src="' +
            addCurrentTimeToURL(embed_url) + '" style="border:none;"></iframe>';
    }
};

const storage = (function () {
    try { if (localStorage.length !== -1) return localStorage; }
    catch (e) { console.info('No storage available: ' + e); }

    return undefined;
})();

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
    player.mobileUi();

    var buttons = ['playToggle', 'volumePanel', 'captionsButton'];

    if (video_data.params.quality !== 'dash') buttons.push('qualitySelector');

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
    operations_bar_element.className += ' mobile-operations-bar';
    player.addChild(operations_bar);

    // Playback menu doesn't work when it's initialized outside of the primary control bar
    var playback_element = document.getElementsByClassName('vjs-playback-rate')[0];
    operations_bar_element.append(playback_element);

    // The share and http source selector element can't be fetched till the players ready.
    player.one('playing', function () {
        var share_element = document.getElementsByClassName('vjs-share-control')[0];
        operations_bar_element.append(share_element);

        if (video_data.params.quality === 'dash') {
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
 * @returns cookieValue
 */
function getCookieValue(name) {
    var value = document.cookie.split(';').filter(function (item) {return item.includes(name + '=');});

    return (value.length >= 1)
        ? value[0].substring((name + '=').length, value[0].length)
        : null;
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
    date.setTime(date.getTime() + 63115200);

    var ipRegex = /^((\d+\.){3}\d+|[A-Fa-f0-9]*:[A-Fa-f0-9:]*:[A-Fa-f0-9:]+)$/;
    var domainUsed = window.location.hostname;

    // Fix for a bug in FF where the leading dot in the FQDN is not ignored
    if (domainUsed.charAt(0) !== '.' && !ipRegex.test(domainUsed) && domainUsed !== 'localhost')
        domainUsed = '.' + window.location.hostname;

    document.cookie = 'PREFS=' + cookieData + '; SameSite=Strict; path=/; domain=' +
        domainUsed + '; expires=' + date.toGMTString() + ';';

    video_data.params.volume = volumeValue;
    video_data.params.speed = speedValue;
}

player.on('ratechange', function () {
    updateCookie(null, player.playbackRate());
});

player.on('volumechange', function () {
    updateCookie(Math.ceil(player.volume() * 100), null);
});

player.on('waiting', function () {
    if (player.playbackRate() > 1 && player.liveTracker.isLive() && player.liveTracker.atLiveEdge()) {
        console.info('Player has caught up to source, resetting playbackRate.');
        player.playbackRate(1);
    }
});

if (video_data.premiere_timestamp && Math.round(new Date() / 1000) < video_data.premiere_timestamp) {
    player.getChild('bigPlayButton').hide();
}

if (video_data.params.save_player_pos) {
    const url = new URL(location);
    const hasTimeParam = url.searchParams.has('t');
    const remeberedTime = get_video_time();
    let lastUpdated = 0;

    if(!hasTimeParam) set_seconds_after_start(remeberedTime);

    const updateTime = function () {
        const raw = player.currentTime();
        const time = Math.floor(raw);

        if(lastUpdated !== time && raw <= video_data.length_seconds - 15) {
            save_video_time(time);
            lastUpdated = time;
        }
    };

    player.on('timeupdate', updateTime);
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
                        const targetHeight = Number.parseInt(video_data.params.quality_dash, 10);
                        for (let i = 0; i < qualityLevels.length; i++) {
                            if (qualityLevels[i].height <= targetHeight) {
                                targetQualityLevel = i;
                            } else {
                                break;
                            }
                        }
                }
                for (let i = 0; i < qualityLevels.length; i++) {
                    qualityLevels[i].enabled = (i === targetQualityLevel);
                }
            });
        });
    }
}

player.vttThumbnails({
    src: location.origin + '/api/v1/storyboards/' + video_data.id + '?height=90',
    showTimestamp: true
});

// Enable annotations
if (!video_data.params.listen && video_data.params.annotations) {
    window.addEventListener('load', function (e) {
        var video_container = document.getElementById('player');
        let xhr = new XMLHttpRequest();
        xhr.responseType = 'text';
        xhr.timeout = 60000;
        xhr.open('GET', '/api/v1/annotations/' + video_data.id, true);

        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                if (xhr.status === 200) {
                    videojs.registerPlugin('youtubeAnnotationsPlugin', youtubeAnnotationsPlugin);
                    if (!player.paused()) {
                        player.youtubeAnnotationsPlugin({ annotationXml: xhr.response, videoContainer: video_container });
                    } else {
                        player.one('play', function (event) {
                            player.youtubeAnnotationsPlugin({ annotationXml: xhr.response, videoContainer: video_container });
                        });
                    }
                }
            }
        };

        window.addEventListener('__ar_annotation_click', function (e) {
            const url = e.detail.url,
                  target = e.detail.target,
                  seconds = e.detail.seconds;
            var path = new URL(url);

            if (path.href.startsWith('https://www.youtube.com/watch?') && seconds) {
                path.search += '&t=' + seconds;
            }

            path = path.pathname + path.search;

            if (target === 'current') {
                window.location.href = path;
            } else if (target === 'new') {
                window.open(path, '_blank');
            }
        });

        xhr.send();
    });
}

function increase_volume(delta) {
    const curVolume = player.volume();
    let newVolume = curVolume + delta;
    if (newVolume > 1) {
        newVolume = 1;
    } else if (newVolume < 0) {
        newVolume = 0;
    }
    player.volume(newVolume);
}

function toggle_muted() {
    const isMuted = player.muted();
    player.muted(!isMuted);
}

function skip_seconds(delta) {
    const duration = player.duration();
    const curTime = player.currentTime();
    let newTime = curTime + delta;
    if (newTime > duration) {
        newTime = duration;
    } else if (newTime < 0) {
        newTime = 0;
    }
    player.currentTime(newTime);
}

function set_seconds_after_start(delta) {
    const start = video_data.params.video_start;
    player.currentTime(start + delta);
}

function save_video_time(seconds) {
    const videoId = video_data.id;
    const all_video_times = get_all_video_times();

    all_video_times[videoId] = seconds;

    set_all_video_times(all_video_times);
}

function get_video_time() {
    try {
        const videoId = video_data.id;
        const all_video_times = get_all_video_times();
        const timestamp = all_video_times[videoId];

        return timestamp || 0;
    }
    catch (e) {
        return 0;
    }
}

function set_all_video_times(times) {
    if (storage) {
        if (times) {
            try {
                storage.setItem(save_player_pos_key, JSON.stringify(times));
            } catch (e) {
                console.warn('set_all_video_times: ' + e);
            }
        } else {
            storage.removeItem(save_player_pos_key);
        }
    }
}

function get_all_video_times() {
    if (storage) {
        const raw = storage.getItem(save_player_pos_key);
        if (raw !== null) {
            try {
                return JSON.parse(raw);
            } catch (e) {
                console.warn('get_all_video_times: ' + e);
            }
        }
    }
    return {};
}

function remove_all_video_times() {
    set_all_video_times(null);
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
    const onChange = function (e) {
        toggledTrack = null;
    };
    const bindChange = function (onOrOff) {
        player.textTracks()[onOrOff]('change', onChange);
    };
    // Wrapper function to ignore our own emitted events and only listen
    // to events emitted by Video.js on click on the captions menu items.
    const setMode = function (track, mode) {
        bindChange('off');
        track.mode = mode;
        window.setTimeout(function () {
            bindChange('on');
        }, 0);
    };
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
    if (newIndex > maxIndex) {
        newIndex = maxIndex;
    } else if (newIndex < 0) {
        newIndex = 0;
    }
    player.playbackRate(options.playbackRates[newIndex]);
}

window.addEventListener('keydown', function (e) {
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
            if (isPlayerFocused) action = increase_volume.bind(this, 0.1);
            break;
        case 'ArrowDown':
            if (isPlayerFocused) action = increase_volume.bind(this, -0.1);
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

        case '.':
            // TODO: Add support for next-frame-stepping.
            break;
        case ',':
            // TODO: Add support for previous-frame-stepping.
            break;

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
    const volumeStep = 0.05;
    const enableVolumeScroll = true;
    const enableHoverScroll = true;
    const doc = document;
    const pEl = document.getElementById('player');

    var volumeHover = false;
    var volumeSelector = pEl.querySelector('.vjs-volume-menu-button') || pEl.querySelector('.vjs-volume-panel');
    if (volumeSelector !== null) {
        volumeSelector.onmouseover = function () { volumeHover = true; };
        volumeSelector.onmouseout = function () { volumeHover = false; };
    }

    var mouseScroll = function mouseScroll(event) {
        var activeEl = doc.activeElement;
        if (enableHoverScroll) {
            // If we leave this undefined then it can match non-existent elements below
            activeEl = 0;
        }

        // When controls are disabled, hotkeys will be disabled as well
        if (player.controls()) {
            if (volumeHover) {
                if (enableVolumeScroll) {
                    event = window.event || event;
                    var delta = Math.max(-1, Math.min(1, (event.wheelDelta || -event.detail)));
                    event.preventDefault();

                    if (delta === 1) {
                        increase_volume(volumeStep);
                    } else if (delta === -1) {
                        increase_volume(-volumeStep);
                    }
                }
            }
        }
    };

    player.on('mousewheel', mouseScroll);
    player.on('DOMMouseScroll', mouseScroll);
}());

// Since videojs-share can sometimes be blocked, we defer it until last
if (player.share) {
    player.share(shareOptions);
}

// show the preferred caption by default
if (player_data.preferred_caption_found) {
    player.ready(function () {
        player.textTracks()[1].mode = 'showing';
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
if (window.location.pathname.startsWith('/embed/')) {
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
