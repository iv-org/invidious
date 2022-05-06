'use strict';
var notification_data = JSON.parse(document.getElementById('notification_data').textContent);

var notifications, delivered;
var notifications_substitution = { close: function () { } };

function get_subscriptions() {
    helpers.xhr('GET', '/api/v1/auth/subscriptions?fields=authorId', {
        retries: 5,
        entity_name: 'subscriptions'
    }, {
        on200: create_notification_stream
    });
}

function create_notification_stream(subscriptions) {
    // sse.js can't be replaced to EventSource in place as it lack support of payload and headers
    // see https://developer.mozilla.org/en-US/docs/Web/API/EventSource/EventSource
    notifications = new SSE(
        '/api/v1/auth/notifications?fields=videoId,title,author,authorId,publishedText,published,authorThumbnails,liveNow', {
            withCredentials: true,
            payload: 'topics=' + subscriptions.map(function (subscription) { return subscription.authorId; }).join(','),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });
    delivered = [];

    var start_time = Math.round(new Date() / 1000);

    notifications.onmessage = function (event) {
        if (!event.id) return;

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
                    open('/watch?v=' + event.currentTarget.tag, '_blank');
                };
            }

            delivered.push(notification.videoId);
            helpers.storage.set('notification_count', parseInt(helpers.storage.get('notification_count') || '0') + 1);
            var notification_ticker = document.getElementById('notification_ticker');

            if (parseInt(helpers.storage.get('notification_count')) > 0) {
                notification_ticker.innerHTML =
                    '<span id="notification_count">' + helpers.storage.get('notification_count') + '</span> <i class="icon ion-ios-notifications"></i>';
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
    notifications = notifications_substitution;
    setTimeout(get_subscriptions, 1000);
}

addEventListener('load', function (e) {
    helpers.storage.set('notification_count', document.getElementById('notification_count') ? document.getElementById('notification_count').innerText : '0');

    if (helpers.storage.get('stream')) {
        helpers.storage.remove('stream');
    } else {
        setTimeout(function () {
            if (!helpers.storage.get('stream')) {
                notifications = notifications_substitution;
                helpers.storage.set('stream', true);
                get_subscriptions();
            }
        }, Math.random() * 1000 + 50);
    }

    addEventListener('storage', function (e) {
        if (e.key === 'stream' && !e.newValue) {
            if (notifications) {
                helpers.storage.set('stream', true);
            } else {
                setTimeout(function () {
                    if (!helpers.storage.get('stream')) {
                        notifications = notifications_substitution;
                        helpers.storage.set('stream', true);
                        get_subscriptions();
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

addEventListener('unload', function (e) {
    if (notifications) helpers.storage.remove('stream');
});
