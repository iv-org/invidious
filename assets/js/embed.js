'use strict';
var video_data = JSON.parse(document.getElementById('video_data').textContent);

function set_search_params() {
  if (video_data.params.autoplay || video_data.params.continue_autoplay)
      url.searchParams.set('autoplay', '1');

  ['listen', 'speed', 'local'].forEach(p => {
    if (video_data.params[p] !== video_data.preferences[p])
        url.searchParams.set(p, video_data.params[p]);
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
                set_search_params();

                location.assign(url.pathname + url.search);
            });
        }
    });
}

addEventListener('load', function (e) {
    if (video_data.plid) {
        get_playlist(video_data.plid);
    } else if (video_data.video_series) {
        player.on('ended', function () {
            var url = new URL('https://example.com/embed/' + video_data.video_series.shift());

            set_search_params();
            if (video_data.video_series.length !== 0)
                url.searchParams.set('playlist', video_data.video_series.join(','));

            location.assign(url.pathname + url.search);
        });
    }
});
