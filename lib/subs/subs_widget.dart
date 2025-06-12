import 'package:flutter/material.dart';
import 'package:obssource/pixel_rain_letters.dart';
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_text.dart';

class SubsWidget extends StatefulWidget {
  final String who;
  final BoxConstraints constraints;

  const SubsWidget({super.key, required this.who, required this.constraints});

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<SubsWidget> {
  static const _descriptionColor = Colors.white;
  static const _twitchColor = Color(0xFF8829FF);

  static const _pixelSize = 12.0;

  late final _Graffity _name;
  late final _Graffity _heart;
  late final _Graffity _description;
  late final _Graffity _heartBackground;

  static _Graffity _createDescription({
    required String text,
    required BoxConstraints constraints,
  }) {
    final size = PixelRainText.calculateSize(
      word: text,
      letters: PixelRainLetter.all,
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
    );

    final start = Offset(
      constraints.maxWidth / 2.0 - size.width / 2.0,
      constraints.maxHeight - size.height - 32.0,
    );

    final pixels = PixelRainText.generateWordPixels(
      word: text,
      letters: PixelRainLetter.all,
      startOffset: start,
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
      color: _descriptionColor,
    );

    for (int i = 0; i < pixels.length; i++) {
      final from = pixels[i];
      pixels[i] = Pixel(
        x: from.x,
        y: from.y,
        startX: constraints.maxWidth,
        startY: 0,
        color: from.color,
        delayMs: from.delayMs,
      );
    }

    return _Graffity(size: size, pixels: pixels, start: start);
  }

  static _Graffity _createHeartBackground({
    required _Graffity description,
    required BoxConstraints constraints,
  }) {
    final size = PixelRainText.calculateSize2(
      mask: PixelRainLetter.heartBackground,
      pixelSize: _pixelSize,
    );

    final start = Offset(
      constraints.maxWidth / 2.0 - size.width / 2.0,
      constraints.maxHeight / 2.0 - size.height / 2.0,
    );

    final pixels = List.of(
      PixelRainText.generatePixels(
        mask: PixelRainLetter.heartBackground,
        startOffset: start,
        pixelSize: _pixelSize,
        color: _descriptionColor,
      ),
      growable: true,
    );

    for (int i = 0; i < pixels.length; i++) {
      final from = description.pixels[i % description.pixels.length];
      pixels[i] = pixels[i].copy(startX: from.x, startY: from.y);
    }

    if (description.pixels.length > pixels.length) {
      for (int i = pixels.length; i < description.pixels.length; i++) {
        final from = description.pixels[i];
        pixels.add(
          Pixel(
            x: constraints.maxWidth - _pixelSize,
            y: constraints.maxHeight - _pixelSize,
            startX: from.x,
            startY: from.y,
            color: from.color,
            delayMs: from.delayMs,
          ),
        );
      }
    }

    return _Graffity(size: size, pixels: pixels, start: start);
  }

  static _Graffity _createName({
    required String name,
    required _Graffity description,
    required BoxConstraints constraints,
  }) {
    final size = PixelRainText.calculateSize(
      letters: PixelRainLetter.all,
      word: name.toUpperCase(),
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
    );

    final start = Offset(
      constraints.maxWidth / 2.0 - size.width / 2.0,
      description.start.dy - size.height - 64.0,
    );

    final pixels = PixelRainText.generateWordPixels(
      color: _twitchColor,
      word: name.toUpperCase(),
      letters: PixelRainLetter.all,
      pixelSize: _pixelSize,
      letterSpacing: _pixelSize,
      startOffset: start,
    );

    return _Graffity(size: size, pixels: pixels, start: start);
  }

  static _Graffity _createHeart({
    required BoxConstraints constraints,
    required _Graffity name,
  }) {
    final size = PixelRainText.calculateSize2(
      mask: PixelRainLetter.heart,
      pixelSize: _pixelSize,
    );

    final start = Offset(
      constraints.maxWidth / 2.0 - size.width / 2.0,
      constraints.maxHeight / 2.0 - size.height / 2.0,
    );

    final pixels = PixelRainText.generatePixels(
      mask: PixelRainLetter.heart,
      startOffset: start,
      pixelSize: _pixelSize,
      color: _twitchColor,
    );

    for (int i = 0; i < pixels.length; i++) {
      final from = name.pixels[i % name.pixels.length];
      pixels[i] = pixels[i].copy(startX: from.x, startY: from.y);
    }

    if (name.pixels.length > pixels.length) {
      for (int i = pixels.length; i < name.pixels.length; i++) {
        final from = name.pixels[i];
        pixels.add(
          Pixel(
            x: constraints.maxWidth - _pixelSize,
            y: constraints.maxHeight - _pixelSize,
            startX: from.x,
            startY: from.y,
            color: from.color,
            delayMs: from.delayMs,
          ),
        );
      }
    }

    return _Graffity(size: size, pixels: pixels, start: start);
  }

  @override
  void initState() {
    _description = _createDescription(
      text: 'is now tier 3 subscriber'.toUpperCase(),
      constraints: widget.constraints,
    );
    _heartBackground = _createHeartBackground(
      description: _description,
      constraints: widget.constraints,
    );
    _name = _createName(
      name: widget.who,
      description: _description,
      constraints: widget.constraints,
    );
    _heart = _createHeart(constraints: widget.constraints, name: _name);

    _startAnimation();
    super.initState();
  }

  bool _leaving = false;

  static const _startDuration = Duration(seconds: 5);

  void _startAnimation() async {
    await Future.delayed(Duration(seconds: 10));

    setState(() {
      _opacity = 0.0;
      _leaving = true;
    });
  }

  double _opacity = 1.0;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        /*Positioned(
          bottom: _description.size.height + 32.0 + 32.0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: Duration(seconds: 1),
            child: Container(
              height: _name.size.height + 32.0 + 32.0,
              width: double.infinity,
              color: Colors.white,
            ),
          ),
        ),
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: AnimatedOpacity(
            opacity: _opacity,
            duration: Duration(seconds: 1),
            child: Container(
              height: _description.size.height + 32.0 + 32.0,
              width: double.infinity,
              color: Color(0xFF3C3C3C),
            ),
          ),
        ),*/
        if (_leaving) ...[
          PixelRainText(
            key: ValueKey('heart_background'),
            constraints: widget.constraints,
            pixels: _heartBackground.pixels,
            duration: Duration(seconds: 5),
            fallDuration: Duration(milliseconds: 3000),
            pixelSize: _pixelSize,
            pixelPadding: 0.25,
          ),
          PixelRainText(
            key: ValueKey('heart'),
            constraints: widget.constraints,
            pixels: _heart.pixels,
            duration: Duration(seconds: 5),
            fallDuration: Duration(milliseconds: 3000),
            pixelSize: _pixelSize,
            pixelPadding: 0.25,
          ),
        ] else ...[
          PixelRainText(
            key: ValueKey('description'),
            constraints: widget.constraints,
            pixels: _description.pixels,
            duration: _startDuration,
            fallDuration: Duration(milliseconds: 3000),
            pixelSize: _pixelSize,
            pixelPadding: 0.5,
          ),
          PixelRainText(
            key: ValueKey('name'),
            constraints: widget.constraints,
            pixels: _name.pixels,
            duration: _startDuration,
            fallDuration: Duration(milliseconds: 3000),
            pixelSize: _pixelSize,
            pixelPadding: 0.5,
          ),
        ],
      ],
    );
  }
}

class _Graffity {
  final Size size;
  final Offset start;
  final List<Pixel> pixels;

  _Graffity({required this.size, required this.pixels, required this.start});
}
