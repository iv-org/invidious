'use strict';
var video_data = JSON.parse(document.getElementById('video_data').textContent);

function get_playlist(plid) {
    var plid_url;
    if (plid.startsWith('RD')) {
        plid_url = '/api/v1/mixes/' + plid +
            '?continuation=' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    } else {
        plid_url = '/api/v1/playlists/' + plid +
            '?index=' + video_data.index +
            '&continuation' + video_data.id +
            '&format=html&hl=' + video_data.preferences.locale;
    }

    helpers.xhr('GET', plid_url, {retries: 5, entity_name: 'playlist'}, {
        on200: function (response) {
            if (!response.nextVideo)
                return;

            player.on('ended', function () {
                var url = new URL('https://example.com/embed/' + response.nextVideo);

                url.searchParams.set('list', plid);
                if (!plid.startsWith('RD'))
                    url.searchParams.set('index', response.index);
                if (video_data.params.autoplay || video_data.params.continue_autoplay)
                    url.searchParams.set('autoplay', '1');
                if (video_data.params.listen !== video_data.preferences.listen)
                    url.searchParams.set('listen', video_data.params.listen);
                if (video_data.params.speed !== video_data.preferences.speed)
                    url.searchParams.set('speed', video_data.params.speed);
                if (video_data.params.local !== video_data.preferences.local)
                    url.searchParams.set('local', video_data.params.local);

                location.assign(url.pathname + url.search);
            });
        }
    });
}

addEventListener('load', function (e) {
    if (video_data.plid) {
        get_playlist(video_data.plid);
    } else if (video_data.video_series) {
        player.on('ended', function () {
            var url = new URL('https://example.com/embed/' + video_data.video_series.shift());

            if (video_data.params.autoplay || video_data.params.continue_autoplay)
                url.searchParams.set('autoplay', '1');
            if (video_data.params.listen !== video_data.preferences.listen)
                url.searchParams.set('listen', video_data.params.listen);
            if (video_data.params.speed !== video_data.preferences.speed)
                url.searchParams.set('speed', video_data.params.speed);
            if (video_data.params.local !== video_data.preferences.local)
                url.searchParams.set('local', video_data.params.local);
            if (video_data.video_series.length !== 0)
                url.searchParams.set('playlist', video_data.video_series.join(','));

            location.assign(url.pathname + url.search);
        });
    }
});

function return_message(message, target_window) {
    if (target_window === undefined) {
        target_window = window.parent;
    }
    let url_params = new URLSearchParams(location.search);
    let widgetid = url_params.get('widgetid');
    let additional_info = { from: 'invidious_control' };
    if (widgetid !== null) {
        additional_info.widgetid = widgetid;
    }
    if (message.message_kind === 'event') {
        if (message.eventname === 'timeupdate' || message.eventname === 'loadedmetadata') {
            additional_info['value'] = { getvolume: player.volume(), getduration: player.duration(), getcurrenttime: player.currentTime(), getplaystatus: player.paused(), getplaybackrate: player.playbackRate(), getloopstatus: player.loop(), getmutestatus: player.muted(), getfullscreenstatus: player.isFullscreen(), getavailableplaybackrates: options.playbackRates, gettitle: player_data.title, getplaylistindex: video_data.index, getplaylistid: video_data.plid };
        }
    }
    if (message.eventname === 'error') {
        additional_info['value'] = { geterrorcode: player.error().code };
    }
    message = Object.assign(additional_info, message);
    let target_origin = url_params.get('origin') || '*';
    target_window.postMessage(message, target_origin);
}

function control_embed_iframe(message) {
    const url_params = new URLSearchParams(location.search);
    const origin = url_params.get('origin');
    const origin_equal = origin === null || origin === message.origin;
    if (origin_equal) {
        const widgetid = url_params.get('widgetid');
        const widgetid_equal = widgetid === message.data.widgetid;
        const target_name_equal = message.data.target === 'invidious_control';
        const eventname_string_check = typeof message.data.eventname === 'string';
        if (widgetid_equal && target_name_equal && eventname_string_check) {
            let message_return_value;
            switch (message.data.eventname) {
                case 'play':
                    player.play();
                    break;
                case 'pause':
                    player.pause();
                    break;

                case 'setvolume':
                    player.volume(message.data.value);
                    break;
                case 'seek':
                    const duration = player.duration();
                    let newTime = helpers.clamp(message.data.value, 0, duration);
                    player.currentTime(newTime);
                    break;
                case 'setplaybackrate':
                    player.playbackRate(message.data.value);
                    break;
                case 'setloopstatus':
                    player.loop(message.data.value);
                    break;
                case 'requestfullscreen':
                    player.requestFullscreen();
                    break;
                case 'exitfullscreen':
                    player.exitFullscreen();
                    break;

                case 'getvolume':
                    message_return_value = player.volume();
                    break;
                case 'getduration':
                    message_return_value = player.duration();
                    break;
                case 'getcurrenttime':
                    message_return_value = player.currentTime();
                    break;
                case 'getplaystatus':
                    message_return_value = player.paused();
                    break;
                case 'getplaybackrate':
                    message_return_value = player.playbackRate();
                    break;
                case 'getavailableplaybackrates':
                    message_return_value = options.playbackRates;
                    break;
                case 'getloopstatus':
                    message_return_value = player.loop();
                    break;
                case 'getmutestatus':
                    message_return_value = player.muted();
                    break;
                case 'gettitle':
                    message_return_value = player_data.title;
                    break;
                case 'getfullscreenstatus':
                    message_return_value = player.isFullscreen();
                    break;
                case 'geterrorcode':
                    message_return_value = player.error().code;
                    break;
                case 'getplaylistindex':
                    message_return_value = video_data.index;
                    break;
                case 'getplaylistid':
                    message_return_value = video_data.plid;
                    break;
                default:
                    console.info("Unhandled event name: " + message.data.eventname);
                    break;
            }
            if (message_return_value !== undefined) {
                return_message({ command: message.data.eventname, value: message_return_value, message_kind: 'info_return' }, message.source);
            }
        }
    }
}

if (new URLSearchParams(location.search).get('enablejsapi') === '1') {
    window.addEventListener('message', control_embed_iframe);
    const event_list = ['ended', 'error', 'ratechange', 'volumechange', 'waiting', 'timeupdate', 'loadedmetadata', 'play', 'seeking', 'seeked', 'playerresize', 'pause'];
    event_list.forEach(event_name => {
        player.on(event_name, function () { return_message({ message_kind: 'event', eventname: event_name }) });
    });
}
