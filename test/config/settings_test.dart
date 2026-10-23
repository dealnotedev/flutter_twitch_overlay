import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/music/music_settings.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../support/test_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatar defaults ignore old individual preferences', () async {
    final preferences = testPreferences({
      'alert_avatar_resolution': 32,
      'alert_animation_renderer': 'legacy',
    });
    final settings = Settings(preferences);
    await settings.init();
    expect(settings.avatar.resolution, 48);
    expect(settings.avatar.renderer, AvatarPixelRenderer.rawAtlas);
  });

  test('saves, emits and restores avatar settings', () async {
    final preferences = testPreferences({});
    final settings = Settings(preferences);
    await settings.init();
    final changed = settings.avatarChanges.first;
    const value = AvatarSettings(
      resolution: 40,
      renderer: AvatarPixelRenderer.legacyCanvas,
    );
    await settings.saveAvatar(value);
    expect((await changed).toJson(), value.toJson());
    final restored = Settings(preferences);
    await restored.init();
    expect(restored.avatar.toJson(), value.toJson());
  });

  test('avatar resolution stays within the slider range', () async {
    for (final (resolution, expected) in [
      (-1, 48),
      (0, 48),
      (1, 16),
      (16, 16),
      (48, 48),
      (128, 128),
      (256, 128),
    ]) {
      final preferences = testPreferences({
        'avatar_settings': jsonEncode({'resolution': resolution}),
      });
      final settings = Settings(preferences);
      await settings.init();
      expect(settings.avatar.resolution, expected);
      await settings.saveAvatar(AvatarSettings(resolution: resolution));
      final restored = Settings(preferences);
      await restored.init();
      expect(restored.avatar.resolution, expected);
    }
  });

  test('malformed avatar settings fall back to defaults', () async {
    for (final malformed in <Object>[
      '{broken',
      '[]',
      'null',
      123,
      jsonEncode({'resolution': '32', 'renderer': true}),
      jsonEncode({'renderer': 'unknown'}),
    ]) {
      final preferences = testPreferences({'avatar_settings': malformed});
      final settings = Settings(preferences);
      await settings.init();
      expect(settings.avatar.toJson(), const AvatarSettings().toJson());
    }
  });

  test('music settings preserve the existing Twitch login', () async {
    final credentials = TwitchCreds(
      accessToken: 'token',
      refreshToken: 'refresh',
      broadcasterId: 'channel',
      clientId: 'client',
    );
    final preferences = testPreferences({
      'twitch_login': jsonEncode(credentials.toJson()),
    });
    final settings = Settings(preferences);
    await settings.init();
    await settings.saveMusic(settings.music.copyWith(volumePercent: 25));
    final restored = Settings(preferences);
    await restored.init();
    expect(restored.twitchAuth?.toJson(), credentials.toJson());
    expect(restored.music.volumePercent, 25);
  });

  test(
    'music defaults are independent of old individual preferences',
    () async {
      final preferences = testPreferences({'music_volume_percent': 5});
      final settings = Settings(preferences);
      await settings.init();
      expect(settings.music.toJson(), const MusicSettings().toJson());
    },
  );

  test('saves, emits and restores every music setting', () async {
    final preferences = testPreferences({});
    final settings = Settings(preferences);
    await settings.init();
    final changed = settings.musicChanges.first;
    const value = MusicSettings(
      enabled: false,
      volumePercent: 42,
      maxQueue: 23,
      maxDurationSeconds: 321,
      cacheMaxMb: 512,
      controlServerEnabled: false,
      controlServerPort: 50123,
      playerStyle: MusicPlayerStyle.turntable,
    );
    await settings.saveMusic(value);
    expect((await changed).toJson(), value.toJson());
    final restored = Settings(preferences);
    await restored.init();
    expect(restored.music.toJson(), value.toJson());
  });

  test(
    'normalizes invalid saved music values and tolerates malformed JSON',
    () async {
      final preferences = testPreferences({
        'music_settings': jsonEncode({
          'enabled': 'yes',
          'volume_percent': 150,
          'max_queue': 0,
          'max_duration_seconds': -1,
          'cache_max_mb': -1,
          'control_server_enabled': false,
          'control_server_port': 65536,
        }),
      });
      final settings = Settings(preferences);
      await settings.init();
      expect(
        settings.music.toJson(),
        const MusicSettings(
          volumePercent: 100,
          controlServerEnabled: false,
        ).toJson(),
      );
      for (final malformed in <Object>['{broken', '[]', 'null', 123]) {
        final preferences = testPreferences({'music_settings': malformed});
        final restored = Settings(preferences);
        await restored.init();
        expect(restored.music.toJson(), const MusicSettings().toJson());
      }
    },
  );

  test(
    'cache limits stay within 128 MB and 2 GB when saved or restored',
    () async {
      for (final (stored, expected) in [
        (0, 2048),
        (64, 128),
        (128, 128),
        (1024, 1024),
        (2048, 2048),
        (4096, 2048),
      ]) {
        final preferences = testPreferences({
          'music_settings': jsonEncode({'cache_max_mb': stored}),
        });
        final settings = Settings(preferences);
        await settings.init();
        expect(settings.music.cacheMaxMb, expected);
        await settings.saveMusic(settings.music.copyWith(cacheMaxMb: stored));
        final restored = Settings(preferences);
        await restored.init();
        expect(restored.music.cacheMaxMb, expected);
      }
    },
  );

  test(
    'queue and duration limits stay in the slider ranges when saved or restored',
    () async {
      for (final (queue, duration, expectedQueue, expectedDuration) in [
        (1, 1, 1, 60),
        (1, 60, 1, 60),
        (24, 451, 24, 451),
        (50, 1200, 50, 1200),
        (51, 1201, 50, 1200),
      ]) {
        final preferences = testPreferences({
          'music_settings': jsonEncode({
            'max_queue': queue,
            'max_duration_seconds': duration,
          }),
        });
        final settings = Settings(preferences);
        await settings.init();
        expect(settings.music.maxQueue, expectedQueue);
        expect(settings.music.maxDurationSeconds, expectedDuration);
        await settings.saveMusic(
          settings.music.copyWith(
            maxQueue: queue,
            maxDurationSeconds: duration,
          ),
        );
        final restored = Settings(preferences);
        await restored.init();
        expect(restored.music.maxQueue, expectedQueue);
        expect(restored.music.maxDurationSeconds, expectedDuration);
      }
    },
  );

  test('restores player delay and never-collapse mode', () async {
    final preferences = testPreferences({});
    final settings = Settings(preferences);
    await settings.init();
    expect(settings.playerCollapseSeconds, 5);
    expect(settings.playerAlwaysExpanded, isFalse);
    for (final seconds in [1, 60]) {
      await settings.savePlayerPresentation(
        collapseSeconds: seconds,
        alwaysExpanded: true,
      );
      final restored = Settings(preferences);
      await restored.init();
      expect(restored.playerCollapseSeconds, seconds);
      expect(restored.playerAlwaysExpanded, isTrue);
    }
    await settings.savePlayerPresentation(
      collapseSeconds: 60,
      alwaysExpanded: false,
    );
    final restored = Settings(preferences);
    await restored.init();
    expect(restored.playerAlwaysExpanded, isFalse);
    expect(restored.playerCollapseSeconds, 60);
  });

  test('persists and clears the selected music reward id', () async {
    final preferences = testPreferences({});
    final settings = Settings(preferences);
    await settings.init();

    await settings.saveMusicRewardId(' reward-42 ');

    expect(settings.musicRewardId, 'reward-42');
    final restored = Settings(preferences);
    await restored.init();
    expect(restored.musicRewardId, 'reward-42');

    await restored.saveMusicRewardId(null);
    final cleared = Settings(preferences);
    await cleared.init();
    expect(cleared.musicRewardId, isNull);
  });

  test(
    'Twitch login waits for persistence before updating and emitting',
    () async {
      testPreferences();
      final preferences = _DelayedPreferences();
      final settings = Settings(preferences);
      await settings.init();
      final credentials = TwitchCreds(
        accessToken: 'token',
        refreshToken: 'refresh',
        broadcasterId: 'channel',
        clientId: 'client',
      );
      final changed = settings.twitchAuthChanges.first;
      final saving = settings.saveTwitchAuth(credentials);
      expect(settings.twitchAuth, isNull);
      preferences.write.complete();
      await saving;
      expect(await changed, credentials);
      final restored = Settings(preferences);
      await restored.init();
      expect(restored.twitchAuth?.toJson(), credentials.toJson());
    },
  );

  test(
    'failed storage write preserves music settings and emits no change',
    () async {
      testPreferences();
      final preferences = _DelayedPreferences();
      final settings = Settings(preferences);
      await settings.init();
      final before = settings.music;
      final changes = <MusicSettings>[];
      final subscription = settings.musicChanges.listen(changes.add);
      addTearDown(subscription.cancel);
      final saving = settings.saveMusic(before.copyWith(volumePercent: 25));
      final failed = expectLater(saving, throwsStateError);
      preferences.write.completeError(StateError('disk full'));
      await failed;
      expect(settings.music, before);
      expect(changes, isEmpty);
    },
  );
}

class _DelayedPreferences extends SharedPreferencesAsync {
  final write = Completer<void>();

  @override
  Future<void> setString(String key, String value) async {
    await write.future;
    await super.setString(key, value);
  }
}
