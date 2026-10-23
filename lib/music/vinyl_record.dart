import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:obssource/music/turntable_geometry.dart';

enum VinylEdition {
  classic,
  clear,
  marble,
  gold;

  /// Roll once per request, consistently across snapshots and widget rebuilds.
  /// A new request for the same song can receive a different edition.
  static VinylEdition forItem(String itemId) {
    var seed = 0;
    for (final unit in itemId.codeUnits) {
      seed = (seed * 31 + unit) & 0x7fffffff;
    }
    final roll = math.Random(seed).nextInt(100);
    if (roll < 85) return classic;
    if (roll < 93) return clear;
    if (roll < 98) return marble;
    return gold;
  }
}

/// The oversized circular label occupies 58% of the record's diameter.
class VinylRecord extends StatelessWidget {
  final ImageProvider? artwork;
  final VinylEdition edition;

  const VinylRecord({
    super.key,
    this.artwork,
    this.edition = VinylEdition.classic,
  });

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: TurntableGeometry.recordRadius * 2,
      child: CustomPaint(
        painter: _VinylPainter(edition),
        child: Center(
          child: SizedBox.square(
            dimension: TurntableGeometry.labelRadius * 2,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF8D3977),
                          Color(0xFF302C64),
                          Color(0xFF11182F),
                        ],
                      ),
                    ),
                  ),
                  if (artwork != null)
                    Image(
                      image: artwork!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0x55FFFFFF), width: 1.5),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x28FFFFFF),
                          Color(0x00000000),
                          Color(0x38000000),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111118),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF807C8B),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _VinylPainter extends CustomPainter {
  final VinylEdition edition;

  const _VinylPainter(this.edition);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    final transparent = edition == VinylEdition.clear;
    final disc =
        Path()..addOval(Rect.fromCircle(center: center, radius: radius));
    canvas.drawShadow(
      disc,
      Colors.black.withValues(alpha: transparent ? 0.22 : 1),
      transparent ? 4 : 9,
      true,
    );
    final bodyColors = switch (edition) {
      VinylEdition.classic => const [
        Color(0xFF292932),
        Color(0xFF101016),
        Color(0xFF22222C),
        Color(0xFF08090D),
      ],
      VinylEdition.clear => const [
        Color(0x187EDBD8),
        Color(0x308FCACB),
        Color(0x208AB5CB),
        Color(0x55C1E8EF),
      ],
      VinylEdition.marble => const [
        Color(0xFFF4EDF2),
        Color(0xFFD7CEE3),
        Color(0xFFF7F1E9),
        Color(0xFFAEA4C2),
      ],
      VinylEdition.gold => const [
        Color(0xFFF5D68A),
        Color(0xFFC79235),
        Color(0xFFF6DA96),
        Color(0xFF9C6420),
      ],
    };
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(center, radius, bodyColors, const [
          0,
          0.62,
          0.84,
          1,
        ]),
    );
    if (edition == VinylEdition.marble) {
      _paintMarble(canvas, center, radius, disc);
    } else if (edition == VinylEdition.gold) {
      _paintGold(canvas, center, radius);
    }

    final grooveColor = switch (edition) {
      VinylEdition.classic => const Color(0xFF393842),
      VinylEdition.clear => const Color(0xFFCCE9EC),
      VinylEdition.marble => const Color(0xFF695775),
      VinylEdition.gold => const Color(0xFF71491E),
    };
    for (var r = TurntableGeometry.labelRadius + 3; r < radius - 2; r += 2.2) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = grooveColor.withValues(
            alpha: transparent ? 0.16 : (r % 3 < 1 ? 0.6 : 0.3),
          )
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65,
      );
    }
    final reflection = switch (edition) {
      VinylEdition.clear => const Color(0x88EDFFFF),
      VinylEdition.gold => const Color(0x65FFF5C8),
      _ => const Color(0x22FFFFFF),
    };
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          [
            const Color(0x00FFFFFF),
            reflection,
            const Color(0x00FFFFFF),
            const Color(0x00FFFFFF),
            reflection.withValues(alpha: transparent ? 0.28 : 0.1),
            const Color(0x00FFFFFF),
          ],
          const [0, 0.13, 0.27, 0.5, 0.67, 1],
        ),
    );
    final rimColor = switch (edition) {
      VinylEdition.classic => const Color(0xFF555360),
      VinylEdition.clear => const Color(0xBBDDFAFF),
      VinylEdition.marble => const Color(0xFFDDD4E8),
      VinylEdition.gold => const Color(0xFFFFE4A2),
    };
    canvas.drawCircle(
      center,
      radius - 0.8,
      Paint()
        ..color = rimColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = transparent ? 1.4 : 1,
    );
    if (transparent) {
      canvas.drawCircle(
        center,
        TurntableGeometry.labelRadius + 2,
        Paint()
          ..color = const Color(0x558CCDD2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
  }

  void _paintMarble(Canvas canvas, Offset center, double radius, Path disc) {
    canvas.save();
    canvas.clipPath(disc);
    canvas.translate(center.dx, center.dy);
    canvas.rotate(-0.48);
    for (var band = -7; band <= 7; band++) {
      final path = Path();
      for (var step = 0; step <= 70; step++) {
        final x = -radius * 1.5 + step / 70 * radius * 3;
        final wave =
            math.sin(x / radius * 2.8 + band * 0.48) * radius * 0.2 +
            math.sin(x / radius * 5.6 - band * 0.22) * radius * 0.065;
        final y = band * 19.0 + wave;
        if (step == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(
            0xFF695581,
          ).withValues(alpha: band.isEven ? 0.6 : 0.25)
          ..style = PaintingStyle.stroke
          ..strokeWidth = band.isEven ? 9 : 4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        path.shift(const Offset(0, -4)),
        Paint()
          ..color = const Color(0xCCFFFAF1)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.3,
      );
    }
    canvas.restore();
  }

  void _paintGold(Canvas canvas, Offset center, double radius) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          const [
            Color(0x005B340D),
            Color(0xB3774B14),
            Color(0xCCFFF3BC),
            Color(0x33774B14),
            Color(0xC08E5919),
            Color(0xDDFFF0AD),
            Color(0x005B340D),
          ],
          const [0, 0.13, 0.24, 0.4, 0.61, 0.75, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) =>
      edition != oldDelegate.edition;
}
