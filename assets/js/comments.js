var video_data = JSON.parse(document.getElementById('video_data').textContent);

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

// Moved channel emoji helper to top for safe access
helpers.replaceChannelEmojis = function(html) {
    if (!video_data.channelEmojis) return html;
    // Use DOM parser to replace only in text nodes
    const parser = new DOMParser();
    const doc = parser.parseFromString(html, 'text/html');
    const textNodes = doc.createTreeWalker(doc.body, NodeFilter.SHOW_TEXT);
    
    let node;
    while ((node = textNodes.nextNode())) {
        node.textContent = node.textContent.replace(/:([a-zA-Z0-9_]+):/g, (match, name) => {
            const emoji = video_data.channelEmojis[name];
            return emoji ? `<img src="${emoji.url}" alt="${name}" class="channel-emoji" />` : match;
        });
    }
    return doc.body.innerHTML;
};

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

function toggle_comments(event) {
    // ... existing code ...
}

// ... existing functions ...

function get_youtube_comments() {
    // ... existing code ...

    helpers.xhr('GET', url, {retries: 5, entity_name: 'comments'}, {
        on200: function (response) {
            var commentInnerHtml = `
            <div>
                <h3>
                    <a href="javascript:void(0)" class="comment-toggle">${video_data.comments_text}</a>
                    ${video_data.support_reddit ? ` <a href="javascript:void(0)" class="comment-toggle" data-comments="reddit">${video_data.reddit_comments_text}</a>` : ''}
                </h3>
                <div>${helpers.replaceChannelEmojis(response.contentHtml)}</div>
                <hr>
            </div>`;
            
            // Rebind handlers after DOM update
            document.querySelectorAll('.comment-toggle').forEach(el => {
                el.addEventListener('click', toggle_comments);
            });
            comments.innerHTML = commentInnerHtml;
        },
        // ... existing handlers ...
    });
}
