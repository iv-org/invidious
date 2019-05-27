String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
}

function toggle_parent(target) {
    body = target.parentNode.parentNode.children[1];
    if (body.style.display === null || body.style.display === '') {
        target.innerHTML = '[ + ]';
        body.style.display = 'none';
    } else {
        target.innerHTML = '[ - ]';
        body.style.display = '';
    }
}

function toggle_comments(event) {
    var target = event.target;
    body = target.parentNode.parentNode.parentNode.children[1];
    if (body.style.display === null || body.style.display === '') {
        target.innerHTML = '[ + ]';
        body.style.display = 'none';
    } else {
        target.innerHTML = '[ - ]';
        body.style.display = '';
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

    sub_text = target.getAttribute('data-inner-text');
    inner_text = target.getAttribute('data-sub-text');

    body = target.parentNode.parentNode.children[1];
    body.style.display = 'none';

    target.innerHTML = sub_text;
    target.onclick = show_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function show_youtube_replies(event) {
    var target = event.target;

    sub_text = target.getAttribute('data-inner-text');
    inner_text = target.getAttribute('data-sub-text');

    body = target.parentNode.parentNode.children[1];
    body.style.display = '';

    target.innerHTML = sub_text;
    target.onclick = hide_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

var continue_button = document.getElementById('continue');
if (continue_button) {
    continue_button.onclick = continue_autoplay;
}

function continue_autoplay(event) {
    if (event.target.checked) {
        player.on('ended', function () {
            var url = new URL('https://example.com/watch?v=' + video_data.next_video);

            if (video_data.params.autoplay || video_data.params.continue_autoplay) {
                url.searchParams.set('autoplay', '1');
            }

            if (video_data.params.listen !== video_data.preferences.listen) {
                url.searchParams.set('listen', video_data.params.listen);
            }

            if (video_data.params.speed !== video_data.preferences.speed) {
                url.searchParams.set('speed', video_data.params.speed);
            }

            if (video_data.params.local !== video_data.preferences.local) {
                url.searchParams.set('local', video_data.params.local);
            }

            url.searchParams.set('continue', '1');
            location.assign(url.pathname + url.search);
        });
    } else {
        player.off('ended');
    }
}

function number_with_separator(val) {
    while (/(\d+)(\d{3})/.test(val.toString())) {
        val = val.toString().replace(/(\d+)(\d{3})/, '$1' + ',' + '$2');
    }
    return val;
}

function get_playlist(plid, timeouts = 0) {
    playlist = document.getElementById('playlist');

    if (timeouts > 10) {
        console.log('Failed to pull playlist');
        playlist.innerHTML = '';
        return;
    }

    playlist.innerHTML = ' \
        <h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3> \
        <hr>'

    if (plid.startsWith('RD')) {
        var plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    } else {
        var plid_url = '/api/v1/playlists/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    }

    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', plid_url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status == 200) {
                playlist.innerHTML = xhr.response.playlistHtml;

                if (xhr.response.nextVideo) {
                    player.on('ended', function () {
                        var url = new URL('https://example.com/watch?v=' + xhr.response.nextVideo);

                        if (video_data.params.autoplay || video_data.params.continue_autoplay) {
                            url.searchParams.set('autoplay', '1');
                        }

                        if (video_data.params.listen !== video_data.preferences.listen) {
                            url.searchParams.set('listen', video_data.params.listen);
                        }

                        if (video_data.params.speed !== video_data.preferences.speed) {
                            url.searchParams.set('speed', video_data.params.speed);
                        }

                        if (video_data.params.local !== video_data.preferences.local) {
                            url.searchParams.set('local', video_data.params.local);
                        }

                        url.searchParams.set('list', plid);
                        location.assign(url.pathname + url.search);
                    });
                }
            } else {
                playlist.innerHTML = '';
                document.getElementById('continue').style.display = '';
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling playlist timed out.');
        playlist = document.getElementById('playlist');
        playlist.innerHTML =
            '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3><hr>';
        get_playlist(plid, timeouts + 1);
    }
}

function get_reddit_comments(timeouts = 0) {
    comments = document.getElementById('comments');

    if (timeouts > 10) {
        console.log('Failed to pull comments');
        comments.innerHTML = '';
        return;
    }

    var fallback = comments.innerHTML;
    comments.innerHTML =
        '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';

    var url = '/api/v1/comments/' + video_data.id +
        '?source=reddit&format=html' +
        '&hl=' + video_data.preferences.locale;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status == 200) {
                comments.innerHTML = ' \
                <div> \
                    <h3> \
                        <a href="javascript:void(0)">[ - ]</a> \
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
                    title: xhr.response.title,
                    youtubeCommentsText: video_data.youtube_comments_text,
                    redditPermalinkText: video_data.reddit_permalink_text,
                    permalink: xhr.response.permalink,
                    contentHtml: xhr.response.contentHtml
                });

                comments.children[0].children[0].children[0].onclick = toggle_comments;
                comments.children[0].children[1].children[0].onclick = swap_comments;
            } else {
                if (video_data.preferences.comments[1] === 'youtube') {
                    get_youtube_comments(timeouts + 1);
                } else {
                    comments.innerHTML = fallback;
                }
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling comments timed out.');
        get_reddit_comments(timeouts + 1);
    }
}

