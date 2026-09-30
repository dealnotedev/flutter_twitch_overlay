import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Settings settings;
  late StreamController<bool> connection;
  late List<(String, String, bool)> calls;
  late MusicRewardController controller;
  Object? failure;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    settings = Settings();
    await settings.init();
    settings.twitchAuth = TwitchCreds(
      accessToken: 'unused',
      refreshToken: 'unused',
      clientId: 'unused',
      broadcasterId: 'channel',
    );
    await settings.saveMusicRewardId('music');
    connection = StreamController<bool>.broadcast();
    calls = [];
    failure = null;
    controller = MusicRewardController(
      settings: settings,
      connected: true,
      connectionChanges: connection.stream,
      pauseReward: (channel, reward, paused) async {
        if (failure != null) throw failure!;
        calls.add((channel, reward, paused));
      },
    );
    await controller.refresh();
  });

  tearDown(() async {
    failure = null;
    await controller.close();
    await connection.close();
  });

  test('switch follows settings, reconnect and orderly shutdown', () async {
    expect(calls, [('channel', 'music', false)]);
    await settings.saveMusic(settings.music.copyWith(enabled: false));
    await controller.refresh();
    expect(calls.last, ('channel', 'music', true));
    await settings.saveMusic(settings.music.copyWith(enabled: true));
    await controller.refresh();
    expect(calls.last, ('channel', 'music', false));
    connection.add(false);
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(calls.last, ('channel', 'music', true));
    connection.add(true);
    await Future<void>.delayed(Duration.zero);
    await controller.refresh();
    expect(calls.last, ('channel', 'music', false));
    await controller.close();
    expect(calls.last, ('channel', 'music', true));
  });

  test(
    'changing reward retires the old one and volume does not repatch it',
    () async {
      await settings.saveMusicRewardId('new');
      await controller.refresh();
      expect(calls, [
        ('channel', 'music', false),
        ('channel', 'music', true),
        ('channel', 'new', false),
      ]);
      await settings.saveMusic(settings.music.copyWith(volumePercent: 20));
      await controller.refresh();
      expect(calls, hasLength(3));
    },
  );

  test('returning to the applied state clears an obsolete failure', () async {
    failure = StateError('offline');
    await settings.saveMusic(settings.music.copyWith(enabled: false));
    await controller.refresh();
    expect(controller.error, isNotNull);
    await settings.saveMusic(settings.music.copyWith(enabled: true));
    await controller.refresh();
    expect(controller.error, isNull);
    expect(calls, [('channel', 'music', false)]);
  });

  test('failed Twitch updates are visible and retryable', () async {
    failure = StateError('offline');
    await settings.saveMusic(settings.music.copyWith(enabled: false));
    await controller.refresh();
    expect(controller.error, contains('offline'));
    failure = null;
    await controller.refresh();
    expect(controller.error, isNull);
    expect(calls.last, ('channel', 'music', true));
  });
}
