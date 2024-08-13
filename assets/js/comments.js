var video_data = JSON.parse(document.getElementById('video_data').textContent);

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

function updateReplyLinks() {
    document.querySelectorAll("a[href^='/comment_viewer']").forEach(function (replyLink) {
        replyLink.setAttribute("href", "javascript:void(0)");
        replyLink.removeAttribute("target");
    });
}
updateReplyLinks();

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

function get_youtube_comments() {
    var comments = document.getElementById('comments');

    var fallback = comments.innerHTML;
    comments.innerHTML = spinnerHTML;

    var baseUrl = video_data.base_url || '/api/v1/comments/'+ video_data.id
    var url = baseUrl +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode;

    if (video_data.ucid) {
        url += '&ucid=' + video_data.ucid
    }

    var onNon200 = function (xhr) { comments.innerHTML = fallback; };
    if (video_data.params.comments[1] === 'youtube')
        onNon200 = function (xhr) {};

    helpers.xhr('GET', url, {retries: 5, entity_name: 'comments'}, {
        on200: function (response) {
            var commentInnerHtml = ' \
            <div> \
                <h3> \
                    <a href="javascript:void(0)">[ − ]</a> \
                    {commentsText}  \
                </h3> \
                <b> \
                '
                if (video_data.support_reddit) {
                    commentInnerHtml += ' <a href="javascript:void(0)" data-comments="reddit"> \
                        {redditComments} \
                    </a> \
                    '
                }
                commentInnerHtml += ' </b> \
            </div> \
            <div>{contentHtml}</div> \
            <hr>'
            commentInnerHtml = commentInnerHtml.supplant({
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
            comments.innerHTML = commentInnerHtml;
            updateReplyLinks();
            comments.children[0].children[0].children[0].onclick = toggle_comments;
            if (video_data.support_reddit) {
                comments.children[0].children[1].children[0].onclick = swap_comments;
            }
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
    var baseUrl = video_data.base_url || '/api/v1/comments/'+ video_data.id
    var url = baseUrl +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode +
        '&continuation=' + continuation;

    if (video_data.ucid) {
        url += '&ucid=' + video_data.ucid
    }
    if (load_replies) url += '&action=action_get_comment_replies';

    helpers.xhr('GET', url, {}, {
        on200: function (response) {
            if (load_more) {
                body = body.parentNode.parentNode;
                body.removeChild(body.lastElementChild);
                body.insertAdjacentHTML('beforeend', response.contentHtml);
                updateReplyLinks();
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
                updateReplyLinks();
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