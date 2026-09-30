import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_player.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/ws_event.dart';

/// One owner per overlay: duplicates are keyed by broadcaster + redemption.
/// Request state lives only in memory. Failed Twitch updates are left to moderation.
class TtsController extends ChangeNotifier {
  static const healthInterval = Duration(minutes: 1);
  static const maxTextLength = 1024;
  static const maxQueueLength = 10;
  static const maxRequestAge = Duration(minutes: 2);

  final Settings settings;
  final TtsGateway api;
  final TtsTwitch twitch;
  final TtsPlayback player;
  final DateTime Function() now;
  late final Future<void> ready;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  final Set<String> _seen = {};
  final Set<String> _bindings = {};
  final List<_Work> _queue = [];
  Timer? _timer;
  TtsHealth? health;
  TtsIssue? lastError;
  String? currentRequester;
  TtsPhase phase = TtsPhase.idle;
  bool _connected;
  bool _audioReady = false;
  bool _selectedAllowed = false;
  bool _closed = false;
  bool _disposed = false;
  bool _checking = false;
  Future<void>? _syncFuture;
  Future<void>? _closeFuture;
  bool _syncAgain = false;
  bool _processing = false;
  bool _testing = false;
  CancelToken? _testCancel;
  Future<void>? _testFuture;
  Future<void>? _processingFuture;
  _Work? _active;
  CancelToken? _activeCancel;
  Future<void> _events = Future.value();

  TtsController({
    required this.settings,
    required this.api,
    required this.twitch,
    required this.player,
    required Stream<WsMessage> events,
    required Stream<bool> connectionChanges,
    bool connected = false,
    DateTime Function()? now,
    Duration interval = healthInterval,
  }) : _connected = connected,
       now = now ?? DateTime.now {
    ready = player
        .setVolume(settings.tts.volumePercent / 100)
        .then((_) => _tick())
        .catchError(_recordError);
    _subscriptions.add(
      events.listen((event) {
        _events = _events
            .then((_) => ready)
            .then((_) => _handleEvent(event))
            .catchError(_recordError);
      }),
    );
    _subscriptions.add(
      connectionChanges.listen((connected) {
        _connected = connected;
        _guard(_syncRewards);
      }),
    );
    _subscriptions.add(
      settings.ttsChanges.listen((_) {
        _guard(_settingsChanged);
      }),
    );
    _subscriptions.add(
      settings.twitchAuthChanges.listen((_) {
        _guard(_settingsChanged);
      }),
    );
    _timer = Timer.periodic(interval, (_) => _guard(_tick));
  }

  int get queueLength => _queue.length + (_active == null ? 0 : 1);

  bool get busy => _processing || _testing;

  bool get checking => _checking;

  bool get accepting => _operational && _selectedAllowed;

  TtsIssue? get pauseReason {
    if (!settings.tts.enabled) return TtsIssue.disabled;
    if (settings.tts.rewardId == null) return TtsIssue.noReward;
    if (!_connected) return TtsIssue.twitchUnavailable;
    if (health?.available != true) {
      return health?.reason ?? TtsIssue.serviceUnavailable;
    }
    if (!_audioReady) return TtsIssue.audioUnavailable;
    if (queueLength >= maxQueueLength) return TtsIssue.queueFull;
    if (!_selectedAllowed) return TtsIssue.rewardUnavailable;
    return null;
  }

  bool get _operational =>
      !_closed &&
      !_testing &&
      settings.tts.enabled &&
      _connected &&
      _audioReady &&
      health?.available == true &&
      queueLength < maxQueueLength &&
      settings.tts.rewardId != null &&
      settings.tts.broadcasterId == settings.twitchAuth?.broadcasterId;

  String _binding(String channel, String reward) => '$channel/$reward';

  String _key(String channel, String id) => '$channel/$id';

  void _emit() {
    if (!_disposed) notifyListeners();
  }

  void _recordError(Object error, [StackTrace? stack]) {
    lastError = error is TtsFailure ? error.code : TtsIssue.operationFailed;
    _emit();
  }

  void _guard(Future<void> Function() action) {
    if (_closed) return;
    unawaited(
      ready
          .then((_) {
            if (!_closed) return action();
          })
          .catchError(_recordError),
    );
  }

  Future<void> _settingsChanged() async {
    if (_closed) return;
    if (settings.tts.broadcasterId != settings.twitchAuth?.broadcasterId ||
        !settings.tts.enabled) {
      final canceled = [..._queue, if (_active != null) _active!];
      _queue.clear();
      _activeCancel?.cancel(TtsCancellationReason.disabled);
      for (final work in canceled) {
        await _finish(work, false);
      }
    }
    await player.setVolume(settings.tts.volumePercent / 100);
    final base = settings.tts.baseUrl;
    if (_lastBase != base || health == null) {
      health = null;
      await _tick();
    } else {
      if (settings.tts.enabled && !_audioReady) await _prepareAudio();
      await _syncRewards();
    }
    _emit();
  }

  String? _lastBase;

