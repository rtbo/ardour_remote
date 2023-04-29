import 'dart:convert';
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
  String get typeFlag => val ? "T" : "F";
  @override
  int get encodedSize => 0;

  @override
  void _encode(ByteWriteStream stream) {}
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
  int get asInt => val;

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
}

class OscFloat extends OscAtomic {
  final double val;

  OscFloat(this.val, [this.typeFlag = 'f']) {
    assert(typeFlag == 'f' || typeFlag == 'd');
  }

  @override
  int get encodedSize => typeFlag == "f" ? 4 : 8;

  @override
  bool get isFloat => true;

  @override
  double get asFloat => val;

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
    final chars = utf8.encode(val);
    chars.add(0);
    final alignedLength = alignUp(chars.length);
    while (chars.length != alignedLength) {
      chars.add(0);
    }
    for (final c in chars) {
      stream.writeUint8(c);
    }
  }
}

class OscBlob extends OscAtomic {
  final Uint8List val;
  OscBlob(this.val);

  @override
  String get typeFlag => "b";

  @override
  int get encodedSize => 4 + alignUp(val.lengthInBytes);

  @override
  bool get isBlob => true;

  @override
  Uint8List get asBlob => val;

  factory OscBlob._decode(ByteReadStream stream) {
    final len = stream.readUint32();
    final data = stream.readBlob(len);
    final remainToAlign = alignUp(len) - len;
    stream.moveBy(remainToAlign);
    return OscBlob(data);
  }

  @override
  void _encode(ByteWriteStream stream) {
    stream.writeUint32(val.lengthInBytes);
    stream.writeBlob(val);
    var remainToAlign = alignUp(val.lengthInBytes) - val.lengthInBytes;
    while (remainToAlign != 0) {
      stream.writeUint8(0);
      remainToAlign--;
    }
  }
}

int alignUp(int sz) {
  final rem = sz % 4;
  return rem == 0 ? sz : sz + 4 - rem;
}

class OscMessage {
  final String address;
  final List<OscAtomic> arguments;

  OscMessage(this.address, this.arguments);

  factory OscMessage.decode(Uint8List data) {
    final stream = ByteReadStream(data);
    final address = OscString._decode(stream);
    if (!address.val.startsWith("/")) {
      throw Exception("invalid OSC address: ${address.val}");
    }
    if (stream.remainingBytes == 0) {
      return OscMessage(address.val, []);
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
}
