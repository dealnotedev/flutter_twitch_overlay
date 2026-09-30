import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';
import 'package:obssource/twitch/ws_event.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'tts_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Settings settings;
  late FakeTtsGateway api;
  late FakeTtsPlayer player;
  late FakeTtsTwitch twitch;
  late StreamController<WsMessage> events;
  late StreamController<bool> connections;
  TtsController? controller;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    settings = configuredTtsSettings();
    api = FakeTtsGateway();
    player = FakeTtsPlayer();
    twitch = FakeTtsTwitch();
    events = StreamController.broadcast();
    connections = StreamController.broadcast();
  });
  Future<TtsController> start() async {
    final value =
        controller = TtsController(
          settings: settings,
          api: api,
          twitch: twitch,
          player: player,
          events: events.stream,
          connectionChanges: connections.stream,
          connected: true,
        );
    await value.ready;
    return value;
  }

  tearDown(() async {
    await controller?.close();
    controller = null;
    await events.close();
    await connections.close();
  });

  test('applies saved volume on startup and previews without saving', () async {
    settings.tts = settings.tts.copyWith(volumePercent: 135);
    final manager = await start();
    expect(player.volume, 1.35);
    manager.previewVolume(160);
    await eventually(() => player.volume == 1.6);
    expect(settings.tts.volumePercent, 135);
    await settings.saveTts(settings.tts.copyWith(volumePercent: 200));
    await eventually(() => player.volume == 2.0);
  });

  test(
    'one playback per redemption, fulfillment only after audio finishes',
    () async {
      player.hold = Completer();
      await start();
      events.add(redemption('one'));
      events.add(redemption('one'));
      events.add(redemption('music', reward: 'music'));
      await eventually(() => player.plays == 1);
      expect(twitch.settlements, isEmpty);
      player.hold!.complete();
      await eventually(() => twitch.settlements.length == 1);
      expect(twitch.settlements, [('one', true)]);
      expect(api.calls, ['Hello']);
    },
  );

  test('timeout refunds once and does not retry synthesis', () async {
    api.failure = const TtsFailure(TtsIssue.timeout);
    final manager = await start();
    events.add(redemption('timeout'));
    await eventually(() => twitch.settlements.isNotEmpty);
    events.add(redemption('timeout'));
    await manager.checkNow();
    expect(api.calls.length, 1);
    expect(twitch.settlements, [('timeout', false)]);
    expect(player.plays, 0);
  });

  for (final fulfilled in [true, false]) {
    test(
      'failed Twitch ${fulfilled ? 'fulfillment' : 'refund'} is never retried',
      () async {
        twitch.failSettlement = true;
        if (!fulfilled) api.failure = const TtsFailure(TtsIssue.timeout);
        final manager = await start();
        events.add(redemption('failed'));
        await eventually(
          () => manager.lastError == TtsIssue.settlementFailed && !manager.busy,
        );
        twitch.failSettlement = false;
        events.add(redemption('failed'));
        connections.add(false);
        await eventually(() => !manager.accepting);
        connections.add(true);
        await eventually(() => manager.accepting);
        await manager.checkNow();
        await manager.close();
        expect(twitch.settlementAttempts, [('failed', fulfilled)]);
        expect(twitch.settlements, isEmpty);
        expect(api.calls.length, 1);
        expect(player.plays, fulfilled ? 1 : 0);
      },
    );
  }

  test('moderator cancellation during synthesis prevents playback', () async {
    api.hold = Completer();
    final manager = await start();
    events.add(redemption('canceled'));
    await eventually(() => api.calls.isNotEmpty);
    events.add(redemption('canceled', status: 'canceled', update: true));
    await eventually(() => !manager.busy);
    expect(player.plays, 0);
    expect(twitch.settlements, isEmpty);
  });

  test(
    'unavailable health pauses and recovery resumes an automatic pause',
    () async {
      api.available = false;
      final manager = await start();
      expect(twitch.pauses, [('tts', true)]);
      expect(manager.accepting, isFalse);
      api.available = true;
      await manager.checkNow();
      expect(twitch.pauses, [('tts', true), ('tts', false)]);
      expect(manager.accepting, isTrue);
    },
  );

  test(
    'paused reward resumes on startup but a disabled reward stays disabled',
    () async {
      twitch.catalog = [ttsReward(paused: true)];
      final manager = await start();
      expect(twitch.pauses, [('tts', false)]);
      expect(manager.accepting, isTrue);
      twitch.catalog = [ttsReward(enabled: false, paused: true)];
      await manager.checkNow();
      expect(twitch.pauses, [('tts', false)]);
      expect(manager.accepting, isFalse);
    },
  );

  test(
    'empty, long and stale requests are refunded without synthesis',
    () async {
      await start();
      events.add(redemption('empty', text: '  '));
      events.add(redemption('long', text: 'a' * 1025));
      events.add(
        redemption(
          'stale',
          time: DateTime.now().subtract(const Duration(minutes: 3)),
        ),
      );
      await eventually(() => twitch.settlements.length == 3);
      expect(api.calls, isEmpty);
      expect(twitch.settlements.toSet(), {
        ('empty', false),
        ('long', false),
        ('stale', false),
      });
    },
  );

  test('Twitch accepts exactly 1024 Unicode code points', () async {
    await start();
    final text = '😀' * 1024;
    events.add(redemption('at-limit', text: text));
    await eventually(() => twitch.settlements.isNotEmpty);
    expect(api.calls, [text]);
    expect(player.plays, 1);
    expect(twitch.settlements, [('at-limit', true)]);
  });

  test('test speech accepts 1024 code points and rejects 1025', () async {
    final manager = await start();
    final text = '😀' * 1024;
    await manager.testSpeech(text);
    expect(api.calls, [text]);
    expect(player.plays, 1);
    expect(manager.lastError, isNull);
    await manager.testSpeech('${text}a');
    expect(manager.lastError, TtsIssue.invalidText);
    expect(api.calls, [text]);
    expect(player.plays, 1);
  });

  test(
    'restart forgets failed requests and resumes the reward without settling them',
    () async {
      twitch.failSettlement = true;
      await start();
      events.add(redemption('old'));
      await eventually(
        () =>
            controller!.lastError == TtsIssue.settlementFailed &&
            !controller!.busy,
      );
      await controller!.close();
      expect(twitch.catalog.single.isPaused, isTrue);
      twitch.failSettlement = false;
      final restarted = await start();
      await restarted.checkNow();
      expect(restarted.accepting, isTrue);
      expect(restarted.queueLength, 0);
      expect(twitch.settlementAttempts, [('old', true)]);
      expect(twitch.settlements, isEmpty);
      expect(api.calls, ['Hello']);
      expect(player.plays, 1);
    },
  );

  test('queue stays sequential and snapshots the selected mood', () async {
    api.hold = Completer();
    await start();
    events.add(redemption('first', text: 'First'));
    events.add(redemption('second', text: 'Second'));
    await eventually(() => controller!.queueLength == 2);
    await settings.saveTts(settings.tts.copyWith(mood: TtsMood.lively));
    api.hold!.complete();
    await eventually(() => twitch.settlements.length == 2);
    expect(api.calls, ['First', 'Second']);
    expect(api.moods, [TtsMood.neutral, TtsMood.neutral]);
  });

  test('disabling cancels active work and returns points', () async {
    api.hold = Completer();
    await start();
    events.add(redemption('active'));
    await eventually(() => api.calls.isNotEmpty);
    await settings.saveTts(settings.tts.copyWith(enabled: false));
    await eventually(() => twitch.settlements.isNotEmpty);
    expect(twitch.settlements, [('active', false)]);
    expect(player.plays, 0);
  });

  test('full queue pauses the reward and refunds overflow', () async {
    api.hold = Completer();
    final manager = await start();
    for (var i = 0; i < 11; i++) {
      events.add(redemption('request-$i'));
    }
    await eventually(() => twitch.settlements.any((s) => s.$1 == 'request-10'));
    expect(manager.queueLength, 10);
    expect(twitch.settlements, [('request-10', false)]);
    expect(twitch.pauses.last, ('tts', true));
    expect(api.calls.length, 1);
  });

  test('background health checks run once per minute', () async {
    late FakeAsync testClock;
    var closed = false;
    fakeAsync((clock) {
      testClock = clock;
      final manager = TtsController(
        settings: configuredTtsSettings(),
        api: api,
        twitch: twitch,
        player: player,
        events: const Stream.empty(),
        connectionChanges: const Stream.empty(),
        connected: true,
      );
      var initialized = false;
      manager.ready.then((_) => initialized = true);
      clock.flushMicrotasks();
      expect(initialized, isTrue);
      expect(api.healthCalls, 1);
      clock.elapse(const Duration(seconds: 59));
      expect(api.healthCalls, 1);
      clock.elapse(const Duration(seconds: 1));
      expect(api.healthCalls, 2);
      manager.close().then((_) => closed = true);
      clock.flushMicrotasks();
    });
    // Stream.empty cancellation can complete in the root zone.
    for (var i = 0; i < 20 && !closed; i++) {
      await Future<void>.delayed(Duration.zero);
      testClock.flushMicrotasks();
    }
    expect(closed, isTrue);
  });
}
