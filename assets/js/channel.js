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

// WeakMap to preserve original DOM nodes with event handlers
const fallbackMap = new WeakMap();

function hide_youtube_replies(event) {
    var target = event.target;
    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');
    var body = target.parentNode.parentNode.children[1];
    
    // Preserve original DOM node with event handlers
    fallbackMap.set(target, body.cloneNode(true));
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
    
    if (fallbackMap.has(target)) {
        const preservedNode = fallbackMap.get(target);
        body.parentNode.replaceChild(preservedNode, body);
    }
    
    target.textContent = sub_text;
    target.onclick = hide_youtube_replies;
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function get_youtube_comments() {
    var comments = document.getElementById('comments');
    var originalContent = comments.cloneNode(true);
    var parent = comments.parentNode;
    
    // Create spinner and replace original content
    var spinner = document.createElement('div');
    spinner.innerHTML = spinnerHTML;
    parent.replaceChild(spinner, comments);

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
        // Restore original content with preserved event handlers
        parent.replaceChild(originalContent, spinner);
        
        if (!video_data.comments_enabled) {
            const safeCommentsDisabled = document.createElement('div');
            safeCommentsDisabled.id = "comments-turned-off-on-video-message";
            safeCommentsDisabled.className = "h-box v-box";
            safeCommentsDisabled.innerHTML = `
                <p><b>${escapeHtml(video_data.comments_youtube_disabled_text)}</b></p>
                <p><b><button href="javascript:void(0)" data-comments="reddit" id="try-reddit-comments-link" class="simulated_a">
                    ${escapeHtml(video_data.comments_youtube_disabled_try_reddit)}
                </button></b></p>`;
            
            safeCommentsDisabled.querySelector("#try-reddit-comments-link").onclick = swap_comments;
            parent.appendChild(safeCommentsDisabled);
        }
    };

    if (video_data.params.comments[1] === 'youtube') {
        // Request handling with proper error recovery
        fetch(url)
            .then(response => {
                if (!response.ok) throw new Error('Network error');
                return response.text();
            })
            .then(html => {
                const temp = document.createElement('div');
                temp.innerHTML = html;
                parent.replaceChild(temp.firstChild, spinner);
            })
            .catch(() => onNon200());
    }
}

// Enhanced metadata handling for collaborative videos
function renderVideoMetadata() {
    const metadataContainer = document.getElementById('video-metadata');
    if (!metadataContainer) return;

    const authors = video_data.authors || [video_data.author];
    const authorsHtml = authors.map(a => `<a href="${escapeHtml(a.url)}" class="author-link">${escapeHtml(a.name)}</a>`).join(', ');
    
    const metadataTemplate = `
        <div class="metadata-published">
            ${video_data.published_text} • 
            ${video_data.view_count_text} views
        </div>
        <div class="metadata-authors">${authorsHtml}</div>
    `;
    
    metadataContainer.innerHTML = metadataTemplate;
}

// Initialize metadata rendering
renderVideoMetadata();

// URL validation middleware for all link creation
function createSafeLink(url, text) {
    if (!validateUrl(url)) return document.createTextNode(text);
    
    const link = document.createElement('a');
    link.href = escapeHtml(url);
    link.textContent = text;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    return link;
}

// Apply URL validation to all comment rendering paths
document.querySelectorAll('.comment-link').forEach(link => {
    const url = link.getAttribute('href');
    if (!validateUrl(url)) {
        link.removeAttribute('href');
        link.classList.add('unsafe-link');
    } else {
        link.textContent = escapeHtml(link.textContent);
    }
});
