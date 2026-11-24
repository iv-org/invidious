// Port of FreeTube's SabrManifestParser.js
// Reads shaka from window.shaka, index parsers from window globals.
// Registers a manifest parser for the 'application/sabr+json' mime type.
// Exposes window.MANIFEST_TYPE_SABR.

'use strict';

(function () {
  var shaka = window.shaka;
  var NetworkingEngine = shaka.net.NetworkingEngine;
  var MANIFEST_TYPE_SABR = 'application/sabr+json';
  var CODECS_REGEX = /codecs="?([^"]+)"?/;
  var VIDEO_CODEC_PRIORITIES = ['av01', 'vp09', 'vp9', 'avc1'];

  function buildFormatId(format) {
    return format.itag + '-' + (format.lastModified ?? '0') + '-' + (format.xtags ?? '');
  }

  function getCodecs(format) {
    var match = format.mimeType ? format.mimeType.match(CODECS_REGEX) : null;
    return match ? match[1] : null;
  }

  // Rank of a codec string in VIDEO_CODEC_PRIORITIES; unknown codecs sort last.
  function videoCodecRank(codecs) {
    var rank = VIDEO_CODEC_PRIORITIES.findIndex(function (codec) { return codecs.indexOf(codec) === 0; });
    return rank === -1 ? VIDEO_CODEC_PRIORITIES.length : rank;
  }

  // Prefer the original language, then non-DRC audio, then the highest bitrate.
  function isBetterAudioCompanion(a, b) {
    if (!!a.isOriginal !== !!b.isOriginal) return !!a.isOriginal;
    if (!!a.isDrc !== !!b.isDrc) return !a.isDrc;
    return a.bitrate > b.bitrate;
  }

  // Workaround: https://github.com/LuanRT/googlevideo/issues/42
  function isRejectedAudioFormat(format) {
    return format.xtags === 'CgcKAnZiEgEx';
  }

  function createVodMediaSegmentIndex(url, response, format, stream, duration) {
    var mediaQuality = {
      contentType: stream.type,
      bandwidth: stream.bandwidth,
      mimeType: stream.mimeType,
      codecs: stream.codecs,
      language: stream.language,
      label: stream.label,
      audioSamplingRate: stream.audioSamplingRate,
      channelsCount: stream.channelsCount,
      width: stream.width ?? null,
      height: stream.height ?? null,
      frameRate: stream.frameRate ?? null,
      roles: stream.roles,
      pixelAspectRatio: stream.pixelAspectRatio ?? null
    };

    // Slice through a view so a response that is a subarray (non-zero byteOffset) still works.
    var bytes = ArrayBuffer.isView(response.data)
      ? new Uint8Array(response.data.buffer, response.data.byteOffset, response.data.byteLength)
      : new Uint8Array(response.data);
    var initData = bytes.slice(format.initRange.start, format.initRange.end + 1).buffer;
    var indexData = bytes.slice(format.indexRange.start, format.indexRange.end + 1).buffer;

    var initUrls = [url + '&init'];
    var initSegmentReference = new shaka.media.InitSegmentReference(
      function () { return initUrls; },
      format.initRange.start,
      format.initRange.end,
      mediaQuality,
      null,
      initData,
      null
    );

    initSegmentReference.mimeType = stream.mimeType;
    initSegmentReference.codecs = stream.codecs;

    var references;
    if (stream.mimeType.endsWith('/webm')) {
      references = window.parseWebmSegmentIndex(indexData, initData, url, initSegmentReference, 0, 0, duration);
    } else {
      references = window.parseMp4SegmentIndex(indexData, format.indexRange.start, url, initSegmentReference, 0, 0, duration);
    }

    for (var i = 0; i < references.length; i++) {
      references[i].mimeType = stream.mimeType;
      references[i].codecs = stream.codecs;
    }

    return new shaka.media.SegmentIndex(references);
  }

  // companionFormatId: the format of the other media type to put in the SABR request
  // (a video format for an audio stream, an audio format for a video stream). The init
  // request can run before shaka publishes any variant track, so the scheme plugin
  // cannot always derive it from the player.
  async function createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine, companionFormatId) {
    var url = 'sabr:' + stream.type + '?formatId=' + encodeURIComponent(stream.originalId);
    if (companionFormatId) {
      url += (stream.type === 'audio' ? '&videoFormatId=' : '&audioFormatId=') + encodeURIComponent(companionFormatId);
    }
    if (format.isDrc) {
      url += '&drc';
    } else if (format.isVoiceBoost) {
      url += '&vb';
    }
    if (stream.type === 'video') {
      var resolution = format.height || 360;
      url += '&resolution=' + resolution;
    }

    var request = {
      method: 'GET',
      uris: [url + '&init'],
      contentType: stream.type,
      body: null,
      headers: {},
      allowCrossSiteCredentials: false,
      retryParameters: NetworkingEngine.defaultRetryParameters(),
      licenseRequestType: null,
      sessionId: null,
      drmInfo: null,
      initData: null,
      initDataType: null,
      streamDataCallback: null
    };

    var response = await networkingEngine.request(
      NetworkingEngine.RequestType.SEGMENT,
      request,
      {
        stream: stream,
        type: NetworkingEngine.AdvancedRequestType.INIT_SEGMENT
      }
    ).promise;

    return createVodMediaSegmentIndex(url, response, format, stream, presentationTimeline.getDuration());
  }

  function createAudioStream(format, id, hasDrcAudio, hasVoiceBoostAudio, presentationTimeline, networkingEngine, companionVideoFormatId) {
    var roles = [];

    if (format.isDrc) {
      roles.push('drc');
    } else if (format.isVoiceBoost) {
      roles.push('voice-boost');
    } else if (format.isDubbed) {
      roles.push('dubbed');
    } else if (format.isAutoDubbed) {
      roles.push('dubbed-auto');
    } else if (format.isDescriptive) {
      roles.push('descriptive');
    } else if (format.isSecondary) {
      roles.push('secondary');
    } else if (format.isOriginal) {
      roles.push('main');
    }

    var label = null;
    if (format.label) {
      if (format.isDrc) {
        label = format.label + ' (Stable Volume)';
      } else if (format.isVoiceBoost) {
        label = format.label + ' (Voice Boost)';
      } else {
        label = format.label;
      }
    } else if (hasDrcAudio || hasVoiceBoostAudio) {
      if (format.isDrc) {
        label = 'Stable Volume';
      } else if (format.isVoiceBoost) {
        label = 'Voice Boost';
      } else {
        label = 'Original';
      }
    }

    var stream = {
      type: 'audio',
      id: id,
      originalId: buildFormatId(format),
      mimeType: format.mimeType.split(';', 1)[0],
      codecs: getCodecs(format),
      fullMimeTypes: new Set([format.mimeType]),
      bandwidth: format.bitrate,
      audioSamplingRate: format.audioSampleRate ?? null,
      channelsCount: format.audioChannels ?? null,
      label: label,
      language: format.language ?? 'und',
      originalLanguage: format.language ?? null,
      spatialAudio: format.spatialAudio,
      roles: roles,
      primary: roles.indexOf('main') !== -1,
      segmentIndex: null,
      createSegmentIndex: async function () {
        if (stream.segmentIndex) return;
        stream.segmentIndex = await createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine, companionVideoFormatId);
      },
      closeSegmentIndex: function () {
        if (stream.segmentIndex) {
          stream.segmentIndex.release();
          stream.segmentIndex = null;
        }
      },
      accessibilityPurpose: null,
      closedCaptions: null,
      drmInfos: [],
      emsgSchemeIdUris: null,
      encrypted: false,
      external: false,
      fastSwitching: false,
      forced: false,
      groupId: null,
      isAudioMuxedInVideo: false,
      keyIds: new Set(),
      trickModeVideo: null
    };

    return stream;
  }

  function createVideoStream(format, id, presentationTimeline, networkingEngine, companionAudioFormatId) {
    var colorGamut = format.colorPrimaries === 'BT2020' ? 'rec2020' : 'srgb';
    var hdr = 'SDR';
    if (format.colorTransferCharacteristics === 'SMPTEST2084') {
      hdr = 'PQ';
    } else if (format.colorTransferCharacteristics === 'ARIB_STD_B67') {
      hdr = 'HLG';
    }

    var stream = {
      type: 'video',
      id: id,
      originalId: buildFormatId(format),
      mimeType: format.mimeType.split(';', 1)[0],
      codecs: getCodecs(format),
      fullMimeTypes: new Set([format.mimeType]),
      bandwidth: format.bitrate,
      width: format.width,
      height: format.height,
      frameRate: format.frameRate,
      colorGamut: colorGamut,
      hdr: hdr,
      roles: [],
      segmentIndex: null,
      createSegmentIndex: async function () {
        if (stream.segmentIndex) return;
        stream.segmentIndex = await createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine, companionAudioFormatId);
      },
      closeSegmentIndex: function () {
        if (stream.segmentIndex) {
          stream.segmentIndex.release();
          stream.segmentIndex = null;
        }
      },
      accessibilityPurpose: null,
      audioSamplingRate: null,
      channelsCount: null,
      closedCaptions: null,
      drmInfos: [],
      emsgSchemeIdUris: null,
      encrypted: false,
      external: false,
      fastSwitching: false,
      forced: false,
      groupId: null,
      isAudioMuxedInVideo: false,
      keyIds: new Set(),
      label: null,
      language: 'und',
      originalLanguage: null,
      primary: false,
      spatialAudio: false,
      trickModeVideo: null
    };

    return stream;
  }

  function createTextStreams(captions, presentationTimeline, currentId) {
    var result = [];
    for (var i = 0; i < captions.length; i++) {
      // Block-scoped: the segment index closures below must see this iteration's values.
      let caption = captions[i];
      let stream = {
        type: 'text',
        id: currentId++,
        originalId: caption.id,
        mimeType: caption.mimeType,
        fullMimeTypes: new Set([caption.mimeType]),
        label: caption.label,
        language: caption.language,
        originalLanguage: caption.language,
        kind: 'captions',
        segmentIndex: null,
        createSegmentIndex: function () {
          stream.segmentIndex = shaka.media.SegmentIndex.forSingleSegment(
            0,
            presentationTimeline.getDuration(),
            [caption.url]
          );
          stream.segmentIndex.get(0).mimeType = caption.mimeType;
          return Promise.resolve();
        },
        closeSegmentIndex: function () {
          if (stream.segmentIndex) {
            stream.segmentIndex.release();
            stream.segmentIndex = null;
          }
        },
        accessibilityPurpose: null,
        audioSamplingRate: null,
        channelsCount: null,
        closedCaptions: null,
        codecs: '',
        drmInfos: [],
        emsgSchemeIdUris: null,
        encrypted: false,
        external: false,
        fastSwitching: false,
        forced: false,
        groupId: null,
        isAudioMuxedInVideo: false,
        keyIds: new Set(),
        primary: false,
        roles: [],
        spatialAudio: false,
        trickModeVideo: null
      };
      result.push(stream);
    }
    return result;
  }

  function createImageStreams(storyboards, presentationTimeline, currentId) {
    var result = [];
    for (var i = 0; i < storyboards.length; i++) {
      // Block-scoped: the segment index closures below must see this iteration's values.
      let storyboard = storyboards[i];
      let tilesLayout = storyboard.columns + 'x' + storyboard.rows;

      let stream = {
        type: 'image',
        id: currentId++,
        mimeType: storyboard.mimeType,
        fullMimeTypes: new Set([storyboard.mimeType]),
        tilesLayout: tilesLayout,
        width: storyboard.thumbnailWidth * storyboard.columns,
        height: storyboard.thumbnailHeight * storyboard.rows,
        segmentIndex: null,
        createSegmentIndex: function () {
          var duration = presentationTimeline.getDuration();
          var interval = storyboard.interval > 0 ? storyboard.interval : duration / storyboard.thumbnailCount;
          var segmentDuration = interval * storyboard.columns * storyboard.rows;
          var references = [];
          for (var j = 0; j < storyboard.storyboardCount; j++) {
            var startTime = j * segmentDuration;
            var endTime = Math.min(startTime + segmentDuration, duration);
            // NOTE: must be `let` (block-scoped). With `var` the closure below captures the
            // function-scoped binding, so every SegmentReference returns the LAST storyboard
            // image -> the same (mismatched, distorted) thumbnail for the whole video.
            let urls = [storyboard.templateUrl.replace('$M', String(j))];
            var segmentReference = new shaka.media.SegmentReference(
              startTime, endTime,
              function () { return urls; },
              0, null, null, 0, 0, Infinity, undefined, tilesLayout, interval
            );
            segmentReference.mimeType = storyboard.mimeType;
            references.push(segmentReference);
          }
          stream.segmentIndex = new shaka.media.SegmentIndex(references);
          return Promise.resolve();
        },
        closeSegmentIndex: function () {
          if (stream.segmentIndex) {
            stream.segmentIndex.release();
            stream.segmentIndex = null;
          }
        },
        accessibilityPurpose: null,
        audioSamplingRate: null,
        channelsCount: null,
        closedCaptions: null,
        codecs: '',
        drmInfos: [],
        emsgSchemeIdUris: null,
        encrypted: false,
        external: false,
        fastSwitching: false,
        forced: false,
        groupId: null,
        isAudioMuxedInVideo: false,
        keyIds: new Set(),
        label: null,
        language: 'und',
        originalId: null,
        originalLanguage: null,
        primary: false,
        roles: [],
        spatialAudio: false,
        trickModeVideo: null
      };
      result.push(stream);
    }
    return result;
  }

  function createChapterStreams(chapters, currentId) {
    if (chapters.length === 0) {
      return [];
    }
    var references = [];
    for (var i = 0; i < chapters.length; i++) {
      var chapter = chapters[i];
      var reference = new shaka.media.SegmentReference(
        chapter.startSeconds, chapter.endSeconds,
        function () { return []; },
        0, null, null, 0, 0, Infinity
      );
      reference.setMetadata({
        title: chapter.title,
        images: chapter.thumbnail
          ? [{ url: chapter.thumbnail.url, width: chapter.thumbnail.width, height: chapter.thumbnail.height }]
          : []
      });
      references.push(reference);
    }

    var stream = {
      id: currentId,
      originalId: null,
      groupId: null,
      createSegmentIndex: function () { return Promise.resolve(); },
      segmentIndex: new shaka.media.SegmentIndex(references),
      mimeType: 'text/plain',
      codecs: '',
      supplementalCodecs: '',
      kind: '',
      encrypted: false,
      drmInfos: [],
      keyIds: new Set(),
      language: 'und',
      originalLanguage: 'und',
      label: null,
      type: 'chapter',
      primary: false,
      trickModeVideo: null,
      dependencyStream: null,
      emsgSchemeIdUris: null,
      roles: [],
      forced: false,
      channelsCount: null,
      audioSamplingRate: null,
      spatialAudio: false,
      closedCaptions: null,
      accessibilityPurpose: null,
      external: true,
      fastSwitching: false,
      fullMimeTypes: new Set(['text/plain']),
      isAudioMuxedInVideo: false,
      baseOriginalId: null
    };
    return [stream];
  }

  function SabrManifestParser() {
    this._config = null;
  }
  SabrManifestParser.prototype.banLocation = function (_uri) {};
  SabrManifestParser.prototype.configure = function (config, _isPreloadFn) {
    this._config = config;
  };
  SabrManifestParser.prototype.onInitialVariantChosen = function (_variant) {};
  SabrManifestParser.prototype.setMediaElement = function (_mediaElement) {};

  SabrManifestParser.prototype.start = async function (uri, playerInterface) {
    var filter = playerInterface.filter;
    var networkingEngine = playerInterface.networkingEngine;

    var uriPrefixLength = 5 + MANIFEST_TYPE_SABR.length + 1;
    var manifestData = JSON.parse(decodeURIComponent(uri.slice(uriPrefixLength)));

    var presentationTimeline = new shaka.media.PresentationTimeline(0, 0, true);
    presentationTimeline.setStatic(true);
    presentationTimeline.setSegmentAvailabilityDuration(Infinity);
    presentationTimeline.lockStartTime();
    presentationTimeline.setDuration(manifestData.duration);

    var currentId = 0;
    var audioStreams = [];
    var videoStreams = [];

    var hasDrcAudio = false;
    var hasVoiceBoostAudio = false;
    for (var i = 0; i < manifestData.formats.length; i++) {
      if (manifestData.formats[i].isDrc) hasDrcAudio = true;
      if (manifestData.formats[i].isVoiceBoost) hasVoiceBoostAudio = true;
    }

    // Formats without a codecs parameter can't be played (or described to shaka).
    var formats = manifestData.formats.filter(function (format) { return getCodecs(format) !== null; });

    // Companion formats sent with each stream's SABR requests until shaka has an
    // active variant (see createMediaSegmentIndex). For audio-only playback the
    // video companion is the lowest bitrate video format, as nothing of it is played.
    var companionVideoFormat = null;
    var companionAudioFormat = null;
    for (var i2 = 0; i2 < formats.length; i2++) {
      var currentFormat = formats[i2];
      if (currentFormat.mimeType.indexOf('audio/') === 0) {
        if (isRejectedAudioFormat(currentFormat)) continue;
        if (companionAudioFormat === null || isBetterAudioCompanion(currentFormat, companionAudioFormat)) {
          companionAudioFormat = currentFormat;
        }
      } else if (currentFormat.width !== undefined) {
        if (companionVideoFormat === null) {
          companionVideoFormat = currentFormat;
        } else if (this._config.disableVideo) {
          if (currentFormat.bitrate < companionVideoFormat.bitrate) companionVideoFormat = currentFormat;
        } else if (videoCodecRank(getCodecs(currentFormat)) < videoCodecRank(getCodecs(companionVideoFormat))) {
          companionVideoFormat = currentFormat;
        }
      }
    }
    var companionVideoFormatId = companionVideoFormat ? buildFormatId(companionVideoFormat) : undefined;
    var companionAudioFormatId = companionAudioFormat ? buildFormatId(companionAudioFormat) : undefined;

    for (var i3 = 0; i3 < formats.length; i3++) {
      var format = formats[i3];
      if (format.mimeType.indexOf('audio/') === 0) {
        if (isRejectedAudioFormat(format)) continue;
        audioStreams.push(createAudioStream(format, currentId++, hasDrcAudio, hasVoiceBoostAudio, presentationTimeline, networkingEngine, companionVideoFormatId));
      } else if (!this._config.disableVideo) {
        videoStreams.push(createVideoStream(format, currentId++, presentationTimeline, networkingEngine, companionAudioFormatId));
      }
    }

    audioStreams.sort(function (a, b) { return b.bandwidth - a.bandwidth; });
    if (!this._config.disableVideo) {
      videoStreams.sort(function (a, b) {
        return videoCodecRank(a.codecs) - videoCodecRank(b.codecs);
      });
    }

    var variants = [];
    var variantId = 0;
    if (this._config.disableVideo) {
      for (var i4 = 0; i4 < audioStreams.length; i4++) {
        var stream = audioStreams[i4];
        variants.push({
          id: variantId++,
          audio: stream,
          bandwidth: stream.bandwidth,
          language: stream.language,
          allowedByApplication: true,
          allowedByKeySystem: true,
          decodingInfos: [],
          disabledUntilTime: 0,
          primary: stream.primary,
          video: null
        });
      }
    } else {
      for (var i5 = 0; i5 < audioStreams.length; i5++) {
        for (var j = 0; j < videoStreams.length; j++) {
          variants.push({
            id: variantId++,
            audio: audioStreams[i5],
            video: videoStreams[j],
            bandwidth: audioStreams[i5].bandwidth + videoStreams[j].bandwidth,
            language: audioStreams[i5].language,
            allowedByApplication: true,
            allowedByKeySystem: true,
            decodingInfos: [],
            disabledUntilTime: 0,
            primary: audioStreams[i5].primary
          });
        }
      }
    }

    var textStreams = createTextStreams(manifestData.captions, presentationTimeline, currentId);
    currentId += textStreams.length;

    var imageStreams = createImageStreams(manifestData.storyboards, presentationTimeline, currentId);
    currentId += imageStreams.length;

    var chapterStreams = createChapterStreams(manifestData.chapters, currentId);

    var manifest = {
      type: 'SABR',
      startTime: 0,
      variants: variants,
      textStreams: textStreams,
      imageStreams: imageStreams,
      chapterStreams: chapterStreams,
      presentationTimeline: presentationTimeline,
      gapCount: 0,
      ignoreManifestTimestampsInSegmentsMode: false,
      isLowLatency: false,
      nextUrl: null,
      offlineSessionIds: [],
      periodCount: 1,
      sequenceMode: false,
      serviceDescription: null
    };

    await filter(manifest);
    return manifest;
  };

  SabrManifestParser.prototype.stop = function () {
    this._config = null;
    return Promise.resolve();
  };

  // Register unconditionally so the data: application/sabr+json manifest works.
  shaka.media.ManifestParser.registerParserByMime(MANIFEST_TYPE_SABR, function () { return new SabrManifestParser(); });

  window.MANIFEST_TYPE_SABR = MANIFEST_TYPE_SABR;
})();