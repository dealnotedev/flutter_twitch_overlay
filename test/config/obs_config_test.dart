import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/obs_config.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ObsConfig.getBool', () {
    test('enables all options when configuration is invalid', () {
      final config = ObsConfig();

      expect(config.getBool('followers'), isTrue);
      expect(config.getBool('subscriptions'), isTrue);
      expect(config.getBool('raids'), isTrue);
      expect(config.getBool('followers', fallback: false), isTrue);
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
    test('uses the fallback when configuration is invalid', () {
      final config = ObsConfig();

      expect(
        config.getString('follow_animation_renderer', fallback: 'optimized'),
        'optimized',
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
    test('uses the fallback when configuration is invalid', () {
      final config = ObsConfig();

      expect(config.getInt('follow_avatar_resolution', fallback: 48), 48);
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
