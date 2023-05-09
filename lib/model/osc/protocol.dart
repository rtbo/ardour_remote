import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../../utils/byte_stream.dart';

abstract class OscAtomic {
  OscAtomic();

  String get typeFlag;
  int get encodedSize;

  bool get isBool => false;
  bool get isInt => false;
  bool get isFloat => false;
  bool get isString => false;
  bool get isBlob => false;

  bool? get asBool => null;
  int? get asInt => null;
  double? get asFloat => null;
  String? get asString => null;
  Uint8List? get asBlob => null;

  void _encode(ByteWriteStream stream);

  factory OscAtomic._decode(String typeFlag, ByteReadStream stream) {
    switch (typeFlag) {
      case "T":
        return OscBool(true);
      case "F":
        return OscBool(false);
      case "i":
        return OscInt(stream.readInt32(), typeFlag);
      case "h":
      case "t":
        return OscInt(stream.readInt64(), typeFlag);
      case "f":
        return OscFloat(stream.readFloat32(), typeFlag);
      case "d":
        return OscFloat(stream.readFloat64(), typeFlag);
      case "s":
      case "S":
        return OscString._decode(stream, typeFlag);
      case "b":
        return OscBlob._decode(stream);
      default:
        throw Exception("Unknown OSC type flag: $typeFlag");
    }
  }
}

class OscBool extends OscAtomic {
  final bool val;
  OscBool(this.val);

  @override
  bool get isBool => true;

  @override
  bool get asBool => val;

  @override
  int get asInt => val ? 1 : 0;

  @override
  double get asFloat => val ? 1.0 : 0.0;

  @override
  String get typeFlag => val ? "T" : "F";
  @override
  int get encodedSize => 0;

  @override
  void _encode(ByteWriteStream stream) {}

  @override
  String toString() {
    return "OscBool($val)";
  }
}

class OscInt extends OscAtomic {
  final int val;

  OscInt(this.val, [this.typeFlag = 'i']) {
    assert(typeFlag == 'i' || typeFlag == 'h' || typeFlag == 't');
  }

  @override
  int get encodedSize => typeFlag == "i" ? 4 : 8;

  @override
  bool get isInt => true;

  @override
  bool get asBool => val != 0;

  @override
  int get asInt => val;

  @override
  double get asFloat => val.toDouble();

  @override
  final String typeFlag;

  @override
  void _encode(ByteWriteStream stream) {
    if (typeFlag == 'i') {
      stream.writeInt32(val);
    } else {
      stream.writeInt64(val);
    }
  }

  @override
  String toString() {
    return "OscInt($val)";
  }
}

class OscFloat extends OscAtomic {
  final double val;

  OscFloat(this.val, [this.typeFlag = 'f']) {
    assert(typeFlag == 'f' || typeFlag == 'd');
  }

  @override
  int get encodedSize => typeFlag == "f" ? 4 : 8;

  @override
  bool get asBool => val != 0.0;

  @override
  bool get isFloat => true;

  @override
  double get asFloat => val;

  @override
  int get asInt => val.round();

  @override
  final String typeFlag;

  @override
  void _encode(ByteWriteStream stream) {
    if (typeFlag == 'f') {
      stream.writeFloat32(val);
    } else {
      stream.writeFloat64(val);
    }
  }

  @override
  String toString() {
    return "OscFloat($val)";
  }
}

class OscString extends OscAtomic {
  final String val;
  @override
  final String typeFlag;

  OscString(this.val, [this.typeFlag = 's']) {
    assert(typeFlag == 's' || typeFlag == 'S');
  }

  @override
  int get encodedSize => alignUp(val.runes.length + 1);

  @override
  bool get isString => true;

  @override
  String get asString => val;

