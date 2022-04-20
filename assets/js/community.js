'use strict';
var community_data = JSON.parse(document.getElementById('community_data').textContent);

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

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

function number_with_separator(val) {
    while (/(\d+)(\d{3})/.test(val.toString())) {
        val = val.toString().replace(/(\d+)(\d{3})/, '$1' + ',' + '$2');
    }
    return val;
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
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', url, true);

    xhr.onreadystatechange = function () {
        if (xhr.readyState === 4) {
            if (xhr.status === 200) {
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
                    a.setAttribute('data-sub-text', community_data.hide_replies_text);
                    a.setAttribute('data-inner-text', community_data.show_replies_text);
                    a.innerText = community_data.hide_replies_text;

                    var div = document.createElement('div');
                    div.innerHTML = xhr.response.contentHtml;

                    body.appendChild(p);
                    body.appendChild(div);
                }
            } else {
                body.innerHTML = fallback;
            }
        }
    };

    xhr.ontimeout = function () {
        console.warn('Pulling comments failed.');
        body.innerHTML = fallback;
    };

    xhr.send();
}
