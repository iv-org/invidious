var dismiss_welcome = document.getElementById('dismiss_welcome');
dismiss_welcome.href = 'javascript:void(0);';

dismiss_welcome.addEventListener('click', function () {
    var url = '/dismiss_info?name=welcome&redirect=false';
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', url, true);

    hide_welcome();

    xhr.send();
});

function hide_welcome (bool) {
    document.getElementById('welcome-outer').classList.add('hidden');
}
