import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_player.dart';

import 'tts_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = BasicMessageChannel<String>('obs_audio', StringCodec());
  late List<Map<String, dynamic>> commands;
  late List<bool> ducking;
  late ObsTtsPlayback player;
  setUp(() {
    commands = [];
    ducking = [];
    player = ObsTtsPlayback(
      duckMusic: (value) async {
        ducking.add(value);
      },
    );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(channel, (message) async {
          final command = jsonDecode(message!) as Map<String, dynamic>;
          commands.add(command);
          if (command['cmd'] == 'load') {
            scheduleMicrotask(() => sendEvent(command, 'loaded'));
          }
          return '{"ok":true,"events":true}';
        });
  });
  tearDown(() async {
    await player.close();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(channel, null);
  });

  test(
    'speech volume changes live without changing notification volume or the gap',
    () async {
      final asset = await rootBundle.load(ObsTtsPlayback.notificationAsset);
      expect(
        wavDuration(asset.buffer.asUint8List()),
        greaterThan(Duration.zero),
      );
      await player.setVolume(0.35);
      final playback = player.play(
        TtsAudio(File('speech.wav'), const Duration(seconds: 1)),
        CancelToken(),
      );
      await eventually(() => commands.any((c) => c['cmd'] == 'play'));
      final notification = commands.lastWhere((c) => c['cmd'] == 'play');
      expect(notification['volume'], 1);
      await player.setVolume(1.6);
      expect(commands.where((c) => c['cmd'] == 'volume'), isEmpty);
      expect(commands.first['asset'], ObsTtsPlayback.notificationAsset);
      expect(commands.where((c) => c['absolute_path'] != null), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(commands.where((c) => c['cmd'] == 'play').length, 1);
      final watch = Stopwatch()..start();
      await sendEvent(notification, 'ended');
      await eventually(
        () => commands.where((c) => c['cmd'] == 'play').length == 2,
      );
      expect(watch.elapsedMilliseconds, greaterThanOrEqualTo(990));
      final speech = commands.lastWhere((c) => c['cmd'] == 'play');
      expect(speech['volume'], 1.6);
      await player.setVolume(0);
      await player.setVolume(2.0);
      expect(commands.where((c) => c['cmd'] == 'volume').toList(), [
        {'cmd': 'volume', 'id': speech['id'], 'volume': 0.0},
        {'cmd': 'volume', 'id': speech['id'], 'volume': 2.0},
      ]);
      await sendEvent(speech, 'ended');
      await playback;
      await player.setVolume(0.8);
      expect(commands.where((c) => c['cmd'] == 'volume'), hasLength(2));
      expect(ducking, [true, false]);
    },
  );

  test(
    'stopping during the gap never starts speech and restores music',
    () async {
      final cancel = CancelToken();
      final playback = player.play(
        TtsAudio(File('speech.wav'), const Duration(seconds: 1)),
        cancel,
      );
      final expectation = expectLater(playback, throwsA(isA<TtsFailure>()));
      await eventually(() => commands.any((c) => c['cmd'] == 'play'));
      await sendEvent(commands.lastWhere((c) => c['cmd'] == 'play'), 'ended');
      await Future<void>.delayed(const Duration(milliseconds: 50));
      cancel.cancel();
      await expectation;
      expect(commands.where((c) => c['absolute_path'] != null), isEmpty);
      expect(ducking, [true, false]);
    },
  );
}

Future<void> sendEvent(Map<String, dynamic> command, String event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'obs_audio_events',
        const StringCodec().encodeMessage(
          jsonEncode({
            'id': command['id'],
            'session_id': command['session_id'],
            'event': event,
          }),
        ),
        (_) {},
      );
}
