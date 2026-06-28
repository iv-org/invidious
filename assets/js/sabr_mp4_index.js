// Port of FreeTube's Mp4SegmentIndexParser.js
// Based on shaka-player's dash/mp4_segment_index_parser.js
// Reads shaka from window.shaka (loaded via <script>).

'use strict';

(function () {
  var shaka = window.shaka;
  var ShakaError = shaka.util.Error;
  var SeverityCritical = ShakaError.Severity.CRITICAL;
  var CategoryMedia = ShakaError.Category.MEDIA;

  function parseSIDX(sidxOffset, initSegmentReference, timestampOffset, appendWindowStart, appendWindowEnd, uri, box) {
    var references = [];

    box.reader.skip(4);

    var timescale = box.reader.readUint32();
    if (timescale === 0) {
      console.error('[parseMp4SegmentIndex] Invalid timescale.');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.MP4_SIDX_INVALID_TIMESCALE);
    }

    var earliestPresentationTime;
    var firstOffset;
    if (box.version === 0) {
      earliestPresentationTime = box.reader.readUint32();
      firstOffset = box.reader.readUint32();
    } else {
      earliestPresentationTime = box.reader.readUint64();
      firstOffset = box.reader.readUint64();
    }

    box.reader.skip(2);
    var referenceCount = box.reader.readUint16();

    var unscaledStartTime = earliestPresentationTime;
    var startByte = sidxOffset + box.size + firstOffset;

    for (var i = 0; i < referenceCount; i++) {
      var chunk = box.reader.readUint32();
      var referenceType = (chunk & 0x80000000) >>> 31;
      var referenceSize = chunk & 0x7FFFFFFF;

      var subsegmentDuration = box.reader.readUint32();
      box.reader.skip(4);

      if (referenceType === 1) {
        console.error('[parseMp4SegmentIndex] Hierarchical SIDXs are not supported.');
        throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.MP4_SIDX_TYPE_NOT_SUPPORTED);
      }

      var nativeStartTime = unscaledStartTime / timescale;
      var nativeEndTime = (unscaledStartTime + subsegmentDuration) / timescale;

      var uris = [uri + '&startTimeMs=' + Math.round((nativeStartTime + timestampOffset) * 1000) + '&sq=' + (i + 1)];

      references.push(
        new shaka.media.SegmentReference(
          nativeStartTime + timestampOffset,
          nativeEndTime + timestampOffset,
          function () { return uris; },
          startByte,
          startByte + referenceSize - 1,
          initSegmentReference,
          timestampOffset,
          appendWindowStart,
          appendWindowEnd
        )
      );

      unscaledStartTime += subsegmentDuration;
      startByte += referenceSize;
    }

    box.parser.stop();
    return references;
  }

  function parseMp4SegmentIndex(sidxData, sidxOffset, uri, initSegmentReference, timestampOffset, appendWindowStart, appendWindowEnd) {
    var references;

    var parser = new shaka.util.Mp4Parser()
      .fullBox('sidx', function (box) {
        references = parseSIDX(
          sidxOffset,
          initSegmentReference,
          timestampOffset,
          appendWindowStart,
          appendWindowEnd,
          uri,
          box
        );
      });

    if (sidxData) {
      parser.parse(sidxData);
    }

    if (references) {
      return references;
    } else {
      console.error('[parseMp4SegmentIndex] Invalid box type, expected "sidx".');
      throw new ShakaError(SeverityCritical, CategoryMedia, ShakaError.Code.MP4_SIDX_WRONG_BOX_TYPE);
    }
  }

  window.parseMp4SegmentIndex = parseMp4SegmentIndex;
})();