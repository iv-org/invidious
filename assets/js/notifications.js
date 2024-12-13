'use strict';
var notification_data = JSON.parse(document.getElementById('notification_data').textContent);

/** Boolean meaning 'some tab have stream' */
const STORAGE_KEY_STREAM = 'stream';
/** Number of notifications. May be increased or reset */
const STORAGE_KEY_NOTIF_COUNT = 'notification_count';

var notifications, delivered;
var notifications_mock = { close: function () { } };

function get_subscriptions() {
    helpers.xhr('GET', '/api/v1/auth/subscriptions', {
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
        '/api/v1/auth/notifications', {
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

        // Ignore not actual and delivered notifications
        if (start_time > notification.published || delivered.includes(notification.videoId)) return;

        delivered.push(notification.videoId);

        let notification_count = helpers.storage.get(STORAGE_KEY_NOTIF_COUNT) || 0;
        notification_count++;
        helpers.storage.set(STORAGE_KEY_NOTIF_COUNT, notification_count);

        update_ticker_count();

        // permission for notifications handled on settings page. JS handler is in handlers.js
        if (window.Notification && Notification.permission === 'granted') {
            var notification_text = notification.liveNow ? notification_data.live_now_text : notification_data.upload_text;
            notification_text = notification_text.replace('`x`', notification.author);

            var system_notification = new Notification(notification_text, {
                body: notification.title,
                icon: '/ggpht' + new URL(notification.authorThumbnails[2].url).pathname,
                img: '/ggpht' + new URL(notification.authorThumbnails[4].url).pathname
            });

            system_notification.onclick = function (e) {
                open('/watch?v=' + notification.videoId, '_blank');
            };
        }
    };

    notifications.addEventListener('error', function (e) {
        console.warn('Something went wrong with notifications, trying to reconnect...');
        notifications = notifications_mock;
        setTimeout(get_subscriptions, 1000);
    });

    notifications.stream();
}

function update_ticker_count() {
    var notification_ticker = document.getElementById('notification_ticker');

    const notification_count = helpers.storage.get(STORAGE_KEY_STREAM);
    if (notification_count > 0) {
        notification_ticker.innerHTML =
            '<span id="notification_count">' + notification_count + '</span> <i class="icon ion-ios-notifications"></i>';
    } else {
        notification_ticker.innerHTML =
            '<i class="icon ion-ios-notifications-outline"></i>';
    }
}

function start_stream_if_needed() {
    // random wait for other tabs set 'stream' flag
    setTimeout(function () {
        if (!helpers.storage.get(STORAGE_KEY_STREAM)) {
            // if no one set 'stream', set it by yourself and start stream
            helpers.storage.set(STORAGE_KEY_STREAM, true);
            notifications = notifications_mock;
            get_subscriptions();
        }
    }, Math.random() * 1000 + 50); // [0.050 .. 1.050) second
}


addEventListener('storage', function (e) {
    if (e.key === STORAGE_KEY_NOTIF_COUNT)
        update_ticker_count();

    // if 'stream' key was removed
    if (e.key === STORAGE_KEY_STREAM && !helpers.storage.get(STORAGE_KEY_STREAM)) {
        if (notifications) {
            // restore it if we have active stream
            helpers.storage.set(STORAGE_KEY_STREAM, true);
        } else {
            start_stream_if_needed();
        }
    }
});

addEventListener('load', function () {
    var notification_count_el = document.getElementById('notification_count');
    var notification_count = notification_count_el ? parseInt(notification_count_el.textContent) : 0;
    helpers.storage.set(STORAGE_KEY_NOTIF_COUNT, notification_count);

    if (helpers.storage.get(STORAGE_KEY_STREAM))
        helpers.storage.remove(STORAGE_KEY_STREAM);
    start_stream_if_needed();
});

addEventListener('unload', function () {
    // let chance to other tabs to be a streamer via firing 'storage' event
    if (notifications) helpers.storage.remove(STORAGE_KEY_STREAM);
});
