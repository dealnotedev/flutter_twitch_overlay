import 'dart:async';

import 'package:obssource/music/music_requests.dart';
import 'package:obssource/obs_audio.dart';

class ObsAudioMusicTrackPlayer implements MusicTrackPlayer {
  final double volume;
  final Duration completionGrace;

  int _generation = 0;
  _ActivePlayback? _active;
  bool _pauseRequested = false;
  Duration? _seekRequested;

  ObsAudioMusicTrackPlayer({
    required this.volume,
    this.completionGrace = const Duration(seconds: 2),
  });

  @override
  Future<void> play(DownloadedMusicTrack track) async {
    _pauseRequested = false;
    _seekRequested = null;
    final generation = ++_generation;
    final audioId = await ObsAudio.loadFile(track.filePath);

    if (generation != _generation) {
      await ObsAudio.release(audioId);
      return;
    }

    final sessionId = '${track.itemId}-$generation';
    final completer = Completer<void>();
    final active = _ActivePlayback(
      audioId: audioId,
      completer: completer,
      totalDuration: track.metadata.duration + completionGrace,
    );
    _active = active;

    final eventsSubscription = ObsAudio.events
        .where(
          (event) =>
              event.id == audioId &&
              (event.sessionId == null || event.sessionId == sessionId),
        )
        .listen((event) {
          switch (event.type) {
            case ObsAudioEventType.started:
            case ObsAudioEventType.progress:
              break;
            case ObsAudioEventType.ended:
              if (!completer.isCompleted) completer.complete();
              break;
            case ObsAudioEventType.error:
              if (!completer.isCompleted) {
                completer.completeError(
                  StateError(event.message ?? 'Native audio playback failed'),
                );
              }
              break;
          }
        });

    try {
      await ObsAudio.play(audioId, volume: volume, sessionId: sessionId);
      Duration? appliedSeek;
      while (true) {
        final requested = _seekRequested;
        if (requested == null || requested == appliedSeek) break;
        await ObsAudio.seek(audioId, requested);
        active.seekCountdown(requested, paused: true);
        appliedSeek = requested;
      }
      active.started = true;
      if (_pauseRequested) {
        await ObsAudio.pause(audioId);
      } else {
        active.resumeCountdown();
      }

      await completer.future;
    } finally {
      active.cancelCountdown();
      await eventsSubscription.cancel();
      if (identical(_active, active)) {
        _active = null;
        _pauseRequested = false;
        _seekRequested = null;
      }
      await ObsAudio.stop(audioId);
      await ObsAudio.release(audioId);
    }
  }

  @override
  Future<void> setPaused(bool paused) async {
    _pauseRequested = paused;
    final active = _active;
    if (active == null || !active.started) return;

    if (paused) {
      await ObsAudio.pause(active.audioId);
      if (identical(_active, active)) active.pauseCountdown();
    } else {
      await ObsAudio.resume(active.audioId);
      if (identical(_active, active)) active.resumeCountdown();
    }
  }

  @override
  Future<void> seek(Duration position) async {
    final target = position.isNegative ? Duration.zero : position;
    _seekRequested = target;
    final active = _active;
    if (active == null || !active.started) return;

    await ObsAudio.seek(active.audioId, target);
    if (identical(_active, active) && _seekRequested == target) {
      active.seekCountdown(target, paused: _pauseRequested);
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    _pauseRequested = false;
    _seekRequested = null;
    final active = _active;
    if (active == null) return;

    if (!active.completer.isCompleted) {
      active.completer.complete();
    }
    await ObsAudio.stop(active.audioId);
  }
}

class _ActivePlayback {
  final int audioId;
  final Completer<void> completer;
  final Duration totalDuration;
  Duration remaining;

  bool started = false;
  DateTime? _countdownStartedAt;
  Timer? _timer;

  _ActivePlayback({
    required this.audioId,
    required this.completer,
    required this.totalDuration,
  }) : remaining = totalDuration;

  void pauseCountdown() {
    _timer?.cancel();
    _timer = null;
    final startedAt = _countdownStartedAt;
    _countdownStartedAt = null;
    if (startedAt == null) return;

    remaining -= DateTime.now().difference(startedAt);
    if (remaining.isNegative) remaining = Duration.zero;
  }

  void resumeCountdown() {
    if (completer.isCompleted || _timer != null) return;
    if (remaining <= Duration.zero) {
      completer.complete();
      return;
    }

    _countdownStartedAt = DateTime.now();
    _timer = Timer(remaining, () {
      _timer = null;
      _countdownStartedAt = null;
      if (!completer.isCompleted) completer.complete();
    });
  }

  void seekCountdown(Duration position, {required bool paused}) {
    cancelCountdown();
    remaining = totalDuration - position;
    if (remaining.isNegative) remaining = Duration.zero;
    if (!paused) resumeCountdown();
  }

  void cancelCountdown() {
    _timer?.cancel();
    _timer = null;
    _countdownStartedAt = null;
  }
}
