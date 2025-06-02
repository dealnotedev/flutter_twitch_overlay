import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;

class RainyAvatar extends StatefulWidget {
  final BoxConstraints constraints;
  final Duration duration;
  final Duration fallDuration;

  final double pixelSize;
  final int resolution;
  final img.Image image;

  const RainyAvatar({
    super.key,
    this.pixelSize = 12,
    this.resolution = 64,
    required this.image,
    required this.constraints,
    required this.duration,
    this.fallDuration = const Duration(milliseconds: 1500),
  });

  @override
  State<StatefulWidget> createState() => _State();

  static Future<img.Image?> loadImageFromAssets(String assetPath) async {
    final byteData = await rootBundle.load(assetPath);
    final bytes = byteData.buffer.asUint8List();

    final image = img.decodeImage(bytes);
    return image;
  }

  static Future<img.Image?> loadImageFromUrl(String url) async {
    final response = await http.get(Uri.parse(url));

    if (response.statusCode != 200) throw Exception("Failed to load avatar");

    return img.decodeImage(response.bodyBytes);
  }
}

class _State extends State<RainyAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _fallDurationMs;
  late Decoration? _decoration;

  @override
  void initState() {
    _decoration = (List.of(_decorations)..shuffle())[0];

    _fallDurationMs = widget.fallDuration.inMilliseconds;
    _controller = AnimationController(vsync: this, duration: widget.duration);

    final matrix = _avatarToColorMatrix(
      widget.image,
      widget.resolution,
      widget.resolution,
    );

    _pixels = _makePixels(
      matrix,

      widget.duration.inMilliseconds,
      widget.constraints.maxWidth,
      widget.constraints.maxHeight,
      widget.pixelSize,
      _fallDurationMs,
    );

    _startAnimation();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<_Pixel>? _pixels;

  double _scale = 1.25;

  void _startAnimation() async {
    await Future.delayed(Duration(milliseconds: 250));

    setState(() {
      _scale = 1.0;
    });

    await Future.delayed(Duration(milliseconds: 2000));

    _controller.forward();
  }

  static List<Point<double>> _generateEnoughPerimeterPoints(
    double widgetWidth,
    double widgetHeight,
    double pixelSize,
    int pixelCount,
  ) {
    final points = <Point<double>>[];

    int row = 0;
    while (points.length < pixelCount) {
      final left = row * pixelSize;
      final right = widgetWidth - (row + 1) * pixelSize;

      final top = 0.0;
      final bottom = widgetHeight - pixelSize;

      if (left > right) break;

      // Right side
      for (double y = top; y <= bottom; y += pixelSize) {
        points.add(Point(right, y));
      }
      // Left side
      if (left != right) {
        for (double y = top; y <= bottom; y += pixelSize) {
          points.add(Point(left, y));
        }
      }
      row++;
    }
    return points;
  }

  static List<_Pixel> _makePixels(
    List<List<Color?>> matrix,
    int durationMs,
    double widgetWidth,
    double widgetHeight,
    double pixelSize,
    int fallDurationMs,
  ) {
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
            pixels.add(
              _Pixel(
                x: x,
                y: y,
                startX: 0,
                startY: 0,
                color: color,
                delayMs: 0,
              ),
            );
          }
        }
      }
    }

    final startPositions = _generateEnoughPerimeterPoints(
      widgetWidth,
      widgetHeight,
      pixelSize,
      pixels.length,
    );

    if (startPositions.length < pixels.length) {
      throw StateError('Widget is too small!');
    }

    for (int i = 0; i < pixels.length; i++) {
      final p = pixels[i];
      final start = startPositions[i];
      pixels[i] = _Pixel(
        x: p.x,
        y: p.y,
        startX: start.x / pixelSize,
        startY: start.y / pixelSize,
        color: p.color,
        delayMs: p.delayMs,
      );
    }

    pixels.shuffle(Random());

    final totalSpan = (durationMs - fallDurationMs).toDouble();
    final step = totalSpan / pixels.length;

    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = _Pixel(
        x: pixels[i].x,
        y: pixels[i].y,
        startX: pixels[i].startX,
        startY: pixels[i].startY,
        color: pixels[i].color,
        delayMs: (i * step).round(),
      );
    }

    return pixels;
  }

  static List<List<Color?>> _avatarToColorMatrix(
    img.Image image,
    int gridW,
    int gridH,) {
    final resized = img.copyResize(image, width: gridW, height: gridH);

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

  static const _decorationHuntShowdownSwampNight = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFF111314), Color(0xFF28362F), Color(0xFF1A191F)],
      stops: [0.0, 0.75, 1.0],
    ),
  );

  static const _decorationPurpleGreenCyberpunk = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF15171E), Color(0xFF23213E), Color(0xFF08432A)],
      stops: [0.0, 0.6, 1.0],
    ),
  );

  static const _decorationRadialDarkCenter = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment(0.0, -0.2),
      radius: 1.1,
      colors: [
        Color(0xFF151618),
        Color(0xFF22232A),
        Color(0xFF23213E),
        Color(0xFF0C0D13),
      ],
      stops: [0.0, 0.45, 0.85, 1.0],
    ),
  );

  static const _decorationTwitchInspiredDarkViolet = BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF18162A), Color(0xFF311940), Color(0xFF101012)],
      stops: [0.0, 0.6, 1.0],
    ),
  );

  static const _decorationVignette = BoxDecoration(
    gradient: RadialGradient(
      center: Alignment.center,
      radius: 1.1,
      colors: [Color(0xFF181A21), Color(0xFF08090A)],
      stops: [0.5, 1.0],
    ),
  );

  static const _decorations = <Decoration>[
    _decorationHuntShowdownSwampNight,
    _decorationPurpleGreenCyberpunk,
    _decorationRadialDarkCenter,
    _decorationTwitchInspiredDarkViolet,
    _decorationVignette,
  ];

  @override
  Widget build(BuildContext context) {
    final pixels = _pixels;
    final animation = _controller;

    return Container(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      decoration: _decoration,
      child:
          pixels != null
              ? AnimatedScale(
                scale: _scale,
                duration: Duration(seconds: 1),
                child: _AvatarPixelRain(
                  widgetWidth: widget.constraints.maxWidth,
                  widgetHeight: widget.constraints.maxHeight,
                  pixelSize: widget.pixelSize,
                  durationMs: animation.duration!.inMilliseconds,
                  fallDurationMs: _fallDurationMs,
                  pixels: pixels,
                  animation: animation,
                ),
              )
              : null,
    );
  }
}

class _AvatarPixelRain extends StatelessWidget {
  final List<_Pixel> pixels;
  final double pixelSize;
  final Animation<double> animation;
  final int durationMs;
  final int fallDurationMs;

  final double widgetWidth;
  final double widgetHeight;

  const _AvatarPixelRain({
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

class _Pixel {
  final int x;
  final int y;
  final double startX;
  final double startY;
  final Color color;
  final int delayMs;

  _Pixel({
    required this.x,
    required this.y,
    required this.startX,
    required this.startY,
    required this.color,
    required this.delayMs,
  });
}

class _AvatarRainPainter extends CustomPainter {
  final List<_Pixel> pixels;
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

      final yTarget = p.y * pixelSize + offsetY;
      final xTarget = p.x * pixelSize + offsetX;
      final yStart = p.startY * pixelSize;
      final xStart = p.startX * pixelSize;

      final y = lerpDouble(yStart, yTarget, pixelProgress)!;
      final x = lerpDouble(xStart, xTarget, pixelProgress)!;

      /*if(pixelProgress >= 1.0){
        canvas.drawRect(
          Rect.fromLTWH(x, y, pixelSize, pixelSize),
          _paint..color = Colors.black,
        );
      }*/

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
