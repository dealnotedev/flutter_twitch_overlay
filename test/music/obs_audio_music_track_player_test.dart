import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
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

  test('updates the active music volume in real time', () async {
    final player = ObsAudioMusicTrackPlayer(
      volume: 0.7,
      completionGrace: Duration.zero,
    );
    final playback = player.play(
      DownloadedMusicTrack(
        itemId: 'track-volume',
        requestedBy: 'viewer',
        metadata: MusicTrackMetadata(
          videoId: 'video-volume',
          title: 'Track',
          author: 'Artist',
          duration: const Duration(seconds: 30),
          thumbnail: null,
          sourceUrl: Uri.parse('https://youtu.be/video-volume'),
        ),
        filePath: r'C:\music\track-volume.mp3',
      ),
    );

    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
    final play = commands.singleWhere((item) => item['cmd'] == 'play');
    expect(play['volume'], 0.7);

    await player.setVolume(0.35);

    final volume = commands.singleWhere((item) => item['cmd'] == 'volume');
    expect(volume['volume'], 0.35);

    await player.stop();
    await playback;
  });

  test('music_volume_percent updates active music in real time', () async {
    final config = ObsConfig();
    config.config.set(Config(valid: true, json: {'music_volume_percent': 70}));
    final locator = AppServiceLocator.init(Settings(), config);
    final player = locator.provide<ObsAudioMusicTrackPlayer>();
    final playback = player.play(
      DownloadedMusicTrack(
        itemId: 'configured-volume',
        requestedBy: 'viewer',
        metadata: MusicTrackMetadata(
          videoId: 'configured-volume',
          title: 'Track',
          author: 'Artist',
          duration: const Duration(seconds: 30),
          thumbnail: null,
          sourceUrl: Uri.parse('https://youtu.be/configured-volume'),
        ),
        filePath: r'C:\music\configured-volume.mp3',
      ),
    );
    addTearDown(() async {
      await locator.close();
      await playback;
    });

    await _waitUntil(() => commands.any((item) => item['cmd'] == 'play'));
    final play = commands.singleWhere((item) => item['cmd'] == 'play');
    expect(play['volume'], 0.7);

    config.config.set(Config(valid: true, json: {'music_volume_percent': 25}));

    await _waitUntil(() => commands.any((item) => item['cmd'] == 'volume'));
    final volume = commands.singleWhere((item) => item['cmd'] == 'volume');
    expect(volume['volume'], 0.25);
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
