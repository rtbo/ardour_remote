import 'dart:async';

import 'package:flutter/foundation.dart';

import 'ardour_remote.dart';

const _timerPeriodMs = 200;
const _mockTempo = 120.0;
const _mockDuration = 120.0;
const _mockSig = 4; // beats per bar

/// An Ardour session mock (2 min, 120 bpm , 4/4)
class ArdourRemoteMock extends ArdourRemote {
  ArdourRemoteMock(super.connection);

  var _playheadMs = 0.0;
  var _lastPlayheadMs = 0.0;
  Timer? _timer;
  Timer? _hbTimer;

  @override
  Future connect() async {
    await Future.delayed(const Duration(seconds: 2));

    _playheadMs = 0;
    _computeBbtTimecode();
    sessionName = "Mock session";
    connected = true;
    transport.updateWith(
        playing: false, stopped: true, speed: 0, recordArmed: false);
    _hbTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      heartbeat = !heartbeat;
      notifyListeners();
    });

    notifyListeners();
  }

  @override
  Future disconnect() async {
    print("mock.disconnect");
    _disableTimer();
    _playheadMs = 0;
    _computeBbtTimecode();
    sessionName = "";
    connected = false;
    transport.updateWith(
        playing: false, stopped: false, speed: 0, recordArmed: false);
    _hbTimer?.cancel();

    notifyListeners();
  }

  @override
  void play() {
    transport.speed = 1.0;
    _lastPlayheadMs = _playheadMs;
    _enableTimer();
    notifyListeners();
  }

  @override
  void stop() {
    transport.speed = 0;
    _disableTimer();
    notifyListeners();
  }

  @override
  void stopAndTrash() {
    transport.speed = 0;
    _disableTimer();
    _playheadMs = _lastPlayheadMs;
    _computeBbtTimecode();
    notifyListeners();
  }

  @override
  void recordArmToggle() {
    transport.toggleRecord();
    notifyListeners();
  }

  @override
  void toStart() => _gotoMs(0);

  @override
  void toEnd() => _gotoMs(_mockDuration * 1000);

  // bars and beat are counted zero based
  // (although displayed 1 based)

  @override
  void jumpBars(int bars) {
    if (bars == 0) return;

    var b = _bar;

    final opp = bars > 0 ? -1 : 1;
    final whole = bars > 0 ? b.ceilToDouble() : b.roundToDouble();

    if (b != whole) {
      bars += opp;
    }

    _gotoMs((whole + bars) * _barMs);
  }

  @override
  void ffwd() {
    var spd = transport.speed;
    spd = 1.5;
    if (spd > 8) {
      spd = 8;
    }
    transport.speed = spd;
    _enableTimer();
  }

  @override
  void rewind() {
    var spd = transport.speed;
    spd -= 1.5;
    if (spd < -8) {
      spd = -8;
    }
    transport.speed = spd;
    _enableTimer();
  }

  @override
  void jumpTime(double time) {
    _gotoMs(_playheadMs + time * 1000);
  }

  void _gotoMs(double ms) {
    _playheadMs = clampDouble(ms, 0, 120000);
    _computeBbtTimecode();
    notifyListeners();
  }

  void _enableTimer() {
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(milliseconds: _timerPeriodMs),
        (timer) => _updatePlayhead());
  }

  void _disableTimer() {
    _timer?.cancel();
    _timer = null;
  }

  void _updatePlayhead() {
    _playheadMs += transport.speed * _timerPeriodMs;
    _computeBbtTimecode();
    notifyListeners();
  }

  void _computeBbtTimecode() {
    // Ardour defines 1920 ticks per beat
    final bar = _bar;
    final barI = bar.floor();
    final beat = _beat - barI * _mockSig;
    final beatI = beat.floor();
    final ticks = ((beat - beatI) * 1920).floor();
    final barTxt = (barI + 1).toString().padLeft(3, "0");
    final beatTxt = (beatI + 1).toString().padLeft(2, "0");
    final ticksTxt = ticks.toString().padLeft(4, "0");
    transport.bbt = "$barTxt|$beatTxt|$ticksTxt";

    // 25 fps
    final minutes = (_playheadMs / 60000).floor();
    final seconds = (_playheadMs / 1000).floor() - minutes * 60;
    final frames =
        (_playheadMs / 40).floor() - minutes * 60 * 25 - seconds * 25;
    final minutesTxt = minutes.toString().padLeft(2, "0");
    final secondsTxt = seconds.toString().padLeft(2, "0");
    final framesTxt = frames.toString().padLeft(2, "0");
    transport.timecode = "00:$minutesTxt:$secondsTxt:$framesTxt";
  }

  double get _bar => _playheadMs / _barMs;
  double get _beat => _playheadMs / _beatMs;
  double get _barMs => _mockSig * _beatMs;
  double get _beatMs => 60000 / _mockTempo;
}
