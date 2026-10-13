import 'package:flutter/material.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';

class FollowWidget extends StatelessWidget {
  final UserFollowEvent event;
  final BoxConstraints constraints;
  final AvatarPixelMotion leavingMotion;
  final AvatarPixelRenderer renderer;
  final int avatarResolution;
  final Duration holdDuration;

  const FollowWidget({
    super.key,
    required this.event,
    required this.constraints,
    this.leavingMotion = AvatarPixelMotion.horizontalWaves,
    this.renderer = AvatarPixelRenderer.rawAtlas,
    this.avatarResolution = 48,
    this.holdDuration = const Duration(seconds: 10),
  });

  @override
  Widget build(BuildContext context) => UserAlertWidget(
    userName: event.userName,
    description: context.localizations.follow_thanks,
    avatar: event.avatar,
    constraints: constraints,
    leavingMotion: leavingMotion,
    renderer: renderer,
    avatarResolution: avatarResolution,
    holdDuration: holdDuration,
  );
}
