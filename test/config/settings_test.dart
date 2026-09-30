import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'music defaults are independent of old individual preferences',
    () async {
      SharedPreferences.setMockInitialValues({'music_volume_percent': 5});
      final settings = Settings();
      await settings.init();
      expect(settings.music.toJson(), const MusicSettings().toJson());
    },
  );

  test('saves, emits and restores every music setting', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.init();
    final changed = settings.musicChanges.first;
    const value = MusicSettings(
      enabled: false,
      volumePercent: 42,
      ttsVolumePercent: 15,
      maxQueue: 23,
      maxDurationSeconds: 321,
      cacheMaxMb: 0,
      controlServerEnabled: false,
      controlServerPort: 50123,
    );
    await settings.saveMusic(value);
    expect((await changed).toJson(), value.toJson());
    final restored = Settings();
    await restored.init();
    expect(restored.music.toJson(), value.toJson());
  });

  test(
    'normalizes invalid saved music values and tolerates malformed JSON',
    () async {
      SharedPreferences.setMockInitialValues({
        'music_settings': jsonEncode({
          'enabled': 'yes',
          'volume_percent': 150,
          'tts_volume_percent': -10,
          'max_queue': 0,
          'max_duration_seconds': -1,
          'cache_max_mb': -1,
          'control_server_enabled': false,
          'control_server_port': 65536,
        }),
      });
      final settings = Settings();
      await settings.init();
      expect(
        settings.music.toJson(),
        const MusicSettings(
          volumePercent: 100,
          ttsVolumePercent: 0,
          controlServerEnabled: false,
        ).toJson(),
      );
      for (final malformed in <Object>['{broken', '[]', 'null', 123]) {
        SharedPreferences.setMockInitialValues({'music_settings': malformed});
        final restored = Settings();
        await restored.init();
        expect(restored.music.toJson(), const MusicSettings().toJson());
      }
    },
  );

  test('restores player delay and never-collapse mode', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.init();
    expect(settings.playerCollapseSeconds, 5);
    expect(settings.playerAlwaysExpanded, isFalse);
    for (final seconds in [1, 60]) {
      await settings.savePlayerPresentation(
        collapseSeconds: seconds,
        alwaysExpanded: true,
      );
      final restored = Settings();
      await restored.init();
      expect(restored.playerCollapseSeconds, seconds);
      expect(restored.playerAlwaysExpanded, isTrue);
    }
    await settings.savePlayerPresentation(
      collapseSeconds: 60,
      alwaysExpanded: false,
    );
    final restored = Settings();
    await restored.init();
    expect(restored.playerAlwaysExpanded, isFalse);
    expect(restored.playerCollapseSeconds, 60);
  });

  test('persists and clears the selected music reward id', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.init();

    await settings.saveMusicRewardId(' reward-42 ');

    expect(settings.musicRewardId, 'reward-42');
    final restored = Settings();
    await restored.init();
    expect(restored.musicRewardId, 'reward-42');

    await restored.saveMusicRewardId(null);
    final cleared = Settings();
    await cleared.init();
    expect(cleared.musicRewardId, isNull);
  });
}
