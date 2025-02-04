var video_data = JSON.parse(document.getElementById('video_data').textContent);

var isRTL = (() => {           
    var ltrChars    = 'A-Za-z\u00C0-\u00D6\u00D8-\u00F6\u00F8-\u02B8\u0300-\u0590\u0800-\u1FFF'+'\u2C00-\uFB1C\uFDFE-\uFE6F\uFEFD-\uFFFF',
        rtlChars    = '\u0591-\u07FF\uFB1D-\uFDFD\uFE70-\uFEFC',
        rtlDirCheck = new RegExp('^[^'+ltrChars+']*['+rtlChars+']');

    return rtlDirCheck.test(video_data.hide_replies_text);
})();

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

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

    var originalHTML = comments.innerHTML;
    comments.innerHTML = spinnerHTML;

    var baseUrl = video_data.base_url || '/api/v1/comments/'+ video_data.id
    var url = baseUrl +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode;

    if (video_data.ucid) {
        url += '&ucid=' + video_data.ucid;
    }

    var onNon200 = function (xhr) { comments.innerHTML = originalHTML; };
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

function format_count_load_more(content, current_count, total_count) {
  var load_more_end_str = content.split('data-load-more');
  if (load_more_end_str.length === 1)
      return [content, false];  // no Load More button, return false for has_more_replies
  load_more_end_str = load_more_end_str[1].split('\n')[0];  // ' >("Load more" translated string)</a>'
  var slice_index = content.indexOf(load_more_end_str) + load_more_end_str.length - 4;  // backtrace </a>
  var num_remaining = total_count - current_count;
  return [
      // More replies may have been added since initally loading parent comment
      content.slice(0, slice_index) + ' (+' + (num_remaining > 0 ? num_remaining : '?') + ')' + content.slice(slice_index),
      true  // Load More button present, return true for has_more_replies
  ];
}

function format_count_toggle_replies_button(toggle_reply_button, current_count, total_count, has_more_replies) {
    if (!has_more_replies) {
        // Accept the final current count as the total (comments may have been added or removed since loading)
        total_count = current_count;
    } else if (current_count >= total_count) {
        total_count = '?';
    }

    if (isRTL) [current_count, total_count] = [total_count, current_count];
    ['data-sub-text', 'data-inner-text'].forEach(attr => {
        toggle_reply_button.setAttribute(attr, 
            toggle_reply_button.getAttribute(attr)
                .replace(/\(\d+\/\d+\)/, ' (' + current_count + '/' + total_count + ')')
        );
    });
    toggle_reply_button.textContent = toggle_reply_button.getAttribute('data-sub-text');
}

function get_youtube_replies(target, load_more, load_replies) {
    var continuation = target.getAttribute('data-continuation');

    var body = target.parentNode.parentNode;
    var originalHTML = body.innerHTML;
    body.innerHTML = spinnerHTML;
    var baseUrl = video_data.base_url || '/api/v1/comments/' + video_data.id
    var url = baseUrl +
        '?format=html' +
        '&hl=' + video_data.preferences.locale +
        '&thin_mode=' + video_data.preferences.thin_mode +
        '&continuation=' + continuation;

    if (video_data.ucid) {
        url += '&ucid=' + video_data.ucid;
    }
    if (load_replies) url += '&action=action_get_comment_replies';

    helpers.xhr('GET', url, {}, {
        on200: function (response) {
            var num_incoming_replies = response.contentHtml.split('channel-profile').length - 1;
            if (load_more) {
                body = body.parentNode.parentNode;
                body.removeChild(body.lastElementChild);  // Remove spinner
                
                var toggle_replies_button = body.parentNode.firstChild.firstChild;
                if (!toggle_replies_button) {
                    body.insertAdjacentHTML('beforeend', response.contentHtml); 
                    return;
                }

                var [prev_num_replies, num_total_replies] = toggle_replies_button.textContent.match(/\d+/g);
                if (isRTL) [prev_num_replies, num_total_replies] = [num_total_replies, prev_num_replies];
                prev_num_replies -= 0; num_total_replies -= 0;  // convert to integers
                var num_current_replies = prev_num_replies + num_incoming_replies;

                var [newHTML, has_more_replies] = format_count_load_more(response.contentHtml, num_current_replies, num_total_replies);
                format_count_toggle_replies_button(toggle_replies_button, num_current_replies, num_total_replies, has_more_replies);

                body.insertAdjacentHTML('beforeend', newHTML);
            } else {
                // loads only once for each comment when first opening their replies
                body.removeChild(body.lastElementChild);  // Remove spinner

                var p = document.createElement('p');
                var a = document.createElement('a');
                p.appendChild(a);

                a.href = 'javascript:void(0)';
                a.onclick = hide_youtube_replies;

                var num_total_replies = originalHTML.split('data-load-replies')[1].match(/\d+/)[0] - 0;
                var num_replies_text = ' (0/0)';  // replace later
                var hide_replies_text = video_data.hide_replies_text + num_replies_text;
                a.setAttribute('data-sub-text', hide_replies_text);
                a.setAttribute('data-inner-text', video_data.show_replies_text + num_replies_text);
                a.textContent = hide_replies_text;

                var div = document.createElement('div');
                var [newHTML, has_more_replies] = format_count_load_more(response.contentHtml, num_incoming_replies, num_total_replies);
                format_count_toggle_replies_button(a, num_incoming_replies, num_total_replies, has_more_replies);

                div.innerHTML = newHTML;

                body.appendChild(p);
                body.appendChild(div);
            }
        },
        onNon200: function (xhr) {
            body.innerHTML = originalHTML;
        },
        onTimeout: function (xhr) {
            console.warn('Pulling comments failed');
            body.innerHTML = originalHTML;
        }
    });
}