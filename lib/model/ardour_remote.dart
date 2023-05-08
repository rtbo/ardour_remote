import 'dart:async';
import 'dart:developer';

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
  var tempo = 120.0;
  var speed = 0.0;
  var recordArmed = false;

  ArdourRemote(this.connection);

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }

  Future connect() async {}
  Future disconnect() async {}

  void play() {}
  void stop() {}
  void stopAndTrash() {}
  void recordArmToggle() {}
  void toStart() {}
  void toEnd() {}
  void jumpBars(int bars) {}
  void jumpTime(double time) {}
  void rewind() {}
  void ffwd() {}
}

class ArdourRemoteImpl extends ArdourRemote {
  OscChannel? _channel;

  ArdourRemoteImpl(super.connection);

  @override
  Future connect() async {
    connected = false;
    error = null;

    try {
      final channel = await OscChannel.establish(connection);

      const feedback = feedbackStripButtons |
          feedbackStripControls |
          feedbackHeartbeat |
          feedbackMasterSection |
          feedbackPlayheadBbt |
          feedbackPlayheadTime;
      channel.send(OscMessage("/set_surface/feedback", [OscInt(feedback)]));
      channel
          .send(OscMessage("/set_surface/port", [OscInt(connection.rcvPort)]));

      final receiver = StreamQueue<ChannelMsg>(channel.receiver);
      final fstMsg = await receiver.next.timeout(connectionTimeout);
      if (fstMsg.close) {
        throw Exception("Channel closed");
      }
      _dispatchMessage(fstMsg.msg!);

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

  @override
  Future disconnect() async {
    await _channel?.close();
  }

  @override
  void play() => _sendMsg(OscMessage("/transport_play"));

  @override
  void stop() => _sendMsg(OscMessage("/transport_stop"));

  @override
  void stopAndTrash() => _sendMsg(OscMessage("/stop_forget"));

  @override
  void recordArmToggle() => _sendMsg(OscMessage("/rec_enable_toggle"));

  @override
  void toStart() => _sendMsg(OscMessage("/goto_start"));

  @override
  void toEnd() => _sendMsg(OscMessage("/goto_end"));

  @override
  void jumpBars(int bars) =>
      _sendMsg(OscMessage("/jump_bars", [OscFloat(bars.toDouble())]));

  @override
  void ffwd() {
    _sendMsg(OscMessage("/ffwd"));
  }

  @override
  void rewind() {
    _sendMsg(OscMessage("/ffwd"));
  }

  void _sendMsg(OscMessage msg) => _channel!.send(msg);

  void _onReceiveMessage(ChannelMsg msg) {
    if (msg.close) {
      connected = false;
      error = "Ardour closed the connection";
      _channel = null;
    } else {
      _dispatchMessage(msg.msg!);
    }
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
      case "/transport_play":
        playing = msg.arguments.first.asInt! != 0;
        break;
      case "/transport_stop":
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
      case "/jog/mode/name":
        // Because of UDP nature, socket will not close when ardour exits.
        // However Ardour will send this invalid jog mode name when quitting.
        final name = msg.arguments.first.asString!;
        if (name == " ") {
          error = "Ardour closed the connection";
          connected = false;
        }
        break;
      default:
        break;
    }
  }
}

// master data
// - name
// - mute
// - trimdB
// - pan_stereo_position (0: right, 0.5: middle, 1: left)
// - gain

// monitor data
// - name
// - mute
// - dim
// - mono
// - gain

// per strip data
// - select
// - name
// - group
// - hide
// - mute[/automation|/automation_name]
// - solo[iso|safe]
// - monitor[_input|_disk]
// - recenable
// - gain[/automation|/automation_name]
// - trimdB[/automation|/automation_name]
// - pan_type
// - pan_stereo_position[/automation|/automation_name] (0: right, 0.5: middle, 1: left)
// - pan_stereo_width[/automation|/automation_name]
// - expand

