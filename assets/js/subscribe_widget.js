var subscribe_button = document.getElementById('subscribe');
subscribe_button.parentNode['action'] = 'javascript:void(0)';

if (subscribe_button.getAttribute('data-type') === 'subscribe') {
    subscribe_button.onclick = subscribe;
} else {
    subscribe_button.onclick = unsubscribe;
}

function subscribe(timeouts) {
    if (timeouts >= 10) {
        console.log('Failed to subscribe.');
        return;
    }

    var url = '/subscription_ajax?action_create_subscription_to_channel=1&redirect=false' +
        '&c=' + subscribe_data.ucid;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader("Content-Type", "application/x-www-form-urlencoded");
    xhr.send('csrf_token=' + subscribe_data.csrf_token);

    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = unsubscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.unsubscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status != 200) {
                subscribe_button.onclick = subscribe;
                subscribe_button.innerHTML = fallback;
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Subscribing timed out.');
        subscribe(timeouts++);
    }
}

function unsubscribe(timeouts) {
    if (timeouts >= 10) {
        console.log('Failed to subscribe');
        return;
    }

    var url = '/subscription_ajax?action_remove_subscriptions=1&redirect=false' +
        '&c=' + subscribe_data.ucid;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');
    xhr.send('csrf_token=' + subscribe_data.csrf_token);

    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = subscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.subscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status != 200) {
                subscribe_button.onclick = unsubscribe;
                subscribe_button.innerHTML = fallback;
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Unsubscribing timed out.');
        unsubscribe(timeouts++);
    }
}
