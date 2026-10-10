import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/avatar_contour_renderer.dart';
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/subs/subs_widget.dart';

class UserAlertWidget extends StatefulWidget {
  final String userName;
  final String description;
  final img.Image? avatar;
  final BoxConstraints constraints;
  final AvatarPixelMotion leavingMotion;
  final AvatarPixelRenderer renderer;
  final bool smoothContour;
  final int avatarResolution;
  final double avatarPixelSize;

  const UserAlertWidget({
    super.key,
    required this.userName,
    required this.description,
    this.avatar,
    required this.constraints,
    this.leavingMotion = AvatarPixelMotion.horizontalWaves,
    this.renderer = AvatarPixelRenderer.rawAtlas,
    this.smoothContour = false,
    this.avatarResolution = 48,
    this.avatarPixelSize = 8,
  });

  @override
  State<UserAlertWidget> createState() => _UserAlertWidgetState();
}

class _UserAlertWidgetState extends State<UserAlertWidget> {
  static const _avatarVerticalOffset =
      -SubsWidget.bottomTextBackplatesHeight / 2.0;
  static const _pixelRadius = Radius.circular(1);
  static const _enteringDuration = Duration(seconds: 5);
  static const _enteringFallDuration = Duration(seconds: 3);
  static const _leavingDuration = Duration(seconds: 2);
  static const _radialLeavingFallDuration = Duration(seconds: 2);
  static const _waveLeavingFallDuration = Duration(milliseconds: 1200);

