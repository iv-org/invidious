var video_data = JSON.parse(document.getElementById('video_data').textContent);

var spinnerHTML = '<h3 style="text-align:center"><div class="loading"><i class="icon ion-ios-refresh"></i></div></h3>';
var spinnerHTMLwithHR = spinnerHTML + '<hr>';

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

const validateUrl = (url) => {
    try {
        const parsed = new URL(url);
        return ['http:', 'https:', 'invidious:'].includes(parsed.protocol);
    } catch {
        return false;
    }
};

String.prototype.supplant = function (o) {
    return this.replace(/{([^{}]*)}/g, (match, key) => {
        const replacement = o[key];
        if (typeof replacement === 'string' || typeof replacement === 'number') {
            return escapeHtml(replacement);
        }
        return match;
    });
};

// ... [preserved existing toggle_comments function] ...

// WeakMap to preserve original DOM nodes with event handlers
const fallbackMap = new WeakMap();

// ... [preserved hide/show_youtube_replies functions with DOM restoration] ...

function get_youtube_comments() {
    var comments = document.getElementById('comments');
    var originalContent = comments.cloneNode(true);
    var parent = comments.parentNode;
    
    // Create spinner and replace original content
    var spinner = document.createElement('div');
    spinner.innerHTML = spinnerHTML;
    parent.replaceChild(spinner, comments);

    var baseUrl = video_data.base_url || '/api/v1/comments/' + video_data.id;
    var url = baseUrl +
        '?format=html' +
        '&hl=' + encodeURIComponent(video_data.preferences.locale) +
        '&thin_mode=' + video_data.preferences.thin_mode;

    if (video_data.ucid) {
        url += '&ucid=' + encodeURIComponent(video_data.ucid);
    }

    var onNon200 = function (xhr) {
        parent.replaceChild(originalContent, spinner);
        
        if (!video_data.comments_enabled) {
            const safeCommentsDisabled = document.createElement('div');
            safeCommentsDisabled.id = "comments-turned-off-on-video-message";
            safeCommentsDisabled.className = "h-box v-box";
            safeCommentsDisabled.innerHTML = `
                <p><b>${escapeHtml(video_data.comments_youtube_disabled_text)}</b></p>
                <p><b><button href="${validateUrl(video_data.comments_youtube_disabled_link) ? 
                    escapeHtml(video_data.comments_youtube_disabled_link) : 
                    'javascript:void(0)'}">
                    ${escapeHtml(video_data.comments_youtube_disabled_link_text)}
                </button></b></p>`;
            parent.appendChild(safeCommentsDisabled);
        }
    };

    // ... [preserved XHR handling with proper fallback restoration] ...
}

// Channel metadata rendering with DOM-safe construction
function renderVideoMetadata(metadata) {
    const container = document.getElementById('video-metadata');
    if (!container) return;
    
    container.innerHTML = ''; // Clear existing content
    
    metadata.authors.forEach(author => {
        const authorLink = document.createElement('a');
        const authorUrl = validateUrl(author.url) ? author.url : 'javascript:void(0)';
        authorLink.href = authorUrl;
        authorLink.className = 'author-link';
        
        const nameSpan = document.createElement('span');
        nameSpan.textContent = author.name;
        authorLink.appendChild(nameSpan);
        
        const detailsDiv = document.createElement('div');
        detailsDiv.className = 'author-details';
        detailsDiv.textContent = `${author.publishedText} • ${author.viewCountText}`;
        
        container.appendChild(authorLink);
        container.appendChild(detailsDiv);
    });
}

// ... [remaining preserved code] ...
