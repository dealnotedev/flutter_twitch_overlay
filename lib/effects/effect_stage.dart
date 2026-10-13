import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/reward_card.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/raid/raid_widget.dart';
import 'package:obssource/subs/subscription_text.dart';

/// Draws everything an [EffectRuntime] currently shows, in a fixed layer
/// order. Used by the live overlay and by the settings preview.
class EffectStage extends StatelessWidget {
  final EffectRuntime runtime;

  /// Size of the whole overlay canvas; effects lay out against it.
  final BoxConstraints constraints;
  final AvatarSettings avatar;

  /// Drawn above alerts, e.g. the music player.
  final Widget? foreground;

  const EffectStage({
    super.key,
    required this.runtime,
    required this.constraints,
    this.avatar = const AvatarSettings(),
    this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: runtime,
      builder: (context, _) {
        final stage = runtime.stage;
        return Stack(
          children: [
            _buildRewardCards(),
            if (stage != null) _buildStage(context, stage),
            if (foreground case final foreground?) foreground,
          ],
        );
      },
    );
  }

  Widget _buildRewardCards() {
    final cards = runtime.rewardCards;
    return AnimatedListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      items: cards,
      itemBuilder: (context, index) {
        final card = cards[index];
        return RewardCard(event: card, key: ValueKey(card.id));
      },
      enterTransition: [SlideInLeft()],
      exitTransition: [SlideInLeft()],
      isSameItem: (a, b) => a.id == b.id,
    );
  }

  Widget _buildStage(BuildContext context, StageAlert alert) {
    return switch (alert) {
      FollowStageAlert(:final event) => FollowWidget(
        key: ObjectKey(alert),
        event: event,
        constraints: constraints,
        renderer: avatar.renderer,
        avatarResolution: avatar.resolution,
        holdDuration: alert.hold,
      ),
      RaidStageAlert(:final event) => RaidWidget(
        key: ObjectKey(alert),
        event: event,
        constraints: constraints,
        renderer: avatar.renderer,
        avatarResolution: avatar.resolution,
        holdDuration: alert.hold,
      ),
      SubscriptionStageAlert(:final event) => UserAlertWidget(
        key: ObjectKey(alert),
        userName:
            event.subscription.isAnonymous
                ? context.localizations.subscription_anonymous
                : event.userName!,
        description: event.subscription.description(context.localizations),
        avatar: event.avatar,
        constraints: constraints,
        renderer: avatar.renderer,
        avatarResolution: avatar.resolution,
        holdDuration: alert.hold,
      ),
    };
  }
}
