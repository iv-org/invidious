'use strict';
var watched_data = JSON.parse(document.getElementById('watched_data').textContent);
var payload = 'csrf_token=' + watched_data.csrf_token;

function mark_watched(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/watch_ajax?action_mark_watched=1&redirect=false' +
        '&id=' + target.getAttribute('data-id');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}

function mark_unwatched(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';
    var count = document.getElementById('count');
    count.textContent--;

    var url = '/watch_ajax?action_mark_unwatched=1&redirect=false' +
        '&id=' + target.getAttribute('data-id');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            count.textContent++;
            tile.style.display = '';
        }
    });
}

var save_player_pos_key = 'save_player_pos';

function get_all_video_times() {
    return helpers.storage.get(save_player_pos_key) || {};
}

document.querySelectorAll('.watched-indicator').forEach(function (indicator) {
    var watched_part = get_all_video_times()[indicator.dataset.id];
    var total = parseInt(indicator.dataset.length, 10);
    if (watched_part === undefined) {
        watched_part = total;
    }
    var percentage = Math.round((watched_part / total) * 100);

    if (percentage < 5) {
        percentage = 5;
    }
    if (percentage > 90) {
        percentage = 100;
    }

    indicator.style.width = percentage + '%';
});
