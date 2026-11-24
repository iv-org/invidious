'use strict';
// Show the SABR codec preference only while the SABR player is selected.
(function () {
    var quality = document.getElementById('quality');
    var sabrGroup = document.getElementById('sabr-codec-group');
    if (!quality || !sabrGroup) return;

    quality.addEventListener('change', function () {
        sabrGroup.style.display = this.value === 'sabr' ? '' : 'none';
    });
})();
