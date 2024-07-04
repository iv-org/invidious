'use strict';
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
