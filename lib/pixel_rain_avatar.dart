import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class RainyAvatar extends StatefulWidget {
  final BoxConstraints constraints;
  final String url;
  final Duration duration;

  const RainyAvatar({
    super.key,
    required this.url,
    required this.constraints,
    required this.duration,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RainyAvatar> with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    _loadAvatar();
    super.initState();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  List<_Pixel>? _pixels;

  void _loadAvatar() async {
    final colorMatrix = await _avatarToColorMatrix(widget.url, 64, 64);

    if (!mounted) return;

    print(
      getTopPaletteColors(colorMatrix, 14)
          .map((color) {
            return 'Color(0x${color.alpha.toRadixString(16).padLeft(2, '0').toUpperCase()}'
                '${color.red.toRadixString(16).padLeft(2, '0').toUpperCase()}'
                '${color.green.toRadixString(16).padLeft(2, '0').toUpperCase()}'
                '${color.blue.toRadixString(16).padLeft(2, '0').toUpperCase()})';
          })
          .join(', '),
    );

    setState(() {
      _pixels = _makePixels(colorMatrix, widget.duration.inMilliseconds);
      _controller = AnimationController(vsync: this, duration: widget.duration)
        ..forward();
    });
  }

  static Color quantize(Color c, {int step = 32}) {
    int roundTo(int value, int step) => ((value ~/ step) * step).clamp(0, 255);
    return Color.fromARGB(
      255,
      roundTo(c.red, step),
      roundTo(c.green, step),
      roundTo(c.blue, step),
    );
  }

  static List<Color> getTopPaletteColors(
    List<List<Color?>> matrix,
    int topN, {
    int step = 32,
  }) {
    final colorCounts = <Color, int>{};
    for (final row in matrix) {
      for (final color in row) {
        if (color != null) {
          final qColor = quantize(color, step: step);
          colorCounts[qColor] = (colorCounts[qColor] ?? 0) + 1;
        }
      }
    }
    final sorted =
        colorCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(topN).map((e) => e.key).toList();
  }

  static List<_Pixel> _makePixels(List<List<Color?>> matrix, int durationMs) {
    final pixels = <_Pixel>[];

    final h = matrix.length;
    final w = matrix[0].length;

    final cx = w / 2 - 0.5;
    final cy = h / 2 - 0.5;
    final radius = (w < h ? w : h) / 2 - 0.5;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final color = matrix[y][x];
        if (color != null) {
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= radius * radius) {
            pixels.add(_Pixel(x: x, y: y, color: color, delayMs: 0));
          }
        }
      }
    }

    pixels.shuffle(Random());

    int fallDurationMs = _AvatarRainPainter.fallDurationMs;

    final totalSpan = (durationMs - fallDurationMs).toDouble();
    final step = totalSpan / pixels.length;
    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = _Pixel(
        x: pixels[i].x,
        y: pixels[i].y,
        color: pixels[i].color,
        delayMs: (i * step).round(),
      );
    }

    return pixels;
  }

  static Future<List<List<Color?>>> _avatarToColorMatrix(
    String url,
    int gridW,
    int gridH,
  ) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) throw Exception("Failed to load avatar");

    final avatar = img.decodeImage(response.bodyBytes)!;
    final resized = img.copyResize(avatar, width: gridW, height: gridH);

    return List.generate(
      gridH,
      (y) => List.generate(gridW, (x) {
        final pixel = resized.getPixel(x, y);
        return Color.fromARGB(
          pixel.a.toInt(),
          pixel.r.toInt(),
          pixel.g.toInt(),
          pixel.b.toInt(),
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pixels = _pixels;
    final animation = _controller;
    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child:
          pixels != null && animation != null
              ? AvatarPixelRain(
                durationMs: animation.duration!.inMilliseconds,
                pixels: pixels,
                pixelSize: 12,
                animation: animation,
              )
              : null,
    );
  }
}

class AvatarPixelRain extends StatelessWidget {
  final List<_Pixel> pixels;
  final double pixelSize;
  final Animation<double> animation;
  final int durationMs;

  const AvatarPixelRain({
    super.key,
    required this.pixels,
    required this.pixelSize,
    required this.animation,
    required this.durationMs,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return CustomPaint(
          size: Size(128 * pixelSize, 128 * pixelSize),
          painter: _AvatarRainPainter(
            pixels,
            animation.value,
            pixelSize,
            durationMs,
          ),
        );
      },
    );
  }
}

class _Pixel {
  final int x;
  final int y;
  final Color color;
  final int delayMs;

  _Pixel({
    required this.x,
    required this.y,
    required this.color,
    required this.delayMs,
  });
}

class _AvatarRainPainter extends CustomPainter {
  final List<_Pixel> pixels;
  final double progress;
  final double pixelSize;
  final int durationMs;

  static const int fallDurationMs = 60;

  _AvatarRainPainter(
    this.pixels,
    this.progress,
    this.pixelSize,
    this.durationMs,
  );

  static const _padding = 1.0;
  static const _dualPadding = 2.0;

  @override
  void paint(Canvas canvas, Size size) {
    final imageW =
        pixels.isEmpty
            ? 0
            : (pixels.map((p) => p.x).reduce(max) + 1) * pixelSize;
    final imageH =
        pixels.isEmpty
            ? 0
            : (pixels.map((p) => p.y).reduce(max) + 1) * pixelSize;

    final offsetX = (size.width - imageW) / 2;
    final offsetY = (size.height - imageH) / 2;

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

      // Самое важное: падать с самого верха canvas!
      final y = lerpDouble(0, p.y * pixelSize + offsetY, pixelProgress)!;
      final x = p.x * pixelSize + offsetX;
      final paint = Paint()..color = p.color;

      if (pixelProgress > 0) {
        final rect = Rect.fromLTWH(
          x + _padding,
          y + _padding,
          pixelSize - _dualPadding,
          pixelSize - _dualPadding,
        );
        final rrect = RRect.fromRectAndRadius(rect, Radius.circular(2));
        canvas.drawRRect(rrect, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _AvatarRainPainter oldDelegate) => true;
}
