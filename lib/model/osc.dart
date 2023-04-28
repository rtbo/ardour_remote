import 'dart:convert';
import 'dart:typed_data';

import 'package:ardour_remote/utils/byte_stream.dart';

abstract class OscAtomic {
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

  OscAtomic();

  factory OscAtomic.decode(String typeFlag, ByteReadStream stream) {
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
}

class OscInt extends OscAtomic {
  final int val;
  final String flag;
  OscInt(this.val, [this.flag = 'i']) {
    assert(flag == 'i' || flag == 'h' || flag == 't');
  }

  @override
  bool get isInt => true;

  @override
  int get asInt => val;
}

class OscFloat extends OscAtomic {
  final double val;
  final String flag;
  OscFloat(this.val, [this.flag = 'f']) {
    assert(flag == 'f' || flag == 'd');
  }

  @override
  bool get isFloat => true;

  @override
  double get asFloat => val;
}

class OscString extends OscAtomic {
  final String val;
  final String flag;
  OscString(this.val, [this.flag = 's']) {
    assert(flag == 's' || flag == 'S');
  }

  @override
  bool get isString => true;

  @override
  String get asString => val;

  factory OscString._decode(ByteReadStream stream, String flag) {
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
}

class OscBlob extends OscAtomic {
  final Uint8List val;
  OscBlob(this.val);

  @override
  bool get isBlob => true;

  @override
  Uint8List get asBlob => val;

  factory OscBlob._decode(ByteReadStream stream) {
    final len = stream.readUint32();
    return OscBlob(stream.readBlob(len));
  }
}

int alignUp(int sz) {
  final rem = sz % 4;
  return rem == 0 ? sz : sz + 4 - rem;
}
