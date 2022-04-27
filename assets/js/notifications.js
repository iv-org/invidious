'use strict';
var notification_data = JSON.parse(document.getElementById('notification_data').textContent);

var notifications, delivered;

function get_subscriptions(callback, retries) {
    if (retries === undefined) retries = 5;

    if (retries <= 0) {
        return;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', '/api/v1/auth/subscriptions?fields=authorId', true);

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                var subscriptions = xhr.response;
                callback(subscriptions);
            }
        }
    };

    xhr.onerror = function () {
        console.warn('Pulling subscriptions failed... ' + retries + '/5');
        setTimeout(function () { get_subscriptions(callback, retries - 1); }, 1000);
    };

    xhr.ontimeout = function () {
        console.warn('Pulling subscriptions failed... ' + retries + '/5');
        get_subscriptions(callback, retries - 1);
    };

    xhr.send();
}

function create_notification_stream(subscriptions) {
    notifications = new SSE(
        '/api/v1/auth/notifications?fields=videoId,title,author,authorId,publishedText,published,authorThumbnails,liveNow', {
            withCredentials: true,
            payload: 'topics=' + subscriptions.map(function (subscription) { return subscription.authorId; }).join(','),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });
    delivered = [];

    var start_time = Math.round(new Date() / 1000);

    notifications.onmessage = function (event) {
        if (!event.id) {
            return;
        }

        var notification = JSON.parse(event.data);
        console.info('Got notification:', notification);

        if (start_time < notification.published && !delivered.includes(notification.videoId)) {
            if (Notification.permission === 'granted') {
                var system_notification =
                    new Notification((notification.liveNow ? notification_data.live_now_text : notification_data.upload_text).replace('`x`', notification.author), {
                        body: notification.title,
                        icon: '/ggpht' + new URL(notification.authorThumbnails[2].url).pathname,
                        img: '/ggpht' + new URL(notification.authorThumbnails[4].url).pathname,
                        tag: notification.videoId
                    });

                system_notification.onclick = function (event) {
                    window.open('/watch?v=' + event.currentTarget.tag, '_blank');
                };
            }

            delivered.push(notification.videoId);
            localStorage.setItem('notification_count', parseInt(localStorage.getItem('notification_count') || '0') + 1);
            var notification_ticker = document.getElementById('notification_ticker');

            if (parseInt(localStorage.getItem('notification_count')) > 0) {
                notification_ticker.innerHTML =
                    '<span id="notification_count">' + localStorage.getItem('notification_count') + '</span> <i class="icon ion-ios-notifications"></i>';
            } else {
                notification_ticker.innerHTML =
                    '<i class="icon ion-ios-notifications-outline"></i>';
            }
        }
    };

    notifications.addEventListener('error', handle_notification_error);
    notifications.stream();
}

function handle_notification_error(event) {
    console.warn('Something went wrong with notifications, trying to reconnect...');
    notifications = { close: function () { } };
    setTimeout(function () { get_subscriptions(create_notification_stream); }, 1000);
}

window.addEventListener('load', function (e) {
    localStorage.setItem('notification_count', document.getElementById('notification_count') ? document.getElementById('notification_count').innerText : '0');

    if (localStorage.getItem('stream')) {
        localStorage.removeItem('stream');
    } else {
        setTimeout(function () {
            if (!localStorage.getItem('stream')) {
                notifications = { close: function () { } };
                localStorage.setItem('stream', true);
                get_subscriptions(create_notification_stream);
            }
        }, Math.random() * 1000 + 50);
    }

    window.addEventListener('storage', function (e) {
        if (e.key === 'stream' && !e.newValue) {
            if (notifications) {
                localStorage.setItem('stream', true);
            } else {
                setTimeout(function () {
                    if (!localStorage.getItem('stream')) {
                        notifications = { close: function () { } };
                        localStorage.setItem('stream', true);
                        get_subscriptions(create_notification_stream);
                    }
                }, Math.random() * 1000 + 50);
            }
        } else if (e.key === 'notification_count') {
            var notification_ticker = document.getElementById('notification_ticker');

            if (parseInt(e.newValue) > 0) {
                notification_ticker.innerHTML =
                    '<span id="notification_count">' + e.newValue + '</span> <i class="icon ion-ios-notifications"></i>';
            } else {
                notification_ticker.innerHTML =
                    '<i class="icon ion-ios-notifications-outline"></i>';
            }
        }
    });
});

window.addEventListener('unload', function (e) {
    if (notifications) {
        localStorage.removeItem('stream');
    }
});
