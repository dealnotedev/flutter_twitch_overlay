import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:obssource/pixels/pixel.dart';

enum AvatarPixelMotion { linear, horizontalWaves }

class AvatarPixelRain extends StatelessWidget {
  final List<Pixel> pixels;
  final double pixelSize;
  final Animation<double> animation;
  final int durationMs;
  final int fallDurationMs;

  final double widgetWidth;
  final double widgetHeight;

  final double pixelPadding;
  final Radius pixelRadius;
  final AvatarPixelMotion motion;

  const AvatarPixelRain({
    super.key,
    required this.pixels,
    required this.pixelSize,
    required this.animation,
    required this.durationMs,
    required this.widgetWidth,
    required this.widgetHeight,
    required this.fallDurationMs,
    this.pixelRadius = const Radius.circular(2),
    this.pixelPadding = 0.25,
    this.motion = AvatarPixelMotion.linear,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(widgetWidth, widgetHeight),
          painter: _AvatarRainPainter(
            pixels,
            animation.value,
            pixelSize,
            durationMs,
            fallDurationMs,
            motion: motion,
            pixelRadius: pixelRadius,
            pixelPadding: pixelPadding,
          ),
        );
      },
    );
  }
}

class _AvatarRainPainter extends CustomPainter {
  final List<Pixel> pixels;
  final double progress;
  final double pixelSize;
  final int durationMs;
  final int fallDurationMs;
  final AvatarPixelMotion motion;

  final double pixelPadding;
  final double dualPixelPadding;
  final Radius pixelRadius;

  _AvatarRainPainter(
    this.pixels,
    this.progress,
    this.pixelSize,
    this.durationMs,
    this.fallDurationMs, {
    this.motion = AvatarPixelMotion.linear,
    required this.pixelRadius,
    required this.pixelPadding,
  }) : dualPixelPadding = pixelPadding * 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = progress * durationMs;
    final verticalWaveFactors = <int, double>{};
    final squarePixels = pixelRadius == Radius.zero;
    _paint.isAntiAlias = !squarePixels;

    for (final p in pixels) {
      final startMs = p.delayMs;
      final endMs = startMs + fallDurationMs;

      final double rawPixelProgress;

      if (currentMs < startMs) {
        rawPixelProgress = 0.0;
      } else if (currentMs >= endMs) {
        rawPixelProgress = 1.0;
      } else {
        rawPixelProgress = (currentMs - startMs) / fallDurationMs;
      }
      final normalizedProgress = rawPixelProgress.clamp(0.0, 1.0);
      final pixelProgress = switch (motion) {
        AvatarPixelMotion.linear => Curves.easeOut.transform(
          normalizedProgress,
        ),
        AvatarPixelMotion.horizontalWaves => Curves.easeInOutSine.transform(
          normalizedProgress,
        ),
      };

      final yTarget = p.y;
      final xTarget = p.x;
      final yStart = p.startY;
      final xStart = p.startX;

      final double x;
      final double y;
      switch (motion) {
        case AvatarPixelMotion.linear:
          y = lerpDouble(yStart, yTarget, pixelProgress)!;
          x = lerpDouble(xStart, xTarget, pixelProgress)!;
          break;
        case AvatarPixelMotion.horizontalWaves:
          final verticalWaveFactor = verticalWaveFactors.putIfAbsent(
            p.delayMs,
            () =>
                sin(normalizedProgress * pi * 4.0) *
                sin(normalizedProgress * pi),
          );
          y = yStart + (yTarget - yStart) * verticalWaveFactor;
          x = lerpDouble(xStart, xTarget, pixelProgress)!;
          break;
      }

      final rect = Rect.fromLTWH(
        x + pixelPadding,
        y + pixelPadding,
        pixelSize - dualPixelPadding,
        pixelSize - dualPixelPadding,
      );

      //_paint.maskFilter = MaskFilter.blur(BlurStyle.normal, 16);
      //canvas.drawRRect(rrect, _paint..color = p.color);
      //_paint.maskFilter = null;

      if (squarePixels) {
        canvas.drawRect(rect, _paint..color = p.color);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, pixelRadius),
          _paint..color = p.color,
        );
      }
    }
  }

  final _paint = Paint();

  @override
  bool shouldRepaint(covariant _AvatarRainPainter oldDelegate) => true;
}
