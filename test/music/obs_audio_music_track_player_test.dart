import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = BasicMessageChannel<String>('obs_audio', StringCodec());
  late List<Map<String, dynamic>> commands;

  setUp(() {
    commands = [];
    // Hosts without lifecycle events use the duration-based fallback.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(channel, (message) async {
          commands.add(jsonDecode(message!) as Map<String, dynamic>);
          return '{"ok":true}';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockDecodedMessageHandler(channel, null);
  });

  test('pause freezes the fallback timer and resume continues it', () async {
    final player = ObsAudioMusicTrackPlayer(
      volume: 0.8,
      completionGrace: Duration.zero,
    );
    final playback = player.play(_track(const Duration(milliseconds: 200)));
    addTearDown(() async {
      await player.stop();
      await playback;
    });
    var completed = false;
    unawaited(playback.then((_) => completed = true));
    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));

    await player.setPaused(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));
    expect(completed, isFalse);
    expect(commands.map((item) => item['cmd']), contains('pause'));

    await player.setPaused(false);
    await playback.timeout(const Duration(seconds: 1));
    expect(completed, isTrue);
    expect(commands.map((item) => item['cmd']), contains('resume'));
    expect(commands.last['cmd'], 'release');
  });

  test('seek updates native position and fallback completion time', () async {
    final player = ObsAudioMusicTrackPlayer(
      volume: 0.8,
      completionGrace: Duration.zero,
    );
    final playback = player.play(_track(const Duration(seconds: 1)));
    addTearDown(() async {
      await player.stop();
      await playback;
    });
    var completed = false;
    unawaited(playback.then((_) => completed = true));
    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));

    await player.seek(const Duration(milliseconds: 900));
    expect(
      commands.singleWhere((item) => item['cmd'] == 'seek')['position_ms'],
      900,
    );
    await playback.timeout(const Duration(milliseconds: 400));
    expect(completed, isTrue);
    expect(commands.last['cmd'], 'release');
  });

  test('updates active volume without restarting playback', () async {
    final player = ObsAudioMusicTrackPlayer(volume: 0.7);
    final playback = player.play(_track(const Duration(seconds: 30)));
    addTearDown(() async {
      await player.stop();
      await playback;
    });
    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
    expect(
      commands.singleWhere((item) => item['cmd'] == 'play')['volume'],
      0.7,
    );

    await player.setVolume(0.35);
    expect(
      commands.singleWhere((item) => item['cmd'] == 'volume')['volume'],
      0.35,
    );
    expect(commands.where((item) => item['cmd'] == 'play'), hasLength(1));
    expect(commands.where((item) => item['cmd'] == 'stop'), isEmpty);
    await player.stop();
    await playback;
  });
}

DownloadedMusicTrack _track(Duration duration) => DownloadedMusicTrack(
  itemId: 'track',
  requestedBy: 'viewer',
  metadata: MusicTrackMetadata(
    videoId: 'video',
    title: 'Track',
    author: 'Artist',
    duration: duration,
    thumbnail: null,
    sourceUrl: Uri.parse('https://youtu.be/video'),
  ),
  filePath: r'C:\music\track.mp3',
);

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the native audio command');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
