var notifications, delivered;

function get_subscriptions(callback, timeouts = 1) {
    if (timeouts >= 10) {
        return
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', '/api/v1/auth/subscriptions', true);
    xhr.send(null);

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
                subscriptions = xhr.response;
                callback(subscriptions);
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling subscriptions timed out... ' + timeouts + '/10');
        get_subscriptions(callback, timeouts++);
    }
}

function create_notification_stream(subscriptions) {
    notifications = new SSE(
        '/api/v1/auth/notifications?fields=videoId,title,author,authorId,publishedText,published,authorThumbnails,liveNow', {
            withCredentials: true,
            payload: 'topics=' + subscriptions.map(function (subscription) { return subscription.authorId }).join(','),
            headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
        });
    delivered = [];

    var start_time = Math.round(new Date() / 1000);

    notifications.onmessage = function (event) {
        if (!event.id) {
            return
        }

        var notification = JSON.parse(event.data);
        console.log('Got notification:', notification);

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
                }
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
    }

    notifications.onerror = function (event) {
        console.log('Something went wrong with notifications, trying to reconnect...');
        notifications.close();
        get_subscriptions(create_notification_stream);
    }

    notifications.ontimeout = function (event) {
        console.log('Something went wrong with notifications, trying to reconnect...');
        notifications.close();
        get_subscriptions(create_notification_stream);
    }

    notifications.stream();
}

window.addEventListener('load', function (e) {
    localStorage.setItem('notification_count', document.getElementById('notification_count') ? document.getElementById('notification_count').innerText : '0');

    if (localStorage.getItem('stream')) {
        localStorage.removeItem('stream');
    } else {
        setTimeout(function () {
            if (!localStorage.getItem('stream')) {
                get_subscriptions(create_notification_stream);
                localStorage.setItem('stream', true);
            }
        }, Math.random() * 1000 + 10);
    }

    window.addEventListener('storage', function (e) {
        if (e.key === 'stream' && !e.newValue) {
            if (notifications) {
                localStorage.setItem('stream', true);
            } else {
                setTimeout(function () {
                    if (!localStorage.getItem('stream')) {
                        get_subscriptions(create_notification_stream);
                        localStorage.setItem('stream', true);
                    }
                }, Math.random() * 1000 + 10);
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
