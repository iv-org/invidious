'use strict';
var subscribe_data = JSON.parse(document.getElementById('subscribe_data').textContent);
var payload = 'csrf_token=' + subscribe_data.csrf_token;

var subscribe_button = document.getElementById('subscribe');
subscribe_button.parentNode.action = 'javascript:void(0)';

if (subscribe_button.getAttribute('data-type') === 'subscribe') {
    subscribe_button.onclick = subscribe;
} else {
    subscribe_button.onclick = unsubscribe;
}

function subscribe() {
    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = unsubscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.unsubscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    var url = '/subscription_ajax?action_create_subscription_to_channel=1&redirect=false' +
        '&c=' + subscribe_data.ucid;

    helpers.xhr('POST', url, {payload: payload, retries: 5, entity_name: 'subscribe request'}, {
        onNon200: function (xhr) {
            subscribe_button.onclick = subscribe;
            subscribe_button.innerHTML = fallback;
        }
    });
}

function unsubscribe() {
    var fallback = subscribe_button.innerHTML;
    subscribe_button.onclick = subscribe;
    subscribe_button.innerHTML = '<b>' + subscribe_data.subscribe_text + ' | ' + subscribe_data.sub_count_text + '</b>';

    var url = '/subscription_ajax?action_remove_subscriptions=1&redirect=false' +
        '&c=' + subscribe_data.ucid;

    helpers.xhr('POST', url, {payload: payload, retries: 5, entity_name: 'unsubscribe request'}, {
        onNon200: function (xhr) {
            subscribe_button.onclick = unsubscribe;
            subscribe_button.innerHTML = fallback;
        }
    });
}
