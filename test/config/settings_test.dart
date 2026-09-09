import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
