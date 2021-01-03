function toggle_comments(event) {
    var target = event.target;
    var body = document.getElementById('filters');
    if (body.style.display === 'flex') {
        target.innerHTML = '[ + ]';
        body.style.display = 'none';
    } else {
        target.innerHTML = '[ - ]';
        body.style.display = 'flex';
    }
}

document.getElementById('togglefilters').onclick = toggle_comments;