import 'package:flutter/material.dart';
import 'package:obssource/alerts/user_alert_widget.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';

class RaidWidget extends StatelessWidget {
  final UserRaidEvent event;
  final BoxConstraints constraints;
  final AvatarPixelRenderer renderer;
  final int avatarResolution;

  const RaidWidget({
    super.key,
    required this.event,
    required this.constraints,
    this.renderer = AvatarPixelRenderer.rawAtlas,
    this.avatarResolution = 48,
  });

  @override
  Widget build(BuildContext context) => UserAlertWidget(
    userName: event.userName,
    description: context.localizations.raid_viewers(event.viewers),
    avatar: event.avatar,
    constraints: constraints,
    renderer: renderer,
    avatarResolution: avatarResolution,
  );
}
