import 'dart:async';

import 'package:flutter/material.dart';
import 'package:obssource/pixel_rain_letters.dart';

class SequentialPixelRainLetterA extends StatefulWidget {
  final BoxConstraints constraints;
  final PixelRainLetter letter;
  final double pixelSize;

  final Duration duration;
  final Color? color;

  const SequentialPixelRainLetterA({
    super.key,
    required this.constraints,
    required this.letter,
    this.pixelSize = 16,
    required this.duration,
    required this.color,
  });

  @override
  State<SequentialPixelRainLetterA> createState() =>
      _SequentialPixelRainLetterAState();
}

class _SequentialPixelRainLetterAState
    extends State<SequentialPixelRainLetterA> {
  final _colorA = Color(0xFF541D22);
  final _colorB = Color(0xFF830C18);

  late List<_Pixel> pixels;
  late Duration dropDuration;

  int animatedPixels = 0;

  @override
  void initState() {
    super.initState();
    pixels = _generatePixels();

    final micros = widget.duration.inMicroseconds / pixels.length;
    dropDuration = Duration(microseconds: micros.toInt());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startSequentialAnimation();
    });
  }

  List<_Pixel> _generatePixels() {
    final List<_Pixel> result = [];
    final data = widget.letter.data;

    for (int y = 0; y < data.length; y++) {
      for (int x = 0; x < data[y].length; x++) {
        if (data[y][x] == 1) {
          result.add(
            _Pixel(
              x: x,
              y: y,
              color: (widget.color ?? ((x + y) % 2 == 0 ? _colorB : _colorB)),
            ),
          );
        }
      }
    }

    result.sort((a, b) => a.x != b.x ? a.x - b.x : a.y - b.y);
    return result;
  }

  Future<void> _startSequentialAnimation() async {
    for (int i = 0; i < pixels.length; i++) {
      setState(() {
        animatedPixels = i + 1;
      });

      await Future.delayed(dropDuration);
    }
  }

  double get pixelSize => widget.pixelSize;

  static const _paddingBottom = 16.0;

  @override
  Widget build(BuildContext context) {
    final data = widget.letter.data;

    final letterWidth = data[0].length * pixelSize.toDouble();
    final letterHeight = data.length * pixelSize.toDouble();

    final widgetWidth = widget.letter.width.toDouble() * pixelSize;
    final widgetHeight = widget.constraints.maxHeight;

    final dx = (widgetWidth - letterWidth) / 2;
    final dy = widgetHeight - letterHeight;

    return SizedBox(
      height: widgetHeight,
      width: widgetWidth,
      child: Stack(
        children:
            pixels.asMap().entries.map((entry) {
              final i = entry.key;
              final pixel = entry.value;

              final x = dx + pixel.x * pixelSize.toDouble();
              final targetY = dy + pixel.y * pixelSize.toDouble();
              final y = i < animatedPixels ? targetY : 0.0;

              return AnimatedPositioned(
                key: ValueKey("pixel-$i"),
                left: x,
                top: y,
                duration: dropDuration,
                curve: Curves.easeIn,
                child: Container(
                  width: pixelSize.toDouble(),
                  height: pixelSize.toDouble(),
                  padding: EdgeInsets.all(2),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: pixel.color,
                      borderRadius: BorderRadius.circular(2),
                      border: Border.all(
                        color: Colors.black,
                        width: 1,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
      ),
    );
  }
}

class _Pixel {
  final int x;
  final int y;
  final Color color;

  _Pixel({required this.x, required this.y, required this.color});
}
