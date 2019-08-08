var toggle_theme = document.getElementById('toggle_theme');
toggle_theme.href = 'javascript:void(0);';

toggle_theme.addEventListener('click', function () {
    var dark_mode = document.getElementById('dark_theme').media === 'none';

    var url = '/toggle_theme?redirect=false';
    var xhr = new XMLHttpRequest();
    xhr.responseType = 'json';
    xhr.timeout = 10000;
    xhr.open('GET', url, true);

    set_mode(dark_mode);
    window.localStorage.setItem('dark_mode', dark_mode ? 'dark' : 'light');

    xhr.send();
});

window.addEventListener('storage', function (e) {
    if (e.key === 'dark_mode') {
        update_mode(e.newValue);
    }
});

window.addEventListener('load', function () {
    window.localStorage.setItem('dark_mode', document.getElementById('dark_mode_pref').textContent);
    // Update localStorage if dark mode preference changed on preferences page
    update_mode(window.localStorage.dark_mode);
});

function set_mode (bool) {
    document.getElementById('dark_theme').media = !bool ? 'none' : '';
    document.getElementById('light_theme').media = bool ? 'none' : '';

    if (bool) {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-sunny');
    } else {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-moon');
    }
}

function update_mode (mode) {
    if (mode === 'true' /* for backwards compatibility */ || mode === 'dark') {
        // If preference for dark mode indicated
        set_mode(true);
    }
	else if (mode === 'false' /* for backwards compaibility */ || mode === 'light') {
		// If preference for light mode indicated
		set_mode(false);
	}
    else if (document.getElementById('dark_mode_pref').textContent === '' && window.matchMedia('(prefers-color-scheme: dark)').matches) {
        // If no preference indicated here and no preference indicated on the preferences page (backend), but the browser tells us that the operating system has a dark theme
        set_mode(true);
    }
    // else do nothing, falling back to the mode defined by the `dark_mode` preference on the preferences page (backend)
}


