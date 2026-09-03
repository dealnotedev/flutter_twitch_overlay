import 'dart:ui' as ui;

import 'package:flutter/material.dart';

abstract final class MusicPlayerPalette {
  static const voidBlack = Color(0xFF030518);
  static const midnight = Color(0xFF080A28);
  static const deepPurple = Color(0xFF22072F);
  static const panel = Color(0xEB08091E);
  static const panelSoft = Color(0xB814102D);
  static const neonPink = Color(0xFFFF3EA5);
  static const neonPinkBright = Color(0xFFFFD9F1);
  static const neonBlue = Color(0xFF55C9FF);
  static const textPrimary = Color(0xFFFDF7FF);
  static const textSecondary = Color(0xFFC8C3D8);
  static const error = Color(0xFFFF7CBA);

  static const pinkTextGlow = <Shadow>[
    Shadow(color: Color(0xFFFFD5EF), blurRadius: 2),
    Shadow(color: Color(0xFFFF3EA5), blurRadius: 8),
    Shadow(color: Color(0x99FF168F), blurRadius: 18),
  ];
}

class CosmicMusicSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double width;
  final double? height;
  final double borderRadius;
  final bool compact;
  final bool drawBorder;
  final Key? backgroundKey;

  const CosmicMusicSurface({
    super.key,
    required this.child,
    required this.width,
    this.height,
    this.padding = EdgeInsets.zero,
    this.borderRadius = 18,
    this.compact = false,
    this.drawBorder = true,
    this.backgroundKey,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return RepaintBoundary(
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: MusicPlayerPalette.panel,
          borderRadius: radius,
          border:
              drawBorder
                  ? Border.all(
                    color: MusicPlayerPalette.neonPink.withValues(alpha: 0.58),
                  )
                  : null,
          boxShadow: [
            const BoxShadow(
              color: Color(0x99000000),
              blurRadius: 24,
              offset: Offset(0, 9),
            ),
            BoxShadow(
              color: MusicPlayerPalette.neonPink.withValues(
                alpha: compact ? 0.18 : 0.25,
              ),
              blurRadius: compact ? 16 : 28,
              spreadRadius: compact ? 0 : 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: CustomPaint(
            key: backgroundKey,
            painter: CosmicMusicBackgroundPainter(compact: compact),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

class CosmicMusicBackgroundPainter extends CustomPainter {
  final bool compact;

  const CosmicMusicBackgroundPainter({this.compact = false});

  static const _stars = <Offset>[
    Offset(0.06, 0.17),
    Offset(0.14, 0.39),
    Offset(0.22, 0.12),
    Offset(0.31, 0.27),
    Offset(0.39, 0.08),
    Offset(0.48, 0.33),
    Offset(0.57, 0.14),
    Offset(0.67, 0.42),
    Offset(0.76, 0.18),
    Offset(0.87, 0.31),
    Offset(0.94, 0.09),
    Offset(0.09, 0.72),
    Offset(0.19, 0.88),
    Offset(0.29, 0.61),
    Offset(0.43, 0.79),
    Offset(0.53, 0.55),
    Offset(0.62, 0.86),
    Offset(0.73, 0.68),
    Offset(0.82, 0.91),
    Offset(0.91, 0.59),
    Offset(0.35, 0.48),
    Offset(0.98, 0.77),
  ];

  static const _rings = <Offset>[
    Offset(0.18, 0.24),
    Offset(0.68, 0.16),
    Offset(0.88, 0.72),
    Offset(0.42, 0.83),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height),
          const [
            MusicPlayerPalette.deepPurple,
            MusicPlayerPalette.voidBlack,
            MusicPlayerPalette.midnight,
          ],
          const [0, 0.52, 1],
        ),
    );

    _drawNebula(
      canvas,
      bounds,
      center: Offset(size.width * 0.12, size.height * 0.82),
      radius: size.longestSide * (compact ? 0.82 : 0.68),
      color: MusicPlayerPalette.neonPink,
      opacity: compact ? 0.30 : 0.25,
    );
    _drawNebula(
      canvas,
      bounds,
      center: Offset(size.width * 0.93, size.height * 0.12),
      radius: size.longestSide * 0.54,
      color: MusicPlayerPalette.neonBlue,
      opacity: compact ? 0.15 : 0.11,
    );

    final starCount = compact ? 8 : _stars.length;
    for (var index = 0; index < starCount; index++) {
      final normalized = _stars[index];
      final center = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      final color = switch (index % 5) {
        0 || 3 => MusicPlayerPalette.neonPink,
        1 => MusicPlayerPalette.neonBlue,
        _ => MusicPlayerPalette.textPrimary,
      };
      final radius = 0.65 + (index % 3) * 0.35;
      canvas.drawCircle(
        center,
        radius * 3.2,
        Paint()..color = color.withValues(alpha: 0.10),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = color.withValues(alpha: 0.74),
      );
    }

    final ringCount = compact ? 1 : _rings.length;
    for (var index = 0; index < ringCount; index++) {
      final normalized = _rings[index];
      final center = Offset(
        normalized.dx * size.width,
        normalized.dy * size.height,
      );
      final radius = compact ? 5.0 : 5.5 + index * 1.6;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = MusicPlayerPalette.neonPink.withValues(alpha: 0.16)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = MusicPlayerPalette.neonPink.withValues(alpha: 0.55)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2,
      );
    }
  }

  void _drawNebula(
    Canvas canvas,
    Rect bounds, {
    required Offset center,
    required double radius,
    required Color color,
    required double opacity,
  }) {
    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, [
          color.withValues(alpha: opacity),
          color.withValues(alpha: 0),
        ]),
    );
  }

  @override
  bool shouldRepaint(covariant CosmicMusicBackgroundPainter oldDelegate) {
    return oldDelegate.compact != compact;
  }
}
