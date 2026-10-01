import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/obs_config.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/di/app_service_locator.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/obs_audio_music_track_player.dart';
import 'package:obssource/tts/tts_controller.dart';
import 'package:obssource/tts/tts_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  test(
    'UI music settings ignore legacy OBS keys and update playback and server live',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      Future<int> freePort() async {
        final socket = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        final port = socket.port;
        await socket.close(force: true);
        return port;
      }

      final first = await freePort();
      await settings.saveMusic(
        settings.music.copyWith(
          controlServerEnabled: false,
          controlServerPort: first,
        ),
      );
      final config = ObsConfig();
      // Legacy keys are deliberately conflicting: only Settings may control music.
      config.config.set(
        Config(
          valid: true,
          json: {
            'music_volume_percent': 5,
            'music_control_server_enabled': true,
            'music_control_server_port': 1,
          },
        ),
      );
      final locator = AppServiceLocator.init(settings, config);
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

      config.config.set(
        Config(valid: true, json: {'music_volume_percent': 90}),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(commands.where((item) => item['cmd'] == 'volume'), isEmpty);
      await settings.saveMusic(settings.music.copyWith(volumePercent: 25));

      await _waitUntil(() => commands.any((item) => item['cmd'] == 'volume'));
      final volume = commands.singleWhere((item) => item['cmd'] == 'volume');
      expect(volume['volume'], 0.25);

      final ttsPlayer =
          locator.provide<TtsController>().player as ObsTtsPlayback;
      await ttsPlayer.duckMusic!(true);
      expect(commands.last['volume'], 0.0625);
      await settings.saveMusic(settings.music.copyWith(ttsVolumePercent: 40));
      await _waitUntil(() => commands.last['volume'] == 0.1);
      await settings.saveMusic(settings.music.copyWith(volumePercent: 50));
      await _waitUntil(() => commands.last['volume'] == 0.2);
      await ttsPlayer.duckMusic!(false);
      expect(commands.last['volume'], 0.5);

      final server = locator.musicControlServer!;
      expect(server.status, MusicControlServerStatus.stopped);
      await settings.saveMusic(
        settings.music.copyWith(controlServerEnabled: true),
      );
      await _waitUntil(() => server.port == first);
      final second = await freePort();
      await settings.saveMusic(
        settings.music.copyWith(controlServerPort: second),
      );
      await _waitUntil(() => server.port == second);
      await settings.saveMusic(
        settings.music.copyWith(controlServerEnabled: false),
      );
      await _waitUntil(() => server.port == null);
      expect(server.status, MusicControlServerStatus.stopped);
      expect(commands.where((item) => item['cmd'] == 'stop'), isEmpty);
    },
  );
}

Future<void> _waitUntil(bool Function() condition) async {
  final deadline = DateTime.now().add(const Duration(seconds: 1));
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for music settings to apply');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
