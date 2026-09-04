import 'dart:async';

import 'package:obssource/music/music_requests.dart';
import 'package:obssource/obs_audio.dart';

class ObsAudioMusicTrackPlayer implements MusicTrackPlayer {
  final Duration completionGrace;
  final Duration nativeEventTimeout;

  double _volume;

  int _generation = 0;
  _ActivePlayback? _active;
  bool _pauseRequested = false;
  Duration? _seekRequested;

  ObsAudioMusicTrackPlayer({
    required double volume,
    this.completionGrace = const Duration(seconds: 2),
    this.nativeEventTimeout = const Duration(seconds: 10),
  }) : _volume = _normalizeVolume(volume);

  double get volume => _volume;

  @override
  Future<void> play(DownloadedMusicTrack track) async {
    _pauseRequested = false;
    _seekRequested = null;
    final generation = ++_generation;
    final sessionId = '${track.itemId}-$generation';
    final audioId = await ObsAudio.loadFile(
      track.filePath,
      sessionId: sessionId,
    );

    if (generation != _generation) {
      await ObsAudio.release(audioId);
      return;
    }

    final completer = Completer<void>();
    final startedCompleter = Completer<void>();
    final active = _ActivePlayback(
      audioId: audioId,
      completer: completer,
      startedCompleter: startedCompleter,
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
            case ObsAudioEventType.loaded:
            case ObsAudioEventType.progress:
              break;
            case ObsAudioEventType.started:
              if (!startedCompleter.isCompleted) startedCompleter.complete();
              break;
            case ObsAudioEventType.ended:
              if (!completer.isCompleted) completer.complete();
              break;
            case ObsAudioEventType.error:
              final error = StateError(
                event.message ?? 'Native audio playback failed',
              );
              if (!startedCompleter.isCompleted) {
                startedCompleter.completeError(error);
              } else if (!completer.isCompleted) {
                completer.completeError(error);
              }
              break;
          }
        });

    try {
      final startedVolume = _volume;
      final eventsSupported = await ObsAudio.play(
        audioId,
        volume: startedVolume,
        sessionId: sessionId,
      );
      if (eventsSupported) {
        await startedCompleter.future.timeout(
          nativeEventTimeout,
          onTimeout:
              () =>
                  throw StateError('Native audio start confirmation timed out'),
        );
      }
      if (generation != _generation) return;
      active.started = true;

      var appliedVolume = startedVolume;
      while (_volume != appliedVolume) {
        final requestedVolume = _volume;
        await ObsAudio.setVolume(audioId, requestedVolume);
        appliedVolume = requestedVolume;
      }

      Duration? appliedSeek;
      while (true) {
        final requested = _seekRequested;
        if (requested == null || requested == appliedSeek) break;
        await ObsAudio.seek(audioId, requested);
        active.seekCountdown(requested, paused: true);
        appliedSeek = requested;
      }
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

  Future<void> setVolume(double volume) async {
    final normalized = _normalizeVolume(volume);
    if (_volume == normalized) return;

    _volume = normalized;
    final active = _active;
    if (active == null || !active.started) return;

    await ObsAudio.setVolume(active.audioId, normalized);
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

    if (!active.startedCompleter.isCompleted) {
      active.startedCompleter.complete();
    }
    if (!active.completer.isCompleted) {
      active.completer.complete();
    }
    await ObsAudio.stop(active.audioId);
  }

  static double _normalizeVolume(double volume) {
    if (!volume.isFinite) return 1;
    return volume.clamp(0.0, 1.0).toDouble();
  }
}

class _ActivePlayback {
  final int audioId;
  final Completer<void> completer;
  final Completer<void> startedCompleter;
  final Duration totalDuration;
  Duration remaining;

  bool started = false;
  DateTime? _countdownStartedAt;
  Timer? _timer;

  _ActivePlayback({
    required this.audioId,
    required this.completer,
    required this.startedCompleter,
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
