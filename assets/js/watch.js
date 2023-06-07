'use strict';
var video_data = JSON.parse(document.getElementById('video_data').textContent);
var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

function toggle_parent(target) {
    var body = target.parentNode.parentNode.children[1];
    if (body.style.display === 'none') {
        target.textContent = '[ − ]';
        body.style.display = '';
    } else {
        target.textContent = '[ + ]';
        body.style.display = 'none';
    }
}

function toggle_comments(event) {
    var target = event.target;
    var body = target.parentNode.parentNode.parentNode.children[1];
    if (body.style.display === 'none') {
        target.textContent = '[ − ]';
        body.style.display = '';
    } else {
        target.textContent = '[ + ]';
        body.style.display = 'none';
    }
}

function swap_comments(event) {
    var source = event.target.getAttribute('data-comments');

    if (source === 'youtube') {
        get_youtube_comments();
    } else if (source === 'reddit') {
        get_reddit_comments();
    }
}

function hide_youtube_replies(event) {
    var target = event.target;

    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');

    var body = target.parentNode.parentNode.children[1];
    body.style.display = 'none';

    target.textContent = sub_text;
    target.onclick = show_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function show_youtube_replies(event) {
    var target = event.target;

    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');

    var body = target.parentNode.parentNode.children[1];
    body.style.display = '';

    target.textContent = sub_text;
    target.onclick = hide_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

var continue_button = document.getElementById('continue');
if (continue_button) {
    continue_button.onclick = continue_autoplay;
}

function next_video() {
    var url = new URL('https://example.com/watch?v=' + video_data.next_video);

    if (video_data.params.autoplay || video_data.params.continue_autoplay)
        url.searchParams.set('autoplay', '1');
    if (video_data.params.listen !== video_data.preferences.listen)
        url.searchParams.set('listen', video_data.params.listen);
    if (video_data.params.speed !== video_data.preferences.speed)
        url.searchParams.set('speed', video_data.params.speed);
    if (video_data.params.local !== video_data.preferences.local)
        url.searchParams.set('local', video_data.params.local);
    url.searchParams.set('continue', '1');

    location.assign(url.pathname + url.search);
}

function continue_autoplay(event) {
    if (event.target.checked) {
        player.on('ended', next_video);
    } else {
        player.off('ended');
    }
}

function get_playlist(plid) {
    var playlist = document.getElementById('playlist');

    playlist.innerHTML = spinnerHTMLwithHR;

    var plid_url;
    if (plid.startsWith('RD')) {
        plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    } else {
        plid_url = '/api/v1/playlists/' + plid +
            '?index=' + video_data.index +
            '&continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    }

    helpers.xhr('GET', plid_url, {retries: 5, entity_name: 'playlist'}, {
        on200: function (response) {
            playlist.innerHTML = response.playlistHtml;

            if (!response.nextVideo) return;

            var nextVideo = document.getElementById(response.nextVideo);
            nextVideo.parentNode.parentNode.scrollTop = nextVideo.offsetTop;

            player.on('ended', function () {
                var url = new URL('https://example.com/watch?v=' + response.nextVideo);

                url.searchParams.set('list', plid);
                if (!plid.startsWith('RD'))
                    url.searchParams.set('index', response.index);
                if (video_data.params.autoplay || video_data.params.continue_autoplay)
                    url.searchParams.set('autoplay', '1');
                if (video_data.params.listen !== video_data.preferences.listen)
                    url.searchParams.set('listen', video_data.params.listen);
                if (video_data.params.speed !== video_data.preferences.speed)
                    url.searchParams.set('speed', video_data.params.speed);
                if (video_data.params.local !== video_data.preferences.local)
                    url.searchParams.set('local', video_data.params.local);

                location.assign(url.pathname + url.search);
            });
        },
        onNon200: function (xhr) {
            playlist.innerHTML = '';
            document.getElementById('continue').style.display = '';
        },
        onError: function (xhr) {
            playlist.innerHTML = spinnerHTMLwithHR;
        },
        onTimeout: function (xhr) {
            playlist.innerHTML = spinnerHTMLwithHR;
        }
    });
}

function get_reddit_comments() {
    var comments = document.getElementById('comments');

    var fallback = comments.innerHTML;
    comments.innerHTML = spinnerHTML;

    var url = '/api/v1/comments/' + video_data.id +
        '?source=reddit&format=html' +
        '&hl=' + video_data.preferences.locale;

    var onNon200 = function (xhr) { comments.innerHTML = fallback; };
    if (video_data.params.comments[1] === 'youtube')
        onNon200 = function (xhr) {};

    helpers.xhr('GET', url, {retries: 5, entity_name: ''}, {
        on200: function (response) {
            comments.innerHTML = ' \
            <div> \
                <h3> \
                    <a href="javascript:void(0)">[ − ]</a> \
                    {title} \
                </h3> \
                <p> \
                    <b> \
                        <a href="javascript:void(0)" data-comments="youtube"> \
                            {youtubeCommentsText} \
                        </a> \
                    </b> \
                </p> \
                <b> \
                    <a rel="noopener" target="_blank" href="https://reddit.com{permalink}">{redditPermalinkText}</a> \
                </b> \
            </div> \
            <div>{contentHtml}</div> \
            <hr>'.supplant({
                title: response.title,
                youtubeCommentsText: video_data.youtube_comments_text,
                redditPermalinkText: video_data.reddit_permalink_text,
                permalink: response.permalink,
                contentHtml: response.contentHtml
            });

            comments.children[0].children[0].children[0].onclick = toggle_comments;
            comments.children[0].children[1].children[0].onclick = swap_comments;
        },
        onNon200: onNon200, // declared above
    });
}

function get_youtube_comments() {
    var comments = document.getElementById('comments');

    var fallback = comments.innerHTML;
    comments.innerHTML = spinnerHTML;

    var url = '/api/v1/comments/' + video_data.id +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode;

    var onNon200 = function (xhr) { comments.innerHTML = fallback; };
    if (video_data.params.comments[1] === 'youtube')
        onNon200 = function (xhr) {};

    helpers.xhr('GET', url, {retries: 5, entity_name: 'comments'}, {
        on200: function (response) {
            comments.innerHTML = ' \
            <div> \
                <h3> \
                    <a href="javascript:void(0)">[ − ]</a> \
                    {commentsText}  \
                </h3> \
                <b> \
                    <a href="javascript:void(0)" data-comments="reddit"> \
                        {redditComments} \
                    </a> \
                </b> \
            </div> \
            <div>{contentHtml}</div> \
            <hr>'.supplant({
                contentHtml: response.contentHtml,
                redditComments: video_data.reddit_comments_text,
                commentsText: video_data.comments_text.supplant({
                    // toLocaleString correctly splits number with local thousands separator. e.g.:
                    // '1,234,567.89' for user with English locale
                    // '1 234 567,89' for user with Russian locale
                    // '1.234.567,89' for user with Portuguese locale
                    commentCount: response.commentCount.toLocaleString()
                })
            });

            comments.children[0].children[0].children[0].onclick = toggle_comments;
            comments.children[0].children[1].children[0].onclick = swap_comments;
        },
        onNon200: onNon200, // declared above
        onError: function (xhr) {
            comments.innerHTML = spinnerHTML;
        },
        onTimeout: function (xhr) {
            comments.innerHTML = spinnerHTML;
        }
    });
}

function get_youtube_replies(target, load_more, load_replies) {
    var continuation = target.getAttribute('data-continuation');

    var body = target.parentNode.parentNode;
    var fallback = body.innerHTML;
    body.innerHTML = spinnerHTML;

    var url = '/api/v1/comments/' + video_data.id +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode +
        '&continuation=' + continuation;
    if (load_replies) url += '&action=action_get_comment_replies';

    helpers.xhr('GET', url, {}, {
        on200: function (response) {
            if (load_more) {
                body = body.parentNode.parentNode;
                body.removeChild(body.lastElementChild);
                body.insertAdjacentHTML('beforeend', response.contentHtml);
            } else {
                body.removeChild(body.lastElementChild);

                var p = document.createElement('p');
                var a = document.createElement('a');
                p.appendChild(a);

                a.href = 'javascript:void(0)';
                a.onclick = hide_youtube_replies;
                a.setAttribute('data-sub-text', video_data.hide_replies_text);
                a.setAttribute('data-inner-text', video_data.show_replies_text);
                a.textContent = video_data.hide_replies_text;

                var div = document.createElement('div');
                div.innerHTML = response.contentHtml;

                body.appendChild(p);
                body.appendChild(div);
            }
        },
        onNon200: function (xhr) {
            body.innerHTML = fallback;
        },
        onTimeout: function (xhr) {
            console.warn('Pulling comments failed');
            body.innerHTML = fallback;
        }
    });
}

if (video_data.play_next) {
    player.on('ended', function () {
        var url = new URL('https://example.com/watch?v=' + video_data.next_video);

        if (video_data.params.autoplay || video_data.params.continue_autoplay)
            url.searchParams.set('autoplay', '1');
        if (video_data.params.listen !== video_data.preferences.listen)
            url.searchParams.set('listen', video_data.params.listen);
        if (video_data.params.speed !== video_data.preferences.speed)
            url.searchParams.set('speed', video_data.params.speed);
        if (video_data.params.local !== video_data.preferences.local)
            url.searchParams.set('local', video_data.params.local);
        url.searchParams.set('continue', '1');

        location.assign(url.pathname + url.search);
    });
}

addEventListener('load', function (e) {
    if (video_data.plid)
        get_playlist(video_data.plid);

    if (video_data.params.comments[0] === 'youtube') {
        get_youtube_comments();
    } else if (video_data.params.comments[0] === 'reddit') {
        get_reddit_comments();
    } else if (video_data.params.comments[1] === 'youtube') {
        get_youtube_comments();
    } else if (video_data.params.comments[1] === 'reddit') {
        get_reddit_comments();
    } else {
        var comments = document.getElementById('comments');
        comments.innerHTML = '';
    }
});