  Future<void> checkNow() async {
    await ready;
    await _tick();
  }

  void stopCurrent() {
    _activeCancel?.cancel(TtsCancellationReason.stopped);
    _testCancel?.cancel(TtsCancellationReason.stopped);
  }

  /// Apply a slider preview immediately; the settings pane saves it on release.
  void previewVolume(int percent) {
    _guard(
      () => player.setVolume(
        percent.clamp(0, TtsSettings.maxVolumePercent) / 100,
      ),
    );
  }

  Future<void> testSpeech(String text) async {
    await ready;
    if (_closed || busy) return;
    final normalized = text.trim();
    if (normalized.isEmpty || normalized.runes.length > maxTextLength) {
      lastError = TtsIssue.invalidText;
      _emit();
      return;
    }
    _testFuture = _test(normalized);
    await _testFuture;
  }

  Future<void> _test(String text) async {
    _testing = true;
    lastError = null;
    final token = _testCancel = CancelToken();
    TtsAudio? audio;
    _emit();
    try {
      await _syncRewards();
      await player.prepare();
      audio = await api.speech(settings.tts, text, newTtsRequestKey(), token);
      checkTtsCancellation(token);
      await player.play(audio, token);
    } catch (error) {
      if (!token.isCancelled ||
          token.cancelError?.error == TtsCancellationReason.timeout) {
        _recordError(error);
      }
    } finally {
      await audio?.dispose();
      _testCancel = null;
      _testing = false;
      _emit();
      _guard(_syncRewards);
      _ensureProcessing();
    }
  }

  Future<void> _prepareAudio() async {
    try {
      await player.prepare();
      _audioReady = true;
    } catch (_) {
      _audioReady = false;
      lastError = TtsIssue.audioUnavailable;
    }
  }

  Future<void> _tick() async {
    if (_closed || _checking) return;
    _checking = true;
    _emit();
    try {
      if (settings.twitchAuth != null) {
        final base = settings.tts.baseUrl;
        final result = await api.health(base);
        if (base == settings.tts.baseUrl) {
          health = result;
          _lastBase = base;
        }
        if (settings.tts.enabled && !_audioReady) await _prepareAudio();
        await _syncRewards();
      }
    } finally {
      _checking = false;
      _emit();
    }
  }

  Future<void> _syncRewards() {
    if (_syncFuture != null) {
      _syncAgain = true;
      return _syncFuture!;
    }
    final operation = _syncRewardsInternal();
    return _syncFuture = operation.whenComplete(() => _syncFuture = null);
  }

  Future<void> _syncRewardsInternal() async {
    final channel = settings.twitchAuth?.broadcasterId;
    if (channel == null) {
      _selectedAllowed = false;
      _emit();
      return;
    }
    try {
      do {
        _syncAgain = false;
        final options = settings.tts;
        final selected =
            options.broadcasterId == channel ? options.rewardId : null;
        if (selected != null) _bindings.add(_binding(channel, selected));
        if (!_bindings.any((b) => b.startsWith('$channel/'))) break;
        final rewards = await twitch.rewards(channel);
        _selectedAllowed = false;
        for (final reward in rewards) {
          final key = _binding(channel, reward.id);
          if (!_bindings.contains(key)) continue;
          final allowed = reward.isEnabled && reward.isMusicRequestCompatible;
          if (reward.id == selected) _selectedAllowed = allowed;
          final open = reward.id == selected && _operational && allowed;
          if (reward.isPaused != !open) {
            await twitch.pause(channel, reward.id, !open);
          }
          if (reward.id != selected) _bindings.remove(key);
        }
      } while (_syncAgain);
    } catch (error) {
      _selectedAllowed = false;
      _recordError(error);
    } finally {
      _emit();
    }
  }

  Future<void> _handleEvent(WsMessage message) async {
    if (_closed) return;
    final type = message.payload.subscription?.type;
    final event = message.payload.event;
    if (event == null || event.id == null || event.broadcasterId == null) {
      return;
    }
    if (type == 'channel.channel_points_custom_reward_redemption.update') {
      final status = event.redemptionStatus;
      if (status != TwitchRedemptionStatus.fulfilled &&
          status != TwitchRedemptionStatus.canceled) {
        return;
      }
      final key = _key(event.broadcasterId!, event.id!);
      if (!_seen.contains(key) &&
          (event.broadcasterId != settings.tts.broadcasterId ||
              event.reward?.id != settings.tts.rewardId)) {
        return;
      }
      _seen.add(key);
      if (_active?.key == key) {
        _active!.finished = true;
        _activeCancel?.cancel(TtsCancellationReason.settledOnTwitch);
      }
      _queue.removeWhere((work) => work.key == key);
      _guard(_syncRewards);
      return;
    }
    if (type != 'channel.channel_points_custom_reward_redemption.add') return;
    await _accept(event);
  }

