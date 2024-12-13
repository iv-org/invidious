'use strict';
var toggle_theme = document.getElementById('toggle_theme');
toggle_theme.href = 'javascript:void(0)';

const STORAGE_KEY_THEME = 'dark_mode';
const THEME_DARK = 'dark';
const THEME_LIGHT = 'light';

// TODO: theme state controlled by system
toggle_theme.addEventListener('click', function () {
    const isDarkTheme = helpers.storage.get(STORAGE_KEY_THEME) === THEME_DARK;
    const newTheme = isDarkTheme ? THEME_LIGHT : THEME_DARK;
    setTheme(newTheme);
    helpers.storage.set(STORAGE_KEY_THEME, newTheme);
    helpers.xhr('GET', '/toggle_theme?redirect=false', {}, {});
});

/** @param {THEME_DARK|THEME_LIGHT} theme */
function setTheme(theme) {
    // By default body element has .no-theme class that uses OS theme via CSS @media rules
    // It rewrites using hard className below
    if (theme === THEME_DARK) {
        toggle_theme.children[0].className = 'icon ion-ios-sunny';
        document.body.className = 'dark-theme';
    } else if (theme === THEME_LIGHT) {
        toggle_theme.children[0].className = 'icon ion-ios-moon';
        document.body.className = 'light-theme';
    } else {
        document.body.className = 'no-theme';
    }
}

// Handles theme change event caused by other tab
addEventListener('storage', function (e) {
    if (e.key === STORAGE_KEY_THEME)
        setTheme(helpers.storage.get(STORAGE_KEY_THEME));
});

// Set theme from preferences on page load
addEventListener('DOMContentLoaded', function () {
    const prefTheme = document.getElementById('dark_mode_pref').textContent;
    if (prefTheme) {
        setTheme(prefTheme);
        helpers.storage.set(STORAGE_KEY_THEME, prefTheme);
    }
});
