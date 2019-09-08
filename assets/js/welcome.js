var dismiss_welcome = document.getElementById('dismiss_welcome');
dismiss_welcome.href = 'javascript:void(0);';

dismiss_welcome.addEventListener('click', function () {
    var dark_mode = document.getElementById('dark_theme').media === 'none';

    var url = '/dismiss_welcome?redirect=false';
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', url, true);

    hide_welcome();
    window.localStorage.setItem('welcome_dismissed', true);

    xhr.send();
});

function hide_welcome (bool) {
    document.getElementById('feed-menu').classList.remove('hidden');
    document.getElementById('welcome-outer').classList.add('hidden');
}
