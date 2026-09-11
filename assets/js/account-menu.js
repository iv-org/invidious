'use strict';

// Native details handles disclosure without scripts. These only add dismissal.
(function () {
    var menu = document.querySelector('.redesign-account-menu');
    if (!menu) return;
    var trigger = menu.querySelector('summary');
    document.addEventListener('keydown', function (event) {
        if (event.key === 'Escape' && menu.open) {
            menu.open = false;
            trigger.focus();
        }
    });
    document.addEventListener('click', function (event) {
        if (menu.open && !menu.contains(event.target)) menu.open = false;
    });
    document.addEventListener('focusin', function (event) {
        if (menu.open && !menu.contains(event.target)) menu.open = false;
    });
})();
