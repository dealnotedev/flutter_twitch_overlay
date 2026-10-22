import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/music/turntable_playback_controller.dart';
import 'package:obssource/obs_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const commandChannel = BasicMessageChannel<String>(
    'obs_audio',
    StringCodec(),
  );
  late List<Map<String, dynamic>> commands;

  setUp(() {
    commands = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(commandChannel, (message) async {
          commands.add(jsonDecode(message!) as Map<String, dynamic>);
          return '{"ok":true,"events":true}';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(commandChannel, null);
  });

  test('loadFile surfaces a native asynchronous load error', () async {
    final loading = ObsAudio.loadFile(r'C:\music\broken.mp3');
    await _waitUntil(() => commands.any((item) => item['cmd'] == 'load'));
    final load = commands.singleWhere((item) => item['cmd'] == 'load');

    await _sendAudioEvent({
      'event': 'error',
      'id': load['id'],
      'message': 'Unable to decode audio',
    });

    await expectLater(
      loading,
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'Unable to decode audio',
        ),
      ),
    );
  });

  test(
    'player waits for loaded and started, then completes on ended',
    () async {
      final needle = Completer<void>();
      var ready = false;
      var started = false;
      final player = ObsAudioMusicTrackPlayer(
        volume: 0.8,
        completionGrace: Duration.zero,
        beforeStart: (_, interrupted) {
          ready = true;
          return Future.any([needle.future, interrupted]);
        },
      );
      addTearDown(player.stop);

      final playback = player.play(
        DownloadedMusicTrack(
          itemId: 'event-track',
          requestedBy: 'viewer',
          metadata: MusicTrackMetadata(
            videoId: 'event-video',
            title: 'Track',
            author: 'Artist',
            duration: const Duration(seconds: 30),
            thumbnail: null,
            sourceUrl: Uri.parse('https://youtu.be/event-video'),
          ),
          filePath: r'C:\music\event-track.mp3',
        ),
        onStarted: () => started = true,
      );

      var completed = false;
      unawaited(playback.whenComplete(() => completed = true));

      await _waitUntil(() => commands.any((item) => item['cmd'] == 'load'));
      final load = commands.singleWhere((item) => item['cmd'] == 'load');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(commands.where((item) => item['cmd'] == 'play'), isEmpty);
      expect(ready, isFalse);

      await _sendAudioEvent({
        'event': 'loaded',
        'id': load['id'],
        'session_id': load['session_id'],
      });
      await _waitUntil(() => ready);
      expect(commands.where((item) => item['cmd'] == 'play'), isEmpty);
      expect(started, isFalse);
      needle.complete();
      await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
      expect(started, isFalse);
      final play = commands.singleWhere((item) => item['cmd'] == 'play');

      await _sendAudioEvent({
        'event': 'started',
        'id': play['id'],
        'session_id': play['session_id'],
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(completed, isFalse);
      expect(started, isTrue);

      await _sendAudioEvent({
        'event': 'ended',
        'id': play['id'],
        'session_id': play['session_id'],
      });
      await playback.timeout(const Duration(seconds: 1));
    },
  );

  test(
    'native errors while cueing cancel the gate and release the file',
    () async {
      final turntable = TurntablePlaybackController()..attach();
      final player = ObsAudioMusicTrackPlayer(
        volume: 0.8,
        beforeStart: turntable.beforeStart,
      );
      final playback = player.play(
        DownloadedMusicTrack(
          itemId: 'failed-cue',
          requestedBy: 'viewer',
          metadata: MusicTrackMetadata(
            videoId: 'failed-cue',
            title: 'Track',
            author: 'Artist',
            duration: const Duration(seconds: 30),
            thumbnail: null,
            sourceUrl: Uri.parse('https://youtu.be/failed-cue'),
          ),
          filePath: r'C:\music\failed-cue.mp3',
        ),
      );
      final failed = expectLater(playback, throwsStateError);
      await _waitUntil(() => commands.any((item) => item['cmd'] == 'load'));
      final load = commands.singleWhere((item) => item['cmd'] == 'load');
      await _sendAudioEvent({
        'event': 'loaded',
        'id': load['id'],
        'session_id': load['session_id'],
      });
      await _waitUntil(() => turntable.readyItemId != null);
      await _sendAudioEvent({
        'event': 'error',
        'id': load['id'],
        'session_id': load['session_id'],
        'message': 'Decoder failed',
      });
      await failed;
      expect(commands.where((item) => item['cmd'] == 'play'), isEmpty);
      expect(commands.last['cmd'], 'release');
      expect(turntable.readyItemId, isNull);
      turntable.detach();
      turntable.dispose();
    },
  );
}

Future<void> _sendAudioEvent(Map<String, Object?> event) async {
  await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .handlePlatformMessage(
        'obs_audio_events',
        const StringCodec().encodeMessage(jsonEncode(event)),
        (_) {},
      );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the native audio transition');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
