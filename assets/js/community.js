'use strict';
var community_data = JSON.parse(document.getElementById('community_data').textContent);

function hide_youtube_replies(event) {
    var target = event.target;
    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');
    
    var body = target.parentNode.parentNode.children[1];
    body.style.display = 'none';
    
    target.innerHTML = sub_text;  // Show "show replies" label
    target.onclick = show_youtube_replies;
    // Swap data attributes for next toggle
    target.setAttribute('data-inner-text', inner_text);
    target.setAttribute('data-sub-text', sub_text);
}

function show_youtube_replies(event) {
    var target = event.target;
    var sub_text = target.getAttribute('data-inner-text');
    var inner_text = target.getAttribute('data-sub-text');
    
    var body = target.parentNode.parentNode.children[1];
    body.style.display = '';
    
    target.innerHTML = inner_text;  // Show "hide replies" label
    target.onclick = hide_youtube_replies;
    // Swap data attributes for next toggle
    target.setAttribute('data-inner-text', sub_text);
    target.setAttribute('data-sub-text', inner_text);
}

// Ensure community.js is included in watch pages
if (typeof get_youtube_replies === 'undefined' && window.location.pathname.includes('/watch')) {
    // Implement watch-page specific reply loader or include community.js
    console.error('Community functions not initialized for watch page');
}

// ... rest of existing code ...
