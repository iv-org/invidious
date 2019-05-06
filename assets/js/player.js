var options = {
    preload: "auto",
    playbackRates: [0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 2.0],
    controlBar: {
        children: [
            "playToggle",
            "volumePanel",
            "currentTimeDisplay",
            "timeDivider",
            "durationDisplay",
            "progressControl",
            "remainingTimeDisplay",
            "captionsButton",
            "qualitySelector",
            "playbackRateMenuButton",
            "fullscreenToggle"
        ]
    }
}

if (player_data.aspect_ratio) {
    options.aspectRatio = player_data.aspect_ratio;
}

var embed_url = new URL(location);
embed_url.searchParams.delete('v');
embed_url = location.origin + '/embed/' + video_data.id + embed_url.search;

var shareOptions = {
    socials: ["fbFeed", "tw", "reddit", "email"],

    url: window.location.href,
    title: player_data.title,
    description: player_data.description,
    image: player_data.thumbnail,
    embedCode: "<iframe id='ivplayer' type='text/html' width='640' height='360' src='" + embed_url + "' frameborder='0'></iframe>"
}

var player = videojs("player", options, function () {
    this.hotkeys({
        volumeStep: 0.1,
        seekStep: 5,
        enableModifiersForNumbers: false,
        enableHoverScroll: true,
        customKeys: {
            // Toggle play with K Key
            play: {
                key: function (e) {
                    return e.which === 75;
                },
                handler: function (player, options, e) {
                    if (player.paused()) {
                        player.play();
                    } else {
                        player.pause();
                    }
                }
            },
            // Go backward 10 seconds
            backward: {
                key: function (e) {
                    return e.which === 74;
                },
                handler: function (player, options, e) {
                    player.currentTime(player.currentTime() - 10);
                }
            },
            // Go forward 10 seconds
            forward: {
                key: function (e) {
                    return e.which === 76;
                },
                handler: function (player, options, e) {
                    player.currentTime(player.currentTime() + 10);
                }
            },
            // Increase speed
            increase_speed: {
                key: function (e) {
                    return (e.which === 190 && e.shiftKey);
                },
                handler: function (player, _, e) {
                    size = options.playbackRates.length;
                    index = options.playbackRates.indexOf(player.playbackRate());
                    player.playbackRate(options.playbackRates[(index + 1) % size]);
                }
            },
            // Decrease speed
            decrease_speed: {
                key: function (e) {
                    return (e.which === 188 && e.shiftKey);
                },
                handler: function (player, _, e) {
                    size = options.playbackRates.length;
                    index = options.playbackRates.indexOf(player.playbackRate());
                    player.playbackRate(options.playbackRates[(size + index - 1) % size]);
                }
            }
        }
    });
});

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

if (video_data.params.autoplay) {
    var bpb = player.getChild('bigPlayButton');

    if (bpb) {
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
}

if (!video_data.params.listen && video_data.params.quality === 'dash') {
    player.httpSourceSelector();
}

player.vttThumbnails({
    src: location.origin + '/api/v1/storyboards/' + video_data.id + '?height=90'
});

// Enable annotations
if (video_data.params.listen && video_data.params.annotations) {
    var video_container = document.getElementById('player');
    let xhr = new XMLHttpRequest();
    xhr.responseType = 'text';
    xhr.timeout = 60000;
    xhr.open('GET', '/api/v1/annotations/' + video_data.id, true);
    xhr.send();

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
}

// Since videojs-share can sometimes be blocked, we defer it until last
player.share(shareOptions);
