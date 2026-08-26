import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:obssource/pixels/pixel.dart';

enum AvatarPixelMotion { linear, horizontalWaves }

enum AvatarPixelRenderer {
  /// Batches every pixel into one atlas draw call.
  rawAtlas,

  /// Preserves the original per-pixel canvas implementation as a fallback.
  legacyCanvas,
}

class AvatarPixelRain extends StatefulWidget {
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
  final AvatarPixelRenderer renderer;

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
    this.renderer = AvatarPixelRenderer.rawAtlas,
  });

  @override
  State<AvatarPixelRain> createState() => _AvatarPixelRainState();
}

class _AvatarPixelRainState extends State<AvatarPixelRain> {
  ui.Image? _atlas;

  @override
  void initState() {
    super.initState();
    if (widget.renderer == AvatarPixelRenderer.rawAtlas) {
      _atlas = _createPixelAtlas(
        widget.pixelSize,
        widget.pixelPadding,
        widget.pixelRadius,
      );
    }
  }

  @override
  void didUpdateWidget(covariant AvatarPixelRain oldWidget) {
    super.didUpdateWidget(oldWidget);
    final atlasShapeChanged =
        oldWidget.pixelSize != widget.pixelSize ||
        oldWidget.pixelPadding != widget.pixelPadding ||
        oldWidget.pixelRadius != widget.pixelRadius;
    if (widget.renderer == AvatarPixelRenderer.rawAtlas &&
        (oldWidget.renderer != AvatarPixelRenderer.rawAtlas ||
            atlasShapeChanged)) {
      final oldAtlas = _atlas;
      _atlas = _createPixelAtlas(
        widget.pixelSize,
        widget.pixelPadding,
        widget.pixelRadius,
      );
      oldAtlas?.dispose();
    } else if (widget.renderer == AvatarPixelRenderer.legacyCanvas &&
        oldWidget.renderer == AvatarPixelRenderer.rawAtlas) {
      _atlas?.dispose();
      _atlas = null;
    }
  }

  @override
  void dispose() {
    _atlas?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return switch (widget.renderer) {
      AvatarPixelRenderer.rawAtlas => CustomPaint(
        size: Size(widget.widgetWidth, widget.widgetHeight),
        painter: _AtlasAvatarRainPainter(
          widget.pixels,
          widget.animation,
          widget.pixelSize,
          widget.durationMs,
          widget.fallDurationMs,
          atlas: _atlas!,
          motion: widget.motion,
          pixelRadius: widget.pixelRadius,
          pixelPadding: widget.pixelPadding,
        ),
      ),
      AvatarPixelRenderer.legacyCanvas => AnimatedBuilder(
        animation: widget.animation,
        builder: (context, _) {
          return CustomPaint(
            size: Size(widget.widgetWidth, widget.widgetHeight),
            painter: _LegacyAvatarRainPainter(
              widget.pixels,
              widget.animation.value,
              widget.pixelSize,
              widget.durationMs,
              widget.fallDurationMs,
              motion: widget.motion,
              pixelRadius: widget.pixelRadius,
              pixelPadding: widget.pixelPadding,
            ),
          );
        },
      ),
    };
  }
}

const _atlasExtent = 64.0;

ui.Image _createPixelAtlas(
  double pixelSize,
  double pixelPadding,
  Radius pixelRadius,
) {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final drawableExtent = pixelSize - pixelPadding * 2.0;

  if (drawableExtent > 0) {
    final atlasScale = _atlasExtent / drawableExtent;
    final rect = Rect.fromLTWH(0, 0, _atlasExtent, _atlasExtent);
    final paint =
        Paint()
          ..color = Colors.white
          ..isAntiAlias = pixelRadius != Radius.zero;

    if (pixelRadius == Radius.zero) {
      canvas.drawRect(rect, paint);
    } else {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          rect,
          Radius.elliptical(
            pixelRadius.x * atlasScale,
            pixelRadius.y * atlasScale,
          ),
        ),
        paint,
      );
    }
  }

  return recorder.endRecording().toImageSync(
    _atlasExtent.toInt(),
    _atlasExtent.toInt(),
  );
}

class _AtlasAvatarRainPainter extends CustomPainter {
  final List<Pixel> pixels;
  final Animation<double> animation;
  final double pixelSize;
  final int durationMs;
  final int fallDurationMs;
  final AvatarPixelMotion motion;
  final double pixelPadding;
  final Radius pixelRadius;
  final ui.Image atlas;

  late final Float32List _transforms;
  late final Float32List _rects;
  late final Int32List _colors;
  late final Paint _paint;

