import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/config/settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
