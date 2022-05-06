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
    count.innerText = parseInt(count.innerText) - 1;

    var url = '/watch_ajax?action_mark_unwatched=1&redirect=false' +
        '&id=' + target.getAttribute('data-id');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            count.innerText = parseInt(count.innerText) + 1;
            tile.style.display = '';
        }
    });
}
