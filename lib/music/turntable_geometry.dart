import 'dart:math' as math;
import 'dart:ui';

/// Needle travel stays within the grooves, clear of the oversized cover label.
abstract final class TurntableGeometry {
  static const deckSize = Size(440, 281);
  static const chassisOrigin = Offset(14, 22);
  static const footSize = Size(39, 16);
  static const platterCenter = Offset(158, 147);
  static const recordRadius = 110.0;
  static const labelRadius = 64.0;
  static const outerGrooveRadius = recordRadius - 5;
  static const innerGrooveRadius = labelRadius + 8;
  static const armPivot = Offset(340, 62);
  static const needleOffset = Offset(-15, 162);

  static double trackingAngle(double progress) {
    final radius =
        outerGrooveRadius +
        (innerGrooveRadius - outerGrooveRadius) * progress.clamp(0.0, 1.0);
    final toSpindle = platterCenter - armPivot;
    final distance = toSpindle.distance;
    final armLength = needleOffset.distance;
    final cosine =
        (distance * distance + armLength * armLength - radius * radius) /
        (2 * distance * armLength);
    return toSpindle.direction -
        math.acos(cosine.clamp(-1.0, 1.0)) -
        needleOffset.direction;
  }

  static Offset needlePosition(double angle, {double lift = 0}) {
    final tip = needleOffset - Offset(0, lift * 2);
    return armPivot +
        Offset(
          tip.dx * math.cos(angle) - tip.dy * math.sin(angle),
          tip.dx * math.sin(angle) + tip.dy * math.cos(angle),
        );
  }
}
