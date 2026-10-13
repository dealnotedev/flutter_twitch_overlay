import 'package:flutter/foundation.dart';
import 'package:obssource/obs_audio.dart';

/// Plays alert sounds; separated so previews can stay silent.
abstract interface class AlertAudio {
  Future<void> play(String asset, {int volumePercent = 100});
}

/// Plays through the OBS source, i.e. on stream.
class ObsAlertAudio implements AlertAudio {
  const ObsAlertAudio();

  @override
  Future<void> play(String asset, {int volumePercent = 100}) async {
    try {
      final sound = await ObsAudio.loadAsset(asset);
      await ObsAudio.play(sound, volume: volumePercent / 100);
    } catch (error) {
      debugPrint('Could not play $asset: $error');
    }
  }
}

class SilentAlertAudio implements AlertAudio {
  const SilentAlertAudio();

  @override
  Future<void> play(String asset, {int volumePercent = 100}) async {}
}
