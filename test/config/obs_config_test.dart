import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/obs_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('uses fallback JSON after a malformed OBS response', () async {
    const channel = BasicMessageChannel<String>('obs_config', StringCodec());
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockDecodedMessageHandler(
      channel,
      (_) async => '{not-valid-json',
    );
    addTearDown(
      () => messenger.setMockDecodedMessageHandler<String>(channel, null),
    );

    final config = ObsConfig();
    await config.init();

    expect(config.config.current.valid, isFalse);
    expect(
      config.getString('music_reward_title', fallback: 'Other'),
      'Play Music',
    );
    expect(config.getInt('music_max_queue', fallback: 1), 10);
    expect(config.getInt('music_cache_max_mb', fallback: 1), 2048);
  });

  group('ObsConfig.getBool', () {
    test('uses fallback JSON when configuration is invalid', () {
      final config = ObsConfig();

      expect(config.getBool('followers'), isTrue);
      expect(config.getBool('music_enabled', fallback: false), isTrue);
      expect(config.getBool('subscriptions'), isFalse);
      expect(config.getBool('subscriptions', fallback: true), isTrue);
    });

    test('honors explicit values', () {
      final config = ObsConfig();
      config.config.set(
        Config(valid: true, json: {'followers': false, 'subscriptions': true}),
      );

      expect(config.getBool('followers'), isFalse);
      expect(config.getBool('subscriptions'), isTrue);
    });

    test('uses the fallback for a missing option in valid configuration', () {
      final config = ObsConfig();
      config.config.set(Config(valid: true, json: <String, bool>{}));

      expect(config.getBool('followers', fallback: false), isFalse);
      expect(config.getBool('followers', fallback: true), isTrue);
    });

    test('uses the fallback for malformed data marked as valid', () {
      final config = ObsConfig();
      config.config.set(Config(valid: true, json: 'not-an-object'));

      expect(config.getBool('followers'), isFalse);
      expect(config.getBool('followers', fallback: true), isTrue);
    });
  });

  group('ObsConfig.getString', () {
    test('uses fallback JSON when configuration is invalid', () {
      final config = ObsConfig();

      expect(
        config.getString('follow_animation_renderer', fallback: 'legacy'),
        'optimized',
      );
      expect(
        config.getString('music_reward_title', fallback: 'Other'),
        'Play Music',
      );
    });

    test('returns a configured string value', () {
      final config = ObsConfig();
      config.config.set(
        Config(valid: true, json: {'follow_animation_renderer': 'legacy'}),
      );

      expect(
        config.getString('follow_animation_renderer', fallback: 'optimized'),
        'legacy',
      );
    });

    test('uses the fallback for a missing or malformed value', () {
      final config = ObsConfig();
      config.config.set(
        Config(valid: true, json: {'follow_animation_renderer': true}),
      );

      expect(
        config.getString('follow_animation_renderer', fallback: 'optimized'),
        'optimized',
      );
    });
  });

  group('ObsConfig.getInt', () {
    test('uses fallback JSON when configuration is invalid', () {
      final config = ObsConfig();

      expect(config.getInt('follow_avatar_resolution', fallback: 24), 48);
      expect(config.getInt('music_max_queue', fallback: 1), 10);
      expect(config.getInt('music_cache_max_mb', fallback: 1), 2048);
    });

    test('returns a configured integer value', () {
      final config = ObsConfig();
      config.config.set(
        Config(valid: true, json: {'follow_avatar_resolution': 40}),
      );

      expect(config.getInt('follow_avatar_resolution', fallback: 48), 40);
    });

    test('uses the fallback for a missing or malformed value', () {
      final config = ObsConfig();
      config.config.set(
        Config(valid: true, json: {'follow_avatar_resolution': '40'}),
      );

      expect(config.getInt('follow_avatar_resolution', fallback: 48), 48);
    });
  });
}
