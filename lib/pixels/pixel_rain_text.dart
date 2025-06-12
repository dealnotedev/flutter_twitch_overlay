import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';

class PixelRainText extends StatefulWidget {
  final BoxConstraints constraints;

  final double pixelSize;
  final List<Pixel> pixels;
  final Duration duration;
  final Duration fallDuration;
  final double pixelPadding;
  final Radius pixelRadius;

  const PixelRainText({
    super.key,
    this.pixelRadius = const Radius.circular(2),
    required this.constraints,
    required this.pixels,
    required this.duration,
    required this.fallDuration,
    required this.pixelSize,
    this.pixelPadding = 1.0,
  });

  @override
  State<StatefulWidget> createState() => _State();

  static Size calculateSize({
    required String word,
    required Map<String, List<List<int>>> letters,
    required double pixelSize,
    required double letterSpacing,
  }) {
    double w = 0.0;
    double h = 0.0;

    for (int charIndex = 0; charIndex < word.length; charIndex++) {
      if (charIndex > 0) {
        w += letterSpacing;
      }

      final char = word[charIndex];
      final mask = letters[char]!;

      w += mask[0].length * pixelSize;

      final height = mask.length * pixelSize;
      if (h < height) {
        h = height;
      }
    }

    return Size(w, h);
  }

  static Size calculateSize2({
    required List<List<int>> mask,
    required double pixelSize,
  }) {
    return Size(mask[0].length * pixelSize, mask.length * pixelSize);
  }

  static List<List<int>> generateMatrixFromImage({required img.Image image}) {
    return List.generate(
      image.height,
      (y) => List.generate(image.width, (x) {
        final pixel = image.getPixel(x, y);
        return pixel.a == 0.0 ? 0 : 1;
      }),
    );
  }

  static List<Pixel> generatePixels({
    required List<List<int>> mask,
    required Offset startOffset,
    required double pixelSize,
    required Color color,
    int minDelayMs = 0,
    int maxDelayMs = 1600,
  }) {
    final rnd = Random();
    final List<Pixel> result = [];

    for (int y = 0; y < mask.length; y++) {
      for (int x = 0; x < mask[y].length; x++) {
        if (mask[y][x] == 1) {
          final double targetX = startOffset.dx + (x * pixelSize);
          final double targetY = startOffset.dy + y * pixelSize;

          result.add(
            Pixel(
              x: targetX,
              y: targetY,
              startX: 0,
              startY: 0,
              color: color,
              delayMs:
                  minDelayMs +
                  rnd.nextInt((maxDelayMs - minDelayMs).clamp(0, 10000)),
            ),
          );
        }
      }
    }

    return result;
  }

  static List<Pixel> generateWordPixels({
    required String word,
    required Map<String, List<List<int>>> letters,
    required Offset startOffset,
    required double pixelSize,
    required double letterSpacing,
    required Color color,
    int minDelayMs = 0,
    int maxDelayMs = 1600,
  }) {
    final rnd = Random();
    final List<Pixel> result = [];

    double xOffset = 0.0;

    for (int charIndex = 0; charIndex < word.length; charIndex++) {
      final char = word[charIndex];
      final mask = letters[char]!;

      for (int y = 0; y < mask.length; y++) {
        for (int x = 0; x < mask[y].length; x++) {
          if (mask[y][x] == 1) {
            final double targetX = startOffset.dx + xOffset + (x * pixelSize);
            final double targetY = startOffset.dy + y * pixelSize;

            result.add(
              Pixel(
                x: targetX,
                y: targetY,
                startX: 0,
                startY: 0,
                color: color,
                delayMs:
                    minDelayMs +
                    rnd.nextInt((maxDelayMs - minDelayMs).clamp(0, 10000)),
              ),
            );
          }
        }
      }

      xOffset += pixelSize * mask[0].length + letterSpacing;
    }

    return result;
  }
}

class _State extends State<PixelRainText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<Pixel> _pixels;

  @override
  void initState() {
    _pixels = widget.pixels;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pixels = _pixels;
    final animation = _controller;

    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child: AvatarPixelRain(
        widgetWidth: widget.constraints.maxWidth,
        widgetHeight: widget.constraints.maxHeight,
        pixelSize: widget.pixelSize,
        durationMs: widget.duration.inMilliseconds,
        fallDurationMs: widget.fallDuration.inMilliseconds,
        pixels: pixels,
        animation: animation,
        pixelPadding: widget.pixelPadding,
        pixelRadius: widget.pixelRadius,
      ),
    );
  }
}
