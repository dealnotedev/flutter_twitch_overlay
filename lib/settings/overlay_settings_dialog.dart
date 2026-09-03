import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:obssource/config/settings.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/twitch/twitch_api.dart';

class OverlaySettingsDialog extends StatefulWidget {
  final Settings settings;
  final TwitchRewardCatalog rewardCatalog;

  const OverlaySettingsDialog({
    super.key,
    required this.settings,
    required this.rewardCatalog,
  });

  @override
  State<OverlaySettingsDialog> createState() => _OverlaySettingsDialogState();
}

class _OverlaySettingsDialogState extends State<OverlaySettingsDialog> {
  List<TwitchCustomReward> _rewards = const [];
  String? _selectedRewardId;
  Object? _error;
  bool _loading = true;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    _selectedRewardId = widget.settings.musicRewardId;
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
          rewards.any((reward) => reward.id == selectedId);
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

  Future<void> _selectReward(TwitchCustomReward reward) async {
    final previousId = _selectedRewardId;
    setState(() {
      _selectedRewardId = reward.id;
      _error = null;
    });

    try {
      await widget.settings.saveMusicRewardId(reward.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _selectedRewardId = previousId;
        _error = error;
      });
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
        Expanded(child: _buildPlayerSettings(context)),
      ],
    );
  }

  Widget _buildNavigation(BuildContext context) {
    return Container(
      color: MusicPlayerPalette.voidBlack.withValues(alpha: 0.38),
      padding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Container(
            key: const ValueKey('overlay_settings_player_section'),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
            decoration: BoxDecoration(
              color: MusicPlayerPalette.neonPink.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: MusicPlayerPalette.neonPink.withValues(alpha: 0.42),
              ),
              boxShadow: [
                BoxShadow(
                  color: MusicPlayerPalette.neonPink.withValues(alpha: 0.13),
                  blurRadius: 14,
                ),
              ],
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.graphic_eq_rounded,
                  size: 19,
                  color: MusicPlayerPalette.neonPinkBright,
                ),
                const Gap(9),
                Text(
                  context.localizations.overlay_settings_player,
                  style: const TextStyle(
                    color: MusicPlayerPalette.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerSettings(BuildContext context) {
    return Padding(
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
          _buildRewardSubsection(context),
        ],
      ),
    );
  }

  Widget _buildRewardSubsection(BuildContext context) {
    final actionsEnabled = !_loading && !_creating;

    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: MusicPlayerPalette.midnight.withValues(alpha: 0.76),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.18),
          ),
        ),
        child: Column(
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
                          context.localizations.overlay_settings_reward_title,
                          style: const TextStyle(
                            color: MusicPlayerPalette.textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const Gap(4),
                        Text(
                          context
                              .localizations
                              .overlay_settings_reward_description,
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
                  _SettingsAction(
                    key: const ValueKey('overlay_settings_create_reward'),
                    icon: Icons.add_rounded,
                    label: context.localizations.overlay_settings_create_reward,
                    busy: _creating,
                    onPressed: actionsEnabled ? _createReward : null,
                  ),
                  const Gap(16),
                  _SettingsAction(
                    key: const ValueKey('overlay_settings_refresh_rewards'),
                    icon: Icons.refresh_rounded,
                    label:
                        context.localizations.overlay_settings_refresh_rewards,
                    busy: _loading,
                    onPressed: actionsEnabled ? _loadRewards : null,
                  ),
                ],
              ),
            ),
            Container(
              height: 1,
              color: MusicPlayerPalette.neonBlue.withValues(alpha: 0.10),
            ),
            Expanded(child: _buildRewardContent(context)),
          ],
        ),
      ),
    );
  }

  Widget _buildRewardContent(BuildContext context) {
    if (_loading && _rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.auto_awesome_rounded,
        label: context.localizations.overlay_settings_loading_rewards,
        loading: true,
      );
    }

    if (_error != null && _rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.cloud_off_rounded,
        label: context.localizations.overlay_settings_load_error,
        detail: _error.toString(),
      );
    }

    if (_rewards.isEmpty) {
      return _CenteredMessage(
        icon: Icons.loyalty_outlined,
        label: context.localizations.overlay_settings_no_rewards_title,
        detail: context.localizations.overlay_settings_no_rewards_body,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Wrap(
              key: const ValueKey('overlay_settings_reward_wrap'),
              spacing: 16,
              runSpacing: 16,
              children: [
                for (final reward in _rewards)
                  _TwitchRewardCard(
                    key: ValueKey('twitch_reward_${reward.id}'),
                    reward: reward,
                    selected: reward.id == _selectedRewardId,
                    onPressed: () => _selectReward(reward),
                  ),
              ],
            ),
          ),
        ),
        if (_error != null)
          Positioned(
            left: 20,
            right: 20,
            bottom: 12,
            child: _InlineError(message: _error.toString()),
          ),
        if (_loading || _creating)
          const Positioned(
            top: 10,
            right: 14,
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MusicPlayerPalette.neonPink,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  const _SettingsAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    required this.busy,
  });

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor:
          onPressed == null
              ? SystemMouseCursors.basic
              : SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            NeonMusicIconButton(
              icon: busy ? Icons.more_horiz_rounded : icon,
              onPressed: onPressed,
              size: 34,
            ),
            const Gap(7),
            Text(
              label,
              style: TextStyle(
                color:
                    onPressed == null
                        ? MusicPlayerPalette.textSecondary.withValues(
                          alpha: 0.45,
                        )
                        : MusicPlayerPalette.neonPinkBright,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TwitchRewardCard extends StatefulWidget {
  final TwitchCustomReward reward;
  final bool selected;
  final VoidCallback onPressed;

  const _TwitchRewardCard({
    super.key,
    required this.reward,
    required this.selected,
    required this.onPressed,
  });

  @override
  State<_TwitchRewardCard> createState() => _TwitchRewardCardState();
}

class _TwitchRewardCardState extends State<_TwitchRewardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    final rewardColor =
        HexColor.fromHex(reward.backgroundColor) ?? const Color(0xFF9147FF);
    final active = reward.isEnabled && !reward.isPaused && reward.isInStock;

    final card = Semantics(
      button: true,
      selected: widget.selected,
      label: '${reward.title}, ${reward.cost}',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 178,
            height: 174,
            transform: _hovered ? Matrix4.translationValues(0, -3, 0) : null,
            decoration: BoxDecoration(
              color: const Color(0xFF18181B),
              borderRadius: BorderRadius.circular(7),
              border: Border.all(
                width: widget.selected ? 2 : 1,
                color:
                    widget.selected
                        ? MusicPlayerPalette.neonPinkBright
                        : Colors.white.withValues(
                          alpha: _hovered ? 0.30 : 0.12,
                        ),
              ),
              boxShadow: [
                BoxShadow(
                  color:
                      widget.selected
                          ? MusicPlayerPalette.neonPink.withValues(alpha: 0.42)
                          : Colors.black.withValues(alpha: 0.36),
                  blurRadius: widget.selected ? 18 : (_hovered ? 13 : 8),
                  spreadRadius: widget.selected ? 1 : 0,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ColoredBox(color: rewardColor),
                        Center(child: _RewardImage(image: reward.image)),
                        if (!active)
                          ColoredBox(
                            color: Colors.black.withValues(alpha: 0.48),
                          ),
                        if (widget.selected)
                          Positioned(
                            top: 7,
                            right: 7,
                            child: Container(
                              width: 25,
                              height: 25,
                              decoration: const BoxDecoration(
                                color: MusicPlayerPalette.neonPink,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: MusicPlayerPalette.neonPink,
                                    blurRadius: 10,
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 18,
                              ),
                            ),
                          ),
                        if (!reward.isMusicRequestCompatible)
                          Positioned(
                            top: 7,
                            left: 7,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF18181B,
                                ).withValues(alpha: 0.90),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Icon(
                                Icons.warning_amber_rounded,
                                color: Color(0xFFFFC94A),
                                size: 18,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Container(
                    height: 68,
                    padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                    color: const Color(0xFF18181B),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reward.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color:
                                active
                                    ? Colors.white
                                    : Colors.white.withValues(alpha: 0.55),
                            fontSize: 12,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Image.asset(
                              Assets.assetsIcTwitchChannelPosints32dp,
                              width: 15,
                              height: 15,
                            ),
                            const Gap(5),
                            Text(
                              NumberFormat.decimalPattern().format(reward.cost),
                              style: TextStyle(
                                color:
                                    active
                                        ? const Color(0xFFBF94FF)
                                        : Colors.white.withValues(alpha: 0.45),
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    return card;
  }
}

class _RewardImage extends StatelessWidget {
  final Uri? image;

  const _RewardImage({required this.image});

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) {
      return const Icon(
        Icons.music_note_rounded,
        color: Colors.white,
        size: 58,
        shadows: [Shadow(color: Colors.black38, blurRadius: 8)],
      );
    }

    return CachedNetworkImage(
      imageUrl: image.toString(),
      width: 72,
      height: 72,
      fit: BoxFit.contain,
      errorWidget: (_, _, _) => const _RewardImage(image: null),
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
    return Center(
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
