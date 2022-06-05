'use strict';
var community_data = JSON.parse(document.getElementById('community_data').textContent);

function hide_youtube_replies(event) {
    var target = event.target;

    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');

    var body = target.parentNode.parentNode.children[1];
    body.style.display = 'none';

    target.innerHTML = sub_text;
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

    target.innerHTML = sub_text;
    target.onclick = hide_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function get_youtube_replies(target, load_more) {
    var continuation = target.getAttribute('data-continuation');

    var body = target.parentNode.parentNode;
    var fallback = body.innerHTML;
    body.innerHTML =
        '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';

    var url = '/api/v1/channels/comments/' + community_data.ucid +
        '?format=html' +
        '&hl=' + community_data.preferences.locale +
        '&thin_mode=' + community_data.preferences.thin_mode +
        '&continuation=' + continuation;

    helpers.xhr('GET', url, {}, {
        on200: function (response) {
            if (load_more) {
                body = body.parentNode.parentNode;
                body.removeChild(body.lastElementChild);
                body.innerHTML += response.contentHtml;
            } else {
                body.removeChild(body.lastElementChild);

                var p = document.createElement('p');
                var a = document.createElement('a');
                p.appendChild(a);

                a.href = 'javascript:void(0)';
                a.onclick = hide_youtube_replies;
                a.setAttribute('data-sub-text', community_data.hide_replies_text);
                a.setAttribute('data-inner-text', community_data.show_replies_text);
                a.textContent = community_data.hide_replies_text;

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
