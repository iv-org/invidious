'use strict';
var subscribe_data = JSON.parse(document.getElementById('subscribe_data').textContent);
var payload = 'csrf_token=' + subscribe_data.csrf_token;

var subscribe_button = document.getElementById('subscribe');

if (subscribe_button.getAttribute('data-type') === 'subscribe') {
    subscribe_button.onclick = subscribe;
} else {
    subscribe_button.onclick = unsubscribe;
}

function toggleSubscribeButton() {
	subscribe_button.classList.remove("primary");
	subscribe_button.classList.remove("secondary");
	subscribe_button.classList.remove("unsubscribe");
	subscribe_button.classList.remove("subscribe");

	if (subscribe_button.getAttribute('data-type') === 'subscribe') {
    subscribe_button.textContent = subscribe_data.unsubscribe_text + ' | ' + subscribe_data.sub_count_text;
		subscribe_button.onclick = unsubscribe;
		subscribe_button.classList.add("secondary");
		subscribe_button.classList.add("unsubscribe");
	} else {
    subscribe_button.textContent = subscribe_data.subscribe_text + ' | ' + subscribe_data.sub_count_text;
		subscribe_button.onclick = subscribe;
		subscribe_button.classList.add("primary");
		subscribe_button.classList.add("subscribe");
	}
}

function subscribe(e) {
		e.preventDefault();
    var fallback = subscribe_button.textContent;
		toggleSubscribeButton();

    var url = '/subscription_ajax?action=create_subscription_to_channel&redirect=false' +
        '&c=' + subscribe_data.ucid;

    helpers.xhr('POST', url, {payload: payload, retries: 5, entity_name: 'subscribe request'}, {
        onNon200: function (xhr) {
            subscribe_button.onclick = subscribe;
            subscribe_button.textContent = fallback;
        }
    });
}

function unsubscribe(e) {
		e.preventDefault();
    var fallback = subscribe_button.textContent;
		toggleSubscribeButton();

    var url = '/subscription_ajax?action=remove_subscriptions&redirect=false' +
        '&c=' + subscribe_data.ucid;

    helpers.xhr('POST', url, {payload: payload, retries: 5, entity_name: 'unsubscribe request'}, {
        onNon200: function (xhr) {
            subscribe_button.onclick = unsubscribe;
            subscribe_button.textContent = fallback;
        }
    });
}
