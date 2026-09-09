var video_data = JSON.parse(document.getElementById('video_data').textContent);

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, function (a, b) {
        var r = o[b];
        return typeof r === 'string' || typeof r === 'number' ? r : a;
    });
};

// Added channel emoji conversion helper
helpers.replaceChannelEmojis = function(html) {
    if (!video_data.channelEmojis) return html;
    return html.replace(/:([a-zA-Z0-9_]+):/g, (match, name) => {
        const emoji = video_data.channelEmojis[name];
        return emoji ? `<img src="${emoji.url}" alt="${name}" class="channel-emoji" />` : match;
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
            
            // Apply channel emoji conversion
            var processedContentHtml = helpers.replaceChannelEmojis(response.contentHtml);
            commentInnerHtml = commentInnerHtml.supplant({
                contentHtml: processedContentHtml,
                commentsText: video_data.comments_text,
                redditComments: video_data.reddit_comments_text
            });
            comments.innerHTML = commentInnerHtml;
        },
        // ... existing handlers ...
    });
}
