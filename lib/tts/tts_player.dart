import 'dart:async';

import 'package:dio/dio.dart';
import 'package:obssource/obs_audio.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';

abstract interface class TtsPlayback {
  Future<void> prepare();
  Future<void> setVolume(double volume);
  Future<void> play(TtsAudio audio, CancelToken cancel);
  Future<void> close();
}

class ObsTtsPlayback implements TtsPlayback {
  static const notificationAsset = 'assets/tts_notification.wav';
  final Future<void> Function(bool active)? duckMusic;
  int? _notification;
  int? _speech;
  double _volume = 1;
  bool _closed = false;

  ObsTtsPlayback({this.duckMusic});

  @override
  Future<void> setVolume(double volume) async {
    _volume = volume.clamp(0.0, TtsSettings.maxVolumePercent / 100);
    final id = _speech;
    if (!_closed && id != null) await ObsAudio.setVolume(id, _volume);
  }

  @override
  Future<void> prepare() async {
    if (_closed) throw const TtsFailure(TtsIssue.audioUnavailable);
    if (_notification != null) return;
    _notification = await ObsAudio.loadAsset(
      notificationAsset,
      sessionId: 'tts-notification',
      requireEvents: true,
    );
  }

  @override
  Future<void> play(TtsAudio audio, CancelToken cancel) async {
    await prepare();
    checkTtsCancellation(cancel);
    try {
      await duckMusic?.call(true);
      await _playSlot(
        _notification!,
        'tts-notification',
        const Duration(seconds: 30),
        cancel,
      );
      await _orCanceled(
        Future<void>.delayed(const Duration(seconds: 1)),
        cancel,
      );
      checkTtsCancellation(cancel);
      final session = newTtsRequestKey();
      final id = await ObsAudio.loadFile(audio.file.path, sessionId: session);
      _speech = id;
      try {
        checkTtsCancellation(cancel);
        await _playSlot(
          id,
          session,
          audio.duration + const Duration(seconds: 10),
          cancel,
          volume: _volume,
        );
      } finally {
        _speech = null;
        await ObsAudio.release(id);
      }
    } finally {
      await duckMusic?.call(false);
    }
  }

  Future<void> _playSlot(
    int id,
    String session,
    Duration timeout,
    CancelToken cancel, {
    double volume = 1,
  }) async {
    checkTtsCancellation(cancel);
    final ended = Completer<void>();
    final subscription = ObsAudio.events
        .where(
          (e) => e.id == id && (e.sessionId == null || e.sessionId == session),
        )
        .listen((event) {
          if (ended.isCompleted) return;
          if (event.type == ObsAudioEventType.ended) ended.complete();
          if (event.type == ObsAudioEventType.error) {
            ended.completeError(const TtsFailure(TtsIssue.audioUnavailable));
          }
        });
    // Attach the error listener before sending a native command.
    final completion = _orCanceled(ended.future, cancel).timeout(timeout);
    unawaited(completion.catchError((Object _) {}));
    try {
      if (!await ObsAudio.play(id, sessionId: session, volume: volume)) {
        throw const TtsFailure(TtsIssue.audioUnavailable);
      }
      await completion;
    } finally {
      if (!ended.isCompleted) ended.complete();
      await subscription.cancel();
      await ObsAudio.stop(id);
    }
  }

  Future<void> _orCanceled(Future<void> future, CancelToken token) =>
      Future.any([
        future,
        token.whenCancel.then<void>((_) {
          throw const TtsFailure(TtsIssue.canceled);
        }),
      ]);

  @override
  Future<void> close() async {
    _closed = true;
    final id = _notification;
    _notification = null;
    if (id != null) await ObsAudio.release(id);
  }
}
