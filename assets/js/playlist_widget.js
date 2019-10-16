function add_playlist_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/playlist_ajax?action_add_video=1&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&playlist_id=' + target.getAttribute('data-plid');
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status != 200) {
                tile.style.display = '';
            }
        }
    }

    xhr.send('csrf_token=' + playlist_data.csrf_token);
}

function remove_playlist_item(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/playlist_ajax?action_remove_video=1&redirect=false' +
        '&set_video_id=' + target.getAttribute('data-index') +
        '&playlist_id=' + target.getAttribute('data-plid');
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status != 200) {
                tile.style.display = '';
            }
        }
    }

    xhr.send('csrf_token=' + playlist_data.csrf_token);
}