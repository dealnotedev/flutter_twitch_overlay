import 'dart:convert';

import 'package:file/memory.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/config/source_preferences.dart';
import 'package:obssource/config/source_profile.dart';
import 'package:obssource/twitch/twitch_creds.dart';
import 'package:path_provider_windows/path_provider_windows.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

const _firstId = '0a123456-1234-4567-89ab-123456789abc';
const _secondId = '0b123456-1234-4567-89ab-123456789abc';

class _Paths extends PathProviderWindows {
  @override
  Future<String?> getApplicationSupportPath() async => r'C:\prefs';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MemoryFileSystem fs;
  SharedPreferencesAsyncPlatform? previousPlatform;

  setUp(() {
    previousPlatform = SharedPreferencesAsyncPlatform.instance;
    fs = MemoryFileSystem(style: FileSystemStyle.windows);
  });

  tearDown(() {
    SharedPreferencesAsyncPlatform.instance = previousPlatform;
  });

  Settings startEngine(List<String> arguments) {
    // Each OBS source owns an engine with a separate platform singleton/cache.
    SharedPreferencesAsyncPlatform.instance =
        SharedPreferencesAsyncWindows()
          ..fs = fs
          ..pathProvider = _Paths();
    return Settings(
      createSourcePreferences(SourceProfile.fromArguments(arguments)),
    );
  }

  Map<String, dynamic> stored(String profile) =>
      jsonDecode(fs.file('C:\\prefs\\source_$profile.json').readAsStringSync())
          as Map<String, dynamic>;

  test(
    'source files isolate all settings across writes and engine restarts',
    () async {
      final a = startEngine([_firstId]);
      final b = startEngine([_secondId]);
      await Future.wait([a.init(), b.init()]);
      final credentials = TwitchCreds(
        accessToken: 'token-a',
        refreshToken: 'refresh-a',
        broadcasterId: 'channel-a',
        clientId: 'client-a',
      );

      Future<void> saveA() async {
        await a.saveTwitchAuth(credentials);
        await a.saveMusic(a.music.copyWith(volumePercent: 25));
        await a.saveMusicRewardId('reward-a');
        await a.savePlayerPresentation(
          collapseSeconds: 11,
          alwaysExpanded: true,
        );
      }

      Future<void> saveB() async {
        await b.saveTwitchAuth(credentials);
        await b.saveMusic(b.music.copyWith(volumePercent: 80));
        await b.saveMusicRewardId('reward-b');
        await b.savePlayerPresentation(
          collapseSeconds: 31,
          alwaysExpanded: false,
        );
        await b.saveTwitchAuth(null);
        await b.saveMusicRewardId(null);
      }

      await Future.wait([saveA(), saveB()]);
      final restoredA = startEngine([_firstId]);
      final restoredB = startEngine([_secondId]);
      await Future.wait([restoredA.init(), restoredB.init()]);
      expect(restoredA.twitchAuth?.toJson(), credentials.toJson());
      expect(restoredA.music.volumePercent, 25);
      expect(restoredA.musicRewardId, 'reward-a');
      expect(restoredA.playerCollapseSeconds, 11);
      expect(restoredA.playerAlwaysExpanded, isTrue);
      expect(restoredB.twitchAuth, isNull);
      expect(restoredB.music.volumePercent, 80);
      expect(restoredB.musicRewardId, isNull);
      expect(restoredB.playerCollapseSeconds, 31);
      expect(restoredB.playerAlwaysExpanded, isFalse);
      expect(
        stored(_firstId).keys,
        containsAll([
          'twitch_credentials',
          'music_settings',
          'music_reward_id',
          'player_collapse_seconds',
          'player_always_expanded',
        ]),
      );
      expect(stored(_secondId), isNot(contains('twitch_credentials')));
      expect(stored(_secondId), isNot(contains('music_reward_id')));
    },
  );

  test(
    'no arguments select a persistent standalone file separate from OBS',
    () async {
      final standalone = startEngine([]);
      final source = startEngine([_firstId]);
      await standalone.init();
      await source.init();
      await standalone.saveMusicRewardId('standalone-reward');
      await source.saveMusicRewardId('source-reward');

      final restored = startEngine([]);
      await restored.init();
      expect(restored.musicRewardId, 'standalone-reward');
      expect(stored('standalone')['music_reward_id'], 'standalone-reward');
      expect(stored(_firstId)['music_reward_id'], 'source-reward');
    },
  );

  test('UUID casing and whitespace select the same file', () async {
    final source = startEngine([' ${_firstId.toUpperCase()} ']);
    await source.init();
    await source.saveMusicRewardId('reward');
    final restored = startEngine([_firstId]);
    await restored.init();
    expect(restored.musicRewardId, 'reward');
    expect(stored(_firstId)['music_reward_id'], 'reward');
  });

  test('invalid source ids cannot select paths or the standalone profile', () {
    for (final id in [
      '',
      'standalone',
      '../other',
      r'..\other',
      '--debug',
      'not-a-uuid',
    ]) {
      expect(() => SourceProfile.fromArguments([id]), throwsArgumentError);
    }
  });

  test('new profiles leave the legacy shared preferences untouched', () async {
    final legacy =
        fs.file(r'C:\prefs\shared_preferences.json')
          ..createSync(recursive: true)
          ..writeAsStringSync('{"flutter.music_reward_id":"legacy-reward"}');
    final before = legacy.readAsStringSync();
    for (final arguments in <List<String>>[
      [],
      [_firstId],
    ]) {
      final settings = startEngine(arguments);
      await settings.init();
      expect(settings.musicRewardId, isNull);
      await settings.saveMusicRewardId('new-reward');
    }
    expect(legacy.readAsStringSync(), before);
  });
}
