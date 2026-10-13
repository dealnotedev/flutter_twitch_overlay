import 'dart:async';

import 'package:obssource/settings/twitch_reward_picker.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/settings/alert_settings_page.dart';
import 'package:obssource/settings/avatar_settings_controls.dart';
import 'package:obssource/settings/kills_settings_page.dart';

import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/settings/reward_effect_settings_page.dart';
import 'package:obssource/twitch/twitch_api.dart';
import 'package:obssource/settings/neon_settings_controls.dart';
import 'package:obssource/settings/music_settings_controls.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_reward_controller.dart';
import 'package:obssource/music/youtube_connection_controller.dart';

class OverlaySettingsDialog extends StatefulWidget {
  final Settings settings;
  final TwitchRewardCatalog rewardCatalog;
  final MusicControlServerController? musicServer;
  final MusicRewardController? musicRewardController;
  final YoutubeConnectionController? youtubeConnection;
  final MusicRequestManager? musicRequests;

  /// Every channel points reward, for binding effects; `null` without
  /// Twitch.
  final Future<List<TwitchCustomReward>> Function()? loadAllRewards;

  const OverlaySettingsDialog({
    super.key,
    required this.settings,
    required this.rewardCatalog,
    this.musicServer,
    this.musicRewardController,
    this.youtubeConnection,
    this.musicRequests,
    this.loadAllRewards,
  });

  @override
  State<OverlaySettingsDialog> createState() => _OverlaySettingsDialogState();
}

// Player and avatar come first: their indexes are used by the IndexedStack.
enum _SettingsSection {
  player,
  avatar,
  follow,
  raid,
  subscriptions,
  rewardCards,
  chat,
  flashbang,
  crt,
  pause,
  stickers,
  kills,
}

class _OverlaySettingsDialogState extends State<OverlaySettingsDialog> {
  _SettingsSection _section = _SettingsSection.player;
  List<TwitchCustomReward>? _allRewards;
  bool _allRewardsLoading = false;
  bool _allRewardsFailed = false;
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

  Future<void> _loadAllRewards() async {
    final load = widget.loadAllRewards;
    if (load == null) return;
    setState(() {
      _allRewardsLoading = true;
      _allRewardsFailed = false;
    });
    try {
      final rewards = await load();
      if (!mounted) return;
      setState(() => _allRewards = rewards);
    } catch (_) {
      if (mounted) setState(() => _allRewardsFailed = true);
    } finally {
      if (mounted) setState(() => _allRewardsLoading = false);
    }
  }

