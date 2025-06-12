import 'dart:ui';

class Pixel {
  final double x;
  final double y;
  final double startX;
  final double startY;
  final Color color;
  final int delayMs;

  Pixel({
    required this.x,
    required this.y,
    required this.startX,
    required this.startY,
    required this.color,
    required this.delayMs,
  });

  Pixel copy({double? startX, double? startY}) {
    return Pixel(
      x: x,
      y: y,
      startX: startX ?? this.startX,
      startY: startY ?? this.startY,
      color: color,
      delayMs: delayMs,
    );
  }
}