  _AtlasAvatarRainPainter(
    this.pixels,
    this.animation,
    this.pixelSize,
    this.durationMs,
    this.fallDurationMs, {
    required this.atlas,
    this.motion = AvatarPixelMotion.linear,
    required this.pixelRadius,
    required this.pixelPadding,
  }) : super(repaint: animation) {
    final drawableExtent = max(0.0, pixelSize - pixelPadding * 2.0);
    final atlasScale = drawableExtent / _atlasExtent;
    _transforms = Float32List(pixels.length * 4);
    _rects = Float32List(pixels.length * 4);
    _colors = Int32List(pixels.length);

    for (var index = 0; index < pixels.length; index++) {
      final offset = index * 4;
      _transforms[offset] = atlasScale;
      _rects[offset + 2] = _atlasExtent;
      _rects[offset + 3] = _atlasExtent;
      _colors[index] = pixels[index].color.toARGB32();
    }

    _paint =
        Paint()
          ..isAntiAlias = false
          ..filterQuality =
              pixelRadius == Radius.zero
                  ? FilterQuality.none
                  : FilterQuality.low;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = animation.value * durationMs;
    final verticalWaveFactors = <int, double>{};

    for (var index = 0; index < pixels.length; index++) {
      final pixel = pixels[index];
      final startMs = pixel.delayMs;
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

      final double x;
      final double y;
      switch (motion) {
        case AvatarPixelMotion.linear:
          x = pixel.startX + (pixel.x - pixel.startX) * pixelProgress;
          y = pixel.startY + (pixel.y - pixel.startY) * pixelProgress;
          break;
        case AvatarPixelMotion.horizontalWaves:
          final verticalWaveFactor = verticalWaveFactors.putIfAbsent(
            pixel.delayMs,
            () =>
                sin(normalizedProgress * pi * 4.0) *
                sin(normalizedProgress * pi),
          );
          x = pixel.startX + (pixel.x - pixel.startX) * pixelProgress;
          y = pixel.startY + (pixel.y - pixel.startY) * verticalWaveFactor;
          break;
      }

      final transformOffset = index * 4;
      _transforms[transformOffset + 2] = x + pixelPadding;
      _transforms[transformOffset + 3] = y + pixelPadding;
    }

    canvas.drawRawAtlas(
      atlas,
      _transforms,
      _rects,
      _colors,
      BlendMode.modulate,
      Offset.zero & size,
      _paint,
    );
  }

  @override
  bool shouldRepaint(covariant _AtlasAvatarRainPainter oldDelegate) {
    return oldDelegate.pixels != pixels ||
        oldDelegate.animation != animation ||
        oldDelegate.pixelSize != pixelSize ||
        oldDelegate.durationMs != durationMs ||
        oldDelegate.fallDurationMs != fallDurationMs ||
        oldDelegate.motion != motion ||
        oldDelegate.pixelPadding != pixelPadding ||
        oldDelegate.pixelRadius != pixelRadius ||
        oldDelegate.atlas != atlas;
  }
}

class _LegacyAvatarRainPainter extends CustomPainter {
  final List<Pixel> pixels;
  final double progress;
  final double pixelSize;
  final int durationMs;
  final int fallDurationMs;
  final AvatarPixelMotion motion;
  final double pixelPadding;
  final double dualPixelPadding;
  final Radius pixelRadius;

  _LegacyAvatarRainPainter(
    this.pixels,
    this.progress,
    this.pixelSize,
    this.durationMs,
    this.fallDurationMs, {
    this.motion = AvatarPixelMotion.linear,
    required this.pixelRadius,
    required this.pixelPadding,
  }) : dualPixelPadding = pixelPadding * 2.0;

  final _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final currentMs = progress * durationMs;
    final verticalWaveFactors = <int, double>{};
    final squarePixels = pixelRadius == Radius.zero;
    _paint.isAntiAlias = !squarePixels;

    for (final pixel in pixels) {
      final startMs = pixel.delayMs;
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

      final double x;
      final double y;
      switch (motion) {
        case AvatarPixelMotion.linear:
          x = ui.lerpDouble(pixel.startX, pixel.x, pixelProgress)!;
          y = ui.lerpDouble(pixel.startY, pixel.y, pixelProgress)!;
          break;
        case AvatarPixelMotion.horizontalWaves:
          final verticalWaveFactor = verticalWaveFactors.putIfAbsent(
            pixel.delayMs,
            () =>
                sin(normalizedProgress * pi * 4.0) *
                sin(normalizedProgress * pi),
          );
          x = ui.lerpDouble(pixel.startX, pixel.x, pixelProgress)!;
          y = pixel.startY + (pixel.y - pixel.startY) * verticalWaveFactor;
          break;
      }

      final rect = Rect.fromLTWH(
        x + pixelPadding,
        y + pixelPadding,
        pixelSize - dualPixelPadding,
        pixelSize - dualPixelPadding,
      );

      if (squarePixels) {
        canvas.drawRect(rect, _paint..color = pixel.color);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, pixelRadius),
          _paint..color = pixel.color,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _LegacyAvatarRainPainter oldDelegate) => true;
}
