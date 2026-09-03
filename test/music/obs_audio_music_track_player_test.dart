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
    final playback = player.play(
      DownloadedMusicTrack(
        itemId: 'track-1',
        requestedBy: 'viewer',
        metadata: MusicTrackMetadata(
          videoId: 'video-1',
          title: 'Track',
          author: 'Artist',
          duration: const Duration(milliseconds: 200),
          thumbnail: null,
          sourceUrl: Uri.parse('https://youtu.be/video-1'),
        ),
        filePath: r'C:\music\track.mp3',
      ),
    );
    var completed = false;
    unawaited(playback.whenComplete(() => completed = true));

    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
    await player.setPaused(true);
    await Future<void>.delayed(const Duration(milliseconds: 250));

    expect(completed, isFalse);
    expect(commands.map((item) => item['cmd']), contains('pause'));

    await player.setPaused(false);
    await playback.timeout(const Duration(seconds: 1));

    expect(commands.map((item) => item['cmd']), contains('resume'));
    expect(completed, isTrue);
  });

  test('seek updates native position and fallback completion time', () async {
    final player = ObsAudioMusicTrackPlayer(
      volume: 0.8,
      completionGrace: Duration.zero,
    );
    final playback = player.play(
      DownloadedMusicTrack(
        itemId: 'track-seek',
        requestedBy: 'viewer',
        metadata: MusicTrackMetadata(
          videoId: 'video-seek',
          title: 'Track',
          author: 'Artist',
          duration: const Duration(seconds: 1),
          thumbnail: null,
          sourceUrl: Uri.parse('https://youtu.be/video-seek'),
        ),
        filePath: r'C:\music\track-seek.mp3',
      ),
    );

    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
    await player.seek(const Duration(milliseconds: 900));
    await playback.timeout(const Duration(milliseconds: 400));

    final seek = commands.singleWhere((item) => item['cmd'] == 'seek');
    expect(seek['position_ms'], 900);
  });
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for the native audio command');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
