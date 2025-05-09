'use strict';
var compilation_data = JSON.parse(document.getElementById('compilation_data').textContent);
var payload = 'csrf_token=' + compilation_data.csrf_token;

function add_compilation_video(target) {
    var select = target.parentNode.children[0].children[1];
    var option = select.children[select.selectedIndex];

    var url = '/compilation_ajax?action_add_video=1&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&compilation_id=' + option.getAttribute('data-compid');

    helpers.xhr('POST', url, {payload: payload}, {
        on200: function (response) {
            option.textContent = '✓' + option.textContent;
        }
    });
}

function add_compilation_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/compilation_ajax?action_add_video=1&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&compilation_id=' + target.getAttribute('data-compid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}

function remove_compilation_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/compilation_ajax?action_remove_video=1&redirect=false' +
        '&set_video_id=' + target.getAttribute('data-index') +
        '&compilation_id=' + target.getAttribute('data-compid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}

function move_compilation_video_before(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/compilation_ajax?action_move_video_before=1&redirect=false' +
        '&set_video_id=' + target.getAttribute('data-index') +
        '&compilation_id=' + target.getAttribute('data-compid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
            tile.style.display = '';
        }
    });
}
