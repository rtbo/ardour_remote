import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';
import 'package:flutter/foundation.dart';

import '../connection.dart';
import 'protocol.dart';

class OscChannel {
  static Future<OscChannel> establish(Connection connection) async {
    final address = (await InternetAddress.lookup(connection.host)).first;

    final sendIsolatePort = ReceivePort("OscChannel.send");
    await Isolate.spawn(_messageSender, sendIsolatePort.sendPort);
    final sendPort = await sendIsolatePort.first;
    sendPort.send(_Endpoint(address, connection.sendPort));

    final receivePort = ReceivePort("OscChannel.receive");
    final rcvIsolate = await Isolate.spawn(
        _messageReceiver, receivePort.sendPort,
        paused: true);
    rcvIsolate.addErrorListener(receivePort.sendPort);
    rcvIsolate.resume(rcvIsolate.pauseCapability!);
    final receiveQueue = StreamQueue(receivePort);
    final SendPort receiveCommandPort = await receiveQueue.next;
    receiveCommandPort.send(_Endpoint(address, connection.rcvPort));

    return OscChannel._private(
        connection, address, sendPort, receiveQueue.rest.cast());
  }

  void send(OscMessage msg) => _sendPort.send(ChannelMsg.msg(msg));
  Stream<ChannelMsg> get receiver => _receiveStream;

  Future close() async {
    // closing sender
    _sendPort.send(ChannelMsg.close());
    // closing receiver
    final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
    socket.send(_closeAscii, _address, connection.rcvPort);
    socket.close();
  }

  OscChannel._private(
      this.connection, this._address, this._sendPort, this._receiveStream);

  final Connection connection;
  final InternetAddress _address;

  final SendPort _sendPort;
  final Stream<ChannelMsg> _receiveStream;
}

class _Endpoint {
  final InternetAddress address;
  final int port;

  _Endpoint(this.address, this.port);
}

class ChannelMsg {
  ChannelMsg.msg(OscMessage this.msg);
  ChannelMsg.close() : msg = null;

  final OscMessage? msg;
  bool get close => msg == null;
}

void _messageSender(SendPort p) async {
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  final commandQueue = StreamQueue(commandPort);
  final _Endpoint ep = await commandQueue.next;
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  await for (final ChannelMsg msg in commandQueue.rest) {
    final m = msg.msg;
    if (m != null) {
      socket.send(m.encode(), ep.address, ep.port);
    } else if (msg.close) {
      return;
    }
  }
}

const _closeAscii = [95, 99, 108, 111, 115, 101];

void _messageReceiver(SendPort p) async {
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  final commandQueue = StreamQueue(commandPort);
  final _Endpoint ep = await commandQueue.next;
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, ep.port);
  await for (final event in socket) {
    if (event == RawSocketEvent.read) {
      final d = socket.receive()!;
      if (listEquals(d.data, _closeAscii)) {
        break;
      } else {
        p.send(ChannelMsg.msg(OscMessage.decode(d.data)));
      }
    } else if (event == RawSocketEvent.closed) {
      p.send(ChannelMsg.close());
    }
  }
  socket.close();
}
