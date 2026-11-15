'use strict';

(function () {
    function related_videos_setup() {
        var items = document.getElementById('related-videos');
        var loading = document.getElementById('related-videos-loading');
        var sentinel = document.getElementById('related-videos-sentinel');
        var error_message = document.getElementById('related-videos-error');

        if (!items || !sentinel) {
            return;
        }

        var video_id = sentinel.getAttribute('data-video-id');
        var continuation = sentinel.getAttribute('data-continuation') || null;
        var listen = sentinel.getAttribute('data-listen') || 'false';
        var is_loading = false;
        var has_more = !!continuation;

        function get_url() {
            var url = '/api/v1/videos/' + video_id + '/related?format=html&listen=' + encodeURIComponent(listen);
            if (continuation) {
                url += '&continuation=' + encodeURIComponent(continuation);
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

            helpers.xhr('GET', get_url(), {}, {
                on200: function (response) {
                    var content_html = response ? response.contentHtml : null;

                    if (content_html && content_html !== '') {
                        items.insertAdjacentHTML('beforeend', content_html);
                    }

                    continuation = response ? (response.continuation || null) : null;

                    if (!continuation) {
                        has_more = false;
                        observer.disconnect();
                        sentinel.hidden = true;
                    }

                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onNon200: function () {
                    show_error('Could not load more related videos.');
                    has_more = false;
                    observer.disconnect();
                    sentinel.hidden = true;
                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onError: function () {
                    show_error('Could not load more related videos.');
                    has_more = false;
                    observer.disconnect();
                    sentinel.hidden = true;
                    is_loading = false;
                    if (loading) loading.hidden = true;
                },
                onTimeout: function () {
                    show_error('Could not load more related videos.');
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

    related_videos_setup();
})();
