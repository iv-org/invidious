'use strict';
// Show the SABR preferences (video quality, codec) only while the SABR player is selected.
(function () {
    var quality = document.getElementById('quality');
    var sabrGroups = document.querySelectorAll('.sabr-preference');
    if (!quality || sabrGroups.length === 0) return;

    quality.addEventListener('change', function () {
        var display = this.value === 'sabr' ? '' : 'none';
        sabrGroups.forEach(function (group) { group.style.display = display; });
    });
})();
