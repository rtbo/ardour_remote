import 'dart:async';
import 'dart:developer';
import 'dart:io';

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

const connectionTimeout = Duration(seconds: 3);

class ArdourRemote with ChangeNotifier {
  final Connection connection;
  String? error;
  var connected = false;
  var sessionName = '';
  var heartbeat = false;
  var bbt = "";
  var timecode = "";
  var playing = false;
  var stopped = false;
  var speed = 0.0;
  var recordArmed = false;

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
      final fstMsg = await receiver.next.timeout(connectionTimeout);
      _dispatchMessage(fstMsg);

      receiver.rest.listen(_onReceiveMessage);

      _channel = channel;
      connected = true;
    } on TimeoutException {
      error = "Connection timeout";
    } on Exception catch (e) {
      error = e.toString();
    } finally {
      notifyListeners();
    }
  }

  void play() => _sendMsg(OscMessage("/transport/play"));

  void stop() => _sendMsg(OscMessage("/transport/stop"));

  void stopAndTrash() => _sendMsg(OscMessage("/stop_forget"));

  void recordArmToggle() => _sendMsg(OscMessage("/rec_enable_toggle"));

  void toStart() => _sendMsg(OscMessage("/goto_start"));

  void toEnd() => _sendMsg(OscMessage("/goto_end"));

  void jumpBars(int bars) => _sendMsg(OscMessage("/jump_bars", [OscInt(bars)]));

  void _sendMsg(OscMessage msg) => _channel!.send(msg);

  void _onReceiveMessage(OscMessage msg) {
    _dispatchMessage(msg);
    notifyListeners();
  }

  void _dispatchMessage(OscMessage msg) {
    log("received message $msg");

    switch (msg.address) {
      case "/heartbeat":
        heartbeat = msg.arguments.first.asFloat! > 0.5;
        break;
      case "/position/bbt":
        bbt = msg.arguments.first.asString!;
        break;
      case "/position/time":
        timecode = msg.arguments.first.asString!;
        break;
      case "/transport/play":
        playing = msg.arguments.first.asInt! != 0;
        break;
      case "/transport/stop":
        stopped = msg.arguments.first.asInt! != 0;
        break;
      case "/transport/speed":
        speed = msg.arguments.first.asFloat!;
        stopped = (speed == 0.0);
        playing = (speed == 1.0);
        break;
      case "/rec_enable_toggle":
        if (msg.arguments.isNotEmpty) {
          recordArmed = msg.arguments.first.asInt! != 0;
        } else {
          recordArmed = !recordArmed;
        }
        break;
      case "/session_name":
        sessionName = msg.arguments.first.asString!;
        break;
      default:
        break;
    }
  }
}
