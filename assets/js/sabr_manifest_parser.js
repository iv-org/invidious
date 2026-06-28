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

    var buffer = ArrayBuffer.isView(response.data) ? response.data.buffer : response.data;
    var initData = buffer.slice(format.initRange.start, format.initRange.end + 1);
    var indexData = buffer.slice(format.indexRange.start, format.indexRange.end + 1);

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

  async function createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine, fakeVideoFormatId) {
    var url = 'sabr:' + stream.type + '?formatId=' + encodeURIComponent(stream.originalId);
    if (fakeVideoFormatId) {
      url += '&videoFormatId=' + encodeURIComponent(fakeVideoFormatId);
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

  function createAudioStream(format, id, hasDrcAudio, hasVoiceBoostAudio, presentationTimeline, networkingEngine, fakeVideoFormatId) {
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
      codecs: format.mimeType.match(CODECS_REGEX)[1],
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
        stream.segmentIndex = await createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine, fakeVideoFormatId);
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

  function createVideoStream(format, id, presentationTimeline, networkingEngine) {
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
      codecs: format.mimeType.match(CODECS_REGEX)[1],
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
        stream.segmentIndex = await createMediaSegmentIndex(format, stream, presentationTimeline, networkingEngine);
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
      var caption = captions[i];
      var stream = {
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
      var storyboard = storyboards[i];
      var tilesLayout = storyboard.columns + 'x' + storyboard.rows;

      var stream = {
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
            var urls = [storyboard.templateUrl.replace('$M', String(j))];
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

    var fakeVideoFormatId;
    if (this._config.disableVideo) {
      var worstVideoFormat = null;
      for (var i2 = 0; i2 < manifestData.formats.length; i2++) {
        var currentFormat = manifestData.formats[i2];
        if (currentFormat.width === undefined) continue;
        if (worstVideoFormat === null) {
          worstVideoFormat = currentFormat;
        } else if (currentFormat.bitrate < worstVideoFormat.bitrate) {
          worstVideoFormat = currentFormat;
        }
      }
      fakeVideoFormatId = worstVideoFormat ? buildFormatId(worstVideoFormat) : undefined;
    }

    for (var i3 = 0; i3 < manifestData.formats.length; i3++) {
      var format = manifestData.formats[i3];
      if (format.mimeType.indexOf('audio/') === 0) {
        if (format.xtags === 'CgcKAnZiEgEx') {
          // Workaround: https://github.com/LuanRT/googlevideo/issues/42
          continue;
        }
        audioStreams.push(createAudioStream(format, currentId++, hasDrcAudio, hasVoiceBoostAudio, presentationTimeline, networkingEngine, fakeVideoFormatId));
      } else if (!this._config.disableVideo) {
        videoStreams.push(createVideoStream(format, currentId++, presentationTimeline, networkingEngine));
      }
    }

    audioStreams.sort(function (a, b) { return b.bandwidth - a.bandwidth; });
    if (!this._config.disableVideo) {
      videoStreams.sort(function (a, b) {
        return VIDEO_CODEC_PRIORITIES.findIndex(function (codec) { return a.codecs.indexOf(codec) === 0; }) -
          VIDEO_CODEC_PRIORITIES.findIndex(function (codec) { return b.codecs.indexOf(codec) === 0; });
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