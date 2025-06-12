import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';

class RainyAvatar extends StatefulWidget {
  final BoxConstraints constraints;

  final Duration? initialDelay;
  final Duration duration;
  final Duration fallDuration;

  final double pixelSize;
  final int resolution;
  final img.Image image;
  final bool randomBackground;
  final double verticalOffset;

  final bool scaleWhenStart;
  final RainyPixelOrigin origin;

  const RainyAvatar({
    super.key,
    this.initialDelay,
    this.verticalOffset = 0,
    this.pixelSize = 12,
    this.resolution = 64,
    this.origin = RainyPixelOrigin.inside,
    this.randomBackground = true,
    this.scaleWhenStart = true,
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

enum RainyPixelOrigin { inside, outside }

class _State extends State<RainyAvatar> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _fallDurationMs;
  late Decoration? _decoration;

  @override
  void initState() {
    _scale = widget.scaleWhenStart ? 1.25 : 1.0;
    _decoration =
        widget.randomBackground ? (List.of(_decorations)..shuffle())[0] : null;

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
      widget.origin,
      verticalOffset: widget.verticalOffset,
    );

    _startAnimation();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<Pixel>? _pixels;

  late double _scale;

  void _startAnimation() async {
    final delay = widget.initialDelay;

    if (delay != null) {
      await Future.delayed(delay);
    }

    if (widget.scaleWhenStart) {
      await Future.delayed(Duration(milliseconds: 250));

      setState(() {
        _scale = 1.0;
      });

      await Future.delayed(Duration(milliseconds: 2000));
    }

    _controller.forward();
  }

  static List<Point<double>> _generateEnoughPerimeterPoints2(
    double widgetWidth,
    double widgetHeight,
    double pixelSize,
    int pixelCount,
  ) {
    final points = <Point<double>>[];

    final startLeft = -pixelSize;
    final startRight = widgetWidth;

    final verticalCount = (widgetHeight / pixelSize).toInt();
    final verticalPadding = (widgetHeight - (verticalCount * pixelSize)) / 2.0;

    final top = verticalPadding;

    int row = 0;
    while (points.length < pixelCount) {
      final left = startLeft - row * pixelSize;
      final right = startRight + row * pixelSize;

      for (int y = 0; y < verticalCount; y++) {
        if (points.length >= pixelCount) break;

        points.add(Point(right, top + (y * pixelSize)));
      }

      for (int y = 0; y < verticalCount; y++) {
        if (points.length >= pixelCount) break;

        points.add(Point(left, top + (y * pixelSize)));
      }
      row++;
    }

    return points;
  }

  static List<Point<double>> _generateEnoughPerimeterPoints(
    double widgetWidth,
    double widgetHeight,
    double pixelSize,
    int pixelCount,
  ) {
    final points = <Point<double>>[];

    final verticalCount = (widgetHeight / pixelSize).toInt();
    final verticalPadding = (widgetHeight - (verticalCount * pixelSize)) / 2.0;

    final top = verticalPadding;

    int row = 0;
    while (points.length < pixelCount) {
      final left = row * pixelSize;
      final right = widgetWidth - (row + 1) * pixelSize;

      for (int y = 0; y < verticalCount; y++) {
        if (points.length >= pixelCount) break;

        points.add(Point(right, top + (y * pixelSize)));
      }

      for (int y = 0; y < verticalCount; y++) {
        if (points.length >= pixelCount) break;

        points.add(Point(left, top + (y * pixelSize)));
      }
      row++;
    }
    return points;
  }

  static List<Pixel> _makePixels(
    List<List<Color?>> matrix,
    int durationMs,
    double widgetWidth,
    double widgetHeight,
    double pixelSize,
    int fallDurationMs,
    RainyPixelOrigin origin, {
    required double verticalOffset,
  }) {
    final pixels = <Pixel>[];

    final h = matrix.length;
    final w = matrix[0].length;

    final cx = w / 2 - 0.5;
    final cy = h / 2 - 0.5;
    final radius = (w < h ? w : h) / 2 - 0.5;

    final width = w * pixelSize;
    final height = h * pixelSize;

    final startX = (widgetWidth / 2.0) - (width / 2.0);
    final startY = (widgetHeight / 2.0) - (height / 2.0) + verticalOffset;

    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        final color = matrix[y][x];

        if (color != null) {
          final dx = x - cx;
          final dy = y - cy;
          if (dx * dx + dy * dy <= radius * radius) {
            pixels.add(
              Pixel(
                x: startX + (x * pixelSize),
                y: startY + (y * pixelSize),
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

    final List<Point<double>> startPositions;
    switch (origin) {
      case RainyPixelOrigin.inside:
        startPositions = _generateEnoughPerimeterPoints(
          widgetWidth,
          widgetHeight,
          pixelSize,
          pixels.length,
        );
        break;
      case RainyPixelOrigin.outside:
        startPositions = _generateEnoughPerimeterPoints2(
          widgetWidth,
          widgetHeight,
          pixelSize,
          pixels.length,
        );
        break;
    }

    if (startPositions.length < pixels.length) {
      throw StateError('Widget is too small!');
    }

    for (int i = 0; i < pixels.length; i++) {
      final p = pixels[i];
      final start = startPositions[i];
      pixels[i] = Pixel(
        x: p.x,
        y: p.y,
        startX: start.x,
        startY: start.y,
        color: p.color,
        delayMs: p.delayMs,
      );
    }

    pixels.shuffle(Random());

    final totalSpan = (durationMs - fallDurationMs).toDouble();
    final step = totalSpan / pixels.length;

    for (int i = 0; i < pixels.length; i++) {
      pixels[i] = Pixel(
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
    int gridH,
  ) {
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
                child: AvatarPixelRain(
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
