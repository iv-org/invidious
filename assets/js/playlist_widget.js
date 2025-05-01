'use strict';
var playlist_data = JSON.parse(document.getElementById('playlist_data').textContent);
var payload = 'csrf_token=' + playlist_data.csrf_token;

function add_playlist_video(event) {
		const target = event.target;
    var select = document.querySelector("#playlists");
    var option = select.children[select.selectedIndex];

    var url = '/playlist_ajax?action=add_video&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&playlist_id=' + option.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        on200: function (response) {
            option.textContent = '✓ ' + option.textContent;
        }
    });
}

function add_playlist_item(event) {
		event.preventDefault();
		const target = event.target;
		const video_id = target.getAttribute('data-id');
    var card = document.querySelector(`#video-card-${video_id}`);
    card.classList.add("hide");

    var url = '/playlist_ajax?action=add_video&redirect=false' +
        '&video_id=' + target.getAttribute('data-id') +
        '&playlist_id=' + target.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
					card.classList.remove("hide");
        }
    });
}

function remove_playlist_item(event) {
		event.preventDefault();
		const target = event.target;
		const video_index = target.getAttribute('data-index');
		const card = document.querySelector(`.video-card [data-index="${video_index}"]`)
    card.classList.add("hide");

    var url = '/playlist_ajax?action=remove_video&redirect=false' +
        '&set_video_id=' + target.getAttribute('data-index') +
        '&playlist_id=' + target.getAttribute('data-plid');

    helpers.xhr('POST', url, {payload: payload}, {
        onNon200: function (xhr) {
					card.classList.remove("hide");
        }
    });
}
