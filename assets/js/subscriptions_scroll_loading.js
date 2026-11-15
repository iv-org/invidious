'use strict';

(function () {
    function subscriptions_setup() {
        var items = document.getElementById('subscription-items');
        var loading = document.getElementById('subscriptions-loading');
        var sentinel = document.getElementById('subscriptions-sentinel');
        var error_message = document.getElementById('subscriptions-error');

        if (!items || !sentinel) {
            return;
        }

        var page = parseInt(sentinel.getAttribute('data-page') || '1', 10);
        var max_results = sentinel.getAttribute('data-max-results') || '';
        var has_more = sentinel.getAttribute('data-has-more') === 'true';
        var is_loading = false;

        function get_url() {
            var url = '/feed/subscriptions?format=html&page=' + page;
            if (max_results) {
                url += '&max_results=' + encodeURIComponent(max_results);
            }
            return url;
        }

        function show_error(message) {
            if (!error_message) {
                return;
            }
            error_message.textContent = message;
            error_message.hidden = false;
        }

        function hide_error() {
            if (error_message) {
                error_message.hidden = true;
            }
        }

        function load_more() {
            if (is_loading || !has_more) {
                return;
            }

            is_loading = true;
            hide_error();
            if (loading) loading.hidden = false;

            page += 1;

            helpers.xhr('GET', get_url(), {}, {
                on200: function (response) {
                    var content_html = response ? response.contentHtml : null;

                    if (content_html && content_html !== '') {
                        items.insertAdjacentHTML('beforeend', content_html);
                    }

                    has_more = response && response.hasMore === true;

                    if (!has_more) {
                        observer.disconnect();
                        sentinel.hidden = true;
                    }

                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onNon200: function () {
                    show_error('Could not load more subscriptions.');
                    has_more = false;
                    observer.disconnect();
                    sentinel.hidden = true;
                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onError: function () {
                    show_error('Could not load more subscriptions.');
                    has_more = false;
                    observer.disconnect();
                    sentinel.hidden = true;
                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onTimeout: function () {
                    show_error('Could not load more subscriptions.');
                    has_more = false;
                    observer.disconnect();
                    sentinel.hidden = true;
                    is_loading = false;
                    if (loading) loading.hidden = true;
                }
            });
        }

        if (loading) loading.hidden = true;

        if (!has_more) {
            sentinel.hidden = true;
            return;
        }

        var observer = new IntersectionObserver(function (entries) {
            if (!entries[0] || !entries[0].isIntersecting) {
                return;
            }
            load_more();
        }, {
            rootMargin: '300px'
        });

        observer.observe(sentinel);
    }

    subscriptions_setup();
})();
