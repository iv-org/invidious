// Port of FreeTube's WebmSegmentIndexParser.js
// Based on shaka-player's dash/webm_segment_index_parser.js
// Reads shaka from window.shaka (loaded via <script>) and EbmlParser from window.EbmlParser.

'use strict';

(function () {
  var shaka = window.shaka;
  var ShakaError = shaka.util.Error;
  var SeverityCritical = ShakaError.Severity.CRITICAL;
  var CategoryMedia = ShakaError.Category.MEDIA;

  var EBML_ID = 0x1a45dfa3;
  var SEGMENT_ID = 0x18538067;
  var INFO_ID = 0x1549a966;
  var TIMECODE_SCALE_ID = 0x2ad7b1;
  var DURATION_ID = 0x4489;
  var CUES_ID = 0x1c53bb6b;
  var CUE_POINT_ID = 0xbb;
  var CUE_TIME_ID = 0xb3;
  var CUE_TRACK_POSITIONS_ID = 0xb7;
  var CUE_CLUSTER_POSITION = 0xf1;

  function parseInfo(infoElement) {
    var parser = infoElement.createParser();

    var timecodeScaleNanoseconds = 1000000;
    var durationScale = null;

    while (parser.hasMoreData()) {
      var elem = parser.parseElement();
      if (elem.id === TIMECODE_SCALE_ID) {
        timecodeScaleNanoseconds = elem.getUint();
      } else if (elem.id === DURATION_ID) {
        durationScale = elem.getFloat();
      }
    }
    if (durationScale == null) {
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_DURATION_ELEMENT_MISSING);
    }

    var timecodeScale = timecodeScaleNanoseconds / 1000000000;
    var durationSeconds = durationScale * timecodeScale;

    return { timecodeScale: timecodeScale, duration: durationSeconds };
  }

  function parseSegment(segmentElement) {
    var parser = segmentElement.createParser();
    var infoElement = null;
    while (parser.hasMoreData()) {
      var elem = parser.parseElement();
      if (elem.id !== INFO_ID) continue;
      infoElement = elem;
      break;
    }
    if (!infoElement) {
      console.error('[parseWebmSegmentIndex] Not an Info element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_INFO_ELEMENT_MISSING);
    }
    return parseInfo(infoElement);
  }

  function parseWebmContainer(initData) {
    var parser = new EbmlParser(initData);
    var ebmlElement = parser.parseElement();
    if (ebmlElement.id !== EBML_ID) {
      console.error('Not an EBML element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_EBML_HEADER_ELEMENT_MISSING);
    }
    var segmentElement = parser.parseElement();
    if (segmentElement.id !== SEGMENT_ID) {
      console.error('[parseWebmSegmentIndex] Not a Segment element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_SEGMENT_ELEMENT_MISSING);
    }
    var segmentOffset = segmentElement.getOffset();
    var segmentInfo = parseSegment(segmentElement);
    return {
      segmentOffset: segmentOffset,
      timecodeScale: segmentInfo.timecodeScale,
      duration: segmentInfo.duration
    };
  }

  function parseCuePoint(cuePointElement) {
    var parser = cuePointElement.createParser();
    var cueTimeElement = parser.parseElement();
    if (cueTimeElement.id !== CUE_TIME_ID) {
      console.warn('[parseWebmSegmentIndex] Not a CueTime element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_CUE_TIME_ELEMENT_MISSING);
    }
    var unscaledTime = cueTimeElement.getUint();

    var cueTrackPositionsElement = parser.parseElement();
    if (cueTrackPositionsElement.id !== CUE_TRACK_POSITIONS_ID) {
      console.warn('[parseWebmSegmentIndex] Not a CueTrackPositions element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_CUE_TRACK_POSITIONS_ELEMENT_MISSING);
    }
    var cueTrackParser = cueTrackPositionsElement.createParser();
    var relativeOffset = 0;
    while (cueTrackParser.hasMoreData()) {
      var elem = cueTrackParser.parseElement();
      if (elem.id !== CUE_CLUSTER_POSITION) continue;
      relativeOffset = elem.getUint();
      break;
    }
    return { unscaledTime: unscaledTime, relativeOffset: relativeOffset };
  }

  function parseCues(cuesElement, segmentOffset, timecodeScale, duration, uri, initSegmentReference, timestampOffset, appendWindowStart, appendWindowEnd) {
    var references = [];
    var parser = cuesElement.createParser();
    var lastTime = null;
    var lastOffset = null;
    var sq = 1;

    while (parser.hasMoreData()) {
      var elem = parser.parseElement();
      if (elem.id !== CUE_POINT_ID) continue;

      var tuple = parseCuePoint(elem);
      if (!tuple) continue;

      var currentTime = timecodeScale * tuple.unscaledTime;
      var currentOffset = segmentOffset + tuple.relativeOffset;

      if (lastTime != null) {
        // NOTE: must be `let` (block-scoped). With `var` the closure below
        // captures the function-scoped binding, so every SegmentReference would
        // return the LAST segment's URL (wrong startTimeMs/sq -> SABR serves no media).
        let uris1 = [uri + '&startTimeMs=' + Math.round((lastTime + timestampOffset) * 1000) + '&sq=' + (sq++)];
        references.push(
          new shaka.media.SegmentReference(
            lastTime + timestampOffset,
            currentTime + timestampOffset,
            function () { return uris1; },
            lastOffset,
            currentOffset - 1,
            initSegmentReference,
            timestampOffset,
            appendWindowStart,
            appendWindowEnd
          )
        );
      }

      lastTime = currentTime;
      lastOffset = currentOffset;
    }

    if (lastTime != null) {
      var uris2 = [uri + '&startTimeMs=' + Math.round((lastTime + timestampOffset) * 1000) + '&sq=' + sq];
      references.push(
        new shaka.media.SegmentReference(
          lastTime + timestampOffset,
          duration + timestampOffset,
          function () { return uris2; },
          lastOffset,
          null,
          initSegmentReference,
          timestampOffset,
          appendWindowStart,
          appendWindowEnd
        )
      );
    }

    return references;
  }

  function parseWebmSegmentIndex(cuesData, initData, uri, initSegmentReference, timestampOffset, appendWindowStart, appendWindowEnd) {
    var tuple = parseWebmContainer(initData);
    var parser = new EbmlParser(cuesData);
    var cuesElement = parser.parseElement();
    if (cuesElement.id !== CUES_ID) {
      console.error('[parseWebmSegmentIndex] Not a Cues element.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.WEBM_CUES_ELEMENT_MISSING);
    }

    return parseCues(
      cuesElement,
      tuple.segmentOffset,
      tuple.timecodeScale,
      tuple.duration,
      uri,
      initSegmentReference,
      timestampOffset,
      appendWindowStart,
      appendWindowEnd
    );
  }

  window.parseWebmSegmentIndex = parseWebmSegmentIndex;
})();