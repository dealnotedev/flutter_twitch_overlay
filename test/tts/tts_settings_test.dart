import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('reads stored mood strings and defaults unknown values to neutral', () {
    expect(TtsSettings.fromJson({'mood': 'calm'}).mood, TtsMood.calm);
    expect(TtsSettings.fromJson({'mood': 'lively'}).mood, TtsMood.lively);
    expect(TtsSettings.fromJson({'mood': 'unknown'}).mood, TtsMood.neutral);
    expect(TtsSettings.fromJson({}).mood, TtsMood.neutral);
  });

  test(
    'persists all TTS settings, normalizes base and rejects reward reuse',
    () async {
      SharedPreferences.setMockInitialValues({});
      final settings = Settings();
      await settings.init();
      expect(settings.tts.enabled, isFalse);
      expect(settings.tts.volumePercent, 100);
      await settings.saveTts(
        const TtsSettings(
          enabled: true,
          baseUrl: 'https://example.test/tts/v1/',
          mood: TtsMood.lively,
          volumePercent: 35,
          rewardId: 'tts',
          broadcasterId: 'channel',
        ),
      );
      final restored = Settings();
      await restored.init();
      expect(restored.tts.toJson(), {
        'enabled': true,
        'baseUrl': 'https://example.test/tts/v1',
        'mood': 'lively',
        'volumePercent': 35,
        'rewardId': 'tts',
        'broadcasterId': 'channel',
      });
      await expectLater(restored.saveMusicRewardId('tts'), throwsStateError);
      await restored.saveMusicRewardId('music');
      await expectLater(
        restored.saveTts(restored.tts.copyWith(rewardId: 'music')),
        throwsStateError,
      );
    },
  );

  test('updates the old default URL and preserves a custom API version', () {
    expect(TtsSettings.fromJson({}).volumePercent, 100);
    expect(
      TtsSettings.fromJson({
        'baseUrl': 'https://api.teamplay.com.ua/tts/',
      }).baseUrl,
      TtsSettings.defaultBaseUrl,
    );
    expect(
      TtsSettings.fromJson({
        'baseUrl': 'https://example.test/proxy/v2/',
      }).baseUrl,
      'https://example.test/proxy/v2',
    );
  });

  test('speech volume is bounded and zero is preserved', () async {
    SharedPreferences.setMockInitialValues({});
    final settings = Settings();
    await settings.saveTts(const TtsSettings(volumePercent: 300));
    expect(settings.tts.volumePercent, 200);
    final amplified = Settings();
    await amplified.init();
    expect(amplified.tts.volumePercent, 200);
    expect(TtsSettings.fromJson({'volumePercent': 350}).volumePercent, 200);
    await settings.saveTts(const TtsSettings(volumePercent: -1));
    final restored = Settings();
    await restored.init();
    expect(restored.tts.volumePercent, 0);
  });
}
