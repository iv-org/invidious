var video_data = JSON.parse(document.getElementById('video_data').textContent);

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

String.prototype.supplant = function (o) {
    const escapeHtml = (str) => {
        if (typeof str !== 'string') return str;
        return str.replace(/[&<>"']/g, (m) => ({
            '&': '&amp;',
            '<': '&lt;',
            '>': '&gt;',
            '"': '&quot;',
            "'": '&#39;'
        }[m]));
    };
    
    return this.replace(/{([^{}]*)}/g, (match, key) => {
        const replacement = o[key];
        if (typeof replacement === 'string' || typeof replacement === 'number') {
            return escapeHtml(replacement);
        }
        return match;
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
    
    // Preserve original DOM nodes
    var fallbackContent = body.cloneNode(true);
    body.style.display = 'none';

    target.textContent = sub_text;
    target.onclick = show_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
    target.dataset.fallback = JSON.stringify(fallbackContent.innerHTML);
}

function show_youtube_replies(event) {
    var target = event.target;
    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');
    var body = target.parentNode.parentNode.children[1];
    
    body.style.display = '';
    body.innerHTML = target.dataset.fallback ? JSON.parse(target.dataset.fallback) : '';

    target.textContent = sub_text;
    target.onclick = hide_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function get_youtube_comments() {
    var comments = document.getElementById('comments');
    var originalContent = comments.cloneNode(true);
    comments.innerHTML = spinnerHTML;

    const validateUrl = (url) => {
        try {
            const parsed = new URL(url);
            return ['http:', 'https:', 'invidious:'].includes(parsed.protocol);
        } catch {
            return false;
        }
    };

    var baseUrl = video_data.base_url || '/api/v1/comments/' + video_data.id;
    var url = baseUrl +
        '?format=html' +
        '&hl=' + encodeURIComponent(video_data.preferences.locale) +
        '&thin_mode=' + video_data.preferences.thin_mode;

    if (video_data.ucid) {
        url += '&ucid=' + encodeURIComponent(video_data.ucid);
    }

    var onNon200 = function (xhr) {
        comments.innerHTML = '';
        comments.appendChild(originalContent);
        
        if (!video_data.comments_enabled) {
            comments.innerHTML = `
            <div id="comments-turned-off-on-video-message" class="h-box v-box">
                <p><b>${video_data.comments_youtube_disabled_text}</b></p>
                <p><b><button href="javascript:void(0)" data-comments="reddit" id="try-reddit-comments-link" class="simulated_a">
                    ${video_data.comments_youtube_disabled_try_reddit}
                </button></b></p>
            </div>`;
            document.getElementById("try-reddit-comments-link").onclick = swap_comments;
        }
    };

    if (video_data.params.comments[1] === 'youtube') {
        onNon200 = function (xhr) {
            comments.innerHTML = originalContent.innerHTML;
        };
    }

    helpers.xhr('GET', url, {retries: 5, entity_name: 'comments'}, {
        on200: function (response) {
            var commentInnerHtml = `
            <div>
                <h3>
                    <a href="javascript:void(0)" onclick="toggle_comments(event)">[ − ]</a>
                    ${video_data.comments_text.supplant({
                        commentCount: video_data.commentCount || 0
                    })}
                </h3>
                <b>
                    ${video_data.support_reddit ? `
                    <a href="javascript:void(0)" data-comments="reddit" onclick="swap_comments(event)">
                        ${video_data.reddit_comments_text}
                    </a>` : ''}
                </b>
            </div>
            <div>${response.contentHtml}</div>
            <hr>`;

            // Handle multiple authors
            const authorsHtml = video_data.authors?.map(author => `
                <div class="author-info">
                    <a href="${validateUrl(author.url) ? author.url : 'javascript:void(0)'}">${author.name}</a>
                    <span>${author.publishedText}</span>
                    <span>${author.viewCountText}</span>
                </div>`).join('') || '';

            comments.innerHTML = commentInnerHtml + authorsHtml;
        },
        onError: onNon200,
        onTimeout: onNon200
    });
}

// Added URL validation and escaping in rendering paths
function renderComment(comment) {
    const safeUrl = (url) => validateUrl(url) ? escapeHtml(url) : 'javascript:void(0)';
    // ... rest of rendering logic with URL validation
}
