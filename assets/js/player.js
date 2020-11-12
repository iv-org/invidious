var player_data = JSON.parse(document.getElementById('player_data').innerHTML);
var video_data = JSON.parse(document.getElementById('video_data').innerHTML);

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
            'captionsButton',
            'qualitySelector',
            'playbackRateMenuButton',
            'fullscreenToggle'
        ]
    }
}

if (player_data.aspect_ratio) {
    options.aspectRatio = player_data.aspect_ratio;
}

var embed_url = new URL(location);
embed_url.searchParams.delete('v');
short_url = location.origin + '/' + video_data.id + embed_url.search;
embed_url = location.origin + '/embed/' + video_data.id + embed_url.search;

var shareOptions = {
    socials: ['fbFeed', 'tw', 'reddit', 'email'],

    url: short_url,
    title: player_data.title,
    description: player_data.description,
    image: player_data.thumbnail,
    embedCode: "<iframe id='ivplayer' width='640' height='360' src='" + embed_url + "' style='border:none;'></iframe>"
}

var player = videojs('player', options);

if (location.pathname.startsWith('/embed/')) {
    player.overlay({
        overlays: [{
            start: 'loadstart',
            content: '<h1><a rel="noopener" target="_blank" href="' + location.origin + '/watch?v=' + video_data.id + '">' + player_data.title + '</a></h1>',
            end: 'playing',
            align: 'top'
        }, {
            start: 'pause',
            content: '<h1><a rel="noopener" target="_blank" href="' + location.origin + '/watch?v=' + video_data.id + '">' + player_data.title + '</a></h1>',
            end: 'playing',
            align: 'top'
        }]
    });
}

player.on('error', function (event) {
    if (player.error().code === 2 || player.error().code === 4) {
        setInterval(setTimeout(function (event) {
            console.log('An error occured in the player, reloading...');

            var currentTime = player.currentTime();
            var playbackRate = player.playbackRate();
            var paused = player.paused();

            player.load();

            if (currentTime > 0.5) {
                currentTime -= 0.5;
            }

            player.currentTime(currentTime);
            player.playbackRate(playbackRate);

            if (!paused) {
                player.play();
            }
        }, 5000), 5000);
    }
});

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
            if (marker.text === 'End') {
                if (player.loop()) {
                    player.markers.prev('Start');
                } else {
                    player.pause();
                }
            }
        },
        markers: markers
    });

    player.currentTime(video_data.params.video_start);
}

player.volume(video_data.params.volume / 100);
player.playbackRate(video_data.params.speed);

player.on('waiting', function () {
    if (player.playbackRate() > 1 && player.liveTracker.isLive() && player.liveTracker.atLiveEdge()) {
        console.log('Player has caught up to source, resetting playbackRate.')
        player.playbackRate(1);
    }
});

if (video_data.premiere_timestamp && Math.round(new Date() / 1000) < video_data.premiere_timestamp) {
    player.getChild('bigPlayButton').hide();
}

if (video_data.params.autoplay) {
    var bpb = player.getChild('bigPlayButton');
    bpb.hide();

    player.ready(function () {
        new Promise(function (resolve, reject) {
            setTimeout(() => resolve(1), 1);
        }).then(function (result) {
            var promise = player.play();

            if (promise !== undefined) {
                promise.then(_ => {
                }).catch(error => {
                    bpb.show();
                });
            }
        });
    });
}

if (!video_data.params.listen && video_data.params.quality === 'dash') {
    player.httpSourceSelector();
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
        }

        window.addEventListener('__ar_annotation_click', e => {
            const { url, target, seconds } = e.detail;
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

function set_time_percent(percent) {
    const duration = player.duration();
    const newTime = duration * (percent / 100);
    player.currentTime(newTime);
}

function play() {
    player.play();
}

function pause() {
    player.pause();
}

function stop() {
    player.pause();
    player.currentTime(0);
}

function toggle_play() {
    if (player.paused()) {
        play();
    } else {
        pause();
    }
}

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
            if (track.kind !== 'captions') {
                continue;
            }

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
    if (player.isFullscreen()) {
        player.exitFullscreen();
    } else {
        player.requestFullscreen();
    }
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

window.addEventListener('keydown', e => {
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

        case 'MediaPlay':
            action = play;
            break;

        case 'MediaPause':
            action = pause;
            break;

        case 'MediaStop':
            action = stop;
            break;

        case 'ArrowUp':
            if (isPlayerFocused) {
                action = increase_volume.bind(this, 0.1);
            }
            break;
        case 'ArrowDown':
            if (isPlayerFocused) {
                action = increase_volume.bind(this, -0.1);
            }
            break;

        case 'm':
            action = toggle_muted;
            break;

        case 'ArrowRight':
        case 'MediaFastForward':
            action = skip_seconds.bind(this, 5);
            break;
        case 'ArrowLeft':
        case 'MediaTrackPrevious':
            action = skip_seconds.bind(this, -5);
            break;
        case 'l':
            action = skip_seconds.bind(this, 10);
            break;
        case 'j':
            action = skip_seconds.bind(this, -10);
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
            const percent = (code - 48) * 10;
            action = set_time_percent.bind(this, percent);
            break;

        case 'c':
            action = toggle_captions;
            break;
        case 'f':
            action = toggle_fullscreen;
            break;

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

        case '>':
            action = increase_playback_rate.bind(this, 1);
            break;
        case '<':
            action = increase_playback_rate.bind(this, -1);
            break;

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
    if (volumeSelector != null) {
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

                    if (delta == 1) {
                        increase_volume(volumeStep);
                    } else if (delta == -1) {
                        increase_volume(-volumeStep);
                    }
                }
            }
        }
    };

    player.on('mousewheel', mouseScroll);
    player.on("DOMMouseScroll", mouseScroll);
}());

// Since videojs-share can sometimes be blocked, we defer it until last
player.share(shareOptions);
