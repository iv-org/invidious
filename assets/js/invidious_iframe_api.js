class invidious_embed{
    static widgetid = 0;
    static eventname_table = {onPlaybackRateChange:'ratechange',onStateChange:'statechange',onerror:'error'};
    static api_promise = false;
    addEventListener(eventname,func){
        if(eventname in invidious_embed.eventname_table){
            this.eventobject[invidious_embed.eventname_table[eventname]].push(func);
        }
        else{
            try{
                this.eventobject[eventname].push(func);
            }
            catch{}
        }
    }
    removeEventListner(eventname,func){
        var internal_eventname;
        if(eventname in invidious_embed.eventname_table){
            internal_eventname = invidious_embed.eventname_table[eventname];
        }
        else{
            internal_eventname = eventname;
        }
        this.eventobject[internal_eventname] = this.eventobject[internal_eventname].fillter(x=>x!==func);
    }
    Player(element,options){
        this.player_status = -1;
        this.error_code = 0;
        this.volume = 100;
        this.eventobject = {ready:[],ended:[],error:[],ratechange:[],volumechange:[],waiting:[],timeupdate:[],loadedmetadata:[],play:[],seeking:[],seeked:[],playerresize:[],pause:[],statechange:[]};
        var replace_elemnt;
        if(element===undefined||element===null){
            throw 'Please, pass element id or HTMLElement as first argument';
        }
        else if(typeof element==='string'){
            replace_elemnt = document.getElementById(element);
        }
        else{
            replace_elemnt = element;
        }
        var iframe_src = '';
        if(options.host!==undefined&&options.host!==""){
            iframe_src = new URL(options.host).origin;
        }
        else{
            iframe_src = 'https://vid.puffyan.us';//I set most hot instanse but this may need discuss or change ay to default instanse
        }
        this.target_origin = iframe_src.slice();
        iframe_src += '/embed/';
        if(typeof options.videoId==='string'&&options.videoId.length===11){
            iframe_src += options.videoId;
            this.videoId = options.videoId;
        }
        else{
            this.error_code = 2;
            this.event_executor('error');
        }
        var search_params = new URLSearchParams('');
        search_params.append('widgetid',invidious_embed.widgetid);
        this.widgetid = invidious_embed.widgetid;
        invidious_embed.widgetid++;
        search_params.append('origin',location.origin);
        search_params.append('enablejsapi','1');
        if(typeof options.playerVars==='object'){
            this.option_playerVars = options.playerVars;
            for(var x in options.playerVars){
                if(typeof x==='string'&&typeof options.playerVars[x]==='string'){
                    search_params.append(x,options.playerVars[x]);
                }
            }
            if(options.playerVars.autoplay===undefined){
                search_params.append('autoplay','0');
            }
        }
        iframe_src += "?" + search_params.toString();
        if(options.events!==undefined&&typeof options.events==='object'){
            for(let x in options.events){
                this.addEventListener(x,options.events[x]);
            }
        }
        this.player_iframe = document.createElement("iframe");
        this.loaded = false;
        this.addEventListener('loadedmetadata',()=>{this.event_executor('ready');this.loaded=true});
        this.addEventListener('loadedmetadata',()=>{this.setVolume(this.volume)});
        this.player_iframe.src = iframe_src;
        if(options.width!==undefined&&typeof options.width==='number'){
            this.player_iframe.width = options.width;
        }
        else{
            if(document.body.clientWidth < 640){
                this.player_iframe.width = document.body.clientWidth;
            }
            else{
                this.player_iframe.width = 640;
            }
        }
        if(options.width!==undefined&&typeof options.width==='number'){
            this.player_iframe.width = options.width;
        }
        else{
            this.player_iframe.height = this.player_iframe.width * (9/16);
        }
        this.player_iframe.style.border = "none";
        replace_elemnt.replaceWith(this.player_iframe);
        this.eventdata = {};
        return this;
    }
    postMessage(data){
        var additionalInfo = {'origin':location.origin,'widgetid':String(this.widgetid),'target':'invidious_control'};
        data = Object.assign(additionalInfo,data);
        this.player_iframe.contentWindow.postMessage(data,this.target_origin);
    }
    event_executor(eventname){
        var execute_functions = this.eventobject[eventname];
        var return_data = {data:undefined,target:this};
        if(eventname==='statechange'){
            return_data.data = this.getPlayerState();
        }
        for(var x=0;x<execute_functions.length;x++){
            try{
                execute_functions[x](return_data);
            }
            catch{}
        }
    }
    receiveMessage(message){
        if(message.data.from==='invidious_control'&&message.data.widgetid===String(this.widgetid)){
            switch(message.data.message_kind){
                case 'info_return':
                    var promise_array = this.message_wait[message.data.command];
                    for(var x=0;x<promise_array.length;x++){
                        if(message.data.command==='getvolume'){
                            promise_array[x](message.data.value*100);
                        }
                        else{
                            promise_array[x](message.data.value);
                        }
                    }
                    this.message_wait[message.data.command] = [];
                    break;
                case 'event':
                    if(message.data.eventname!==undefined&&typeof message.data.eventname==='string'){
                        this.event_executor(message.data.eventname);
                        var previous_status = this.player_status;
                        switch(message.data.eventname){
                            case 'ended':
                                this.player_status = 0;
                                break;
                            case 'play':
                                this.player_status = 1;
                                break;
                            case 'timeupdate':
                                this.player_status = 1;
                                this.eventdata = Object.assign({},this.eventdata,message.data.value);
                                break;
                            case 'pause':
                                this.player_status = 2;
                                break;
                            case 'waiting':
                                this.player_status = 3;
                                break;
                            case 'loadedmetadata':
                                this.eventdata = Object.assign({},this.eventdata,message.data.value);
                                break;
                        }
                        if(previous_status!==this.player_status){
                            this.event_executor('statechange');
                        }
                    }
            }
        }
    }
    promise_resolve(){
        var res_outer;
        var pro = new Promise((res,rej)=>{res_outer=res});
        return {'promise':pro,'resolve':res_outer};
    }
    promise_send_event(event_name){
        if(invidious_embed.api_promise){
            var pro_object = this.promise_resolve();
            this.message_wait[event_name].push(pro_object.resolve);
            this.postMessage({eventname:event_name});
            return pro_object.promise;
        }
        else{
            return this.eventdata[event_name];
        }
    }
    getPlayerState(){
        return this.player_status;
    }
    playVideo(){
        this.postMessage({eventname:'play'});
    }
    pauseVideo(){
        this.postMessage({eventname:'pause'});
    }
    getVolume(){
        return this.promise_send_event('getvolume');
    }
    setVolume(volume){
        volume = Number(volume);
        this.volume = volume;
        if(volume!==NaN&&volume!=undefined&&volume>=0&&volume<=100){
            this.postMessage({eventname:'setvolume',value:volume/100});
        }
    }
    getIframe(){
        return this.player_iframe;
    }
    destroy(){
        this.player_iframe.remove();
    }
    mute(){
        this.postMessage({eventname:'setmutestatus',value:true});
    }
    unMute(){
        this.postMessage({eventname:'setmutestatus',value:false});
    }
    isMuted(){
        return this.promise_send_event('getmutestatus');
    }
    seekTo(seconds,allowSeekAhead){//seconds must be a number and allowSeekAhead is ignore
        seconds = Number(seconds);
        if(seconds!==NaN&&seconds!==undefined){
            this.postMessage({eventname:'seek',value:seconds});
        }
    }
    setSize(width,height){//width and height must be Number
        this.player_iframe.width = Number(width);
        this.player_iframe.height = Number(height);
    }
    getPlaybackRate(){
        return this.promise_send_event('getplaybackrate');
    }
    setPlaybackRate(suggestedRate){//suggestedRate must be number.this player allow not available playback rate such as 1.4
        suggestedRate = Number(suggestedRate);
        if(suggestedRate!==NaN&&suggestedRate!==undefined){
            this.postMessage({eventname:'setplaybackrate',value:suggestedRate});
        }
    }
    getAvailablePlaybackRates(){
        return this.promise_send_event('getavailableplaybackrates');
    }
    playOtherVideoById(option,autoplay,startSeconds_arg){//internal fuction
        let videoId = '';
        let startSeconds = -1;
        let endSeconds = -1;
        let mediaContetUrl = '';
        if(typeof option==='string'){
            if(option.length===11){
                videoId = option
            }
            else{
                mediaContetUrl = option;
            }
            if(startSeconds_arg!==undefined&&typeof startSeconds_arg==='number'){
                startSeconds = startSeconds_arg;
            }
        }
        else if(typeof option==='object'){
            if(option.videoId!==undefined&&typeof option.videoId==='string'){
                if(option.videoId.length==11){
                    videoId = option.videoId;
                }
                else{
                    this.error_code = 2;
                    this.event_executor('error');
                }
            }
            else if(option.mediaContentUrl!==undefined&&typeof option.mediaContentUrl==='string'){
                mediaContetUrl = option.mediaContentUrl;
            }
            else{
                this.error_code = 2;
                this.event_executor('error');
            }
            if(option.startSeconds!==undefined&&typeof option.startSeconds==='number'&&option.startSeconds>=0){
                startSeconds = option.startSeconds;
            }
            if(option.endSeconds!==undefined&&typeof option.endSeconds==='number'&&option.endSeconds>=0){
                endSeconds = option.endSeconds;
            }
        }
        if(mediaContetUrl.length>0){
            var tmp_videoId = '';
            if(mediaContetUrl.indexOf('/v/')!==-1){
                var end_pos = mediaContetUrl.length-1;
                if(mediaContetUrl.indexOf('?')!==-1){
                    end_pos = mediaContetUrl.indexOf('?');
                }
                tmp_videoId = mediaContetUrl.substring(mediaContetUrl.indexOf('/v/'),end_pos);
            }
            else{
                tmp_videoId = new URL(mediaContetUrl).searchParams.get('v');
            }
            if(tmp_videoId===null||tmp_videoId.length!==11){
                this.error_code = 2;
                this.event_executor('error');
            }
            videoId = tmp_videoId;
        }
        var iframe_sorce = this.target_origin.slice();
        iframe_sorce += "/embed/" + videoId;
        this.videoId = videoId;
        var search_params = new URLSearchParams('');
        search_params.append('origin',location.origin);
        search_params.append('enablejsapi','1');
        search_params.append('widgetid',invidious_embed.widgetid);
        this.widgetid = invidious_embed.widgetid;
        invidious_embed.widgetid++;
        if(autoplay){
            search_params.append('autoplay',1);
        }
        else{
            search_params.append('autoplay',0);
        }
        if(this.option_playerVars!==undefined){
            for(var x in this.option_playerVars){
                if(x!=='autoplay'&&x!=='start'&&x!=='end'){
                    search_params.append(x,this.option_playerVars[x]);
                }
            }
        }
        if(startSeconds!==-1&&startSeconds>=0){
            search_params.append('start',startSeconds);
        }
        if(endSeconds!==-1&&endSeconds>=0){
            if(endSeconds>startSeconds){
                search_params.append('end',endSeconds);
            }
            else{
                throw 'invalid end seconds';
            }
        }
        iframe_sorce += "?" + search_params.toString();
        this.player_iframe.src = iframe_sorce;
        if(autoplay){
            this.player_status = 5;
        }
        this.eventdata = {};
    }
    loadVideoById(option,startSeconds){
        this.playOtherVideoById(option,true,startSeconds);
    }
    cueVideoById(option,startSeconds){
        this.playOtherVideoById(option,false,startSeconds);
    }
    cueVideoByUrl(option,startSeconds){
        this.playOtherVideoById(option,false,startSeconds);
    }
    loadVideoByUrl(option,startSeconds){
        this.playOtherVideoById(option,true,startSeconds);
    }
    getDuration(){
        return this.promise_send_event('getduration');
    }
    getVideoUrl(){
        return this.target_origin + "/watch?v=" + this.videoId;
    }
    async getVideoEmbedCode(){
        var title = await this.getVideoTitle();
        return '<iframe width="560" height="315" src="' + this.target_origin + "/embed/" + this.videoId + '" title="' + title.replace('"','') + '" frameborder="0" allow="autoplay;encrypted-media;picture-in-picture; web-share" allowfullscreen></iframe>';
    }
    getCurrentTime(){
        return this.promise_send_event('getcurrenttime');
    }
    constructor(element,options){
        this.Player(element,options);
        window.addEventListener('message',(ms)=>{this.receiveMessage(ms)});
        this.message_wait = {getvolume:[],getmutestatus:[],getduration:[],getcurrenttime:[],getplaybackrate:[],getavailableplaybackrates:[],gettitle:[]};
    }
    async getVideoData(){
        return {video_id:this.videoId,title:await this.promise_send_event('gettitle')};
    }
}
function invidious_ready(func){
    if(typeof func==='function'){
        func();
    }
}
const invidious = {Player:invidious_embed,PlayerState:{ENDED:0,PLAYING:1,PAUSED:2,BUFFERING:3,CUED:5},ready:invidious_ready};
try{
    onInvidiousIframeAPIReady();
}
catch{}
