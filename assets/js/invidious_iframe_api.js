class invidious_embed {
    static widgetid = 0;

    static eventname_table = {
        onPlaybackRateChange: 'ratechange',
        onStateChange: 'statechange',
        onError: 'error',
        onReady: 'ready'
    };

    static available_event_name = [
        'ready',
        'ended',
        'error',
        'ratechange',
        'volumechange',
        'waiting',
        'timeupdate',
        'loadedmetadata',
        'play',
        'seeking',
        'seeked',
        'playerresize',
        'pause'
    ];

    /**
     * Recive event response synchronization or asynchronous.
     * 
     * Default false mean synchronization
     * @type {boolean}
     */
    static api_promise = false;
    static invidious_instance = '';

    /**
     * @type {[string]}
     */
    static api_instance_list = [];

    /**
     *  @type {Object<string,boolean>}
     */
    static instance_status_list = {};

    /**
     * @typedef {{
     * title:string,
     * videoId:string,
     * videoThumbnails:[{
     * quarity:string,
     * url:string,
     * height:number,
     * width:number
     * }],
     * storyboards:[{
     * url:string,
     * templateUrl:string,
     * width:number,
     * height:number,
     * count:number,
     * interval:number,
     * storyboardWidth:number,
     * storyboardHeight:number,
     * storyboardCount:number
     * }]
     * description:string,
     * descriptionHtml:string,
     * published:number,
     * publishedText:string,
     * keywords:[string],
     * viewCount:number,
     * likeCount:number,
     * dislikeCount:number,
     * paid:boolean,
     * premium:boolean,
     * isFamilyFriendly:boolean,
     * allowedRegions:[string],
     * genre:string,
     * genreUrl:string,
     * author:string,
     * authorId:string,
     * authorUrl:string,
     * authorThumbnails:[{
     * url:string,
     * width:number,
     * height:number
     * }]
     * subCountText:string,
     * lengthSeconds:number,
     * allowRatings:string,
     * rating:number,
     * isListed:boolean,
     * liveNow:boolean,
     * isUpcoming:boolean,
     * dashUrl:string,
     * adaptiveFormats:[{
     * init:string,
     * index:string,
     * bitrate:string,
     * url:string,
     * itag:string,
     * type:string,
     * clen:string,
     * lmt:string,
     * projectionType:string,
     * fps:number,
     * container:string,
     * encoding:string,
     * audioQuality:string,
     * audioSampleRate:number,
     * audioChannels:number
     * }]
     * formatStreams:[{
     * url:string,
     * itag:string,
     * type:string,
     * quarity:string,
     * fps:number,
     * container:string,
     * encoding:string,
     * resolution:string,
     * qualityLabel:string,
     * size:string
     * }]
     * captions:[{
     * label:string,
     * language_code:string,
     * url:string
     * }]
     * recommendedVideos:[{
     * videoId:string,
     * title:string,
     * videoThumbnails:[{
     * quarity:string,
     * url:string,
     * height:number,
     * width:number
     * }],
     * author:string,
     * authorId:string,
     * authorUrl:string,
     * lengthSeconds:number,
     * viewCountText:string,
     * viewCount:number
     * }]
     * }} videoDataApi
     */

    /**
     * @type {Object<string,videoDataApi>}
     */
    static videodata_cahce = {};

    /**
     * Add event execute function for player
     * @param {string} eventname 
     * @param {Function} event_execute_function 
     */
    addEventListener(eventname, event_execute_function) {
        if (typeof event_execute_function === 'function') {
            if (eventname in invidious_embed.eventname_table) {
                this.eventobject[invidious_embed.eventname_table[eventname]].push(event_execute_function);
            } else if (invidious_embed.available_event_name.includes(eventname)) {
                this.eventobject[eventname].push(event_execute_function);
            } else {
                console.warn('addEventListener cannot find such eventname : ' + eventname);
            }
        } else {
            console.warn("addEventListner secound args must be function");
        }
    }

    /**
     * remove spacific event execute function
     * @param {string} eventname 
     * @param {Function} delete_event_function 
     */
    removeEventListener(eventname, delete_event_function) {
        if (typeof delete_event_function === 'function') {
            let internal_eventname;
            if (eventname in invidious_embed.eventname_table) {
                internal_eventname = invidious_embed.eventname_table[eventname];
            } else if (invidious_embed.available_event_name.includes(eventname)) {
                internal_eventname = eventname;
            } else {
                console.warn('removeEventListner cannot find such eventname : ' + eventname);
                return;
            }

            this.eventobject[internal_eventname] = this.eventobject[internal_eventname].filter(listed_function => {
                const allowFunctionDetected = listed_function.toString()[0] === '(';
                if (allowFunctionDetected) {
                    listed_function.toString() !== delete_event_function.toString();
                } else {
                    listed_function !== delete_event_function;
                }
            });
        } else {
            console.warn("removeEventListener secound args must be function");
        }
    }

    /**
     * return whether instance_origin origin can use or not
     * @param {string} instance_origin 
     * @returns {Promise<boolean>}
     */
    async instance_access_check(instance_origin) {
        let return_status;
        const status_cahce_exist = instance_origin in invidious_embed.instance_status_list;
        if (status_cahce_exist) {
            return invidious_embed.instance_status_list[instance_origin];
        }

        try {
            const instance_stats = await fetch(instance_origin + '/api/v1/stats');
            if (instance_stats.ok) {
                const instance_stats_json = await instance_stats.json();
                return_status = (instance_stats_json.software.name === 'invidious');
            } else {
                return_status = false;
            }
        } catch {
            return_status = false;
        }
        invidious_embed.instance_status_list[instance_origin] = return_status;
        return return_status;
    }

    /**
     * Need to use await
     * 
     * Add invidious_embed.api_instance_list
     * 
     * fetch from api.invidious.io
     */
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

    /**
     * Need to use await
     * 
     * Auto select invidious instance and set invidious_embed.invidious_instance
     */
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

    /**
     * Return videoData using invidious videos api
     * @param {string} videoid 
     * @returns {Promise<videoDataApi>}
     */
    async videodata_api(videoid) {
        const not_in_videodata_cahce = !(videoid in invidious_embed.videodata_cahce);
        if (not_in_videodata_cahce) {
            const video_api_response = await fetch(invidious_embed.invidious_instance + "/api/v1/videos/" + videoid);
            if (video_api_response.ok) {
                invidious_embed.videodata_cahce[videoid] = Object.assign({}, { status: true }, await video_api_response.json());
            } else {
                invidious_embed.videodata_cahce[videoid] = { status: false };
            }
        }
        return invidious_embed.videodata_cahce[videoid];
    }

    /**
     * check whether videoid exist or not
     * @param {string} videoid 
     * @returns {promise<boolean>}
     */
    async videoid_accessable_check(videoid) {
        return (await this.videodata_api(videoid)).status;
    }

    /**
     * return array of videoid in playlistid
     * @param {string} playlistid 
     * @returns {Promise<[string]>}
     */
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

    /**
     * 
     * @param {string|Node} element 
     * @param {{
     * videoId:string,
     * host:string,
     * width:number,
     * height:number,
     * playerVars:{
     * start:number|string,
     * end:number|string,
     * autoplay:number|string
     * },
     * events:{
     * onReady:Function,
     * onError:Function,
     * onStateChange:Function,
     * onPlaybackRateChange:Function
     * }
     * }} options 
     * @returns 
     */
    async Player(element, options) {
        this.player_status = -1;
        this.error_code = 0;
        this.volume = 100;
        this.loop = false;

        /**
         * @type {[string]}
         */
        this.playlistVideoIds = [];

        /**
         * @type {{
         * ready:Function,
         * ended:Function,
         * error:Function,
         * ratechange:Function,
         * volumechange:Function,
         * waiting:Function,
         * timeupdate:Function,
         * loadedmetadata:Function,
         * play:Function,
         * seeking:Function,
         * seeked:Function,
         * playerresize:Function,
         * pause:Function,
         * statechange:Function
         * }}
         */
        this.eventobject = {
            ready: [],
            ended: [],
            error: [],
            ratechange: [],
            volumechange: [],
            waiting: [],
            timeupdate: [],
            loadedmetadata: [],
            play: [],
            seeking: [],
            seeked: [],
            playerresize: [],
            pause: [],
            statechange: []
        };

        let replace_elemnt;
        this.isPlaylistVideoList = false;
        if (element === undefined || element === null) {
            throw 'Please, pass element id or HTMLElement as first argument';
        } else if (typeof element === 'string') {
            replace_elemnt = document.getElementById(element);

            if (replace_elemnt === null) {
                throw 'Can not find spacific element'
            }
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

        let no_start_parameter = true;
        if (typeof options.playerVars === 'object') {
            this.option_playerVars = options.playerVars;
            Object.keys(options.playerVars).forEach(key => {
                if (typeof key === 'string') {
                    let keyValue = options.playerVars[key];
                    switch (typeof keyValue) {
                        case 'number':
                            keyValue = keyValue.toString();
                            break;
                        case 'string':
                            break;
                        default:
                            console.warn('player vars key value must be string or number');
                    }
                    search_params.append(key, keyValue);
                } else {
                    console.warn('player vars key must be string');
                }
            });

            if (options.playerVars.start !== undefined) {
                no_start_parameter = false;
            }

            if (options.playerVars.autoplay === undefined) {
                search_params.append('autoplay', '0');
            }

        } else {
            search_params.append('autoplay', '0');
        }

        if (no_start_parameter) {
            search_params.append('start', '0');
        }

        iframe_src += "?" + search_params.toString();

        if (typeof options.events === 'object') {
            Object.keys(options.events).forEach(key => {
                if (typeof options.events[key] === 'function') {
                    this.addEventListener(key, options.events[key]);
                } else {
                    console.warn('event function must be function');
                }
            });
        }

        this.player_iframe = document.createElement("iframe");
        this.loaded = false;
        this.addEventListener('loadedmetadata', () => { this.event_executor('ready'); this.loaded = true; });
        this.addEventListener('loadedmetadata', () => { this.setVolume(this.volume); });
        this.addEventListener('ended', () => { if (this.isPlaylistVideoList) { this.nextVideo() } })
        this.player_iframe.src = iframe_src;

        if (typeof options.width === 'number') {
            this.player_iframe.width = options.width;
        } else {
            this.player_iframe.width = 640;
            this.player_iframe.style.maxWidth = '100%';
        }

        if (typeof options.height === 'number') {
            this.player_iframe.height = options.height;
        } else {
            this.player_iframe.height = this.player_iframe.width * (9 / 16);
        }

        this.player_iframe.style.border = "none";
        replace_elemnt.replaceWith(this.player_iframe);
        /**
         * @type {Object.<string,string>}
         */
        this.eventdata = {};
        return this;
    }

    /**
     * send message to iframe player
     * @param {Object} data 
     */
    postMessage(data) {
        const additionalInfo = {
            'origin': location.origin,
            'widgetid': this.widgetid.toString(),
            'target': 'invidious_control'
        };
        data = Object.assign(additionalInfo, data);
        this.player_iframe.contentWindow.postMessage(data, this.target_origin);
    }

    /**
     * execute eventname event
     * @param {string} eventname 
     */
    event_executor(eventname) {
        const execute_functions = this.eventobject[eventname];
        let return_data = {
            type: eventname,
            data: null,
            target: this
        };
        switch (eventname) {
            case 'statechange':
                return_data.data = this.getPlayerState();
                break;
            case 'error':
                return_data.data = this.error_code;
        }
        execute_functions.forEach(func => {
            try {
                func(return_data);
            } catch (e) {
                console.error(e);
            }
        });
    }

    /**
     * recieve message from iframe player
     * @param {{
     * data:{
     * from:string,
     * message_kind:string,
     * widgetid:string,
     * command:string,
     * value:string|number|object|null,
     * eventname:string
     * }
     * }} message 
     */
    receiveMessage(message) {
        const onControlAndHasWidgetId = message.data.from === 'invidious_control' && message.data.widgetid === this.widgetid.toString();
        if (onControlAndHasWidgetId) {
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

    /**
     * Default return no Promise value.
     * 
     * But if set invidious_embed.api_promise true, return Promise value
     * 
     * send eventname event to player iframe
     * @param {'getvolume'|'setvolume'|'getmutestatus'|'getplaybackrate'|'getavailableplaybackrates'|'getplaylistindex'|'getduration'|'gettitle'|'getplaylistid'|'getcurrenttime'} event_name 
     * @returns {number|boolean|[number]|string|Promise<number>|Promise<boolean>|Promise<[number]>|Promise<string>}
     */
    promise_send_event(event_name) {
        if (invidious_embed.api_promise) {
            const promise_object = new Promise((resolve, reject) => this.message_wait[event_name].push(resolve));
            this.postMessage({
                eventname: event_name
            });
            return promise_object;
        } else {
            return this.eventdata[event_name];
        }
    }

    /**
     * return playerstatus same as youtube iframe api
     * 
     * -1:unstarted
     * 
     * 0:ended
     * 
     * 1:playing
     * 
     * 2:paused
     * 
     * 3:buffering
     * 
     * 5:video cued
     * @returns {number}
     * @example
     * const player_statrus = player.getPlayerState();
     * //player_statrus = 1;
     */
    getPlayerState() {
        return this.player_status;
    }

    /**
     * send play command to iframe player
     * @example
     * player.playVideo();
     */
    playVideo() {
        this.postMessage({ eventname: 'play' });
    }

    /**
     * send pause command to iframe player
     * @example
     * player.pauseVideo();
     */
    pauseVideo() {
        this.postMessage({ eventname: 'pause' });
    }

    /**
     * Default return number range 0 to 100
     * 
     * But if set invidious_embed.api_promise true, return Promise<number>
     * @returns {number|Promise<number>}
     * @example
     * const volume = player.getVolume();//invidious_embed.api_promise is false
     * const volume = await player.getVolume();//invidious_embed.api_promise is true
     * //volume = 100
     */
    getVolume() {
        return this.promise_send_event('getvolume');
    }

    /**
     * Send set volume event to iframe player
     * 
     * volume must be range 0 to 100
     * @param {number} volume 
     * @example
     * player.setVolume(50);//set volume 50%
     */
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

    /**
     * Get player iframe node
     * @returns {Node}
     * @example
     * const invidious_player_node = player.getIframe();
     */
    getIframe() {
        return this.player_iframe;
    }

    /**
     * delete player iframe
     * @example
     * player.destroy();
     */
    destroy() {
        this.player_iframe.remove();
    }

    /**
     * send mute event to iframe player
     * @example
     * player.mute();
     */
    mute() {
        this.postMessage({ eventname: 'setmutestatus', value: true });
    }

    /**
     * send unmute event to iframe player
     * @example
     * player.unMute();
     */
    unMute() {
        this.postMessage({ eventname: 'setmutestatus', value: false });
    }

    /**
     * Whether mute or not.
     * 
     * Default return boolean.
     * 
     * But if set invidious_embed.api_promise true, return Promise<boolean>.
     * @returns {boolean|Promise<boolean>}
     * @example
     * const muteStatus = player.isMuted();//invidious_embed.api_promise false
     * const muteStatus = await player.isMuted();//invidious_embed.api_promise true
     * //muteStatus = false
     */
    isMuted() {
        return this.promise_send_event('getmutestatus');
    }

    /**
     * send command seek video to seconds to iframe player.
     * 
     * seconds count start with video 0 seconds.
     * @param {number} seconds
     * @param {boolean} allowSeekAhead ignore. only maintained for compatibility of youtube iframe player
     * @example
     * player.seekTo(100);//seek to 100 seconds of video which counts start with 0 seconds of the video
     */
    seekTo(seconds, allowSeekAhead) {
        if (typeof seconds === 'number') {
            if (seconds !== NaN && seconds !== undefined) {
                this.postMessage({ eventname: 'seek', value: seconds });
            }
        } else {
            console.warn('seekTo first argument type must be number')
        }
    }

    /**
     * set iframe size
     * @param {number} width 
     * @param {number} height 
     * @example
     * player.setSize(480,270);
     */
    setSize(width, height) {
        if (typeof width === 'number' && typeof height === 'number') {
            this.player_iframe.width = width;
            this.player_iframe.height = height;
        } else {
            console.warn('setSize first and secound argument type must be number');
        }
    }

    /**
     * get playback rate.
     * 
     * Default return number.
     * 
     * But if set invidious_embed.api_promise true, return Promise<number>.
     * @returns {number|Promise<number>}
     * @example
     * const now_playback_rate = player.getPlaybackRate();//invidious_embed.api_promise is false
     * const now_playback_rate = await player.getPlaybackRate();//invidious_embed.api_promise is true
     * //now_playback_rate = 1.0
     */
    getPlaybackRate() {
        return this.promise_send_event('getplaybackrate');
    }

    /**
     * Set video play back rate
     * @param {number} suggestedRate 
     * @example
     * player.setPlaybackRate(0.5);//play video 0.5x
     * player.setPlaybackRate(1.2);//play video 1.2x
     */
    setPlaybackRate(suggestedRate) {
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

    /**
     * get available playback rates.
     * 
     * Default return [number].
     * 
     * But if set invidious_embed.api_promise true, return Promise<[number]>
     * @returns {[number]|Promise<[number]>}
     * @example
     * const available_playback_rates = player.getAvailablePlaybackRates();//invidious_embed.api_promise is false
     * const available_playback_rates = player.getAvailablePlaybackRates();//invidious_embed.api_promise is true
     * //available_playback_rates = [0.25,0.5,0.75,1,1.25,1.5,1.75,2.0];
     */
    getAvailablePlaybackRates() {
        return this.promise_send_event('getavailableplaybackrates');
    }

    /**
     * Internal function, so use such as loadVideoById() instead of this function.
     * @param {string|{
     * videoId:string|undefined,
     * mediaContentUrl:string|undefined,
     * startSeconds:number,
     * endSeconds:number
     * }} option 
     * @param {boolean} autoplay 
     * @param {number|undefined} startSeconds_arg 
     * @param {Object.<string,string>} additional_argument 
     * @returns 
     */
    async playOtherVideoById(option, autoplay, startSeconds_arg, additional_argument) {//internal fuction
        let videoId = '';
        let startSeconds = 0;
        let endSeconds = -1;
        let mediaContetUrl = '';

        if (typeof option === 'string') {
            if (option.length === 11) {
                videoId = option;
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
            const match_result = mediaContetUrl.match(/\/([A-Za-z0-9]{11})/);
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
            const ignore_keys = ['autoplay', 'start', 'end', 'index', 'list'];
            Object.keys(this.option_playerVars).forEach(key => {
                if (!ignore_keys.includes(key)) {
                    search_params.append(key, this.option_playerVars[key]);
                }
            })
        }

        if (typeof additional_argument === 'object') {
            const ignore_keys = ['autoplay', 'start', 'end'];
            Object.keys(additional_argument).forEach(key => {
                if (!ignore_keys.includes(key)) {
                    search_params.append(key, additional_argument[key]);
                }
            })
        }

        search_params.append('start', startSeconds);
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

    /**
     * Load video using videoId
     * @param {string|{
     * videoId:string,
     * startSeconds:number|undefined,
     * endSeconds:number|undefined
     * }} option 
     * @param {number|undefined} startSeconds 
     * @example
     * player.loadVideoById('INHasAVlzI8');//load video INHasAVlzI8
     * player.loadVideoById('INHasAVlzI8',52);//load video INHasAVlzI8 and start with 52 seconds
     * player.loadVideoById({videoId:'INHasAVlzI8',startSeconds:52,endSeconds:76});//load video INHasAVlzI8 ,start with 52 seconds and end 76 seconds
     */
    loadVideoById(option, startSeconds) {
        this.isPlaylistVideoList = false;
        this.playOtherVideoById(option, true, startSeconds, {});
    }

    /**
     * Cue video using videoId
     * 
     * Cue mean before playing video only show video thumbnail and title
     * @param {string|{
     * videoId:string,
     * startSeconds:number|undefined,
     * endSeconds:number|undefined
     * }} option 
     * @param {number|undefined} startSeconds 
     * @example
     * player.cueVideoById('INHasAVlzI8');//load video INHasAVlzI8
     * player.cueVideoById('INHasAVlzI8',52);//load video INHasAVlzI8 and start with 52 seconds
     * player.cueVideoById({videoId:'INHasAVlzI8',startSeconds:52,endSeconds:76});//load video INHasAVlzI8 ,start with 52 seconds and end 76 seconds
     */
    cueVideoById(option, startSeconds) {
        this.isPlaylistVideoList = false;
        this.playOtherVideoById(option, false, startSeconds, {});
    }

    /**
     * Cue video using media content url
     * 
     * Cue mean before playing video only show video thumbnail and title
     * 
     * Media content url like https://youtube.com/v/INHasAVlzI8 .Cannot run like https://youtube.com/watch/?v=INHasAVlzI8 this behavior is same as youtube iframe api
     * @param {string|{
     * mediaContentUrl:string,
     * startSeconds:number|undefined,
     * endSeconds:number|undefined
     * }} option 
     * @param {number|undefined} startSeconds 
     * @example
     * player.cueVideoByUrl('https://youtube.com/v/INHasAVlzI8');//load video INHasAVlzI8
     * player.cueVideoByUrl('https://youtube.com/v/INHasAVlzI8',52);//load video INHasAVlzI8 and start with 52 seconds
     * player.cueVideoByUrl({mediaContentUrl:'https://youtube.com/v/INHasAVlzI8',startSeconds:52,endSeconds:76});//load video INHasAVlzI8 ,start with 52 seconds and end 76 seconds
     */
    cueVideoByUrl(option, startSeconds) {
        this.isPlaylistVideoList = false;
        this.playOtherVideoById(option, false, startSeconds, {});
    }

    /**
     * Load video using media content url
     * 
     * Media content url like https://youtube.com/v/INHasAVlzI8 .Cannot run like https://youtube.com/watch/?v=INHasAVlzI8 this behavior is same as youtube iframe api
     * @param {string|{
     * mediaContentUrl:string,
     * startSeconds:number|undefined,
     * endSeconds:number|undefined
     * }} option 
     * @param {number|undefined} startSeconds 
     * @example
     * player.loadVideoByUrl('https://youtube.com/v/INHasAVlzI8');//load video INHasAVlzI8
     * player.loadVideoByUrl('https://youtube.com/v/INHasAVlzI8',52);//load video INHasAVlzI8 and start with 52 seconds
     * player.loadVideoByUrl({mediaContentUrl:'https://youtube.com/v/INHasAVlzI8',startSeconds:52,endSeconds:76});//load video INHasAVlzI8 ,start with 52 seconds and end 76 seconds
     */
    loadVideoByUrl(option, startSeconds) {
        this.isPlaylistVideoList = false;
        this.playOtherVideoById(option, true, startSeconds, {});
    }

    /**
     * Internal function, so use such as loadPlaylist() instead of this function.
     * @param {string|[string]|{index:number|undefined,list:string,listType:string|undefined}} playlistData 
     * @param {boolean} autoplay 
     * @param {number} index 
     * @param {number} startSeconds 
     */
    async playPlaylist(playlistData, autoplay, index, startSeconds) {
        /**
         * @type {string}
         */
        let playlistId;
        if (typeof playlistData === 'string') {
            this.playlistVideoIds = [playlistData];
            this.isPlaylistVideoList = true;
        } else if (typeof playlistData === 'object') {
            if (Array.isArray(playlistData)) {
                this.playlistVideoIds = playlistData;
                this.isPlaylistVideoList = true;
            } else {
                index = playlistData['index'];
                let listType = 'playlist';
                if (typeof playlistData['listType'] === 'string') {
                    listType = playlistData['listType'];
                }

                switch (listType) {
                    case 'playlist':
                        if (typeof playlistData['list'] === 'string') {
                            this.playlistVideoIds = await this.getPlaylistVideoids(playlistData['list']);
                            playlistId = playlistData['list'];
                        } else {
                            console.error('playlist data list must be string');
                            return;
                        }
                        break;
                    case 'user_uploads':
                        console.warn('sorry user_uploads not support');
                        return;
                    default:
                        console.error('listType : ' + listType + ' is unknown');
                        return;
                }
            }

            if (typeof playlistData.startSeconds === 'number') {
                startSeconds = playlistData.startSeconds;
            }
        } else {
            console.error('playlist function first argument must be string or array of string');
            return;
        }

        if (this.playlistVideoIds.length === 0) {
            console.error('playlist length 0 is invalid');
            return;
        }
        let parameter = { index: 0 };
        if (typeof index === 'undefined') {
            index = 0;
        } else if (typeof index === 'number') {
            parameter.index = index;
        } else {
            console.error('index must be number of undefined');
        }

        if (typeof playlistId === 'string') {
            parameter['list'] = playlistId;
            this.playlistId = playlistId;
        }
        this.sub_index = parameter.index;

        if (index >= this.playlistVideoIds.length) {
            index = 0;
            parameter.index = 0;
        }
        this.playOtherVideoById(this.playlistVideoIds[index], autoplay, startSeconds, parameter);
    }

    /**
     * Cue playlist and play video at index number
     * @param {string|[string]|{index:number|undefined,list:string,listType:string|undefined}} data 
     * @param {number|undefined} index count start with 0
     * @param {number|undefined} startSeconds only affect first video
     * @example
     * player.loadPlaylist('i50sUufNbzY');//play i50sUufNbzY video start with 0 second
     * player.loadPlaylist(['i50sUufNbzY','BgNVwiX7K8E','L7PCS7afS3Y'],1,10);//play index second playlist (BgNVwiX7K8E) and play start with 10 seconds
     * player.loadPlaylist({list:'PL84LbRiy3noqhbyqr-IcCKhyXE6mFoQzF'});//play playlist first index of PL84LbRiy3noqhbyqr-IcCKhyXE6mFoQzF and start with 0 second
     */
    cuePlaylist(data, index, startSeconds) {
        this.playPlaylist(data, false, index, startSeconds);
    }

    /**
     * Load playlist and play video at index number
     * 
     * Cue mean before playing video only show video thumbnail and title
     * @param {string|[string]|{index:number|undefined,list:string,listType:string|undefined}} data 
     * @param {number|undefined} index count start with 0
     * @param {number|undefined} startSeconds only affect first video
     * @example
     * player.loadPlaylist('i50sUufNbzY');//play i50sUufNbzY video start with 0 second
     * player.loadPlaylist(['i50sUufNbzY','BgNVwiX7K8E','L7PCS7afS3Y'],1,10);//play index second playlist (BgNVwiX7K8E) and play start with 10 seconds
     * player.loadPlaylist({list:'PL84LbRiy3noqhbyqr-IcCKhyXE6mFoQzF'});//play playlist first index of PL84LbRiy3noqhbyqr-IcCKhyXE6mFoQzF and start with 0 second
     */
    loadPlaylist(data, index, startSeconds) {
        this.playPlaylist(data, true, index, startSeconds);
    }

    /**
     * Play video spacific number of index
     * @param {number} index count start with 0
     * @example
     * player.playVideoAt(5);//play video playlist index 6th
     */
    playVideoAt(index) {
        if (typeof index === 'number') {
            let parameter = { index: index };
            if (this.playlistId !== undefined) {
                parameter['list'] = this.playlistId;
            }
            this.playOtherVideoById(this.playlistVideoIds[index], true, 0, parameter);
        } else {
            console.error('playVideoAt first argument must be number');
        }
    }

    /**
     * play next video of playlist
     * 
     * if end of playlist,if loop is true, load first video of playlist.
     * @example
     * player.nextVideo();
     */
    async nextVideo() {
        let now_index = this.promise_send_event('getplaylistindex');
        if (now_index === null) {
            now_index = this.sub_index;
        }

        if (now_index === this.playlistVideoIds.length - 1) {
            if (this.loop) {
                now_index = 0;
            } else {
                console.log('end of playlist');
                return;
            }
        } else {
            now_index++;
        }
        this.sub_index = now_index;
        let parameter = { index: now_index };
        if (this.playlistId !== undefined) {
            parameter['list'] = this.playlistId;
        }
        this.playOtherVideoById(this.playlistVideoIds[now_index], true, 0, parameter);
    }

    /**
     * play previous video of playlist
     * 
     * if start of playlist,if loop is true, load end video of playlist.
     * @example
     * player.previousVideo();
     */
    async previousVideo() {
        let now_index = this.promise_send_event('getplaylistindex');
        if (now_index === null) {
            now_index = this.sub_index;
        }
        if (now_index === 0) {
            if (this.loop) {
                now_index = this.playlistVideoIds.length - 1;
            } else {
                console.log('back to start of playlist');
                return;
            }
        } else {
            now_index--;
        }
        this.sub_index = now_index;
        let parameter = { index: now_index };
        if (this.playlistId !== undefined) {
            parameter['list'] = this.playlistId;
        }
        this.playOtherVideoById(this.playlistVideoIds[now_index], true, 0, parameter);
    }

    /**
    * Get dulation of video
    * 
    * Default return number
    * 
    * But if set invidious_embed.api_promise true, return Promise<number>.
    * @returns {number|Promise<number>}
    * @example
    * const player_dulation = player.getDuration();//invidious_embed.api_promise is false
    * const player_dulation = await player.getDuration();//invidious_embed.api_promise is true
    * //player_dulation = 80
    */
    getDuration() {
        return this.promise_send_event('getduration');
    }

    /**
     * Get url of loaded video
     * @returns {string}
     * @example
     * const video_url = player.getVideoUrl();
     * //video_url = "https://yewtu.be/watch?v=KqE7Bwhd-rE"
     */
    getVideoUrl() {
        return this.target_origin + "/watch?v=" + this.videoId;
    }

    /**
     * Get title of loaded video.
     * 
     * Default return string
     * 
     * But if set invidious_embed.api_promise true, return Promise<string>.
     * @returns {string,Promise<string>}
     * @example
     * const title = player.getTitle();//invidious_embed.api_promise is false
     * const title = await player.getTitle();//invidious_embed.api_promise is true
     * //title = "【夏の終わりに】夏祭り/ときのそら【歌ってみた】"
     */
    getTitle() {
        return this.promise_send_event('gettitle');
    }

    /**
     * Get video embed iframe string
     * 
     * Default return string
     * 
     * But if set invidious_embed.api_promise true, return Promise<string>.
     * @returns {string,Promise<string>}
     * @example
     * const embed_code = player.getVideoEmbedCode();//invidious_embed.api_promise is false
     * const embed_code = await player.getVideoEmbedCode();//invidious_embed.api_promise is true
     * //embed_code = `<iframe width="560" height="315" src="https://yewtu.be/embed/KqE7Bwhd-rE" title="【夏の終わりに】夏祭り/ときのそら【歌ってみた】" frameborder="0" allow="autoplay;encrypted-media;picture-in-picture;web-share" allowfullscreen></iframe>`
     */
    getVideoEmbedCode() {
        const embed_url = encodeURI(`${this.target_origin}/embed/${this.videoId}`);
        const html_escape = (html) => {
            const html_escaped = html.replace(/[&'`"<>]/g, match => {
                return {
                    '&': '&amp;',
                    "'": '&#x27;',
                    '`': '&#x60;',
                    '"': '&quot;',
                    '<': '&lt;',
                    '>': '&gt;',
                }[match]
            });
            return html_escaped;
        }
        const iframe_constractor = (raw_title) => {
            const html_escaped_title = html_escape(raw_title);
            return `<iframe width="560" height="315" src="${embed_url}" title="${html_escaped_title}" frameborder="0" allow="autoplay;encrypted-media;picture-in-picture;web-share" allowfullscreen></iframe>`;
        }
        if (invidious_embed.api_promise) {
            return new Promise(async (resolve, reject) => {
                resolve(iframe_constractor(await this.getTitle()));
            })
        }
        else {
            return iframe_constractor(this.getTitle());
        }
    }

    /**
     * Get current playing time start with video 0 seconds
     * 
     * Default return number
     * 
     * But if set invidious_embed.api_promise true, return Promise<number>.
     * @returns {number|Promise<number>}
     * @example
     * const player_time = player.getCurrentTime();//invidious_embed.api_promise is false
     * const player_time = await player.getCurrentTime();//invidious_embed.api_promise is true
     * //player_time = 80
     */
    getCurrentTime() {
        return this.promise_send_event('getcurrenttime');
    }

    /**
     * Get video related data.
     * 
     * This function is not compatible with youtube iframe api
     * @returns {Promise<{
     * video_id:string,
     * title:string,
     * list:?string,
     * isListed:boolean,
     * isLibe:boolean,
     * isPremiere:boolean
     * }>}
     * @example
     * const video_data = await player.getVideoData();
     * //video_data = {"video_id": "KqE7Bwhd-rE","title": "【夏の終わりに】夏祭り/ときのそら【歌ってみた】","list": null,"isListed": true,"isLive": false,"isPremiere": false}
     */
    async getVideoData() {
        const videoData = await this.videodata_api(this.videoId);
        return {
            video_id: this.videoId,
            title: await this.promise_send_event('gettitle'),
            list: await this.promise_send_event('getplaylistid'),
            isListed: videoData.isListed,
            isLive: videoData.liveNow,
            isPremiere: videoData.premium
        };
    }

    /**
     * Get playlist index which count start with 0
     * 
     * Default return number
     * 
     * But if set invidious_embed.api_promise true, return Promise<number>.
     * @returns {number|Promise<number>}
     * @example
     * const playlist_index = player.getPlaylistIndex();//invidious_embed.api_promise is false
     * const playlist_index = await player.getPlaylistIndex();//invidious_embed.api_promise is true
     * //playlist_index = 3
     */
    getPlaylistIndex() {
        return this.promise_send_event('getplaylistindex');
    }

    /**
     * Get playlist videoIds
     * @returns {[string]|undefined}
     * @example
     * const playlist_videoids = player.getPlaylist();
     * //playlist_videoids = ['i50sUufNbzY','BgNVwiX7K8E','L7PCS7afS3Y'];
     */
    getPlaylist() {
        return this.playlistVideoIds !== undefined ? this.playlistVideoIds : [];
    }

    /**
     * set loop video or not
     * @param {boolean} loopStatus 
     * @example
     * player.setLoop(true);
     */
    setLoop(loopStatus) {
        if (typeof loopStatus === 'boolean') {
            this.loop = loopStatus;
        } else {
            console.error('setLoop first argument must be bool');
        }
    }

    constructor(element, options) {
        this.Player(element, options);
        window.addEventListener('message', (ms) => { this.receiveMessage(ms) });
        this.message_wait = {
            getvolume: [],
            getmutestatus: [],
            getduration: [],
            getcurrenttime: [],
            getplaybackrate: [],
            getavailableplaybackrates: [],
            gettitle: []
        };
    }
}

/**
 * After load iFrame api,function will execute
 * 
 * But this function always execute immediately because iframe api ready mean load complete this js file
 * @param {Function} func 
 */
function invidious_ready(func) {
    if (typeof func === 'function') {
        func();
    }
    else {
        console.warn('invidious.ready first argument must be function');
    }
}

invidious_embed.invidious_instance = new URL(document.currentScript.src).origin;//set default instance using load origin of js file instance

const invidious = {
    Player: invidious_embed,
    PlayerState: {
        ENDED: 0,
        PLAYING: 1,
        PAUSED: 2,
        BUFFERING: 3,
        CUED: 5
    },
    ready: invidious_ready
};

if (typeof onInvidiousIframeAPIReady === 'function') {
    try {
        onInvidiousIframeAPIReady();
    } catch (e) {
        console.error(e);
    }
}
