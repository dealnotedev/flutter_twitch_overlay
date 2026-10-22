import 'dart:math' as math;

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';
import 'package:obssource/music/turntable_geometry.dart';

enum TurntablePhase {
  hidden,
  entering,
  placing,
  spinningUp,
  waiting,
  cueing,
  playing,
  lifting,
  removing,
  exiting,
}

/// A time-based choreography shared by the painter and the playback gate.
/// Download readiness never advances the needle before the record is seated
/// and the platter has reached 33 1/3 RPM.
class TurntableMotion extends ChangeNotifier {
  static const standardRpm = 100 / 3;
  static const entranceSeconds = 0.75;
  static const placementSeconds = 1.05;
  static const spinUpSeconds = 1.65;
  static const cueSeconds = 1.2;
  static const liftSeconds = 0.65;
  static const removalSeconds = 0.85;

  final void Function(String itemId) onNeedlePlaced;

  TurntablePhase phase = TurntablePhase.hidden;
  String? itemId;
  double visibility = 0;
  double recordPlacement = 0;
  double arm = 0;
  double rotation = 0;
  double rpm = 0;
  double needleLift = 1;
  double _trackProgress = 0;
  double _targetProgress = 0;
  double _incomingProgress = 0;

  String? _targetId;
  bool _ready = false;
  bool _paused = false;
  double _phaseTime = 0;
  double _liftFrom = 0;
  double _removalFrom = 0;
  double _entranceFrom = 0;

  TurntableMotion({required this.onNeedlePlaced});

  bool get recordVisible => itemId != null && phase != TurntablePhase.entering;
  double get trackProgress => _trackProgress;
  double get armAngle => arm * TurntableGeometry.trackingAngle(_trackProgress);

  void setTrackProgress(double progress) {
    // The departing record keeps its needle position until the arm lifts.
    if (phase == TurntablePhase.lifting ||
        phase == TurntablePhase.removing ||
        phase == TurntablePhase.exiting) {
      return;
    }
    _targetProgress = progress.clamp(0.0, 1.0);
  }

  void update({
    required String? itemId,
    required bool ready,
    required bool paused,
    double progress = 0,
  }) {
    _targetId = itemId;
    _ready = ready;
    _paused = paused;
    _incomingProgress = progress.clamp(0.0, 1.0);
    if (this.itemId == itemId) setTrackProgress(_incomingProgress);
    if (phase == TurntablePhase.hidden && itemId != null) {
      this.itemId = itemId;
      _trackProgress = _targetProgress = _incomingProgress;
      _enter(TurntablePhase.entering);
    } else if (this.itemId != itemId &&
        phase != TurntablePhase.hidden &&
        phase != TurntablePhase.lifting &&
        phase != TurntablePhase.removing &&
        phase != TurntablePhase.exiting) {
      _liftFrom = arm;
      _enter(TurntablePhase.lifting);
    }
    notifyListeners();
  }

  void advance(Duration delta) {
    if (delta <= Duration.zero || phase == TurntablePhase.hidden) return;
    var seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    // Small integration steps preserve phase boundaries after a slow frame.
    while (seconds > 0) {
      final step = math.min(seconds, 1 / 60);
      _advanceStep(step);
      seconds -= step;
    }
    notifyListeners();
  }

  void _advanceStep(double seconds) {
    _phaseTime += seconds;
    final previousRpm = rpm;
    if (phase == TurntablePhase.cueing || phase == TurntablePhase.playing) {
      // Follow ordinary playback continuously and glide to a seek position.
      _trackProgress +=
          (_targetProgress - _trackProgress) * (1 - math.exp(-seconds * 10));
    }
    switch (phase) {
      case TurntablePhase.hidden:
        break;
      case TurntablePhase.entering:
        visibility =
            _entranceFrom +
            (1 - _entranceFrom) * _ease(_phaseTime / entranceSeconds);
        if (_phaseTime >= entranceSeconds) _enter(TurntablePhase.placing);
        break;
      case TurntablePhase.placing:
        recordPlacement = _ease(_phaseTime / placementSeconds);
        if (_phaseTime >= placementSeconds) {
          recordPlacement = 1;
          _enter(TurntablePhase.spinningUp);
        }
        break;
      case TurntablePhase.spinningUp:
        rpm = standardRpm * _ease(_phaseTime / spinUpSeconds);
        if (_phaseTime >= spinUpSeconds) {
          rpm = standardRpm;
          _enter(TurntablePhase.waiting);
        }
        break;
      case TurntablePhase.waiting:
        if (_ready && !_paused) _enter(TurntablePhase.cueing);
        break;
      case TurntablePhase.cueing:
        if (_paused) {
          _phaseTime -= seconds;
          break;
        }
        arm = _ease(_phaseTime / (cueSeconds * 0.8));
        needleLift =
            1 - _ease((_phaseTime - cueSeconds * 0.8) / (cueSeconds * 0.2));
        if (_phaseTime >= cueSeconds) {
          arm = 1;
          needleLift = 0;
          _enter(TurntablePhase.playing);
          onNeedlePlaced(itemId!);
        }
        break;
      case TurntablePhase.playing:
        final targetRpm = _paused ? 0.0 : standardRpm;
        rpm += (targetRpm - rpm) * math.min(1, seconds * 3);
        needleLift +=
            ((_paused ? 1.0 : 0.0) - needleLift) * math.min(1, seconds * 6);
        break;
      case TurntablePhase.lifting:
        needleLift = _ease(_phaseTime / (liftSeconds * 0.3));
        arm =
            _liftFrom *
            (1 - _ease((_phaseTime - liftSeconds * 0.3) / (liftSeconds * 0.7)));
        rpm *= math.exp(-seconds * 3);
        if (_phaseTime >= liftSeconds) {
          arm = 0;
          _enter(TurntablePhase.removing);
        }
        break;
      case TurntablePhase.removing:
        recordPlacement =
            _removalFrom * (1 - _ease(_phaseTime / removalSeconds));
        rpm *= math.exp(-seconds * 4);
        if (_phaseTime >= removalSeconds) {
          final target = _targetId;
          itemId = target;
          rotation = 0;
          rpm = 0;
          recordPlacement = 0;
          _trackProgress = _targetProgress = _incomingProgress;
          _enter(
            target == null ? TurntablePhase.exiting : TurntablePhase.placing,
          );
        }
        break;
      case TurntablePhase.exiting:
        visibility = 1 - _ease(_phaseTime / entranceSeconds);
        if (_targetId != null) {
          itemId = _targetId;
          _enter(TurntablePhase.entering);
        } else if (_phaseTime >= entranceSeconds) {
          visibility = 0;
          _enter(TurntablePhase.hidden);
        }
        break;
    }
    rotation =
        (rotation + (previousRpm + rpm) / 2 / 60 * math.pi * 2 * seconds) %
        (math.pi * 2);
  }

  void _enter(TurntablePhase next) {
    if (next == TurntablePhase.removing) _removalFrom = recordPlacement;
    if (next == TurntablePhase.entering) _entranceFrom = visibility;
    phase = next;
    _phaseTime = 0;
  }

  static double _ease(double value) =>
      Curves.easeInOutCubic.transform(value.clamp(0.0, 1.0));
}
