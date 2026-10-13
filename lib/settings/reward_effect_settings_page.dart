import 'dart:async';

import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/config/reward_effects_settings.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/l10n/app_localizations.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/preview/effect_preview.dart';
import 'package:obssource/settings/preview/effect_samples.dart';
import 'package:obssource/settings/settings_page_layout.dart';
import 'package:obssource/twitch/twitch_api.dart';

enum EffectPage { flashbang, crt, pause, stickers }

/// Channel points rewards of the channel, loaded by the settings dialog.
class RewardChoices {
  /// `null` while unavailable, e.g. before connecting Twitch.
  final List<TwitchCustomReward>? rewards;
  final bool loading;
  final bool failed;
  final VoidCallback? onRefresh;

  const RewardChoices({
    required this.rewards,
    this.loading = false,
    this.failed = false,
    this.onRefresh,
  });
}

/// Settings of one channel points effect with its preview.
class RewardEffectSettingsPage extends StatefulWidget {
  final EffectPage page;
  final Settings settings;
  final RewardChoices rewards;

  const RewardEffectSettingsPage({
    super.key,
    required this.page,
    required this.settings,
    required this.rewards,
  });

  @override
  State<RewardEffectSettingsPage> createState() =>
      _RewardEffectSettingsPageState();
}

class _RewardEffectSettingsPageState extends State<RewardEffectSettingsPage> {
  late final StreamSubscription<RewardEffectsSettings> _subscription;
  final _drafts = <String, int>{};
  bool _saving = false;
  bool _saveError = false;

  RewardEffectsSettings get _effects => widget.settings.rewardEffects;

  @override
  void initState() {
    super.initState();
    _subscription = widget.settings.rewardEffectsChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    super.dispose();
  }

  Future<void> _save(
    RewardEffectsSettings Function(RewardEffectsSettings) update,
  ) async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _saveError = false;
    });
    try {
      await widget.settings.saveRewardEffects(update(_effects));
    } catch (_) {
      if (mounted) _saveError = true;
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _drafts.clear();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final (title, description) = switch (widget.page) {
      EffectPage.flashbang => (
        l.settings_flashbang,
        l.settings_flashbang_description,
      ),
      EffectPage.crt => (l.settings_crt, l.settings_crt_description),
      EffectPage.pause => (l.settings_pause, l.settings_pause_description),
      EffectPage.stickers => (
        l.settings_stickers,
        l.settings_stickers_description,
      ),
    };

    return SettingsPageLayout(
      scrollKey: ValueKey('effect_settings_${widget.page.name}'),
      form: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonSettingsHeader(title: title, description: description),
          const Gap(18),
          ..._cards(l),
          if (_saveError) ...[
            const Gap(10),
            Text(
              l.overlay_settings_save_error,
              style: const TextStyle(
                color: MusicPlayerPalette.error,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      preview: EffectPreview(
        settings: widget.settings,
        samples: switch (widget.page) {
          EffectPage.flashbang => EffectSamples.flashbang(l),
          EffectPage.crt => EffectSamples.crt(l),
          EffectPage.pause => EffectSamples.pause(l),
          EffectPage.stickers => EffectSamples.stickers(l),
        },
        screenAttack: widget.page == EffectPage.stickers,
      ),
    );
  }

  List<Widget> _cards(AppLocalizations l) {
    final effects = _effects;
    return switch (widget.page) {
      EffectPage.flashbang => [
        _bindingCard(l, RewardAction.flashbang, sound: true),
        const Gap(14),
        NeonSettingsCard(
          child: _slider(
            'flashbang_pro_chance',
            l.flashbang_pro_chance,
            effects.flashbangProChancePercent,
            0,
            100,
            (v) => l.settings_percent(v),
            (e, v) => e.copyWith(flashbangProChancePercent: v),
            step: 5,
          ),
        ),
      ],
      EffectPage.crt => [
        _bindingCard(l, RewardAction.crt, sound: true),
        const Gap(14),
        NeonSettingsCard(
          child: _slider(
            'crt_seconds',
            l.settings_duration,
            effects.crtSeconds,
            RewardEffectsSettings.minCrtSeconds,
            RewardEffectsSettings.maxCrtSeconds,
            l.overlay_settings_seconds,
            (e, v) => e.copyWith(crtSeconds: v),
            step: 5,
          ),
        ),
      ],
      EffectPage.pause => [
        _bindingCard(l, RewardAction.pause),
        const Gap(14),
        NeonSettingsCard(
          child: _slider(
            'pause_max_minutes',
            l.pause_max,
            effects.pauseMaxMinutes,
            1,
            RewardEffectsSettings.maxPauseMinutes,
            l.settings_minutes,
            (e, v) => e.copyWith(pauseMaxMinutes: v),
          ),
        ),
      ],
      EffectPage.stickers => [
        _bindingCard(l, RewardAction.sticker, title: l.sticker_reward),
        const Gap(14),
        _bindingCard(l, RewardAction.crosshair, title: l.crosshair_reward),
        const Gap(14),
        NeonSettingsCard(
          child: _slider(
            'crosshair_seconds',
            l.crosshair_duration,
            effects.crosshairSeconds,
            RewardEffectsSettings.minCrosshairSeconds,
            RewardEffectsSettings.maxCrosshairSeconds,
            l.overlay_settings_seconds,
            (e, v) => e.copyWith(crosshairSeconds: v),
            step: 5,
          ),
        ),
      ],
    };
  }

  Widget _bindingCard(
    AppLocalizations l,
    RewardAction action, {
    String? title,
    bool sound = false,
  }) {
    final binding = _effects.binding(action);
    RewardEffectsSettings update(
      RewardEffectsSettings effects,
      RewardEffectBinding Function(RewardEffectBinding) change,
    ) => effects.withBinding(action, change(effects.binding(action)));

    return NeonSettingsCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          NeonSettingsSwitch(
            switchKey: ValueKey('${action.name}_enabled'),
            label: title ?? l.settings_enabled,
            value: binding.enabled,
            onChanged:
                _saving
                    ? null
                    : (value) => unawaited(
                      _save(
                        (e) => update(e, (b) => b.copyWith(enabled: value)),
                      ),
                    ),
          ),
          const Gap(10),
          RewardBindingSelector(
            keyPrefix: '${action.name}_reward',
            binding: binding,
            choices: widget.rewards,
            excludedIds: {if (widget.settings.musicRewardId case final id?) id},
            onSelected:
                _saving
                    ? null
                    : (reward) => unawaited(
                      _save(
                        (e) => update(
                          e,
                          (b) => b.withReward(
                            id: reward?.id,
                            title: reward?.title,
                          ),
                        ),
                      ),
                    ),
          ),
          if (sound) ...[
            const Gap(14),
            _slider(
              '${action.name}_volume',
              l.settings_volume,
              binding.volumePercent,
              0,
              100,
              (v) => l.settings_percent(v),
              (e, v) => update(e, (b) => b.copyWith(volumePercent: v)),
              step: 5,
            ),
          ],
        ],
      ),
    );
  }

  Widget _slider(
    String key,
    String label,
    int value,
    int min,
    int max,
    String Function(int) format,
    RewardEffectsSettings Function(RewardEffectsSettings, int) update, {
    int step = 1,
  }) => NeonSettingsSlider(
    sliderKey: ValueKey(key),
    label: label,
    value: (_drafts[key] ?? value).clamp(min, max),
    min: min,
    max: max,
    step: step,
    formatValue: format,
    onChanged: _saving ? null : (v) => setState(() => _drafts[key] = v),
    onChangeEnd: _saving ? null : (v) => unawaited(_save((e) => update(e, v))),
  );
}

