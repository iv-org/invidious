'use strict';
var video_data = JSON.parse(document.getElementById('video_data').textContent);

function get_compilation(compid) {
    var compid_url;
    compid_url = '/api/v1/compilations/' + compid +
    '?index=' + video_data.index +
    '&continuation' + video_data.id +
    '&format=html&hl=' + video_data.preferences.locale;

    helpers.xhr('GET', compid_url, {retries: 5, entity_name: 'compilation'}, {
        on200: function (response) {
            if (!response.nextVideo)
                return;

            player.on('ended', function () {
                var url = new URL('https://example.com/embed/' + response.nextVideo);

                url.searchParams.set('comp', compid);
                if (!compid.startsWith('RD'))
                    url.searchParams.set('index', response.index);
                if (video_data.params.autoplay || video_data.params.continue_autoplay)
                    url.searchParams.set('autoplay', '1');
                if (video_data.params.listen !== video_data.preferences.listen)
                    url.searchParams.set('listen', video_data.params.listen);
                if (video_data.params.speed !== video_data.preferences.speed)
                    url.searchParams.set('speed', video_data.params.speed);
                if (video_data.params.local !== video_data.preferences.local)
                    url.searchParams.set('local', video_data.params.local);

                location.assign(url.pathname + url.search);
            });
        }
    });   
}

function get_playlist(plid) {
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

    helpers.xhr('GET', plid_url, {retries: 5, entity_name: 'playlist'}, {
        on200: function (response) {
            if (!response.nextVideo)
                return;

            player.on('ended', function () {
                var url = new URL('https://example.com/embed/' + response.nextVideo);

                url.searchParams.set('list', plid);
                if (!plid.startsWith('RD'))
                    url.searchParams.set('index', response.index);
                if (video_data.params.autoplay || video_data.params.continue_autoplay)
                    url.searchParams.set('autoplay', '1');
                if (video_data.params.listen !== video_data.preferences.listen)
                    url.searchParams.set('listen', video_data.params.listen);
                if (video_data.params.speed !== video_data.preferences.speed)
                    url.searchParams.set('speed', video_data.params.speed);
                if (video_data.params.local !== video_data.preferences.local)
                    url.searchParams.set('local', video_data.params.local);

                location.assign(url.pathname + url.search);
            });
        }
    });
}

addEventListener('load', function (e) {
    if (video_data.plid) {
        get_playlist(video_data.plid);
    } else if (video_data.compid) {
        get_compilation(video_data.compid)
    } else if (video_data.video_series) {
        player.on('ended', function () {
            var url = new URL('https://example.com/embed/' + video_data.video_series.shift());

            if (video_data.params.autoplay || video_data.params.continue_autoplay)
                url.searchParams.set('autoplay', '1');
            if (video_data.params.listen !== video_data.preferences.listen)
                url.searchParams.set('listen', video_data.params.listen);
            if (video_data.params.speed !== video_data.preferences.speed)
                url.searchParams.set('speed', video_data.params.speed);
            if (video_data.params.local !== video_data.preferences.local)
                url.searchParams.set('local', video_data.params.local);
            if (video_data.video_series.length !== 0)
                url.searchParams.set('playlist', video_data.video_series.join(','));

            location.assign(url.pathname + url.search);
        });
    }
});
