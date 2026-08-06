// Port of FreeTube's EbmlParser.js
// Based on shaka-player's dash/ebml_parser.js
// Reads shaka from window.shaka (loaded via <script>).

'use strict';

(function () {
  var shaka = window.shaka;
  var ShakaError = shaka.util.Error;
  var BufferUtils = shaka.util.BufferUtils;

  var DYNAMIC_SIZES = [
    [0xff],
    [0x7f, 0xff],
    [0x3f, 0xff, 0xff],
    [0x1f, 0xff, 0xff, 0xff],
    [0x0f, 0xff, 0xff, 0xff, 0xff],
    [0x07, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
    [0x03, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff],
    [0x01, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff, 0xff]
  ];

  function getVintValue(vint) {
    if ((vint.length === 8) && (vint[1] & 0xe0)) {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.JS_INTEGER_OVERFLOW
      );
    }

    var value = 0;
    for (var i = 0; i < vint.length; i++) {
      var item = vint[i];
      if (i === 0) {
        var mask = 0x1 << (8 - vint.length);
        value = item & (mask - 1);
      } else {
        value = (256 * value) + item;
      }
    }

    return value;
  }

  function isDynamicSizeValue(vint) {
    for (var i = 0; i < DYNAMIC_SIZES.length; i++) {
      if (BufferUtils.equal(vint, new Uint8Array(DYNAMIC_SIZES[i]))) {
        return true;
      }
    }
    return false;
  }

  function EbmlElement(id, dataView) {
    this.id = id;
    this._dataView = dataView;
  }
  EbmlElement.prototype.getOffset = function () {
    return this._dataView.byteOffset;
  };
  EbmlElement.prototype.createParser = function () {
    return new EbmlParser(this._dataView);
  };
  EbmlElement.prototype.getUint = function () {
    if (this._dataView.byteLength > 8) {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.EBML_OVERFLOW
      );
    }
    if ((this._dataView.byteLength === 8) && (this._dataView.getUint8(0) & 0xe0)) {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.JS_INTEGER_OVERFLOW
      );
    }
    var value = 0;
    for (var i = 0; i < this._dataView.byteLength; i++) {
      value = (256 * value) + this._dataView.getUint8(i);
    }
    return value;
  };
  EbmlElement.prototype.getFloat = function () {
    if (this._dataView.byteLength === 4) {
      return this._dataView.getFloat32(0);
    } else if (this._dataView.byteLength === 8) {
      return this._dataView.getFloat64(0);
    } else {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.EBML_BAD_FLOATING_POINT_SIZE
      );
    }
  };

  function EbmlParser(data) {
    this._dataView = BufferUtils.toDataView(data);
    this._reader = new shaka.util.DataViewReader(this._dataView, shaka.util.DataViewReader.Endianness.BIG_ENDIAN);
  }
  EbmlParser.prototype.hasMoreData = function () {
    return this._reader.hasMoreData();
  };
  EbmlParser.prototype.parseElement = function () {
    var id = this._parseId();
    var vint = this._parseVint();
    var size;
    if (isDynamicSizeValue(vint)) {
      size = this._dataView.byteLength - this._reader.getPosition();
    } else {
      size = getVintValue(vint);
    }

    var elementSize =
      this._reader.getPosition() + size <= this._dataView.byteLength
        ? size
        : this._dataView.byteLength - this._reader.getPosition();

    var dataView = BufferUtils.toDataView(this._dataView, this._reader.getPosition(), elementSize);
    this._reader.skip(elementSize);

    return new EbmlElement(id, dataView);
  };
  EbmlParser.prototype._parseId = function () {
    var vint = this._parseVint();
    if (vint.length > 7) {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.EBML_OVERFLOW
      );
    }
    var id = 0;
    for (var i = 0; i < vint.length; i++) {
      id = (256 * id) + vint[i];
    }
    return id;
  };
  EbmlParser.prototype._parseVint = function () {
    var position = this._reader.getPosition();
    var firstByte = this._reader.readUint8();
    if (firstByte === 0) {
      throw new ShakaError(
        ShakaError.Severity.CRITICAL,
        ShakaError.Category.MEDIA,
        ShakaError.Code.EBML_OVERFLOW
      );
    }
    var index = Math.floor(Math.log2(firstByte));
    var numBytes = 8 - index;
    this._reader.skip(numBytes - 1);
    return BufferUtils.toUint8(this._dataView, position, numBytes);
  };

  window.EbmlParser = EbmlParser;
})();