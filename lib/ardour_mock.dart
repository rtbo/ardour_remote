import 'dart:async';

import 'package:flutter/material.dart';

import 'model/ardour_remote.dart';

const _timerPeriodMs = 200;

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
    playing = false;
    stopped = true;
    speed = 0.0;
    recordArmed = false;
    connected = true;
    _hbTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      heartbeat = !heartbeat;
      notifyListeners();
    });

    notifyListeners();
  }

  @override
  void disconnect() {
    _disableTimer();
    _playheadMs = 0;
    _computeBbtTimecode();
    sessionName = "";
    playing = false;
    stopped = false;
    speed = 0.0;
    recordArmed = false;
    connected = false;
    _hbTimer?.cancel();

    notifyListeners();
  }

  @override
  void play() {
    speed = 1.0;
    _lastPlayheadMs = _playheadMs;
    _enableTimer();
    notifyListeners();
  }

  @override
  void stop() {
    speed = 0.0;
    _disableTimer();
    notifyListeners();
  }

  @override
  void stopAndTrash() {
    speed = 0.0;
    _disableTimer();
    _playheadMs = _lastPlayheadMs;
    _computeBbtTimecode();
    notifyListeners();
  }

  @override
  void recordArmToggle() {
    recordArmed = !recordArmed;
    notifyListeners();
  }

  @override
  void toStart() => _gotoMs(0);

  @override
  void toEnd() => _gotoMs(120000);

  @override
  void jumpBars(int bars) {
    _gotoMs((_bar + bars - 1) * 2000);
  }

  void _gotoMs(double ms) {
    _playheadMs = ms;
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
    _playheadMs += speed * _timerPeriodMs;
    _computeBbtTimecode();
    notifyListeners();
  }

  void _computeBbtTimecode() {
    // a bar at 120 bpm is 2 seconds
    // a beat is 0.5 seconds
    // Ardour defines 1920 ticks per beat
    final bar = _bar;
    final beatF = 1 + _playheadMs / 500 - (bar - 1) * 4;
    final beat = beatF.floor();
    final ticks = ((beatF - beat) * 1920).floor();
    final barTxt = _bar.toString().padLeft(3, "0");
    final beatTxt = beat.toString().padLeft(2, "0");
    final ticksTxt = ticks.toString().padLeft(4, "0");
    bbt = "$barTxt|$beatTxt|$ticksTxt";

    // 25 fps
    final minutes = (_playheadMs / 60000).floor();
    final seconds = (_playheadMs / 1000).floor() - minutes * 60;
    final frames = (_playheadMs / 40).floor() - minutes * 60 - seconds * 25;
    final minutesTxt = minutes.toString().padLeft(2, "0");
    final secondsTxt = seconds.toString().padLeft(2, "0");
    final framesTxt = frames.toString().padLeft(2, "0");
    timecode = "00:$minutesTxt:$secondsTxt:$framesTxt";
  }

  int get _bar => 1 + (_playheadMs / 2000).floor();
}
