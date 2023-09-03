class invidious_embed {
    static widgetid = 0;
    static eventname_table = { onPlaybackRateChange: 'ratechange', onStateChange: 'statechange', onError: 'error', onReady: 'ready' };
    static available_event_name = ['ready', 'ended', 'error', 'ratechange', 'volumechange', 'waiting', 'timeupdate', 'loadedmetadata', 'play', 'seeking', 'seeked', 'playerresize', 'pause'];
    static api_promise = false;
    static invidious_instance = '';
    static api_instance_list = [];
    static instance_status_list = {};

    addEventListener(eventname, func) {
        if (eventname in invidious_embed.eventname_table) {
            eventname = invidious_embed.eventname_table[eventname];
        }
        this.eventElement.addEventListener(eventname,func);
    }

    removeEventListener(eventname, func) {
        if (eventname in invidious_embed.eventname_table) {
            eventname = invidious_embed.eventname_table[eventname];
        }
        this.eventElement.removeEventListener(eventname,func);
    }

    async instance_access_check(instance_origin) {
        let return_status;
        const status_cahce_exist = instance_origin in invidious_embed.instance_status_list;
        if (!status_cahce_exist) {
            try {
                const instance_stats = await fetch(instance_origin + '/api/v1/stats');
                if (instance_stats.ok) {
                    const instance_stats_json = await instance_stats.json();
                    if (instance_stats_json.software.name === 'invidious') {
                        return_status = true;
                    } else {
                        return_status = false;
                    }
                } else {
                    return_status = false;
                }
            } catch {
                return_status = false;
            }
            invidious_embed.instance_status_list[instance_origin] = return_status;
            return return_status;
        } else {
            return invidious_embed.instance_status_list[instance_origin];
        }
    }

    async get_instance_list() {
        invidious_embed.api_instance_list = [];
        const instance_list_api = await (await fetch('https://api.invidious.io/instances.json?pretty=1&sort_by=type,users')).json();
        instance_list_api.forEach(instance_data => {
            const http_check = instance_data[1]['type'] === 'https';
            let status_check_api_data;
            if (instance_data[1]['monitor'] !== null) {
                status_check_api_data = instance_data[1]['monitor']['statusClass'] === 'success';
            }
            const api_available = instance_data[1]['api'] && instance_data[1]['cors'];
            if (http_check && status_check_api_data && api_available) {
                invidious_embed.api_instance_list.push(instance_data[1]['uri']);
            }
        });
    }

    async auto_instance_select() {
        if (await this.instance_access_check(invidious_embed.invidious_instance)) {
            return;
        } else {
            if (invidious_embed.api_instance_list.length === 0) {
                await this.get_instance_list();
            }
            for (let x = 0; x < invidious_embed.api_instance_list.length; x++) {
                if (await this.instance_access_check(invidious_embed.api_instance_list[x])) {
                    invidious_embed.invidious_instance = invidious_embed.api_instance_list[x];
                    break;
                }
            }
        }
    }

    async videoid_accessable_check(videoid) {
        const video_api_response = await fetch(invidious_embed.invidious_instance + "/api/v1/videos/" + videoid);
        return video_api_response.ok;
    }

    async getPlaylistVideoids(playlistid) {
        const playlist_api_response = await fetch(invidious_embed.invidious_instance + "/api/v1/playlists/" + playlistid);
        if (playlist_api_response.ok) {
            const playlist_api_json = await playlist_api_response.json();
            let tmp_videoid_list = [];
            playlist_api_json.videos.forEach(videodata => tmp_videoid_list.push(videodata.videoId));
            return tmp_videoid_list;
        } else {
            return [];
        }
    }

    async Player(element, options) {
        this.eventElement = document.createElement("span");
        this.player_status = -1;
        this.error_code = 0;
        this.volume = 100;
        this.eventobject = { ready: [], ended: [], error: [], ratechange: [], volumechange: [], waiting: [], timeupdate: [], loadedmetadata: [], play: [], seeking: [], seeked: [], playerresize: [], pause: [], statechange: [] };
        let replace_elemnt;
        if (element === undefined || element === null) {
            throw 'Please, pass element id or HTMLElement as first argument';
        } else if (typeof element === 'string') {
            replace_elemnt = document.getElementById(element);
        } else {
            replace_elemnt = element;
        }
        let iframe_src = '';
        if (options.host !== undefined && options.host !== "") {
            iframe_src = new URL(options.host).origin;
        } else if (invidious_embed.invidious_instance !== '') {
            iframe_src = invidious_embed.invidious_instance;
        }
        if (!await this.instance_access_check(iframe_src)) {
            await this.auto_instance_select();
            iframe_src = invidious_embed.invidious_instance;
        }
        invidious_embed.invidious_instance = iframe_src;
        this.target_origin = iframe_src;
        iframe_src += '/embed/';
        if (typeof options.videoId === 'string' && options.videoId.length === 11) {
            iframe_src += options.videoId;
            this.videoId = options.videoId;
            if (!await this.videoid_accessable_check(options.videoId)) {
                this.error_code = 100;
                this.event_executor('error');
                return;
            }
        } else {
            this.error_code = 2;
            this.event_executor('error');
            return;
        }
        let search_params = new URLSearchParams('');
        search_params.append('widgetid', invidious_embed.widgetid);
        this.widgetid = invidious_embed.widgetid;
        invidious_embed.widgetid++;
        search_params.append('origin', location.origin);
        search_params.append('enablejsapi', '1');
        if (typeof options.playerVars === 'object') {
            this.option_playerVars = options.playerVars;
            for (let x in options.playerVars) {
                if (typeof x === 'string' && typeof options.playerVars[x] === 'string') {
                    search_params.append(x, options.playerVars[x]);
                }
            }
            if (options.playerVars.autoplay === undefined) {
                search_params.append('autoplay', '0');
            }
        }
        iframe_src += "?" + search_params.toString();
        if (typeof options.events === 'object') {
            for (let x in options.events) {
                this.addEventListener(x, options.events[x]);
            }
        }
        this.player_iframe = document.createElement("iframe");
        this.loaded = false;
        this.addEventListener('loadedmetadata', () => { this.event_executor('ready'); this.loaded = true; });
        this.addEventListener('loadedmetadata', () => { this.setVolume(this.volume); });
        this.addEventListener('loadedmetadata', async () => { const plid = await this.promise_send_event('getplaylistid'); (plid === null || plid === undefined) ? this.playlistVideoIds = [] : this.playlistVideoIds = await this.getPlaylistVideoids(plid); })
        this.player_iframe.src = iframe_src;
        if (typeof options.width === 'number') {
            this.player_iframe.width = options.width;
        } else {
            if (document.body.clientWidth < 640) {
                this.player_iframe.width = document.body.clientWidth;
            } else {
                this.player_iframe.width = 640;
            }
        }
        if (typeof options.width === 'number') {
            this.player_iframe.width = options.width;
        } else {
            this.player_iframe.height = this.player_iframe.width * (9 / 16);
        }
        this.player_iframe.style.border = "none";
        replace_elemnt.replaceWith(this.player_iframe);
        this.eventdata = {};
        return this;
    }

    postMessage(data) {
        const additionalInfo = { 'origin': location.origin, 'widgetid': this.widgetid.toString(), 'target': 'invidious_control' };
        data = Object.assign(additionalInfo, data);
        this.player_iframe.contentWindow.postMessage(data, this.target_origin);
    }

    event_executor(eventname) {
        this.eventElement.dispatchEvent(new Event(eventname));
    }

    receiveMessage(message) {
        if (message.data.from === 'invidious_control' && message.data.widgetid === String(this.widgetid)) {
            switch (message.data.message_kind) {
                case 'info_return':
                    const promise_array = this.message_wait[message.data.command];
                    promise_array.forEach(element => {
                        if (message.data.command === 'getvolume') {
                            element(message.data.value * 100);
                        } else {
                            element(message.data.value);
                        }
                    });
                    this.message_wait[message.data.command] = [];
                    break;
                case 'event':
                    if (typeof message.data.eventname === 'string') {
                        this.event_executor(message.data.eventname);
                        const previous_status = this.player_status;
                        switch (message.data.eventname) {
                            case 'ended':
                                this.player_status = 0;
                                break;
                            case 'play':
                                this.player_status = 1;
                                break;
                            case 'timeupdate':
                                this.player_status = 1;
                                this.eventdata = Object.assign({}, this.eventdata, message.data.value);
                                break;
                            case 'pause':
                                this.player_status = 2;
                                break;
                            case 'waiting':
                                this.player_status = 3;
                                break;
                            case 'loadedmetadata':
                                this.eventdata = Object.assign({}, this.eventdata, message.data.value);
                                break;
                        }
                        if (previous_status !== this.player_status) {
                            this.event_executor('statechange');
                        }
                    }
            }
        }
    }

    promise_send_event(event_name) {
        if (invidious_embed.api_promise) {
            const promise_object = new Promise((resolve, reject) => { this.message_wait[event_name].push(resolve) });
            this.postMessage({ eventname: event_name });
            return promise_object;
        } else {
            return this.eventdata[event_name];
        }
    }

    getPlayerState() {
        return this.player_status;
    }

    playVideo() {
        this.postMessage({ eventname: 'play' });
    }

    pauseVideo() {
        this.postMessage({ eventname: 'pause' });
    }

    getVolume() {
        return this.promise_send_event('getvolume');
    }

    setVolume(volume) {
        if (typeof volume === 'number') {
            this.volume = volume;
            if (volume !== NaN && volume >= 0 && volume <= 100) {
                this.postMessage({ eventname: 'setvolume', value: volume / 100 });
            }
        } else {
            console.warn("setVolume first argument must be number");
        }
    }

    getIframe() {
        return this.player_iframe;
    }

    destroy() {
        this.player_iframe.remove();
    }

    mute() {
        this.postMessage({ eventname: 'setmutestatus', value: true });
    }

    unMute() {
        this.postMessage({ eventname: 'setmutestatus', value: false });
    }

    isMuted() {
        return this.promise_send_event('getmutestatus');
    }

    seekTo(seconds, allowSeekAhead) {//seconds must be a number and allowSeekAhead is ignore
        if (typeof seconds === 'number') {
            if (seconds !== NaN && seconds !== undefined) {
                this.postMessage({ eventname: 'seek', value: seconds });
            }
        } else {
            console.warn('seekTo first argument type must be number')
        }
    }

    setSize(width, height) {//width and height must be Number
        if (typeof width === 'number' && typeof height === 'number') {
            this.player_iframe.width = width;
            this.player_iframe.height = height;
        } else {
            console.warn('setSize first and secound argument type must be number');
        }
    }

    getPlaybackRate() {
        return this.promise_send_event('getplaybackrate');
    }

    setPlaybackRate(suggestedRate) {//suggestedRate must be number.this player allow not available playback rate such as 1.4
        if (typeof suggestedRate === 'number') {
            if (suggestedRate !== NaN) {
                this.postMessage({ eventname: 'setplaybackrate', value: suggestedRate });
            } else {
                console.warn('setPlaybackRate first argument NaN is no valid');
            }
        } else {
            console.warn('setPlaybackRate first argument type must be number');
        }
    }

    getAvailablePlaybackRates() {
        return this.promise_send_event('getavailableplaybackrates');
    }

    async playOtherVideoById(option, autoplay, startSeconds_arg) {//internal fuction
        let videoId = '';
        let startSeconds = 0;
        let endSeconds = -1;
        let mediaContetUrl = '';
        if (typeof option === 'string') {
            if (option.length === 11) {
                videoId = option
            } else {
                mediaContetUrl = option;
            }
            if (typeof startSeconds_arg === 'number') {
                startSeconds = startSeconds_arg;
            }
        } else if (typeof option === 'object') {
            if (typeof option.videoId === 'string') {
                if (option.videoId.length == 11) {
                    videoId = option.videoId;
                } else {
                    this.error_code = 2;
                    this.event_executor('error');
                    return;
                }
            } else if (typeof option.mediaContentUrl === 'string') {
                mediaContetUrl = option.mediaContentUrl;
            } else {
                this.error_code = 2;
                this.event_executor('error');
                return;
            }
            if (typeof option.startSeconds === 'number' && option.startSeconds >= 0) {
                startSeconds = option.startSeconds;
            }
            if (typeof option.endSeconds === 'number' && option.endSeconds >= 0) {
                endSeconds = option.endSeconds;
            }
        }
        if (mediaContetUrl.length > 0) {
            const match_result = mediaContetUrl.match(/\/([A-Za-z0-9]{11})\//);
            if (match_result !== null && match_result.length === 2) {
                videoId = match_result[1];
            } else {
                this.error_code = 2;
                this.event_executor('error');
                return;
            }
        }
        let iframe_sorce = this.target_origin.slice();
        iframe_sorce += "/embed/" + videoId;
        this.videoId = videoId;
        if (!await this.videoid_accessable_check(videoId)) {
            this.error_code = 100;
            this.event_executor('error');
            return;
        }
        let search_params = new URLSearchParams('');
        search_params.append('origin', location.origin);
        search_params.append('enablejsapi', '1');
        search_params.append('widgetid', invidious_embed.widgetid);
        this.widgetid = invidious_embed.widgetid;
        invidious_embed.widgetid++;
        search_params.append('autoplay', Number(autoplay));
        if (this.option_playerVars !== undefined) {
            Object.keys(this.option_playerVars).forEach(key => {
                if (key !== 'autoplay' && key !== 'start' && key !== 'end') {
                    search_params.append(key, this.option_playerVars[key]);
                }
            })
        }
        if (startSeconds > 0) {
            search_params.append('start', startSeconds);
        }
        if (endSeconds !== -1 && endSeconds >= 0) {
            if (endSeconds > startSeconds) {
                search_params.append('end', endSeconds);
            } else {
                throw 'Invalid end seconds because end seconds before start seconds';
            }
        }
        iframe_sorce += "?" + search_params.toString();
        this.player_iframe.src = iframe_sorce;
        if (autoplay) {
            this.player_status = 5;
        }
        this.eventdata = {};
    }

    loadVideoById(option, startSeconds) {
        this.playOtherVideoById(option, true, startSeconds);
    }

    cueVideoById(option, startSeconds) {
        this.playOtherVideoById(option, false, startSeconds);
    }

    cueVideoByUrl(option, startSeconds) {
        this.playOtherVideoById(option, false, startSeconds);
    }

    loadVideoByUrl(option, startSeconds) {
        this.playOtherVideoById(option, true, startSeconds);
    }

    getDuration() {
        return this.promise_send_event('getduration');
    }

    getVideoUrl() {
        return this.target_origin + "/watch?v=" + this.videoId;
    }

    async getVideoEmbedCode() {
        const title = await this.getVideoTitle();
        return '<iframe width="560" height="315" src="' + this.target_origin + '/embed/' + this.videoId + '" title="' + title.replace('"', "'") + '" frameborder="0" allow="autoplay;encrypted-media;picture-in-picture;web-share" allowfullscreen></iframe>';
    }

    getCurrentTime() {
        return this.promise_send_event('getcurrenttime');
    }

    async getVideoData() {
        return { video_id: this.videoId, title: await this.promise_send_event('gettitle'), list: this.promise_send_event('getplaylistid') };
    }

    getPlaylistIndex() {
        return this.promise_send_event('getplaylistindex');
    }

    getPlaylist() {
        return this.playlistVideoIds !== undefined ? this.playlistVideoIds : [];
    }

    constructor(element, options) {
        this.Player(element, options);
        window.addEventListener('message', (ms) => { this.receiveMessage(ms) });
        this.message_wait = { getvolume: [], getmutestatus: [], getduration: [], getcurrenttime: [], getplaybackrate: [], getavailableplaybackrates: [], gettitle: [] };
    }
}
function invidious_ready(func) {
    if (typeof func === 'function') {
        func();
    }
    else {
        console.warn('invidious.ready first argument must be function');
    }
}
invidious_embed.invidious_instance = new URL(document.currentScript.src).origin;
const invidious = { Player: invidious_embed, PlayerState: { ENDED: 0, PLAYING: 1, PAUSED: 2, BUFFERING: 3, CUED: 5 }, ready: invidious_ready };
if (typeof onInvidiousIframeAPIReady === 'function') {
    try{
        onInvidiousIframeAPIReady();
    } catch(e) {
        console.error(e);
    }
}

const YT = invidious;
