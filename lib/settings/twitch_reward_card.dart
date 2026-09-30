import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:intl/intl.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/twitch/twitch_api.dart';

class TwitchRewardCard extends StatefulWidget {
  final TwitchCustomReward reward;
  final bool selected;
  final VoidCallback? onPressed;
  final IconData icon;
  final String? blockedReason;

  const TwitchRewardCard({
    super.key,
    required this.reward,
    required this.selected,
    required this.onPressed,
    this.icon = Icons.music_note_rounded,
    this.blockedReason,
  });

  @override
  State<TwitchRewardCard> createState() => TwitchRewardCardState();
}

class TwitchRewardCardState extends State<TwitchRewardCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final reward = widget.reward;
    final rewardColor =
        HexColor.fromHex(reward.backgroundColor) ?? const Color(0xFF9147FF);
    final active = reward.isEnabled && !reward.isPaused && reward.isInStock;

    return Semantics(
      button: true,
      selected: widget.selected,
      label: '${reward.title}, ${reward.cost}',
      child: MouseRegion(
        cursor:
            widget.onPressed == null
                ? SystemMouseCursors.basic
                : SystemMouseCursors.click,
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
                        Center(
                          child: _RewardImage(
                            image: reward.image,
                            icon: widget.icon,
                          ),
                        ),
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
                        if (!reward.isMusicRequestCompatible ||
                            widget.blockedReason != null)
                          Positioned(
                            top: 7,
                            left: 7,
                            child: Tooltip(
                              message:
                                  widget.blockedReason ??
                                  context
                                      .localizations
                                      .overlay_settings_reward_description,
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
  }
}

class _RewardImage extends StatelessWidget {
  final Uri? image;
  final IconData icon;

  const _RewardImage({
    required this.image,
    this.icon = Icons.music_note_rounded,
  });

  @override
  Widget build(BuildContext context) {
    final image = this.image;
    if (image == null) {
      return Icon(
        icon,
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
      errorWidget: (_, _, _) => _RewardImage(image: null, icon: icon),
    );
  }
}
