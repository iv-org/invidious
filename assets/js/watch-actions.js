'use strict';
(function () {
    var menus = document.querySelectorAll('.watch-action-menu');
    menus.forEach(function (menu) {
        menu.addEventListener('toggle', function () {
            if (menu.open) menus.forEach(function (other) {
                if (other !== menu && !other.contains(menu)) other.open = false;
            });
        });
    });
    document.addEventListener('click', function (event) {
        menus.forEach(function (menu) {
            if (!menu.contains(event.target)) menu.open = false;
        });
    });
    document.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') return;
        menus.forEach(function (menu) {
            if (menu.open) { menu.open = false; menu.querySelector('summary').focus(); }
        });
    });
    document.querySelectorAll('.watch-action').forEach(function (action) {
        if (!action.title) action.title = action.textContent.trim();
    });
    document.querySelectorAll('.watch-share-link').forEach(function (link) {
        var row = document.createElement('div');
        row.className = 'watch-share-choice';
        link.before(row); row.appendChild(link);
        var input = document.createElement('input');
        input.readOnly = true; input.value = link.href;
        input.setAttribute('aria-label', link.textContent.trim());
        input.addEventListener('focus', function () { input.select(); });
        row.appendChild(input);
        if (!navigator.clipboard) return;
        var button = document.createElement('button');
        button.type = 'button';
        var panel = row.closest('.watch-share-panel');
        button.textContent = panel.dataset.copyLabel;
        button.addEventListener('click', function () {
            navigator.clipboard.writeText(link.href).then(function () {
                button.textContent = panel.dataset.copiedLabel;
                setTimeout(function () { button.textContent = panel.dataset.copyLabel; }, 1800);
            }).catch(function () { input.focus(); input.select(); });
        });
        row.appendChild(button);
    });
})();
