import 'package:obssource/config/source_profile.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_windows/shared_preferences_windows.dart';

/// Creates the preferences for this engine's source, or the standalone profile.
///
/// On Windows, each profile has its own file. Create this once per engine:
/// shared_preferences_windows caches one file per engine's platform instance.
SharedPreferencesAsync createSourcePreferences(SourceProfile profile) {
  return SharedPreferencesAsync(
    options: SharedPreferencesWindowsOptions(fileName: 'source_${profile.id}'),
  );
}
