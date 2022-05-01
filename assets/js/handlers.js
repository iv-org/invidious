'use strict';

(function () {
    var n2a = function (n) { return Array.prototype.slice.call(n); };

    var video_player = document.getElementById('player_html5_api');
    if (video_player) {
        video_player.onmouseenter = function () { video_player['data-title'] = video_player['title']; video_player['title'] = ''; };
        video_player.onmouseleave = function () { video_player['title'] = video_player['data-title']; video_player['data-title'] = ''; };
        video_player.oncontextmenu = function () { video_player['title'] = video_player['data-title']; };
    }

    // For dynamically inserted elements
    document.addEventListener('click', function (e) {
        if (!e || !e.target) { return; }

        var t = e.target;
        var handler_name = t.getAttribute('data-onclick');

        switch (handler_name) {
            case 'jump_to_time':
                e.preventDefault();
                var time = t.getAttribute('data-jump-time');
                player.currentTime(time);
                break;
            case 'get_youtube_replies':
                var load_more = t.getAttribute('data-load-more') !== null;
                var load_replies = t.getAttribute('data-load-replies') !== null;
                get_youtube_replies(t, load_more, load_replies);
                break;
            case 'toggle_parent':
                toggle_parent(t);
                break;
            default:
                break;
        }
    });

    n2a(document.querySelectorAll('[data-mouse="switch_classes"]')).forEach(function (e) {
        var classes = e.getAttribute('data-switch-classes').split(',');
        var ec = classes[0];
        var lc = classes[1];
        var onoff = function (on, off) {
            var cs = e.getAttribute('class');
            cs = cs.split(off).join(on);
            e.setAttribute('class', cs);
        };
        e.onmouseenter = function () { onoff(ec, lc); };
        e.onmouseleave = function () { onoff(lc, ec); };
    });

    n2a(document.querySelectorAll('[data-onsubmit="return_false"]')).forEach(function (e) {
        e.onsubmit = function () { return false; };
    });

    n2a(document.querySelectorAll('[data-onclick="mark_watched"]')).forEach(function (e) {
        e.onclick = function () { mark_watched(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="mark_unwatched"]')).forEach(function (e) {
        e.onclick = function () { mark_unwatched(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="add_playlist_video"]')).forEach(function (e) {
        e.onclick = function () { add_playlist_video(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="add_playlist_item"]')).forEach(function (e) {
        e.onclick = function () { add_playlist_item(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="remove_playlist_item"]')).forEach(function (e) {
        e.onclick = function () { remove_playlist_item(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="revoke_token"]')).forEach(function (e) {
        e.onclick = function () { revoke_token(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="remove_subscription"]')).forEach(function (e) {
        e.onclick = function () { remove_subscription(e); };
    });
    n2a(document.querySelectorAll('[data-onclick="notification_requestPermission"]')).forEach(function (e) {
        e.onclick = function () { Notification.requestPermission(); };
    });

    n2a(document.querySelectorAll('[data-onrange="update_volume_value"]')).forEach(function (e) {
        var cb = function () { update_volume_value(e); };
        e.oninput = cb;
        e.onchange = cb;
    });

    function update_volume_value(element) {
        document.getElementById('volume-value').innerText = element.value;
    }

    function revoke_token(target) {
        var row = target.parentNode.parentNode.parentNode.parentNode.parentNode;
        row.style.display = 'none';
        var count = document.getElementById('count');
        count.innerText = count.innerText - 1;

        var referer = window.encodeURIComponent(document.location.href);
        var url = '/token_ajax?action_revoke_token=1&redirect=false' +
            '&referer=' + referer +
            '&session=' + target.getAttribute('data-session');
        var xhr = new XMLHttpRequest();
        xhr.responseType = 'json';
        xhr.timeout = 10000;
        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                if (xhr.status !== 200) {
                    count.innerText = parseInt(count.innerText) + 1;
                    row.style.display = '';
                }
            }
        };

        var csrf_token = target.parentNode.querySelector('input[name="csrf_token"]').value;
        xhr.send('csrf_token=' + csrf_token);
    }

    function remove_subscription(target) {
        var row = target.parentNode.parentNode.parentNode.parentNode.parentNode;
        row.style.display = 'none';
        var count = document.getElementById('count');
        count.innerText = count.innerText - 1;

        var referer = window.encodeURIComponent(document.location.href);
        var url = '/subscription_ajax?action_remove_subscriptions=1&redirect=false' +
            '&referer=' + referer +
            '&c=' + target.getAttribute('data-ucid');
        var xhr = new XMLHttpRequest();
        xhr.responseType = 'json';
        xhr.timeout = 10000;
        xhr.open('POST', url, true);
        xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

        xhr.onreadystatechange = function () {
            if (xhr.readyState === 4) {
                if (xhr.status !== 200) {
                    count.innerText = parseInt(count.innerText) + 1;
                    row.style.display = '';
                }
            }
        };

        var csrf_token = target.parentNode.querySelector('input[name="csrf_token"]').value;
        xhr.send('csrf_token=' + csrf_token);
    }

    // Handle keypresses
    window.addEventListener('keydown', function (event) {
        // Ignore modifier keys
        if (event.ctrlKey || event.metaKey) return;

        // Ignore shortcuts if any text input is focused
        let focused_tag = document.activeElement.tagName.toLowerCase();
        const allowed = /^(button|checkbox|file|radio|submit)$/;

        if (focused_tag === 'textarea') return;
        if (focused_tag === 'input') {
            let focused_type = document.activeElement.type.toLowerCase();
            if (!focused_type.match(allowed)) return;
        }

        // Focus search bar on '/'
        if (event.key === '/') {
            document.getElementById('searchbox').focus();
            event.preventDefault();
        }
    });
})();
