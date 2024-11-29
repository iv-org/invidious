'use strict';

(function () {
    var video_player = document.getElementById('player_html5_api');
    if (video_player) {
        video_player.onmouseenter = function () { video_player['data-title'] = video_player['title']; video_player['title'] = ''; };
        video_player.onmouseleave = function () { video_player['title'] = video_player['data-title']; video_player['data-title'] = ''; };
        video_player.oncontextmenu = function () { video_player['title'] = video_player['data-title']; };
    }

    // For dynamically inserted elements
    addEventListener('click', function (e) {
        if (!e || !e.target) return;

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
                e.preventDefault();
                toggle_parent(t);
                break;
            default:
                break;
        }
    });

    document.querySelectorAll('[data-mouse="switch_classes"]').forEach(function (el) {
        var classes = el.getAttribute('data-switch-classes').split(',');
        var classOnEnter = classes[0];
        var classOnLeave = classes[1];
        function toggle_classes(toAdd, toRemove) {
            el.classList.add(toAdd);
            el.classList.remove(toRemove);
        }
        el.onmouseenter = function () { toggle_classes(classOnEnter, classOnLeave); };
        el.onmouseleave = function () { toggle_classes(classOnLeave, classOnEnter); };
    });

    document.querySelectorAll('[data-onsubmit="return_false"]').forEach(function (el) {
        el.onsubmit = function () { return false; };
    });

    document.querySelectorAll('[data-onclick="mark_watched"]').forEach(function (el) {
        el.onclick = function () { mark_watched(el); };
    });
    document.querySelectorAll('[data-onclick="mark_unwatched"]').forEach(function (el) {
        el.onclick = function () { mark_unwatched(el); };
    });
    document.querySelectorAll('[data-onclick="add_playlist_video"]').forEach(function (el) {
        el.onclick = function () { add_playlist_video(el); };
    });
    document.querySelectorAll('[data-onclick="add_compilation_video"]').forEach(function (el) {
        el.onclick = function () { add_compilation_video(el); };
    });
    document.querySelectorAll('[data-onclick="add_playlist_item"]').forEach(function (el) {
        el.onclick = function () { add_playlist_item(el); };
    });
    document.querySelectorAll('[data-onclick="add_compilation_item"]').forEach(function (el) {
        el.onclick = function () { add_compilation_item(el); };
    });
    document.querySelectorAll('[data-onclick="remove_playlist_item"]').forEach(function (el) {
        el.onclick = function () { remove_playlist_item(el); };
    });
    document.querySelectorAll('[data-onclick="remove_compilation_item"]').forEach(function (el) {
        el.onclick = function () { remove_compilation_item(el); };
    });
    document.querySelectorAll('[data-onclick="revoke_token"]').forEach(function (el) {
        el.onclick = function () { revoke_token(el); };
    });
    document.querySelectorAll('[data-onclick="remove_subscription"]').forEach(function (el) {
        el.onclick = function () { remove_subscription(el); };
    });
    document.querySelectorAll('[data-onclick="notification_requestPermission"]').forEach(function (el) {
        el.onclick = function () { Notification.requestPermission(); };
    });

    document.querySelectorAll('[data-onrange="update_volume_value"]').forEach(function (el) {
        function update_volume_value() {
            document.getElementById('volume-value').textContent = el.value;
        }
        el.oninput = update_volume_value;
        el.onchange = update_volume_value;
    });


    function revoke_token(target) {
        var row = target.parentNode.parentNode.parentNode.parentNode.parentNode;
        row.style.display = 'none';
        var count = document.getElementById('count');
        count.textContent--;

        var url = '/token_ajax?action_revoke_token=1&redirect=false' +
            '&referer=' + encodeURIComponent(location.href) +
            '&session=' + target.getAttribute('data-session');

        var payload = 'csrf_token=' + target.parentNode.querySelector('input[name="csrf_token"]').value;

        helpers.xhr('POST', url, {payload: payload}, {
            onNon200: function (xhr) {
                count.textContent++;
                row.style.display = '';
            }
        });
    }

    function remove_subscription(target) {
        var row = target.parentNode.parentNode.parentNode.parentNode.parentNode;
        row.style.display = 'none';
        var count = document.getElementById('count');
        count.textContent--;

        var url = '/subscription_ajax?action_remove_subscriptions=1&redirect=false' +
            '&referer=' + encodeURIComponent(location.href) +
            '&c=' + target.getAttribute('data-ucid');

        var payload = 'csrf_token=' + target.parentNode.querySelector('input[name="csrf_token"]').value;

        helpers.xhr('POST', url, {payload: payload}, {
            onNon200: function (xhr) {
                count.textContent++;
                row.style.display = '';
            }
        });
    }

    // Handle keypresses
    addEventListener('keydown', function (event) {
        // Ignore modifier keys
        if (event.ctrlKey || event.metaKey) return;

        // Ignore shortcuts if any text input is focused
        let focused_tag = document.activeElement.tagName.toLowerCase();
        const allowed = /^(button|checkbox|file|radio|submit)$/;

        if (focused_tag === 'textarea') return;
        if (focused_tag === 'input') {
            let focused_type = document.activeElement.type.toLowerCase();
            if (!allowed.test(focused_type)) return;
        }

        // Focus search bar on '/'
        if (event.key === '/') {
            document.getElementById('searchbox').focus();
            event.preventDefault();
        }
    });
})();