  Future<void> _accept(WsMessageEvent event) async {
    final options = settings.tts;
    final channel = event.broadcasterId;
    final id = event.id;
    final reward = event.reward?.id;
    if (id == null ||
        channel == null ||
        reward == null ||
        channel != settings.twitchAuth?.broadcasterId ||
        channel != options.broadcasterId ||
        reward != options.rewardId ||
        event.redemptionStatus != TwitchRedemptionStatus.unfulfilled) {
      return;
    }
    final key = _key(channel, id);
    if (!_seen.add(key)) return;
    final created = event.redeemedAt ?? now();
    final text = event.userInput?.trim() ?? '';
    final work = _Work(id, options, text, event.user?.name ?? '', created);
    if (!accepting ||
        text.isEmpty ||
        text.runes.length > maxTextLength ||
        now().difference(created) >= maxRequestAge) {
      lastError =
          text.isEmpty || text.runes.length > maxTextLength
              ? TtsIssue.invalidText
              : now().difference(created) >= maxRequestAge
              ? TtsIssue.timeout
              : pauseReason ?? TtsIssue.serviceUnavailable;
      await _finish(work, false);
      return;
    }
    _queue.add(work);
    _emit();
    _guard(_syncRewards);
    _ensureProcessing();
  }

  void _ensureProcessing() {
    if (_processing || _testing || _closed || _queue.isEmpty) return;
    _processingFuture = _process();
    unawaited(_processingFuture!.catchError(_recordError));
  }

  Future<void> _process() async {
    _processing = true;
    try {
      while (!_closed && _queue.isNotEmpty) {
        final work = _active = _queue.removeAt(0);
        final cancel = _activeCancel = CancelToken();
        currentRequester = work.requester;
        phase = TtsPhase.generating;
        _emit();
        TtsAudio? audio;
        final remaining = maxRequestAge - now().difference(work.created);
        final deadline = Timer(
          remaining.isNegative ? Duration.zero : remaining,
          () => cancel.cancel(TtsCancellationReason.timeout),
        );
        try {
          if (remaining <= Duration.zero) {
            throw const TtsFailure(TtsIssue.timeout);
          }
          if (!settings.tts.enabled ||
              settings.twitchAuth?.broadcasterId !=
                  work.options.broadcasterId) {
            throw const TtsFailure(TtsIssue.canceled);
          }
          audio = await api.speech(
            work.options,
            work.text,
            work.requestKey,
            cancel,
          );
          checkTtsCancellation(cancel);
          if (work.finished) throw const TtsFailure(TtsIssue.canceled);
          final status = await twitch.status(
            work.options.broadcasterId!,
            work.options.rewardId!,
            work.id,
          );
          if (status != TwitchRedemptionStatus.unfulfilled) {
            if (status == TwitchRedemptionStatus.fulfilled ||
                status == TwitchRedemptionStatus.canceled) {
              work.finished = true;
            }
            throw const TtsFailure(TtsIssue.canceled);
          }
          checkTtsCancellation(cancel);
          deadline
              .cancel(); // Generation/queue deadline does not truncate speech.
          phase = TtsPhase.playing;
          _emit();
          await player.play(audio, cancel);
          checkTtsCancellation(cancel);
          await _finish(work, true);
        } catch (error) {
          if (error is TtsFailure && error.code == TtsIssue.audioUnavailable) {
            _audioReady = false;
          }
          lastError =
              cancel.isCancelled &&
                      cancel.cancelError?.error == TtsCancellationReason.timeout
                  ? TtsIssue.timeout
                  : error is TtsFailure
                  ? error.code
                  : TtsIssue.generationFailed;
          await _finish(work, false);
        } finally {
          deadline.cancel();
          await audio?.dispose();
          _active = null;
          _activeCancel = null;
          currentRequester = null;
          phase = TtsPhase.idle;
          _emit();
          _guard(_syncRewards);
        }
      }
    } finally {
      _processing = false;
    }
  }

  Future<void> _finish(_Work work, bool fulfilled) async {
    if (work.finished) return;
    work.finished = true;
    try {
      await twitch.settle(
        work.options.broadcasterId!,
        work.options.rewardId!,
        work.id,
        fulfilled,
      );
    } catch (_) {
      lastError = TtsIssue.settlementFailed;
    } finally {
      _emit();
    }
  }

  Future<void> close() => _closeFuture ??= _close();

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    _timer?.cancel();
    await ready;
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _activeCancel?.cancel(TtsCancellationReason.shutdown);
    _testCancel?.cancel(TtsCancellationReason.shutdown);
    for (final work in [..._queue, if (_active != null) _active!]) {
      await _finish(work, false);
    }
    _queue.clear();
    await _syncRewards();
    await _processingFuture;
    await _testFuture;
    await player.close();
    api.close();
    _disposed = true;
    super.dispose();
  }
}

class _Work {
  final String id;
  final TtsSettings options;
  final String text;
  final String requester;
  final DateTime created;
  final String requestKey = newTtsRequestKey();
  bool finished = false;

  String get key => '${options.broadcasterId}/$id';

  _Work(this.id, this.options, this.text, this.requester, this.created);
}
