import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:obssource/pixels/pixel.dart';

class AvatarPixelRain extends StatelessWidget {
  final List<Pixel> pixels;
  final double pixelSize;
  final Animation<double> animation;
  final int durationMs;
  final int fallDurationMs;

  final double widgetWidth;
  final double widgetHeight;

  const AvatarPixelRain({
    super.key,
    required this.pixels,
    required this.pixelSize,
    required this.animation,
    required this.durationMs,
    required this.widgetWidth,
    required this.widgetHeight,
    required this.fallDurationMs,
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

  _AvatarRainPainter(
    this.pixels,
    this.progress,
    this.pixelSize,
    this.durationMs,
    this.fallDurationMs,
  );

  static const _padding = 0.25;
  static const _dualPadding = 0.5;

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = progress * durationMs;

    for (final p in pixels) {
      final startMs = p.delayMs;
      final endMs = startMs + fallDurationMs;

      double pixelProgress;

      if (currentMs < startMs) {
        pixelProgress = 0.0;
      } else if (currentMs >= endMs) {
        pixelProgress = 1.0;
      } else {
        pixelProgress = (currentMs - startMs) / fallDurationMs;
        pixelProgress = Curves.easeOut.transform(pixelProgress.clamp(0.0, 1.0));
      }

      final yTarget = p.y;
      final xTarget = p.x;
      final yStart = p.startY;
      final xStart = p.startX;

      final y = lerpDouble(yStart, yTarget, pixelProgress)!;
      final x = lerpDouble(xStart, xTarget, pixelProgress)!;

      final rect = Rect.fromLTWH(
        x + _padding,
        y + _padding,
        pixelSize - _dualPadding,
        pixelSize - _dualPadding,
      );

      final rrect = RRect.fromRectAndRadius(rect, _radius);
      canvas.drawRRect(rrect, _paint..color = p.color);
    }
  }

  static const _radius = Radius.circular(2);
  final _paint = Paint();

  @override
  bool shouldRepaint(covariant _AvatarRainPainter oldDelegate) => true;
}
