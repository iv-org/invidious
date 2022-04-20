'use strict';
var subscribe_data = JSON.parse(document.getElementById('subscribe_data').textContent);

var subscribe_button = document.getElementById('subscribe');
subscribe_button.parentNode['action'] = 'javascript:void(0)';

if (subscribe_button.getAttribute('data-type') === 'subscribe') {
    subscribe_button.onclick = subscribe;
} else {
    subscribe_button.onclick = unsubscribe;
}

function subscribe(retries) {
    if (retries === undefined) retries = 5;

    if (retries <= 0) {
        console.warn('Failed to subscribe.');
        return;
    }

    var url = '/subscription_ajax?action_create_subscription_to_channel=1&redirect=false' +
        '&c=' + subscribe_data.ucid;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = unsubscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.unsubscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status !== 200) {
                subscribe_button.onclick = subscribe;
                subscribe_button.innerHTML = fallback;
            }
        }
    };

    xhr.onerror = function () {
        console.warn('Subscribing failed... ' + retries + '/5');
        setTimeout(function () { subscribe(retries - 1); }, 1000);
    };

    xhr.ontimeout = function () {
        console.warn('Subscribing failed... ' + retries + '/5');
        subscribe(retries - 1);
    };

    xhr.send('csrf_token=' + subscribe_data.csrf_token);
}

function unsubscribe(retries) {
    if (retries === undefined)
        retries = 5;

    if (retries <= 0) {
        console.warn('Failed to subscribe');
        return;
    }

    var url = '/subscription_ajax?action_remove_subscriptions=1&redirect=false' +
        '&c=' + subscribe_data.ucid;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('POST', url, true);
    xhr.setRequestHeader('Content-Type', 'application/x-www-form-urlencoded');

    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = subscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.subscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status !== 200) {
                subscribe_button.onclick = unsubscribe;
                subscribe_button.innerHTML = fallback;
            }
        }
    };

    xhr.onerror = function () {
        console.warn('Unsubscribing failed... ' + retries + '/5');
        setTimeout(function () { unsubscribe(retries - 1); }, 1000);
    };

    xhr.ontimeout = function () {
        console.warn('Unsubscribing failed... ' + retries + '/5');
        unsubscribe(retries - 1);
    };

    xhr.send('csrf_token=' + subscribe_data.csrf_token);
}
