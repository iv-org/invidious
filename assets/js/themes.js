var toggle_theme = document.getElementById('toggle_theme')
toggle_theme.href = 'javascript:void(0);';

toggle_theme.addEventListener('click', function () {
    var dark_mode = document.getElementById('dark_theme').media == 'none';

    var url = '/toggle_theme?redirect=false';
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 20000;
    xhr.open('GET', url, true);
    xhr.send();

    set_mode(dark_mode);
    localStorage.setItem('dark_mode', dark_mode);
});

window.addEventListener('storage', function (e) {
    if (e.key == 'dark_mode') {
        var dark_mode = e.newValue === 'true';
        set_mode(dark_mode);
    }
});

function set_mode(bool) {
    document.getElementById('dark_theme').media = !bool ? 'none' : '';
    document.getElementById('light_theme').media = bool ? 'none' : '';

    if (bool) {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-sunny');
    } else {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-moon');
    }
}
