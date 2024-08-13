'use strict';
var community_data = JSON.parse(document.getElementById('community_data').textContent);

// first page of community posts are loaded without javascript so we need to update the Load more button
var initialLoadMore = document.querySelector('a[data-onclick="get_youtube_replies"]');
initialLoadMore.setAttribute('href', 'javascript:void(0);');
initialLoadMore.removeAttribute('target');

function updateReplyLinks() {
    document.querySelectorAll("a[href^='/comment_viewer']").forEach(function (replyLink) {
        replyLink.setAttribute("href", "javascript:void(0)");
        replyLink.removeAttribute("target");
    });
}
updateReplyLinks();

function get_youtube_replies(target) {
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
            body = body.parentNode.parentNode;
            body.removeChild(body.lastElementChild);
            body.insertAdjacentHTML('beforeend', response.contentHtml);
            updateReplyLinks();
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
