import 'dart:math';

import 'package:flutter/material.dart';
import 'package:simple_animations/simple_animations.dart';

class AnimatedWave extends StatelessWidget {
  final double height;
  final double speed;
  final double offset;
  final Color color;
  final int alpha;

  const AnimatedWave({
    required this.height,
    required this.speed,
    this.offset = 0.0,
    this.color = Colors.white,
    this.alpha = 15,
    super.key,
  });

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder:
        (context, constraints) => SizedBox(
          height: height,
          width: constraints.biggest.width,
          child: LoopAnimationBuilder(
            duration: Duration(milliseconds: (5000 / speed).round()),
            tween: Tween(begin: 0.0, end: 2 * pi),
            builder:
                (context, value, _) => CustomPaint(
                  foregroundPainter: CurvePainter(value + offset, color, alpha),
                ),
          ),
        ),
  );
}

class CurvePainter extends CustomPainter {
  final double value;
  final Color color;
  final int alpha;

  CurvePainter(this.value, this.color, this.alpha);

  final Paint _paint = Paint();
  final Path _path = Path();

  @override
  void paint(Canvas canvas, Size size) {
    final white = _paint..color = color.withAlpha(alpha);

    _path.reset();

    final y1 = sin(value);
    final y2 = sin(value + pi / 2);
    final y3 = sin(value + pi);

    final startPointY = size.height * (0.5 + 0.4 * y1);
    final controlPointY = size.height * (0.5 + 0.4 * y2);
    final endPointY = size.height * (0.5 + 0.4 * y3);

    _path.moveTo(size.width * 0, startPointY);
    _path.quadraticBezierTo(
      size.width * 0.5,
      controlPointY,
      size.width,
      endPointY,
    );
    _path.lineTo(size.width, size.height);
    _path.lineTo(0, size.height);
    _path.close();

    canvas.drawPath(_path, white);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return true;
  }
}
