import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_player.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';
import 'package:obssource/tts/tts_twitch.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:obssource/twitch/twitch_redemption.dart';
import 'package:obssource/twitch/ws_event.dart';

Settings configuredTtsSettings() =>
    Settings()
      ..twitchAuth = TwitchCreds(
        accessToken: 'unused',
        refreshToken: 'unused',
        broadcasterId: 'channel',
        clientId: 'client',
      )
      ..tts = const TtsSettings(
        enabled: true,
        rewardId: 'tts',
        broadcasterId: 'channel',
      );

TwitchCustomReward ttsReward({
  String id = 'tts',
  bool paused = false,
  bool enabled = true,
}) => TwitchCustomReward(
  id: id,
  title: id,
  prompt: '',
  cost: 1000,
  backgroundColor: '#9147FF',
  image: null,
  isEnabled: enabled,
  isPaused: paused,
  isInStock: true,
  isUserInputRequired: true,
  shouldRedemptionsSkipRequestQueue: false,
);

WsMessage redemption(
  String id, {
  String reward = 'tts',
  String text = 'Hello',
  String status = 'unfulfilled',
  bool update = false,
  DateTime? time,
}) => WsMessage.fromJson({
  'payload': {
    'subscription': {
      'type':
          'channel.channel_points_custom_reward_redemption.${update ? 'update' : 'add'}',
    },
    'event': {
      'id': id,
      'broadcaster_user_id': 'channel',
      'user_id': 'viewer',
      'user_login': 'viewer',
      'user_name': 'Viewer',
      'user_input': text,
      'status': status,
      'redeemed_at': (time ?? DateTime.now()).toIso8601String(),
      'reward': {'id': reward, 'title': reward, 'cost': 1000},
    },
  },
});

class FakeTtsGateway implements TtsGateway {
  bool available = true;
  int healthCalls = 0;
  final List<String> calls = [];
  final List<TtsMood> moods = [];
  Object? failure;
  Completer<void>? hold;
  @override
  Future<TtsHealth> health(String baseUrl) async {
    healthCalls++;
    return TtsHealth(
      available: available,
      connectedAgents: available ? 2 : 0,
      healthyAgents: available ? 1 : 0,
      queueSize: 0,
      checkedAt: DateTime.now(),
      reason: available ? null : TtsIssue.noAgentsAvailable,
    );
  }

  @override
  Future<TtsAudio> speech(
    TtsSettings settings,
    String text,
    String key,
    CancelToken cancel,
  ) async {
    calls.add(text);
    moods.add(settings.mood);
    if (hold != null) await Future.any([hold!.future, cancel.whenCancel]);
    checkTtsCancellation(cancel);
    if (failure != null) throw failure!;
    final dir = await Directory.systemTemp.createTemp('tts-unit-');
    final file = await File('${dir.path}/speech.wav').writeAsBytes([1, 2, 3]);
    return TtsAudio(file, const Duration(milliseconds: 50));
  }

  @override
  void close() {}
}

class FakeTtsPlayer implements TtsPlayback {
  double volume = 1;
  int plays = 0;
  bool prepared = false;
  bool fail = false;
  Completer<void>? hold;
  @override
  Future<void> setVolume(double value) async {
    volume = value;
  }

  @override
  Future<void> prepare() async {
    prepared = true;
  }

  @override
  Future<void> play(TtsAudio audio, CancelToken cancel) async {
    plays++;
    if (hold != null) await Future.any([hold!.future, cancel.whenCancel]);
    checkTtsCancellation(cancel);
    if (fail) throw const TtsFailure(TtsIssue.audioUnavailable);
  }

  @override
  Future<void> close() async {}
}

class FakeTtsTwitch implements TtsTwitch {
  List<TwitchCustomReward> catalog = [ttsReward()];
  final List<(String, bool)> pauses = [];
  final List<(String, bool)> settlements = [];
  final List<(String, bool)> settlementAttempts = [];
  final Map<String, TwitchRedemptionStatus> statuses = {};
  bool failSettlement = false;
  @override
  Future<List<TwitchCustomReward>> rewards(String channel) async => catalog;
  @override
  Future<void> pause(String channel, String reward, bool paused) async {
    pauses.add((reward, paused));
    catalog =
        catalog
            .map(
              (r) =>
                  r.id == reward
                      ? ttsReward(
                        id: reward,
                        paused: paused,
                        enabled: r.isEnabled,
                      )
                      : r,
            )
            .toList();
  }

  @override
  Future<void> settle(
    String channel,
    String reward,
    String redemption,
    bool fulfilled,
  ) async {
    settlementAttempts.add((redemption, fulfilled));
    if (failSettlement) throw StateError('Twitch offline');
    settlements.add((redemption, fulfilled));
    statuses[redemption] =
        fulfilled
            ? TwitchRedemptionStatus.fulfilled
            : TwitchRedemptionStatus.canceled;
  }

  @override
  Future<TwitchRedemptionStatus?> status(
    String channel,
    String reward,
    String redemption,
  ) async => statuses[redemption] ?? TwitchRedemptionStatus.unfulfilled;
}

Future<void> eventually(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 4));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('Condition not reached');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
