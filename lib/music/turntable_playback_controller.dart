import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obssource/music/music_requests.dart';

/// The audio host announces readiness; the visible turntable cues the needle.
/// Without a mounted presentation audio can start immediately.
class TurntablePlaybackController extends ChangeNotifier {
  int _presentations = 0;
  String? _readyItemId;
  Completer<void>? _cue;
  bool _disposed = false;

  String? get readyItemId => _readyItemId;

  void attach() => _presentations++;

  void detach() {
    assert(_presentations > 0);
    _presentations--;
    if (_presentations == 0) _finishCue();
  }

  Future<void> beforeStart(
    DownloadedMusicTrack track,
    Future<void> interrupted,
  ) async {
    if (_presentations == 0) return;
    _finishCue();
    final cue = Completer<void>();
    _cue = cue;
    _readyItemId = track.itemId;
    notifyListeners();
    try {
      await Future.any([cue.future, interrupted]);
    } finally {
      if (identical(_cue, cue)) {
        _cue = null;
        _readyItemId = null;
        if (!_disposed) notifyListeners();
      }
    }
  }

  void needlePlaced(String itemId) {
    if (_readyItemId == itemId) _finishCue();
  }

  void _finishCue() {
    final cue = _cue;
    if (cue != null && !cue.isCompleted) cue.complete();
  }

  @override
  void dispose() {
    _disposed = true;
    _finishCue();
    super.dispose();
  }
}
