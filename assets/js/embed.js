function get_playlist(plid, timeouts = 0) {
    if (timeouts > 10) {
        console.log('Failed to pull playlist');
        return;
    }

    if (plid.startsWith('RD')) {
        var plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + embed_data.id +
            '&format=html&hl=' + embed_data.preferences.locale;
    } else {
        var plid_url = '/api/v1/playlists/' + plid +
            '?continuation=' + embed_data.id +
            '&format=html&hl=' + embed_data.preferences.locale;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', plid_url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status == 200) {
                if (xhr.response.nextVideo) {
                    player.on('ended', function () {
                        var url = new URL('https://example.com/embed/' + xhr.response.nextVideo);

                        if (embed_data.params.autoplay || embed_data.params.continue_autoplay) {
                            url.searchParams.set('autoplay', '1');
                        }

                        if (embed_data.params.listen !== embed_data.preferences.listen) {
                            url.searchParams.set('listen', embed_data.params.listen);
                        }

                        if (embed_data.params.speed !== embed_data.preferences.speed) {
                            url.searchParams.set('speed', embed_data.params.speed);
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

if (embed_data.plid) {
    get_playlist(embed_data.plid);
} else if (embed_data.video_series) {
    player.on('ended', function () {
        var url = new URL('https://example.com/embed/' + embed_data.video_series.shift());

        if (embed_data.params.autoplay || embed_data.params.continue_autoplay) {
            url.searchParams.set('autoplay', '1');
        }

        if (embed_data.params.listen !== embed_data.preferences.listen) {
            url.searchParams.set('listen', embed_data.params.listen);
        }

        if (embed_data.params.speed !== embed_data.preferences.speed) {
            url.searchParams.set('speed', embed_data.params.speed);
        }

        if (embed_data.video_series.length !== 0) {
            url.searchParams.set('playlist', embed_data.video_series.join(','))
        }

        location.assign(url.pathname + url.search);
    });
}
