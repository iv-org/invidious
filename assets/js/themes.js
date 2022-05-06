'use strict';
var toggle_theme = document.getElementById('toggle_theme');
toggle_theme.href = 'javascript:void(0)';

toggle_theme.addEventListener('click', function () {
    var dark_mode = document.body.classList.contains('light-theme');

    set_mode(dark_mode);
    helpers.storage.set('dark_mode', dark_mode ? 'dark' : 'light');

    helpers.xhr('GET', '/toggle_theme?redirect=false', {}, {});
});

// Handles theme change event caused by other tab
addEventListener('storage', function (e) {
    if (e.key === 'dark_mode') {
        update_mode(e.newValue);
    }
});

addEventListener('DOMContentLoaded', function () {
    const dark_mode = document.getElementById('dark_mode_pref').textContent;
    // Update storage if dark mode preference changed on preferences page
    helpers.storage.set('dark_mode', dark_mode);
    update_mode(dark_mode);
});


var darkScheme = matchMedia('(prefers-color-scheme: dark)');
var lightScheme = matchMedia('(prefers-color-scheme: light)');

darkScheme.addListener(scheme_switch);
lightScheme.addListener(scheme_switch);

function scheme_switch (e) {
    // ignore this method if we have a preference set
    if (helpers.storage.get('dark_mode')) return;

    if (!e.matches) return;

    if (e.media.includes('dark')) {
        set_mode(true);
    } else if (e.media.includes('light')) {
        set_mode(false);
    }
}

function set_mode (bool) {
    if (bool) {
        // dark
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-sunny');
        document.body.classList.remove('no-theme');
        document.body.classList.remove('light-theme');
        document.body.classList.add('dark-theme');
    } else {
        // light
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-moon');
        document.body.classList.remove('no-theme');
        document.body.classList.remove('dark-theme');
        document.body.classList.add('light-theme');
    }
}

function update_mode (mode) {
    if (mode === 'true' /* for backwards compatibility */ || mode === 'dark') {
        // If preference for dark mode indicated
        set_mode(true);
    }
    else if (mode === 'false' /* for backwards compatibility */ || mode === 'light') {
        // If preference for light mode indicated
        set_mode(false);
    }
    else if (document.getElementById('dark_mode_pref').textContent === '' && matchMedia('(prefers-color-scheme: dark)').matches) {
        // If no preference indicated here and no preference indicated on the preferences page (backend), but the browser tells us that the operating system has a dark theme
        set_mode(true);
    }
    // else do nothing, falling back to the mode defined by the `dark_mode` preference on the preferences page (backend)
}
