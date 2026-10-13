import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/twitch/twitch_api.dart';

/// Binds rewards of an upgraded master installation by their old titles.
///
/// Runs once after the first successful reward list; unmatched effects stay
/// unbound and are configured in the settings screen.
class LegacyRewardBinder {
  final Settings settings;
  final Future<List<TwitchCustomReward>> Function() loadRewards;
  bool _running = false;

  LegacyRewardBinder({required this.settings, required this.loadRewards});

  Future<void> run() async {
    if (!settings.legacyRewardTitlesPending || _running) return;
    _running = true;
    try {
      final rewards = await loadRewards();
      var effects = settings.rewardEffects;
      for (final action in RewardAction.values) {
        final binding = effects.binding(action);
        if (binding.isBound) continue;
        for (final reward in rewards) {
          if (reward.title != action.legacyTitle) continue;
          effects = effects.withBinding(
            action,
            binding.withReward(id: reward.id, title: reward.title),
          );
          break;
        }
      }
      await settings.saveRewardEffects(effects);
      await settings.completeLegacyRewardTitles();
    } finally {
      _running = false;
    }
  }
}
