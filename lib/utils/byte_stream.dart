import 'dart:typed_data';

class ByteReadStream {
  final ByteData _byteData;
  int _byteOffset;
  final Endian _endian;

  ByteReadStream(this._byteData, {int offset = 0, Endian endian = Endian.big})
      : _byteOffset = offset,
        _endian = endian;

  /// Length of the underlying ByteData
  int get lengthInBytes => _byteData.lengthInBytes;

  /// Remaining bytes in the stream (after [byteOffset])
  int get remainingBytes => lengthInBytes - _byteOffset;

  /// Current read offset in the underlying ByteData
  int get byteOffset => _byteOffset;

  set byteOffset(int val) {
    if (val < 0 || val > lengthInBytes) {
      throw RangeError("Attempt to read out of the data range");
    }
    _byteOffset = val;
  }

  /// Move the reading head by [bytes].
  /// [bytes] can be negative to move backwards.
  void moveBy(int bytes) {
    byteOffset = _byteOffset + bytes;
  }

  int readInt8() {
    final val = _byteData.getInt8(_byteOffset);
    moveBy(1);
    return val;
  }

  int readUint8() {
    final val = _byteData.getUint8(_byteOffset);
    moveBy(1);
    return val;
  }

  int readInt32() {
    final val = _byteData.getInt32(_byteOffset, _endian);
    moveBy(4);
    return val;
  }

  int readUint32() {
    final val = _byteData.getUint32(_byteOffset, _endian);
    moveBy(4);
    return val;
  }

  int readInt64() {
    final val = _byteData.getInt64(_byteOffset, _endian);
    moveBy(8);
    return val;
  }

  int readUint64() {
    final val = _byteData.getUint64(_byteOffset, _endian);
    moveBy(8);
    return val;
  }

  double readFloat32() {
    final val = _byteData.getFloat32(_byteOffset, _endian);
    moveBy(4);
    return val;
  }

  double readFloat64() {
    final val = _byteData.getFloat64(_byteOffset, _endian);
    moveBy(8);
    return val;
  }

  /// Returned data is in the same buffer as [this].
  Uint8List readBlob([int length = -1]) {
    if (length < 0) {
      length = remainingBytes;
    }

    final res = _byteData.buffer
        .asUint8List(_byteData.offsetInBytes + _byteOffset, length);
    moveBy(length);
    return res;
  }

  Uint8List readBlobCopy([int length = -1]) =>
      Uint8List.fromList(readBlob(length));
}