  bool _leaving = false;
  late final AvatarPixelMotion _leavingMotion;
  List<Pixel>? _enteringAvatarPixels;
  List<Pixel>? _leavingAvatarPixels;
  ContourRainData? _enteringContour;
  ContourRainData? _leavingContour;
  int _preparationVersion = 0;
  bool _preparing = false;
  bool _preparationFailed = false;

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
  void didUpdateWidget(covariant UserAlertWidget oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.avatarResolution != widget.avatarResolution ||
        oldWidget.avatarPixelSize != widget.avatarPixelSize ||
        oldWidget.renderer != widget.renderer ||
        oldWidget.smoothContour != widget.smoothContour ||
        oldWidget.avatar != widget.avatar ||
        oldWidget.constraints != widget.constraints) {
      _prepareAvatarPixels();
    }
  }

  void _prepareAvatarPixels() {
    final version = ++_preparationVersion;
    _enteringAvatarPixels = null;
    _leavingAvatarPixels = null;
    _enteringContour = null;
    _leavingContour = null;
    _preparationFailed = false;
    _preparing = false;
    final avatar = widget.avatar;
    if (avatar == null) return;
    final request = _AvatarPreparation(
      image: avatar,
      constraints: widget.constraints,
      resolution: widget.avatarResolution,
      pixelSize: widget.avatarPixelSize,
      renderer: widget.renderer,
      smoothContour: widget.smoothContour,
      leavingMotion: _leavingMotion,
      leavingFallDuration: _leavingFallDuration,
    );
    if (widget.renderer == AvatarPixelRenderer.contourPoints) {
      _leaving = false;
      _preparing = true;
      unawaited(_prepareInBackground(request, version));
    } else {
      _acceptPreparation(_prepareAvatar(request));
    }
  }

  void _acceptPreparation(_PreparedAvatar prepared) {
    _enteringAvatarPixels = prepared.entering;
    _leavingAvatarPixels = prepared.leaving;
    _enteringContour = prepared.enteringContour;
    _leavingContour = prepared.leavingContour;
    _preparing = false;
  }

  Future<void> _prepareInBackground(
    _AvatarPreparation request,
    int version,
  ) async {
    try {
      final prepared = await compute(_prepareAvatar, request);
      if (!mounted || version != _preparationVersion) return;
      setState(() => _acceptPreparation(prepared));
    } catch (error, stack) {
      if (!mounted || version != _preparationVersion) return;
      // Keep the notification usable if avatar preparation fails.
      setState(() {
        _preparing = false;
        _preparationFailed = true;
      });
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stack,
          context: ErrorDescription('while preparing the avatar contour'),
        ),
      );
    }
  }

  void _handleLeaving() {
    if (!mounted) return;

    setState(() {
      _leaving = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Start the text and avatar together, after both animation phases are ready.
    if (_preparing) return const SizedBox.expand();
    final avatar = _preparationFailed ? null : widget.avatar;

    return Stack(
      fit: StackFit.expand,
      children: [
        SubsWidget(
          who: widget.userName,
          description: widget.description,
          constraints: widget.constraints,
          onLeaving: _handleLeaving,
          pixelRadius: _pixelRadius,
          renderer: widget.renderer,
        ),
        if (avatar != null)
          RainyAvatar(
            key: ValueKey((
              _leaving
                  ? 'user_alert_avatar_leaving'
                  : 'user_alert_avatar_entering',
              widget.avatarResolution,
              widget.avatarPixelSize,
              widget.renderer,
              widget.smoothContour,
            )),
            image: avatar,
            constraints: widget.constraints,
            duration: _leaving ? _leavingDuration : _enteringDuration,
            fallDuration:
                _leaving ? _leavingFallDuration : _enteringFallDuration,
            resolution: widget.avatarResolution,
            pixelSize: widget.avatarPixelSize,
            pixelPadding: 0,
            pixelRadius: _pixelRadius,
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
            smoothContour: widget.smoothContour,
            preparedPixels:
                _leaving ? _leavingAvatarPixels : _enteringAvatarPixels,
            preparedContour: _leaving ? _leavingContour : _enteringContour,
          ),
      ],
    );
  }
}

class _AvatarPreparation {
  final img.Image image;
  final BoxConstraints constraints;
  final int resolution;
  final double pixelSize;
  final AvatarPixelRenderer renderer;
  final bool smoothContour;
  final AvatarPixelMotion leavingMotion;
  final Duration leavingFallDuration;

  const _AvatarPreparation({
    required this.image,
    required this.constraints,
    required this.resolution,
    required this.pixelSize,
    required this.renderer,
    required this.smoothContour,
    required this.leavingMotion,
    required this.leavingFallDuration,
  });
}

class _PreparedAvatar {
  final List<Pixel> entering, leaving;
  final ContourRainData? enteringContour, leavingContour;

  const _PreparedAvatar(
    this.entering,
    this.leaving,
    this.enteringContour,
    this.leavingContour,
  );
}

_PreparedAvatar _prepareAvatar(_AvatarPreparation request) {
  List<Pixel> pixels(RainyPixelDirection direction) {
    final leaving = direction == RainyPixelDirection.leaving;
    return RainyAvatar.preparePixels(
      image: request.image,
      constraints: request.constraints,
      duration:
          leaving
              ? _UserAlertWidgetState._leavingDuration
              : _UserAlertWidgetState._enteringDuration,
      fallDuration:
          leaving
              ? request.leavingFallDuration
              : _UserAlertWidgetState._enteringFallDuration,
      resolution: request.resolution,
      pixelSize: request.pixelSize,
      verticalOffset: _UserAlertWidgetState._avatarVerticalOffset,
      origin: RainyPixelOrigin.outside,
      direction: direction,
      motion: leaving ? request.leavingMotion : AvatarPixelMotion.linear,
      renderer: request.renderer,
      smoothContour: request.smoothContour,
    );
  }

  ContourRainData? contour(List<Pixel> pixels, RainyPixelDirection direction) =>
      request.renderer == AvatarPixelRenderer.contourPoints
          ? ContourRainData.prepare(
            pixels,
            pixelSize: request.pixelSize,
            smoothContour: request.smoothContour,
            contour: RainyAvatar.contourFor(
              constraints: request.constraints,
              resolution: request.resolution,
              pixelSize: request.pixelSize,
              verticalOffset: _UserAlertWidgetState._avatarVerticalOffset,
              direction: direction,
            ),
          )
          : null;
  final entering = pixels(RainyPixelDirection.entering);
  final leaving = pixels(RainyPixelDirection.leaving);
  return _PreparedAvatar(
    entering,
    leaving,
    contour(entering, RainyPixelDirection.entering),
    contour(leaving, RainyPixelDirection.leaving),
  );
}
