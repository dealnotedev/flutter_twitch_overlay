import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obssource/config/settings.dart';

typedef PauseMusicReward =
    Future<void> Function(String channel, String rewardId, bool paused);

/// The selected reward follows the request switch and Twitch event connection.
class MusicRewardController extends ChangeNotifier {
  final Settings settings;
  final PauseMusicReward pauseReward;
  final _subscriptions = <StreamSubscription<dynamic>>[];
  Future<void> _pending = Future.value();
  bool _connected;
  bool _closed = false;
  (String, String, bool)? _applied;
  String? error;

  MusicRewardController({
    required this.settings,
    required this.pauseReward,
    required bool connected,
    required Stream<bool> connectionChanges,
  }) : _connected = connected {
    _subscriptions.addAll([
      settings.musicChanges.listen((_) => unawaited(refresh())),
      settings.musicRewardIdChanges.listen((_) => unawaited(refresh())),
      settings.twitchAuthChanges.listen((_) {
        _applied = null;
        unawaited(refresh());
      }),
      connectionChanges.listen((value) {
        _connected = value;
        unawaited(refresh());
      }),
    ]);
    unawaited(refresh());
  }

  Future<void> refresh() {
    if (_closed) return Future.value();
    return _pending = _pending.then((_) => _sync());
  }

  Future<void> _sync({bool stopping = false}) async {
    if (_closed && !stopping) return;
    final channel = settings.twitchAuth?.broadcasterId;
    final reward = settings.musicRewardId;
    final previous = _applied;
    try {
      // Retire the old music reward, unless it has been assigned to TTS.
      if (previous != null &&
          previous.$1 == channel &&
          previous.$2 != reward &&
          previous.$2 != settings.tts.rewardId &&
          !previous.$3) {
        await pauseReward(previous.$1, previous.$2, true);
        _applied = null;
      }
      if (channel == null ||
          reward == null ||
          reward == settings.tts.rewardId) {
        error = null;
        return;
      }
      final target = (
        channel,
        reward,
        stopping || !settings.music.enabled || !_connected,
      );
      if (target == _applied) {
        error = null;
        return;
      }
      await pauseReward(target.$1, target.$2, target.$3);
      _applied = target;
      error = null;
    } catch (failure) {
      error = failure.toString();
    } finally {
      if (!_closed) notifyListeners();
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    );
    await _pending;
    await _sync(stopping: true);
    dispose();
  }
}
