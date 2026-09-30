import 'dart:async';

import 'package:obssource/settings/twitch_reward_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';

import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/tts_settings_pane.dart';
import 'package:obssource/tts/tts_controller.dart';

class OverlaySettingsDialog extends StatefulWidget {
  final Settings settings;
  final TwitchRewardCatalog rewardCatalog;
  final TwitchRewardCatalog? ttsRewardCatalog;
  final TtsController? ttsController;

  const OverlaySettingsDialog({
    super.key,
    required this.settings,
    required this.rewardCatalog,
    this.ttsRewardCatalog,
    this.ttsController,
  });

  @override
  State<OverlaySettingsDialog> createState() => _OverlaySettingsDialogState();
}

class _OverlaySettingsDialogState extends State<OverlaySettingsDialog> {
  bool _ttsSelected = false;
  List<TwitchCustomReward> _rewards = const [];
  String? _selectedRewardId;
  Object? _error;
  bool _loading = true;
  bool _creating = false;
  bool _savingReward = false;
  late int _collapseSeconds;
  late bool _alwaysExpanded;
  bool _savingPresentation = false;
  bool _presentationSaveError = false;

  @override
  void initState() {
    super.initState();
    _selectedRewardId = widget.settings.musicRewardId;
    _collapseSeconds = widget.settings.playerCollapseSeconds;
    _alwaysExpanded = widget.settings.playerAlwaysExpanded;
    unawaited(_loadRewards());
  }

