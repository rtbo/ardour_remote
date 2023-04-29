import 'dart:async';

import 'package:async/async.dart';
import 'package:flutter/material.dart';

import 'connection.dart';
import 'osc/channel.dart';
import 'osc/protocol.dart';

const feedbackStripButtons = 1;
const feedbackStripControls = 2;
const feedbackPathSSID = 4;
const feedbackHeartbeat = 8;
const feedbackMasterSection = 16;
const feedbackPlayheadBbt = 32;
const feedbackPlayheadSmpte = 64;
const feedbackMeteringFloat = 128;
const feedbackMeteringLedStrip = 256;
const feedbackSignalPresent = 512;
const feedbackPlayheadSamples = 1024;
const feedbackPlayheadTime = 2048;
const feedbackPlayheadGui = 4096;
const feedbackExtraSelectFeedback = 8192;
const feedbackLegacyReply = 16384;

class ArdourRemote with ChangeNotifier {
  final Connection connection;
  String? error;
  var connected = false;

  OscChannel? _channel;

  ArdourRemote(this.connection);

  void init() async {
    connected = false;
    error = null;

    try {
      final channel = await OscChannel.establish(connection);

      const feedback = feedbackHeartbeat |
          feedbackMasterSection |
          feedbackPlayheadBbt |
          feedbackPlayheadTime;
      channel.send(OscMessage("/set_surface/feedback", [OscInt(feedback)]));
      channel
          .send(OscMessage("/set_surface/port", [OscInt(connection.rcvPort)]));

      final receiver = StreamQueue<OscMessage>(channel.receiver);
      final fstMsg = await receiver.next.timeout(const Duration(seconds: 1));
      _dispatchMessage(fstMsg);

      receiver.rest.listen(_receiveMessage);

      _channel = channel;
      connected = true;
    } on TimeoutException {
      error = "Could not connect to Ardour";
    } on Exception catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void _receiveMessage(OscMessage msg) {}
  void _dispatchMessage(OscMessage msg) {}
}
