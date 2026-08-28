import 'package:flutter/material.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/subs/subs_widget.dart';

class FollowWidget extends StatefulWidget {
  final UserFollowEvent event;
  final BoxConstraints constraints;
  final AvatarPixelMotion leavingMotion;
  final AvatarPixelRenderer renderer;
  final int avatarResolution;

  const FollowWidget({
    super.key,
    required this.event,
    required this.constraints,
    this.leavingMotion = AvatarPixelMotion.horizontalWaves,
    this.renderer = AvatarPixelRenderer.rawAtlas,
    this.avatarResolution = 48,
  });

  @override
  State<FollowWidget> createState() => _FollowWidgetState();
}

class _FollowWidgetState extends State<FollowWidget> {
  static const _avatarVerticalOffset =
      -SubsWidget.bottomTextBackplatesHeight / 2.0;
  static const _avatarPixelSize = 8.0;
  static const _enteringDuration = Duration(seconds: 5);
  static const _enteringFallDuration = Duration(seconds: 3);
  static const _leavingDuration = Duration(seconds: 2);
  static const _radialLeavingFallDuration = Duration(seconds: 2);
  static const _waveLeavingFallDuration = Duration(milliseconds: 1200);

  bool _leaving = false;
  late final AvatarPixelMotion _leavingMotion;
  List<Pixel>? _enteringAvatarPixels;
  List<Pixel>? _leavingAvatarPixels;

  Duration get _leavingFallDuration =>
      _leavingMotion == AvatarPixelMotion.horizontalWaves
          ? _waveLeavingFallDuration
          : _radialLeavingFallDuration;

  @override
  void initState() {
    super.initState();
    _leavingMotion = widget.leavingMotion;
    _prepareAvatarPixels();
  }

  @override
  void didUpdateWidget(covariant FollowWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.avatarResolution != widget.avatarResolution ||
        oldWidget.event.avatar != widget.event.avatar ||
        oldWidget.constraints != widget.constraints) {
      _prepareAvatarPixels();
    }
  }

  void _prepareAvatarPixels() {
    final avatar = widget.event.avatar;
    if (avatar == null) return;

    _enteringAvatarPixels = RainyAvatar.preparePixels(
      image: avatar,
      constraints: widget.constraints,
      duration: _enteringDuration,
      fallDuration: _enteringFallDuration,
      resolution: widget.avatarResolution,
      pixelSize: _avatarPixelSize,
      verticalOffset: _avatarVerticalOffset,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.entering,
    );
    _leavingAvatarPixels = RainyAvatar.preparePixels(
      image: avatar,
      constraints: widget.constraints,
      duration: _leavingDuration,
      fallDuration: _leavingFallDuration,
      resolution: widget.avatarResolution,
      pixelSize: _avatarPixelSize,
      verticalOffset: _avatarVerticalOffset,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.leaving,
      motion: _leavingMotion,
    );
  }

  void _handleLeaving() {
    if (!mounted) return;

    setState(() {
      _leaving = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.event.avatar;

    return Stack(
      fit: StackFit.expand,
      children: [
        SubsWidget(
          who: widget.event.userName,
          description: context.localizations.follow_thanks,
          constraints: widget.constraints,
          onLeaving: _handleLeaving,
          renderer: widget.renderer,
        ),
        if (avatar != null)
          RainyAvatar(
            key: ValueKey((
              _leaving ? 'follow_avatar_leaving' : 'follow_avatar_entering',
              widget.avatarResolution,
            )),
            image: avatar,
            constraints: widget.constraints,
            duration: _leaving ? _leavingDuration : _enteringDuration,
            fallDuration:
                _leaving ? _leavingFallDuration : _enteringFallDuration,
            resolution: widget.avatarResolution,
            pixelSize: _avatarPixelSize,
            pixelPadding: 0,
            pixelRadius: Radius.circular(1),
            randomBackground: false,
            verticalOffset: _avatarVerticalOffset,
            scaleWhenStart: false,
            origin: RainyPixelOrigin.outside,
            direction:
                _leaving
                    ? RainyPixelDirection.leaving
                    : RainyPixelDirection.entering,
            motion: _leaving ? _leavingMotion : AvatarPixelMotion.linear,
            renderer: widget.renderer,
            preparedPixels:
                _leaving ? _leavingAvatarPixels : _enteringAvatarPixels,
          ),
      ],
    );
  }
}
