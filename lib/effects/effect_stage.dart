import 'package:animated_reorderable_list/animated_reorderable_list.dart';
import 'package:flutter/material.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/config/alerts_settings.dart';
import 'package:obssource/config/avatar_settings.dart';
import 'package:obssource/effects/chat_card.dart';
import 'package:obssource/effects/crt_off.dart';
import 'package:obssource/effects/effect_runtime.dart';
import 'package:obssource/effects/flashbang.dart';
import 'package:obssource/effects/kill_widget.dart';
import 'package:obssource/effects/pause_effect.dart';
import 'package:obssource/effects/reward_card.dart';
import 'package:obssource/effects/screen_attack_game.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/follow/follow_balloons.dart';
import 'package:obssource/follow/follow_widget.dart';
import 'package:obssource/raid/classic_raid_widget.dart';
import 'package:obssource/raid/raid_widget.dart';
import 'package:obssource/subs/subscription_text.dart';

/// Draws everything an [EffectRuntime] currently shows, in a fixed layer
/// order. Used by the live overlay and by the settings preview.
class EffectStage extends StatelessWidget {
  final EffectRuntime runtime;

  /// Size of the whole overlay canvas; effects lay out against it.
  final BoxConstraints constraints;
  final AvatarSettings avatar;

  /// Drawn above alerts and below the flashbang, e.g. the music player.
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
        final crt = runtime.crt;
        final pause = runtime.pause;
        final kill = runtime.kill;
        final flashbang = runtime.flashbang;

        // Every layer is keyed: layers appear and disappear independently, and
        // an unkeyed one between them would be rebuilt from scratch, e.g.
        // reopening the music player or restarting the CRT animation.
        return Stack(
          children: [
            if (runtime.screenAttackMounted)
              Positioned.fill(
                // A new runtime (preview stop) gets a fresh sticker layer.
                key: ObjectKey(runtime.screenAttack),
                child: ScreenAttackGameWidget(controller: runtime.screenAttack),
              ),
            if (crt != null)
              Positioned.fill(
                key: ValueKey(('crt', crt.session)),
                child: CrtOffEffectWidget(effect: crt),
              ),
            if (pause != null)
              Positioned.fill(
                key: ObjectKey(pause),
                child: PauseEffectWidget(
                  effect: pause,
                  constraints: constraints,
                ),
              ),
            for (final card in runtime.chatCards)
              ChatCardWidget(
                key: ObjectKey(card),
                card: card,
                constraints: constraints,
              ),
            KeyedSubtree(
              key: const ValueKey('reward_cards'),
              child: _buildRewardCards(),
            ),
            if (stage != null) _buildStage(context, stage),
            if (kill != null)
              KillWidget(
                key: ObjectKey(kill),
                text: kill.text,
                streak: kill.inMatch,
                constraints: constraints,
              ),
            if (foreground case final foreground?)
              KeyedSubtree(
                key: const ValueKey('foreground'),
                child: foreground,
              ),
            if (flashbang != null)
              FlashbangWidget(
                key: ObjectKey(flashbang),
                flashbang: flashbang,
                constraints: constraints,
                onBang: runtime.playFlashbangSound,
              ),
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
      FollowStageAlert(:final event, style: FollowStyle.pixel) => FollowWidget(
        key: ObjectKey(alert),
        event: event,
        constraints: constraints,
        renderer: avatar.renderer,
        avatarResolution: avatar.resolution,
        holdDuration: alert.hold,
      ),
      FollowStageAlert(:final event, style: FollowStyle.balloons) =>
        FollowBalloonsWidget(
          key: ObjectKey(alert),
          event: event,
          duration: alert.hold,
          constraints: constraints,
        ),
      RaidStageAlert(:final event, style: RaidStyle.pixel) => RaidWidget(
        key: ObjectKey(alert),
        event: event,
        constraints: constraints,
        renderer: avatar.renderer,
        avatarResolution: avatar.resolution,
        holdDuration: alert.hold,
      ),
      RaidStageAlert(:final event, :final from, style: RaidStyle.classic) =>
        ClassicRaidWidget(
          key: ObjectKey(alert),
          raid: ClassicRaid(
            avatar: event.avatar,
            who: from,
            raiders: event.viewers,
          ),
          constraints: constraints,
          maxAnimals: alert.maxAnimals,
          renderer: avatar.renderer,
          avatarResolution: avatar.resolution,
          onDone: () => runtime.completeStage(alert),
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