  Future<void> _loadRewards() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final rewards = await widget.rewardCatalog.load();
      final selectedId = _selectedRewardId;
      final selectionStillExists =
          selectedId == null ||
          rewards.any(
            (reward) =>
                reward.id == selectedId && reward.isMusicRequestCompatible,
          );
      if (!selectionStillExists) {
        await widget.settings.saveMusicRewardId(null);
      }
      if (!mounted) return;
      setState(() {
        _rewards = rewards;
        _selectedRewardId = selectionStillExists ? selectedId : null;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _createReward() async {
    setState(() {
      _creating = true;
      _error = null;
    });

    try {
      final reward = await widget.rewardCatalog.createDefault();
      await widget.settings.saveMusicRewardId(reward.id);
      if (!mounted) return;
      setState(() {
        _rewards = [
          reward,
          ..._rewards.where((candidate) => candidate.id != reward.id),
        ];
        _selectedRewardId = reward.id;
        _creating = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error;
        _creating = false;
      });
    }
  }

  Future<void> _selectReward(TwitchCustomReward? reward) async {
    final previousId = _selectedRewardId;
    setState(() {
      _selectedRewardId = reward?.id;
      _savingReward = true;
      _error = null;
    });

    try {
      await widget.settings.saveMusicRewardId(reward?.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedRewardId = previousId;
        _error = error;
      });
    } finally {
      if (mounted) setState(() => _savingReward = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: SizedBox(
        width: 1040,
        height: 680,
        child: CosmicMusicSurface(
          width: 1040,
          height: 680,
          borderRadius: 22,
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              _buildHeader(context),
              Container(
                height: 1,
                color: MusicPlayerPalette.neonPink.withValues(alpha: 0.22),
              ),
              Expanded(child: _buildBody(context)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 18, 16),
      child: Row(
        children: [
          const Icon(
            Icons.tune_rounded,
            color: MusicPlayerPalette.neonPinkBright,
            size: 25,
            shadows: MusicPlayerPalette.pinkTextGlow,
          ),
          const Gap(12),
          Expanded(
            child: Text(
              context.localizations.overlay_settings_title,
              style: const TextStyle(
                color: MusicPlayerPalette.textPrimary,
                fontSize: 21,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
          NeonMusicIconButton(
            key: const ValueKey('overlay_settings_close_button'),
            icon: Icons.close_rounded,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 198, child: _buildNavigation(context)),
        Container(
          width: 1,
          color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.13),
        ),
        Expanded(
          child:
              _ttsSelected
                  ? TtsSettingsPane(
                    settings: widget.settings,
                    catalog: widget.ttsRewardCatalog,
                    controller: widget.ttsController,
                  )
                  : _buildPlayerSettings(context),
        ),
      ],
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return Container(
      color: MusicPlayerPalette.voidBlack.withValues(alpha: 0.38),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              context.localizations.overlay_settings_sections.toUpperCase(),
              style: TextStyle(
                color: MusicPlayerPalette.textSecondary.withValues(alpha: 0.65),
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.5,
              ),
            ),
          ),
          const Gap(12),
          NeonSettingsButton.section(
            key: const ValueKey('overlay_settings_player_section'),
            label: context.localizations.overlay_settings_player,
            icon: Icons.graphic_eq_rounded,
            selected: !_ttsSelected,
            onPressed: () => setState(() => _ttsSelected = false),
          ),
          const Gap(10),
          NeonSettingsButton.section(
            key: const ValueKey('overlay_settings_tts_section'),
            label: 'TTS',
            icon: Icons.record_voice_over_rounded,
            selected: _ttsSelected,
            onPressed: () => setState(() => _ttsSelected = true),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSettings(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.localizations.overlay_settings_player,
            style: const TextStyle(
              color: MusicPlayerPalette.neonPinkBright,
              fontFamily: 'Segoe Script',
              fontSize: 22,
              fontStyle: FontStyle.italic,
              shadows: MusicPlayerPalette.pinkTextGlow,
            ),
          ),
          const Gap(4),
          Text(
            context.localizations.overlay_settings_player_description,
            style: const TextStyle(
              color: MusicPlayerPalette.textSecondary,
              fontSize: 13,
            ),
          ),
          const Gap(18),
          _buildPresentationSettings(context),
          const Gap(16),
          _buildRewardSubsection(context),
        ],
      ),
    );
  }

  Future<void> _savePresentation() async {
    setState(() {
      _savingPresentation = true;
      _presentationSaveError = false;
    });
    try {
      await widget.settings.savePlayerPresentation(
        collapseSeconds: _collapseSeconds,
        alwaysExpanded: _alwaysExpanded,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _collapseSeconds = widget.settings.playerCollapseSeconds;
        _alwaysExpanded = widget.settings.playerAlwaysExpanded;
        _presentationSaveError = true;
      });
    } finally {
      if (mounted) setState(() => _savingPresentation = false);
    }
  }

  Widget _buildPresentationSettings(BuildContext context) {
    final l10n = context.localizations;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 10),
      decoration: BoxDecoration(
        color: MusicPlayerPalette.midnight.withValues(alpha: 0.76),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: MusicPlayerPalette.neonPink.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.timer_outlined,
                color: MusicPlayerPalette.neonPinkBright,
                size: 22,
              ),
              const Gap(10),
              Expanded(
                child: Text(
                  l10n.overlay_settings_collapse_title,
                  style: const TextStyle(
                    color: MusicPlayerPalette.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                l10n.overlay_settings_never_collapse,
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Gap(8),
              Switch(
                key: const ValueKey('player_always_expanded_switch'),
                value: _alwaysExpanded,
                activeThumbColor: MusicPlayerPalette.neonPinkBright,
                onChanged:
                    _savingPresentation
                        ? null
                        : (value) {
                          setState(() => _alwaysExpanded = value);
                          unawaited(_savePresentation());
                        },
              ),
            ],
          ),
          Text(
            _alwaysExpanded
                ? l10n.overlay_settings_stays_expanded
                : l10n.overlay_settings_collapse_description,
            style: const TextStyle(
              color: MusicPlayerPalette.textSecondary,
              fontSize: 12,
            ),
          ),
          Row(
            children: [
              Text(
                l10n.overlay_settings_seconds(1),
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
              Expanded(
                child: Slider(
                  key: const ValueKey('player_collapse_slider'),
                  value: _collapseSeconds.toDouble(),
                  min: 1,
                  max: 60,
                  divisions: 59,
                  label: l10n.overlay_settings_seconds(_collapseSeconds),
                  activeColor: MusicPlayerPalette.neonPinkBright,
                  inactiveColor: MusicPlayerPalette.neonPink.withValues(
                    alpha: 0.15,
                  ),
                  onChanged:
                      _alwaysExpanded || _savingPresentation
                          ? null
                          : (value) =>
                              setState(() => _collapseSeconds = value.round()),
                  onChangeEnd: (_) => unawaited(_savePresentation()),
                ),
              ),
              Text(
                l10n.overlay_settings_seconds(60),
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 12,
                ),
              ),
              const Gap(16),
              Container(
                width: 72,
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 6),
                decoration: BoxDecoration(
                  color: MusicPlayerPalette.neonPink.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _alwaysExpanded
                      ? '∞'
                      : l10n.overlay_settings_seconds(_collapseSeconds),
                  style: const TextStyle(
                    color: MusicPlayerPalette.neonPinkBright,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (_presentationSaveError)
            Text(
              l10n.overlay_settings_save_error,
              style: const TextStyle(
                color: MusicPlayerPalette.error,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildRewardSubsection(BuildContext context) => TwitchRewardPicker(
    rewards: _rewards,
    selectedId: _selectedRewardId,
    description: context.localizations.overlay_settings_reward_description,
    emptyDescription: context.localizations.overlay_settings_no_rewards_body,
    keyPrefix: 'overlay_settings',
    loading: _loading,
    creating: _creating,
    enabled: !_savingReward,
    error: _error?.toString(),
    blockedReason:
        (reward) =>
            reward.id == widget.settings.tts.rewardId
                ? context.localizations.tts_reward_conflict
                : null,
    onSelected: _selectReward,
    onCreate: _createReward,
    onRefresh: _loadRewards,
  );
}
