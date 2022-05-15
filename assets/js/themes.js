'use strict';
var toggle_theme = document.getElementById('toggle_theme');
toggle_theme.href = 'javascript:void(0)';

const STORAGE_KEY_THEME = 'dark_mode';
const THEME_DARK = 'dark';
const THEME_LIGHT = 'light';
const THEME_SYSTEM = '';

// TODO: theme state controlled by system
toggle_theme.addEventListener('click', function () {
    const isDarkTheme = helpers.storage.get(STORAGE_KEY_THEME) === THEME_DARK;
    setTheme(isDarkTheme ? THEME_LIGHT : THEME_DARK);
    helpers.xhr('GET', '/toggle_theme?redirect=false', {}, {});
});


// Ask system about dark theme
var systemDarkTheme = matchMedia('(prefers-color-scheme: dark)');
systemDarkTheme.addListener(function () {
    // Ignore system events if theme set manually
    if (!helpers.storage.get(STORAGE_KEY_THEME))
        setTheme(THEME_SYSTEM);
});


/** @param {THEME_DARK|THEME_LIGHT|THEME_SYSTEM} theme */
function setTheme(theme) {
    if (theme !== THEME_SYSTEM)
        helpers.storage.set(STORAGE_KEY_THEME, theme);

    if (theme === THEME_DARK || (theme === THEME_SYSTEM && systemDarkTheme.matches)) {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-sunny');
        document.body.classList.remove('no-theme');
        document.body.classList.remove('light-theme');
        document.body.classList.add('dark-theme');
    } else {
        toggle_theme.children[0].setAttribute('class', 'icon ion-ios-moon');
        document.body.classList.remove('no-theme');
        document.body.classList.remove('dark-theme');
        document.body.classList.add('light-theme');
    }
}

// Handles theme change event caused by other tab
addEventListener('storage', function (e) {
    if (e.key === STORAGE_KEY_THEME) setTheme(e.newValue);
});

// Set theme from preferences on page load
addEventListener('DOMContentLoaded', function () {
    const prefTheme = document.getElementById('dark_mode_pref').textContent;
    setTheme(prefTheme);
});
