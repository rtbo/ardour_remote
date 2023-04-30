import 'dart:io';
import 'dart:isolate';

import 'package:async/async.dart';

import '../connection.dart';
import 'protocol.dart';

class OscChannel {
  static Future<OscChannel> establish(Connection connection) async {
    final address = (await InternetAddress.lookup(connection.host)).first;

    final sendIsolatePort = ReceivePort("OscChannel.send");
    await Isolate.spawn(_sendIsolate, sendIsolatePort.sendPort);
    final sendPort = await sendIsolatePort.first;
    sendPort.send(_Endpoint(address, connection.sendPort));

    final receivePort = ReceivePort("OscChannel.receive");
    final rcvIsolate = await Isolate.spawn(
        _receiveIsolate, receivePort.sendPort,
        paused: true);
    rcvIsolate.addErrorListener(receivePort.sendPort);
    rcvIsolate.resume(rcvIsolate.pauseCapability!);
    final receiveQueue = StreamQueue(receivePort);
    final SendPort receiveCommandPort = await receiveQueue.next;
    receiveCommandPort.send(_Endpoint(address, connection.rcvPort));

    return OscChannel._private(sendPort, receiveQueue.rest.cast());
  }

  void send(OscMessage msg) => _sendPort.send(msg);
  Stream<OscMessage> get receiver => _receiveStream;

  OscChannel._private(this._sendPort, this._receiveStream);

  final SendPort _sendPort;
  final Stream<OscMessage> _receiveStream;
}

class _Endpoint {
  final InternetAddress address;
  final int port;

  _Endpoint(this.address, this.port);
}

void _sendIsolate(SendPort p) async {
  final commandPort = ReceivePort();
  p.send(commandPort.sendPort);

  final commandQueue = StreamQueue(commandPort);
  final _Endpoint ep = await commandQueue.next;
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
  await for (final OscMessage msg in commandQueue.rest) {
    socket.send(msg.encode(), ep.address, ep.port);
  }
}

void _receiveIsolate(SendPort p) async {
  final rcv = ReceivePort();
  p.send(rcv.sendPort);
  final _Endpoint ep = await rcv.first;
  final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, ep.port);
  await for (final event in socket) {
    if (event == RawSocketEvent.read) {
      final d = socket.receive()!;
      p.send(OscMessage.decode(d.data));
    }
  }
}