  void _select(_SettingsSection section) {
    setState(() => _section = section);
    final effects = section.index >= _SettingsSection.flashbang.index;
    if (effects &&
        _allRewards == null &&
        !_allRewardsLoading &&
        !_allRewardsFailed) {
      unawaited(_loadAllRewards());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: LayoutBuilder(
        // Uses the whole overlay: forms and the stream-sized preview need room.
        builder:
            (context, constraints) => SizedBox(
              width: constraints.maxWidth,
              height: constraints.maxHeight,
              child: CosmicMusicSurface(
                width: constraints.maxWidth,
                height: constraints.maxHeight,
                borderRadius: 22,
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    _buildHeader(context),
                    Container(
                      height: 1,
                      color: MusicPlayerPalette.neonPink.withValues(
                        alpha: 0.22,
                      ),
                    ),
                    Expanded(child: _buildBody(context)),
                  ],
                ),
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
    final music =
        _section == _SettingsSection.player ||
        _section == _SettingsSection.avatar;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(width: 214, child: _buildNavigation(context)),
        Container(
          width: 1,
          color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.13),
        ),
        Expanded(
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Kept alive while other pages are open, like before.
              Offstage(
                offstage: !music,
                child: TickerMode(
                  enabled: music,
                  child: IndexedStack(
                    index: music ? _section.index : 0,
                    sizing: StackFit.expand,
                    children: [
                      _buildPlayerSettings(context),
                      SingleChildScrollView(
                        key: const ValueKey('avatar_settings_scroll'),
                        padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
                        child: AvatarSettingsControls(
                          settings: widget.settings,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!music) _buildPage(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPage() {
    final rewards = RewardChoices(
      rewards: _allRewards,
      loading: _allRewardsLoading,
      failed: _allRewardsFailed,
      onRefresh: widget.loadAllRewards == null ? null : _loadAllRewards,
    );
    final key = ValueKey(_section);
    AlertSettingsPage alert(AlertPage page) =>
        AlertSettingsPage(key: key, page: page, settings: widget.settings);
    RewardEffectSettingsPage effect(EffectPage page) =>
        RewardEffectSettingsPage(
          key: key,
          page: page,
          settings: widget.settings,
          rewards: rewards,
        );

    return switch (_section) {
      _SettingsSection.player ||
      _SettingsSection.avatar => const SizedBox.shrink(),
      _SettingsSection.follow => alert(AlertPage.follow),
      _SettingsSection.raid => alert(AlertPage.raid),
      _SettingsSection.subscriptions => alert(AlertPage.subscriptions),
      _SettingsSection.rewardCards => alert(AlertPage.rewardCards),
      _SettingsSection.chat => alert(AlertPage.chat),
      _SettingsSection.flashbang => effect(EffectPage.flashbang),
      _SettingsSection.crt => effect(EffectPage.crt),
      _SettingsSection.pause => effect(EffectPage.pause),
      _SettingsSection.stickers => effect(EffectPage.stickers),
      _SettingsSection.kills => KillsSettingsPage(
        key: key,
        settings: widget.settings,
      ),
    };
  }

  Widget _buildNavigation(BuildContext context) {
    final l = context.localizations;
    return Container(
      color: MusicPlayerPalette.voidBlack.withValues(alpha: 0.38),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _navigationGroup(l.settings_group_overlay, [
              _navigationItem(
                const ValueKey('overlay_settings_player_section'),
                l.overlay_settings_player,
                Icons.graphic_eq_rounded,
                _SettingsSection.player,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_avatar_section'),
                l.overlay_settings_avatar,
                Icons.account_circle_outlined,
                _SettingsSection.avatar,
              ),
            ]),
            const Gap(18),
            _navigationGroup(l.settings_group_alerts, [
              _navigationItem(
                const ValueKey('overlay_settings_follow_section'),
                l.settings_follow,
                Icons.favorite_border_rounded,
                _SettingsSection.follow,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_raid_section'),
                l.settings_raid,
                Icons.groups_rounded,
                _SettingsSection.raid,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_subscriptions_section'),
                l.settings_subscriptions,
                Icons.star_border_rounded,
                _SettingsSection.subscriptions,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_reward_cards_section'),
                l.settings_reward_cards,
                Icons.card_giftcard_rounded,
                _SettingsSection.rewardCards,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_chat_section'),
                l.settings_chat,
                Icons.chat_bubble_outline_rounded,
                _SettingsSection.chat,
              ),
            ]),
            const Gap(18),
            _navigationGroup(l.settings_group_effects, [
              _navigationItem(
                const ValueKey('overlay_settings_flashbang_section'),
                l.settings_flashbang,
                Icons.flash_on_rounded,
                _SettingsSection.flashbang,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_crt_section'),
                l.settings_crt,
                Icons.tv_off_rounded,
                _SettingsSection.crt,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_pause_section'),
                l.settings_pause,
                Icons.pause_circle_outline_rounded,
                _SettingsSection.pause,
              ),
              _navigationItem(
                const ValueKey('overlay_settings_stickers_section'),
                l.settings_stickers,
                Icons.gps_fixed_rounded,
                _SettingsSection.stickers,
              ),
            ]),
            const Gap(18),
            _navigationGroup(l.settings_group_integrations, [
              _navigationItem(
                const ValueKey('overlay_settings_kills_section'),
                l.settings_kills,
                Icons.sports_esports_outlined,
                _SettingsSection.kills,
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _navigationGroup(String title, List<Widget> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Text(
          title.toUpperCase(),
          style: TextStyle(
            color: MusicPlayerPalette.textSecondary.withValues(alpha: 0.65),
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 1.5,
          ),
        ),
      ),
      const Gap(10),
      for (final (index, item) in items.indexed) ...[
        if (index > 0) const Gap(6),
        item,
      ],
    ],
  );

  Widget _navigationItem(
    Key key,
    String label,
    IconData icon,
    _SettingsSection section,
  ) => NeonSettingsButton.section(
    key: key,
    label: label,
    icon: icon,
    selected: _section == section,
    onPressed: () => _select(section),
  );

  Widget _buildPlayerSettings(BuildContext context) {
    return SingleChildScrollView(
      key: const ValueKey('music_settings_scroll'),
      padding: const EdgeInsets.fromLTRB(28, 22, 28, 26),
      child: MusicSettingsControls(
        settings: widget.settings,
        server: widget.musicServer,
        rewardController: widget.musicRewardController,
        youtubeConnection: widget.youtubeConnection,
        musicRequests: widget.musicRequests,
        presentationSettings: _buildPresentationSettings(context),
        rewardSettings: _buildRewardSubsection(context),
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
          NeonSettingsSlider(
            sliderKey: const ValueKey('player_collapse_slider'),
            label: l10n.overlay_settings_collapse_delay,
            value: _collapseSeconds,
            min: 1,
            max: 60,
            formatValue: l10n.overlay_settings_seconds,
            valueLabel: _alwaysExpanded ? '∞' : null,
            onChanged:
                _alwaysExpanded || _savingPresentation
                    ? null
                    : (value) => setState(() => _collapseSeconds = value),
            onChangeEnd:
                _alwaysExpanded || _savingPresentation
                    ? null
                    : (_) => unawaited(_savePresentation()),
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
    onSelected: _selectReward,
    onCreate: _createReward,
    onRefresh: _loadRewards,
  );
}
