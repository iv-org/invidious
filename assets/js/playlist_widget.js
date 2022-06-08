'use strict';
var playlist_data = JSON.parse(document.getElementById('playlist_data').textContent);
var payload = 'csrf_token=' + playlist_data.csrf_token;

function add_playlist_video(target) {
    var select = target.parentNode.children[0].children[1];
    var option = select.children[select.selectedIndex];

    var url = '/playlist_ajax?action_add_video=1&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&playlist_id=' + option.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        on200: function (response) {
            option.textContent = '✓' + option.textContent;
        }
    });
}

function add_playlist_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/playlist_ajax?action_add_video=1&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&playlist_id=' + target.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}

function remove_playlist_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/playlist_ajax?action_remove_video=1&redirect=false' +
        '&set_video_id=' + target.getAttribute('data-index') +
        '&playlist_id=' + target.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}
