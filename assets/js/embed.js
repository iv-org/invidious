'use strict';
var video_data = JSON.parse(document.getElementById('video_data').textContent);

function get_playlist(plid, retries) {
    if (retries === undefined) retries = 5;

    if (retries <= 0) {
        console.warn('Failed to pull playlist');
        return;
    }

    var plid_url;
    if (plid.startsWith('RD')) {
        plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    } else {
        plid_url = '/api/v1/playlists/' + plid +
            '?index=' + video_data.index +
            '&continuation' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', plid_url, true);

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                if (xhr.response.nextVideo) {
                    player.on('ended', function () {
                        var url = new URL('https://example.com/embed/' + xhr.response.nextVideo);

                        url.searchParams.set('list', plid);
                        if (!plid.startsWith('RD')) {
                            url.searchParams.set('index', xhr.response.index);
                        }

                        if (video_data.params.autoplay || video_data.params.continue_autoplay) {
                            url.searchParams.set('autoplay', '1');
                        }

                        if (video_data.params.listen !== video_data.preferences.listen) {
                            url.searchParams.set('listen', video_data.params.listen);
                        }

                        if (video_data.params.speed !== video_data.preferences.speed) {
                            url.searchParams.set('speed', video_data.params.speed);
                        }

                        if (video_data.params.local !== video_data.preferences.local) {
                            url.searchParams.set('local', video_data.params.local);
                        }

                        location.assign(url.pathname + url.search);
                    });
                }
            }
        }
    };

    xhr.onerror = function () {
        console.warn('Pulling playlist failed... ' + retries + '/5');
        setTimeout(function () { get_playlist(plid, retries - 1); }, 1000);
    };

    xhr.ontimeout = function () {
        console.warn('Pulling playlist failed... ' + retries + '/5');
        get_playlist(plid, retries - 1);
    };

    xhr.send();
}

window.addEventListener('load', function (e) {
    if (video_data.plid) {
        get_playlist(video_data.plid);
    } else if (video_data.video_series) {
        player.on('ended', function () {
            var url = new URL('https://example.com/embed/' + video_data.video_series.shift());

            if (video_data.params.autoplay || video_data.params.continue_autoplay) {
                url.searchParams.set('autoplay', '1');
            }

            if (video_data.params.listen !== video_data.preferences.listen) {
                url.searchParams.set('listen', video_data.params.listen);
            }

            if (video_data.params.speed !== video_data.preferences.speed) {
                url.searchParams.set('speed', video_data.params.speed);
            }

            if (video_data.params.local !== video_data.preferences.local) {
                url.searchParams.set('local', video_data.params.local);
            }

            if (video_data.video_series.length !== 0) {
                url.searchParams.set('playlist', video_data.video_series.join(','));
            }

            location.assign(url.pathname + url.search);
        });
    }
});