/// Picks the Twitch reward that triggers an effect.
class RewardBindingSelector extends StatelessWidget {
  final String keyPrefix;
  final RewardEffectBinding binding;
  final RewardChoices choices;

  /// Rewards handled elsewhere, e.g. music requests.
  final Set<String> excludedIds;
  final ValueChanged<TwitchCustomReward?>? onSelected;

  const RewardBindingSelector({
    super.key,
    required this.keyPrefix,
    required this.binding,
    required this.choices,
    this.excludedIds = const {},
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.localizations;
    final rewards = [
      for (final reward in choices.rewards ?? const <TwitchCustomReward>[])
        if (!excludedIds.contains(reward.id)) reward,
    ];
    final missing =
        binding.isBound &&
        choices.rewards != null &&
        rewards.every((reward) => reward.id != binding.rewardId);

    final String? status;
    if (choices.loading) {
      status = l.overlay_settings_loading_rewards;
    } else if (choices.failed) {
      status = l.overlay_settings_load_error;
    } else if (choices.rewards == null) {
      status = l.effect_rewards_unavailable;
    } else {
      status = null;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.effect_reward,
                style: const TextStyle(
                  color: MusicPlayerPalette.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (choices.onRefresh case final refresh?)
              NeonMusicIconButton(
                key: ValueKey('${keyPrefix}_refresh'),
                icon: Icons.refresh_rounded,
                size: 30,
                onPressed: choices.loading ? null : refresh,
              ),
          ],
        ),
        const Gap(8),
        Wrap(
          spacing: 24,
          runSpacing: 8,
          children: [
            NeonSettingsButton(
              key: ValueKey('${keyPrefix}_none'),
              label: l.effect_reward_none,
              selected: !binding.isBound,
              onPressed: onSelected == null ? null : () => onSelected!(null),
            ),
            for (final reward in rewards)
              NeonSettingsButton(
                key: ValueKey('${keyPrefix}_${reward.id}'),
                label: '${reward.title} · ${reward.cost}',
                selected: reward.id == binding.rewardId,
                onPressed:
                    onSelected == null ? null : () => onSelected!(reward),
              ),
            if (binding.isBound && (missing || choices.rewards == null))
              NeonSettingsButton(
                key: ValueKey('${keyPrefix}_bound'),
                label:
                    missing
                        ? l.effect_reward_missing(
                          binding.rewardTitle ?? binding.rewardId!,
                        )
                        : binding.rewardTitle ?? binding.rewardId!,
                selected: true,
                onPressed: null,
              ),
          ],
        ),
        if (status != null) ...[
          const Gap(6),
          Text(
            status,
            style: TextStyle(
              color:
                  choices.failed
                      ? MusicPlayerPalette.error
                      : MusicPlayerPalette.textSecondary,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}