  factory OscString._decode(ByteReadStream stream, [String flag = 's']) {
    var chars = <int>[];
    int c = stream.readUint8();
    while (c != 0) {
      chars.add(c);
      c = stream.readUint8();
    }
    final numRead = chars.length + 1;
    final totalToRead = alignUp(numRead);
    final remainToAlign = totalToRead - numRead;
    stream.moveBy(remainToAlign);

    return OscString(utf8.decode(chars), flag);
  }

  @override
  void _encode(ByteWriteStream stream) {
    const encoder = Utf8Encoder();
    final Uint8List chars = encoder.convert(val);
    var len = chars.lengthInBytes;
    final alignedLength = alignUp(len + 1);
    stream.writeBlob(chars);
    while (len != alignedLength) {
      stream.writeUint8(0);
      len++;
    }
  }

  @override
  String toString() {
    return 'OscString("$val")';
  }
}

class OscBlob extends OscAtomic {
  final TransferableTypedData _val;
  final int _valLength;

  OscBlob(Uint8List val)
      : _val = TransferableTypedData.fromList([val]),
        _valLength = val.lengthInBytes;

  @override
  String get typeFlag => "b";

  @override
  int get encodedSize => 4 + alignUp(_valLength);

  @override
  bool get isBlob => true;

  @override
  Uint8List get asBlob => _val.materialize().asUint8List();

  factory OscBlob._decode(ByteReadStream stream) {
    final len = stream.readUint32();
    final data = stream.readBlob(len);
    final remainToAlign = alignUp(len) - len;
    stream.moveBy(remainToAlign);
    return OscBlob(data);
  }

  @override
  void _encode(ByteWriteStream stream) {
    final val = _val.materialize().asUint8List();
    stream.writeUint32(_valLength);
    stream.writeBlob(val);
    var remainToAlign = alignUp(_valLength) - _valLength;
    while (remainToAlign != 0) {
      stream.writeUint8(0);
      remainToAlign--;
    }
  }

  @override
  String toString() {
    return "OscBlob([$_valLength bytes])";
  }
}

int alignUp(int sz) {
  final rem = sz % 4;
  return rem == 0 ? sz : sz + 4 - rem;
}

class OscMessage {
  final String address;
  final List<OscAtomic> arguments;

  OscMessage(this.address, [List<OscAtomic>? arguments])
      : arguments = arguments ?? [];

  factory OscMessage.decode(Uint8List data) {
    final stream = ByteReadStream(data);
    final address = OscString._decode(stream);
    if (!address.val.startsWith("/")) {
      throw Exception("invalid OSC address: ${address.val}");
    }
    if (stream.remainingBytes == 0) {
      return OscMessage(address.val);
    }

    final tagList = OscString._decode(stream);
    if (!tagList.val.startsWith(",")) {
      throw Exception("invalid OSC tag list: ${tagList.val}");
    }
    final tags = tagList.val.substring(1);
    final arguments = tags.runes.map((c) {
      final tag = String.fromCharCode(c);
      return OscAtomic._decode(tag, stream);
    }).toList(growable: false);

    return OscMessage(address.val, arguments);
  }

  Uint8List encode() {
    var size = alignUp(address.runes.length + 1); // + nul
    size += alignUp(arguments.length + 2); // + "," + nul
    var typeFlags = ",";
    for (final arg in arguments) {
      typeFlags += arg.typeFlag;
      size += arg.encodedSize;
    }
    final data = Uint8List(size);
    final stream = ByteWriteStream(data);
    OscString(address)._encode(stream);
    OscString(typeFlags)._encode(stream);
    for (final arg in arguments) {
      arg._encode(stream);
    }
    assert(stream.remainingBytes == 0);
    return data;
  }

  @override
  String toString() {
    String res = 'OscMessage("$address"';

    if (arguments.isNotEmpty) {
      res += ", [";
      arguments.asMap().forEach((index, arg) {
        res += arg.toString();
        if (index < arguments.length - 1) {
          res += ", ";
        }
      });
      res += "]";
    }
    return "$res)";
  }
}
