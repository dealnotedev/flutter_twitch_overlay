import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/twitch_reward_card.dart';
import 'package:obssource/twitch/twitch_api.dart';

/// Shared presentation and selection behavior for music and TTS rewards.
class TwitchRewardPicker extends StatelessWidget {
  final List<TwitchCustomReward> rewards;
  final String? selectedId;
  final String description;
  final String emptyDescription;
  final String keyPrefix;
  final IconData rewardIcon;
  final String? Function(TwitchCustomReward) blockedReason;
  final ValueChanged<TwitchCustomReward?> onSelected;
  final VoidCallback? onCreate;
  final VoidCallback? onRefresh;
  final bool loading;
  final bool creating;
  final bool enabled;
  final String? error;

  const TwitchRewardPicker({
    super.key,
    required this.rewards,
    required this.selectedId,
    required this.description,
    required this.emptyDescription,
    required this.keyPrefix,
    required this.blockedReason,
    required this.onSelected,
    required this.onCreate,
    required this.onRefresh,
    this.rewardIcon = Icons.music_note_rounded,
    this.loading = false,
    this.creating = false,
    this.enabled = true,
    this.error,
  });

  bool get _interactive => enabled && !loading && !creating;

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: MusicPlayerPalette.midnight.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.18),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.overlay_settings_reward_title,
                        style: const TextStyle(
                          color: MusicPlayerPalette.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const Gap(4),
                      Text(
                        description,
                        style: const TextStyle(
                          color: MusicPlayerPalette.textSecondary,
                          height: 1.3,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap(16),
                NeonSettingsButton(
                  key: ValueKey('${keyPrefix}_create_reward'),
                  icon: Icons.add_rounded,
                  label: l.overlay_settings_create_reward,
                  busy: creating,
                  onPressed: _interactive ? onCreate : null,
                ),
                const Gap(16),
                NeonSettingsButton(
                  key: ValueKey('${keyPrefix}_refresh_rewards'),
                  icon: Icons.refresh_rounded,
                  label: l.overlay_settings_refresh_rewards,
                  busy: loading,
                  onPressed: _interactive ? onRefresh : null,
                ),
              ],
            ),
          ),
          Container(
            height: 1,
            color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.10),
          ),
          _buildContent(context),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final l = context.localizations;
    if (loading && rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.auto_awesome_rounded,
        label: l.overlay_settings_loading_rewards,
        loading: true,
      );
    }
    if (error != null && rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        label: l.overlay_settings_load_error,
        detail: error,
      );
    }
    if (rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.loyalty_outlined,
        label: l.overlay_settings_no_rewards_title,
        detail: emptyDescription,
      );
    }
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            key: ValueKey('${keyPrefix}_reward_wrap'),
            spacing: 16,
            runSpacing: 16,
            children: [for (final reward in rewards) _buildCard(reward)],
          ),
          if (error != null) ...[const Gap(12), _InlineError(message: error!)],
        ],
      ),
    );
  }

  Widget _buildCard(TwitchCustomReward reward) {
    final selected = reward.id == selectedId;
    final blocked = blockedReason(reward);
    final selectable =
        selected || (reward.isMusicRequestCompatible && blocked == null);
    return TwitchRewardCard(
      key: ValueKey('${keyPrefix}_reward_${reward.id}'),
      reward: reward,
      icon: rewardIcon,
      selected: selected,
      blockedReason: blocked,
      onPressed:
          _interactive && selectable
              ? () => onSelected(selected ? null : reward)
              : null,
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? detail;
  final bool loading;

  const _CenteredMessage({
    required this.icon,
    required this.label,
    this.detail,
    this.loading = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (loading)
                const SizedBox(
                  width: 34,
                  height: 34,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    color: MusicPlayerPalette.neonPink,
                  ),
                )
              else
                Icon(icon, color: MusicPlayerPalette.neonPink, size: 38),
              const Gap(12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: MusicPlayerPalette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (detail != null) ...[
                const Gap(6),
                Text(
                  detail!,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: MusicPlayerPalette.textSecondary,
                    fontSize: 11,
                    height: 1.35,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;

  const _InlineError({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF3A102F).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: MusicPlayerPalette.error.withValues(alpha: 0.55),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: MusicPlayerPalette.error,
            size: 18,
          ),
          const Gap(8),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MusicPlayerPalette.textPrimary,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
