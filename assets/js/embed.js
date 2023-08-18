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

function return_message(message,target_window){
    if(target_window===undefined){
        target_window = window.parent;
    }
    let url_params = new URLSearchParams(location.search);
    let widgetid = url_params.get('widgetid');
    let additional_info = {from:'invidious_control'};
    if(widgetid!==null){
        additional_info.widgetid = widgetid;
    }
    if(message.message_kind==='event'&&message.eventname==='timeupdate'||message.eventname==='loadedmetadata'){
        let add_value = {getvolume:player.volume(),getduration:player.duration(),getcurrenttime:player.currentTime(),getplaystatus:player.paused(),getplaybackrate:player.playbackRate(),getloopstatus:player.loop(),getmutestatus:player.muted(),getfullscreenstatus:player.isFullscreen(),getavailableplaybackrates:options.playbackRates,gettitle:player_data.title};
        additional_info['value'] = add_value;
    }
    if(message.eventname==='error'){
        let add_value = {geterrorcode:player.error().code};
        additional_info['value'] = add_value;
    }
    message = Object.assign(additional_info,message);
    let target_origin = url_params.get('origin');
    if(target_origin===null){
        target_origin = '*';
    }
    target_window.postMessage(message,target_origin);
}

function control_embed_iframe(message){
    let url_params = new URLSearchParams(location.search);
    let origin = url_params.get('origin');
    if(origin===null||origin===message.origin){
        let widgetid = url_params.get('widgetid');
        if((widgetid===null&&message.data.widgetid===null)||widgetid===message.data.widgetid&&message.data.target==='invidious_control'){
            switch(message.data.eventname){
                case 'play':
                    player.play();
                    break;
                case 'pause':
                    player.pause();
                    break;
                case 'getvolume':
                    return_message({command:'getvolume',value:player.volume(),message_kind:'info_return'},message.source);
                    break;
                case 'setvolume':
                    player.volume(message.data.value);
                    break;
                case 'getduration':
                    return_message({command:'getduration',value:player.duration(),message_kind:'info_return'},message.source);
                    break;
                case 'getcurrenttime':
                    return_message({command:'getcurrenttime',value:player.currentTime(),message_kind:'info_return'},message.source);
                    break;
                case 'seek':
                    const duration = player.duration();
                    let newTime = helpers.clamp(message.data.value, 0, duration);
                    player.currentTime(newTime);
                    break;
                case 'getplaystatus':
                    return_message({command:'getplaystatus',value:player.paused(),message_kind:'info_return'},message.source);
                    break;
                case 'getplaybackrate':
                    return_message({command:'getplaybackrate',value:player.playbackRate(),message_kind:'info_return'},message.source);
                    break;
                case 'setplaybackrate':
                    player.playbackRate(message.data.value);
                    break;
                case 'getavailableplaybackrates':
                    return_message({command:'getavailableplaybackrates',value:options.playbackRates,message_kind:'info_return'},message.source);
                    break;
                case 'getloopstatus':
                    return_message({command:'getloopstatus',value:player.loop(),message_kind:'info_return'},message.source);
                    break;
                case 'setloopstatus':
                    player.loop(message.data.value);
                    break;
                case 'getmutestatus':
                    return_message({command:'getmutestatus',value:player.muted(),message_kind:'info_return'},message.source);
                    break;
                case 'setmutestatus':
                    player.muted(message.data.value);
                    break;
                case 'gettitle':
                    return_message({command:'gettitle',value:player_data.title,message_kind:'info_return'},message.source);
                    break;
                case 'getfullscreenstatus':
                    return_message({command:'getfullscreenstatus',value:player.isFullscreen(),message_kind:'info_return'},message.source);
                    break;
                case 'requestfullscreen':
                    player.requestFullscreen();
                    break;
                case 'exitfullscreen':
                    player.exitFullscreen();
                    break;
                case 'geterrorcode':
                    return_message({command:'geterrorcode',value:player.error().code,message_kind:'info_return'},message.source);
                    break;
                case 'getplaylist':

            }
        }
    }
}

if(new URLSearchParams(location.search).get('enablejsapi')==='1'){
    window.addEventListener('message',control_embed_iframe);
    player.on('ended',()=>{return_message({message_kind:'event',eventname:'ended'})});
    player.on('error',()=>{return_message({message_kind:'event',eventname:'error'})});
    player.on('ratechange',()=>{return_message({message_kind:'event',eventname:'ratechange'})});
    player.on('volumechange',()=>{return_message({message_kind:'event',eventname:'volumechange'})});
    player.on('waiting',()=>{return_message({message_kind:'event',eventname:'waiting'})});
    player.on('timeupdate',()=>{return_message({message_kind:'event',eventname:'timeupdate'})});
    player.on('loadedmetadata',()=>{return_message({message_kind:'event',eventname:'loadedmetadata'})});
    player.on('play',()=>{return_message({message_kind:'event',eventname:'play'})});
    player.on('seeking',()=>{return_message({message_kind:'event',eventname:'seeking'})});
    player.on('seeked',()=>{return_message({message_kind:'event',eventname:'seeked'})});
    player.on('playerresize',()=>{return_message({message_kind:'event',eventname:'playerresize'})});
    player.on('pause',()=>{return_message({message_kind:'event',eventname:'pause'})});
}
