'use strict';
var toggle_theme = document.getElementById('toggle_theme');
if (toggle_theme) toggle_theme.href = 'javascript:void(0)';
var theme_choices = document.querySelectorAll('[data-theme]');

const STORAGE_KEY_THEME = 'dark_mode';
const THEME_DARK = 'dark';
const THEME_LIGHT = 'light';

// TODO: theme state controlled by system
if (toggle_theme) toggle_theme.addEventListener('click', function () {
    const isDarkTheme = helpers.storage.get(STORAGE_KEY_THEME) === THEME_DARK;
    const newTheme = isDarkTheme ? THEME_LIGHT : THEME_DARK;
    setTheme(newTheme);
    helpers.storage.set(STORAGE_KEY_THEME, newTheme);
    helpers.xhr('GET', '/toggle_theme?redirect=false', {}, {});
});

theme_choices.forEach(function (choice) {
    choice.addEventListener('click', function (event) {
        event.preventDefault();
        var theme = choice.dataset.theme;
        setTheme(theme);
        helpers.storage.set(STORAGE_KEY_THEME, theme);
        helpers.xhr('GET', '/toggle_theme?redirect=false&mode=' + theme, {}, {});
    });
});

/** @param {THEME_DARK|THEME_LIGHT} theme */
function setTheme(theme) {
    theme_choices.forEach(function (choice) {
        if (choice.dataset.theme === theme) choice.setAttribute('aria-current', 'true');
        else choice.removeAttribute('aria-current');
    });
    // Replace only the theme; preserve layout classes used by the rendered page.
    document.body.classList.remove('no-theme', 'dark-theme', 'light-theme');
    if (theme === THEME_DARK) {
        if (toggle_theme) toggle_theme.children[0].className = 'icon ion-ios-sunny';
        document.body.classList.add('dark-theme');
    } else if (theme === THEME_LIGHT) {
        if (toggle_theme) toggle_theme.children[0].className = 'icon ion-ios-moon';
        document.body.classList.add('light-theme');
    } else {
        document.body.classList.add('no-theme');
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