function get_youtube_comments(timeouts = 0) {
    comments = document.getElementById('comments');

    if (timeouts > 10) {
        console.log('Failed to pull comments');
        comments.innerHTML = '';
        return;
    }

    var fallback = comments.innerHTML;
    comments.innerHTML =
        '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';

    var url = '/api/v1/comments/' + video_data.id +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status == 200) {
                if (xhr.response.commentCount > 0) {
                    comments.innerHTML = ' \
                    <div> \
                        <h3> \
                            <a href="javascript:void(0)">[ - ]</a> \
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
                        contentHtml: xhr.response.contentHtml,
                        redditComments: video_data.reddit_comments_text,
                        commentsText: video_data.comments_text.supplant(
                            { commentCount: number_with_separator(xhr.response.commentCount) }
                        )
                    });

                    comments.children[0].children[0].children[0].onclick = toggle_comments;
                    comments.children[0].children[1].children[0].onclick = swap_comments;
                } else {
                    comments.innerHTML = '';
                }
            } else {
                if (video_data.preferences[1] === 'youtube') {
                    get_youtube_comments(timeouts + 1);
                } else {
                    comments.innerHTML = '';
                }
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling comments timed out.');
        comments.innerHTML =
            '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
        get_youtube_comments(timeouts + 1);
    }
}

function get_youtube_replies(target, load_more) {
    var continuation = target.getAttribute('data-continuation');

    var body = target.parentNode.parentNode;
    var fallback = body.innerHTML;
    body.innerHTML =
        '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';

    var url = '/api/v1/comments/' + video_data.id +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode +
        '&continuation=' + continuation;
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', url, true);
    xhr.send();

    xhr.onreadystatechange = function () {
        if (xhr.readyState == 4) {
            if (xhr.status == 200) {
                if (load_more) {
                    body = body.parentNode.parentNode;
                    body.removeChild(body.lastElementChild);
                    body.innerHTML += xhr.response.contentHtml;
                } else {
                    body.removeChild(body.lastElementChild);

                    var p = document.createElement('p');
                    var a = document.createElement('a');
                    p.appendChild(a);

                    a.href = 'javascript:void(0)';
                    a.onclick = hide_youtube_replies;
                    a.setAttribute('data-sub-text', video_data.hide_replies_text);
                    a.setAttribute('data-inner-text', video_data.show_replies_text);
                    a.innerText = video_data.hide_replies_text;

                    var div = document.createElement('div');
                    div.innerHTML = xhr.response.contentHtml;

                    body.appendChild(p);
                    body.appendChild(div);
                }
            } else {
                body.innerHTML = fallback;
            }
        }
    }

    xhr.ontimeout = function () {
        console.log('Pulling comments timed out.');
        body.innerHTML = fallback;
    }
}

if (video_data.play_next) {
    player.on('ended', function () {
        var url = new URL('https://example.com/watch?v=' + video_data.next_video);

        if (video_data.params.autoplay || video_data.params.continue_autoplay) {
            url.searchParams.set('autoplay', '1');
        }

        if (video_data.params.listen !== video_data.preferences.listen) {
            url.searchParams.set('listen', video_data.params.listen);
        }

        if (video_data.params.speed !== video_data.preferences.speed) {
            url.searchParams.set('speed', video_data.params.speed);
        }

        if (video_data.params.local !== video_data.preferences.local) {
            url.searchParams.set('local', video_data.params.local);
        }

        url.searchParams.set('continue', '1');
        location.assign(url.pathname + url.search);
    });
}

if (video_data.plid) {
    get_playlist(video_data.plid);
}

if (video_data.preferences.comments[0] === 'youtube') {
    get_youtube_comments();
} else if (video_data.preferences.comments[0] === 'reddit') {
    get_reddit_comments();
} else if (video_data.preferences.comments[1] === 'youtube') {
    get_youtube_comments();
} else if (video_data.preferences.comments[1] === 'reddit') {
    get_reddit_comments();
} else {
    comments = document.getElementById('comments');
    comments.innerHTML = '';
}
