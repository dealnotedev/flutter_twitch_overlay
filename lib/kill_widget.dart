import 'dart:math';

import 'package:flutter/material.dart';
import 'package:obssource/graffity.dart';
import 'package:obssource/pixels/pixel_rain_letters.dart';
import 'package:obssource/pixels/pixel_rain_text.dart';
import 'package:obssource/pixels/pixel_util.dart';

class KillWidget extends StatefulWidget {
  final int streak;
  final String text;
  final BoxConstraints constraints;

  const KillWidget({
    super.key,
    required this.text,
    required this.constraints,
    required this.streak,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<KillWidget> {
  static const _pixelSize = 10.0;

  late final Graffity _graffity;

  @override
  void initState() {
    _graffity = _createText(
      name: widget.text,
      constraints: widget.constraints,
      color: _color,
    );
    super.initState();
  }

  Color get _color {
    switch (widget.streak) {
      case 1:
        return Color(0xFFE53935);
      case 2:
        return Color(0xFFFB8C00);
      case 3:
        return Color(0xFFAB47BC);
      case 4:
        return Color(0xFF43A047);
      case 5:
        return Color(0xFF1E88E5);
      case 6:
        return Color(0xFF8E24AA);
      case 7:
        return Color(0xFF6D4C41);
      case 8:
        return Color(0xFFD81B60);
      case 9:
        return Color(0xFFE91E63);
      case 10:
        return Color(0xFFFF7043);
      case 11:
        return Color(0xFF5E35B1);
      case 12:
      default:
        return Color(0xFF000000);
    }
  }

  static Graffity _createText({
    required String name,
    required Color color,
    required BoxConstraints constraints,
  }) {
    final size = PixelUtil.calculatePixelTextSize(
      letters: PixelRainLetter.all,
      word: name.toUpperCase(),
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
    );

    final start = Offset(
      constraints.maxWidth / 2.0 - size.width / 2.0,
      constraints.maxHeight / 2.0 - size.height / 2.0,
    );

    final pixels = PixelUtil.generateTextPixels(
      maxDelayMs: 500,
      color: color,
      text: name.toUpperCase(),
      letters: PixelRainLetter.all,
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
      startOffset: start,
    );

    final random = Random();

    final startY = constraints.maxHeight / 2.0;

    for (int i = 0; i < pixels.length; i++) {
      final yShift = random.nextInt(250) * (random.nextBool() ? 1 : -1);
      pixels[i] = pixels[i].copy(
        startY: startY + yShift,
        startX: random.nextBool() ? -_pixelSize : constraints.maxWidth,
      );
    }

    return Graffity(size: size, pixels: pixels, start: start);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        Positioned(
          left: 0,
          right: 0,
          child: Container(
            height: _graffity.size.height + 32.0 + 32.0,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
        PixelRainText(
          key: ValueKey('text'),
          constraints: widget.constraints,
          pixels: _graffity.pixels,
          duration: Duration(seconds: 2),
          fallDuration: Duration(milliseconds: 500),
          pixelSize: _pixelSize,
          pixelPadding: 0.5,
        ),
      ],
    );
  }
}
