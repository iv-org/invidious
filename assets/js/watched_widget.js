'use strict';
var watched_data = JSON.parse(document.getElementById('watched_data').textContent);

function mark_watched(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';

    var url = '/watch_ajax?action_mark_watched=1&redirect=false' +
        '&id=' + target.getAttribute('data-id');
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status !== 200) {
                tile.style.display = '';
            }
        }
    };

    xhr.send('csrf_token=' + watched_data.csrf_token);
}

function mark_unwatched(target) {
    var tile = target.parentNode.parentNode.parentNode.parentNode.parentNode;
    tile.style.display = 'none';
    var count = document.getElementById('count');
    count.innerText = count.innerText - 1;

    var url = '/watch_ajax?action_mark_unwatched=1&redirect=false' +
        '&id=' + target.getAttribute('data-id');
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status !== 200) {
                count.innerText = count.innerText - 1 + 2;
                tile.style.display = '';
            }
        }
    };

    xhr.send('csrf_token=' + watched_data.csrf_token);
}
