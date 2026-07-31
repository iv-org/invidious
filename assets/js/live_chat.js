'use strict';

(function () {
    var container = document.getElementById('live-chat-messages');
    var status = document.getElementById('live-chat-status');
    var modeSelect = document.getElementById('live-chat-mode');
    var continuation = null;
    var knownMessages = Object.create(null);
    var retryDelay = 5000;
    var maxMessages = 200;
    var pollTimer = null;
    var polling = false;
    var stopped = false;
    var generation = 0;

    if (!container || !status || !modeSelect) return;

    function setStatus(message) {
        status.textContent = message;
        status.hidden = false;
    }

    function clearStatus() {
        status.hidden = true;
    }

    function removeMessage(id) {
        var element = knownMessages[id];
        if (element) element.parentNode.removeChild(element);
        delete knownMessages[id];
    }

    function appendMessage(action) {
        if (action.id && knownMessages[action.id]) return;

        var message = document.createElement('div');
        message.className = 'live-chat-message';
        if (action.kind === 'engagement')
            message.classList.add('live-chat-message-engagement');

        if (action.id) {
            message.setAttribute('data-live-chat-id', action.id);
            knownMessages[action.id] = message;
        }
        if (action.author) {
            var author = document.createElement('strong');
            author.className = 'live-chat-author';
            author.textContent = action.author;
            message.appendChild(author);
        }

        if (action.badges) {
            action.badges.forEach(function (badge) {
                var badgeElement = document.createElement('span');
                badgeElement.className = 'live-chat-badge';
                badgeElement.textContent = badge;
                message.appendChild(badgeElement);
            });
        }

        if (action.message) {
            var body = document.createElement('span');
            body.textContent = action.message;
            message.appendChild(body);
        }

        container.appendChild(message);

        while (container.children.length > maxMessages) {
            var first = container.firstElementChild;
            if (first.getAttribute('data-live-chat-id'))
                delete knownMessages[first.getAttribute('data-live-chat-id')];
            container.removeChild(first);
        }
    }

    function applyActions(actions) {
        var wasNearBottom = container.scrollHeight - container.scrollTop - container.clientHeight < 50;

        actions.forEach(function (action) {
            if (action.action === 'add') {
                appendMessage(action);
            } else if (action.action === 'remove' && action.id) {
                removeMessage(action.id);
            }
        });

        if (wasNearBottom) container.scrollTop = container.scrollHeight;
    }

    function schedulePoll(timeout) {
        if (stopped || document.hidden) return;

        clearTimeout(pollTimer);
        pollTimer = setTimeout(poll, Math.max(1000, Math.min(timeout || 10000, 30000)));
    }

    function reconnect(requestGeneration) {
        if (requestGeneration !== generation) return;

        polling = false;
        setStatus(video_data.live_chat.reconnecting_text);
        schedulePoll(retryDelay);
        retryDelay = Math.min(retryDelay * 2, 30000);
    }

    function poll() {
        if (polling || stopped || document.hidden) return;
        polling = true;
        var requestGeneration = generation;

        var url = '/api/v1/live_chat/' + encodeURIComponent(video_data.id);
        var query = ['mode=' + encodeURIComponent(modeSelect.value)];

        if (continuation)
            query.push('continuation=' + encodeURIComponent(continuation));
        if (video_data.params.region)
            query.push('region=' + encodeURIComponent(video_data.params.region));
        url += '?' + query.join('&');

        helpers.xhr('GET', url, {timeout: 15000}, {
            on200: function (response) {
                if (requestGeneration !== generation) return;

                polling = false;
                clearStatus();
                retryDelay = 5000;
                applyActions(response.actions || []);
                continuation = response.continuation;

                if (continuation) {
                    schedulePoll(response.timeoutMs);
                } else {
                    stopped = true;
                    setStatus(video_data.live_chat.ended_text);
                }
            },
            onNon200: function (xhr) {
                if (requestGeneration !== generation) return;

                if (xhr.status === 404 || xhr.status === 410) {
                    polling = false;
                    stopped = true;
                    setStatus(video_data.live_chat.unavailable_text);
                } else {
                    reconnect(requestGeneration);
                }
            },
            onError: function () { reconnect(requestGeneration); },
            onTimeout: function () { reconnect(requestGeneration); }
        });
    }

    modeSelect.addEventListener('change', function () {
        generation += 1;
        clearTimeout(pollTimer);
        continuation = null;
        knownMessages = Object.create(null);
        retryDelay = 5000;
        polling = false;
        stopped = false;
        container.textContent = '';
        setStatus(video_data.live_chat.loading_text);
        poll();
    });

    document.addEventListener('visibilitychange', function () {
        if (document.hidden) {
            clearTimeout(pollTimer);
        } else if (!stopped) {
            poll();
        }
    });

    poll();
}());
