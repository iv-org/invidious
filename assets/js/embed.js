function get_playlist(plid, timeouts = 0) {
    if (timeouts > 10) {
        console.log('Failed to pull playlist');
        return;
    }

    if (plid.startsWith('RD')) {
        var plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    } else {
        var plid_url = '/api/v1/playlists/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', plid_url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                if (xhr.response.nextVideo) {
                    player.on('ended', function () {
                        var url = new URL('https://example.com/embed/' + xhr.response.nextVideo);

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

                        url.searchParams.set('list', plid);
                        location.assign(url.pathname + url.search);
                    });
                }
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling playlist timed out.');
        get_playlist(plid, timeouts + 1);
    }
}

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
            url.searchParams.set('playlist', video_data.video_series.join(','))
        }

        location.assign(url.pathname + url.search);
    });
}
