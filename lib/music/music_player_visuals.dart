import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

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

class CosmicMusicSurface extends StatefulWidget {
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
  State<CosmicMusicSurface> createState() => _CosmicMusicSurfaceState();
}

class _CosmicMusicSurfaceState extends State<CosmicMusicSurface>
    with SingleTickerProviderStateMixin {
  late final CosmicMusicMotion _motion;
  late final Ticker _ticker;
  Duration _previousElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _motion = CosmicMusicMotion();
    _ticker = createTicker(_handleTick);
    if (!widget.compact) _ticker.start();
  }

  @override
  void didUpdateWidget(covariant CosmicMusicSurface oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.compact == widget.compact) return;

    _previousElapsed = Duration.zero;
    if (widget.compact) {
      _ticker.stop();
    } else {
      _ticker.start();
    }
  }

  void _handleTick(Duration elapsed) {
    final delta = elapsed - _previousElapsed;
    _previousElapsed = elapsed;
    _motion.advance(delta);
  }

  @override
  void dispose() {
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(widget.borderRadius);

    return RepaintBoundary(
      child: Container(
        width: widget.width,
        height: widget.height,
        decoration: BoxDecoration(
          color: MusicPlayerPalette.panel,
          borderRadius: radius,
          border:
              widget.drawBorder
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
                alpha: widget.compact ? 0.18 : 0.25,
              ),
              blurRadius: widget.compact ? 16 : 28,
              spreadRadius: widget.compact ? 0 : 1,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: Stack(
            children: [
              Positioned.fill(
                child: RepaintBoundary(
                  child: CustomPaint(
                    key: widget.backgroundKey,
                    painter: CosmicMusicBackgroundPainter(
                      motion: _motion,
                      compact: widget.compact,
                    ),
                  ),
                ),
              ),
              Padding(padding: widget.padding, child: widget.child),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small, deterministic-at-a-given-seed particle simulation for the player.
///
/// Positions are normalized, so the same motion works for every player height.
class CosmicMusicMotion extends ChangeNotifier {
  static const _maximumTick = Duration(milliseconds: 100);

  final math.Random _random;
  final List<_CosmicParticle> _particles = [];

  double _elapsedSeconds = 0;
  int _respawnCount = 0;

  CosmicMusicMotion({int? seed}) : _random = math.Random(seed) {
    for (var index = 0; index < 17; index++) {
      _particles.add(_createParticle(_CosmicParticleKind.spark));
    }
    for (var index = 0; index < 5; index++) {
      _particles.add(_createParticle(_CosmicParticleKind.bubble));
    }
    for (var index = 0; index < 4; index++) {
      _particles.add(_createParticle(_CosmicParticleKind.ring));
    }
  }

  double get elapsedSeconds => _elapsedSeconds;
  int get respawnCount => _respawnCount;

  void advance(Duration delta) {
    if (delta <= Duration.zero) return;

    // A suspended window must resume without particles jumping across the card.
    final clampedDelta = delta > _maximumTick ? _maximumTick : delta;
    final seconds = clampedDelta.inMicroseconds / Duration.microsecondsPerSecond;
    _elapsedSeconds += seconds;

    for (final particle in _particles) {
      particle.age += seconds;
      particle.turnPhase += particle.turnRate * seconds;
      particle.heading +=
          math.sin(particle.turnPhase) * particle.turnStrength * seconds;
      particle.position +=
          Offset(math.cos(particle.heading), math.sin(particle.heading)) *
          (particle.speed * seconds);

      if (_isFullyOutside(particle)) {
        _respawn(particle);
      }
    }

    notifyListeners();
  }

  _CosmicParticle _createParticle(_CosmicParticleKind kind) {
    final particle = _CosmicParticle(kind: kind);
    _randomizeParticle(particle, fadeIn: false);
    return particle;
  }

  bool _isFullyOutside(_CosmicParticle particle) {
    final margin = switch (particle.kind) {
      _CosmicParticleKind.spark => 0.035,
      _CosmicParticleKind.bubble => 0.075,
      _CosmicParticleKind.ring => 0.12,
    };
    final position = particle.position;
    return position.dx < -margin ||
        position.dx > 1 + margin ||
        position.dy < -margin ||
        position.dy > 1 + margin;
  }

  void _respawn(_CosmicParticle particle) {
    _respawnCount++;
    _randomizeParticle(particle, fadeIn: true);
  }

  void _randomizeParticle(
    _CosmicParticle particle, {
    required bool fadeIn,
  }) {
    particle
      ..position = Offset(
        0.03 + _random.nextDouble() * 0.94,
        0.05 + _random.nextDouble() * 0.90,
      )
      ..heading = _random.nextDouble() * math.pi * 2
      ..turnPhase = _random.nextDouble() * math.pi * 2
      ..turnRate = 0.16 + _random.nextDouble() * 0.34
      ..turnStrength = 0.08 + _random.nextDouble() * 0.24
      ..pulsePhase = _random.nextDouble() * math.pi * 2
      ..pulseRate = 0.55 + _random.nextDouble() * 0.95
      ..colorIndex = _random.nextInt(5)
      ..opacity = 0.48 + _random.nextDouble() * 0.34
      ..age = fadeIn ? 0 : 3;

    switch (particle.kind) {
      case _CosmicParticleKind.spark:
        particle
          ..radius = 0.65 + _random.nextDouble() * 0.8
          ..speed = 0.009 + _random.nextDouble() * 0.018;
        break;
      case _CosmicParticleKind.bubble:
        particle
          ..radius = 2.4 + _random.nextDouble() * 2.4
          ..speed = 0.006 + _random.nextDouble() * 0.012;
        break;
      case _CosmicParticleKind.ring:
        particle
          ..radius = 5.5 + _random.nextDouble() * 6
          ..speed = 0.004 + _random.nextDouble() * 0.009;
        break;
    }
  }
}

enum _CosmicParticleKind { spark, bubble, ring }

class _CosmicParticle {
  final _CosmicParticleKind kind;

  Offset position = Offset.zero;
  double heading = 0;
  double speed = 0;
  double radius = 0;
  double opacity = 0;
  double turnPhase = 0;
  double turnRate = 0;
  double turnStrength = 0;
  double pulsePhase = 0;
  double pulseRate = 0;
  double age = 0;
  int colorIndex = 0;

  _CosmicParticle({required this.kind});
}

class CosmicMusicBackgroundPainter extends CustomPainter {
  final bool compact;
  final CosmicMusicMotion motion;

  CosmicMusicBackgroundPainter({
    required this.motion,
    this.compact = false,
  }) : super(repaint: compact ? null : motion);

  double get elapsedSeconds => motion.elapsedSeconds;

  @override
  void paint(Canvas canvas, Size size) {
    final bounds = Offset.zero & size;
    final elapsed = compact ? 0.0 : motion.elapsedSeconds;
    _drawMovingGradient(canvas, bounds, elapsed);

    final pinkPhase = elapsed * 0.12;
    _drawNebula(
      canvas,
      bounds,
      center: Offset(
        size.width * (0.12 + math.sin(pinkPhase) * 0.12),
        size.height * (0.78 + math.cos(pinkPhase * 0.83) * 0.13),
      ),
      radius:
          size.longestSide *
          (compact ? 0.82 : 0.66 + math.sin(pinkPhase * 0.71) * 0.045),
      color: MusicPlayerPalette.neonPink,
      opacity: compact ? 0.30 : 0.24,
    );

    final bluePhase = elapsed * 0.095 + 1.7;
    _drawNebula(
      canvas,
      bounds,
      center: Offset(
        size.width * (0.88 + math.cos(bluePhase) * 0.10),
        size.height * (0.18 + math.sin(bluePhase * 0.89) * 0.12),
      ),
      radius:
          size.longestSide *
          (0.52 + (compact ? 0 : math.cos(bluePhase * 0.67) * 0.04)),
      color: MusicPlayerPalette.neonBlue,
      opacity: compact ? 0.15 : 0.11,
    );

    var compactSparks = 0;
    var compactBubbles = 0;
    var compactRings = 0;
    for (final particle in motion._particles) {
      if (compact) {
        final shouldDraw = switch (particle.kind) {
          _CosmicParticleKind.spark => compactSparks++ < 6,
          _CosmicParticleKind.bubble => compactBubbles++ < 1,
          _CosmicParticleKind.ring => compactRings++ < 1,
        };
        if (!shouldDraw) continue;
      }
      _drawParticle(canvas, size, particle, elapsed);
    }
  }

  void _drawMovingGradient(Canvas canvas, Rect bounds, double elapsed) {
    final phase = elapsed * 0.10;
    final start = Offset(
      bounds.width * (0.02 + math.sin(phase) * 0.12),
      bounds.height * (-0.08 + math.cos(phase * 0.73) * 0.15),
    );
    final end = Offset(
      bounds.width * (0.94 + math.cos(phase * 0.81) * 0.10),
      bounds.height * (1.05 + math.sin(phase * 0.67) * 0.12),
    );
    final middleStop = 0.48 + math.sin(phase * 0.47) * 0.08;

    canvas.drawRect(
      bounds,
      Paint()
        ..shader = ui.Gradient.linear(
          start,
          end,
          const [
            MusicPlayerPalette.deepPurple,
            MusicPlayerPalette.voidBlack,
            MusicPlayerPalette.midnight,
          ],
          [0, middleStop, 1],
        ),
    );
  }

  void _drawParticle(
    Canvas canvas,
    Size size,
    _CosmicParticle particle,
    double elapsed,
  ) {
    final center = Offset(
      particle.position.dx * size.width,
      particle.position.dy * size.height,
    );
    final fadeIn = Curves.easeOutCubic.transform(
      (particle.age / 1.4).clamp(0.0, 1.0),
    );
    final pulse =
        1 +
        math.sin(elapsed * particle.pulseRate + particle.pulsePhase) * 0.10;
    final radius = particle.radius * pulse;
    final color = switch (particle.colorIndex) {
      0 || 3 => MusicPlayerPalette.neonPink,
      1 => MusicPlayerPalette.neonBlue,
      _ => MusicPlayerPalette.textPrimary,
    };
    final opacity = particle.opacity * fadeIn;

    switch (particle.kind) {
      case _CosmicParticleKind.spark:
        canvas.drawCircle(
          center,
          radius * 3.2,
          Paint()..color = color.withValues(alpha: opacity * 0.13),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()..color = color.withValues(alpha: opacity),
        );
        break;
      case _CosmicParticleKind.bubble:
        canvas.drawCircle(
          center,
          radius * 2.1,
          Paint()
            ..shader = ui.Gradient.radial(center, radius * 2.1, [
              color.withValues(alpha: opacity * 0.20),
              color.withValues(alpha: 0),
            ]),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = color.withValues(alpha: opacity * 0.38)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.8,
        );
        canvas.drawCircle(
          center - Offset(radius * 0.28, radius * 0.28),
          math.max(0.55, radius * 0.18),
          Paint()
            ..color = MusicPlayerPalette.textPrimary.withValues(
              alpha: opacity * 0.62,
            ),
        );
        break;
      case _CosmicParticleKind.ring:
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = color.withValues(alpha: opacity * 0.22)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 4
            ..maskFilter = const ui.MaskFilter.blur(ui.BlurStyle.normal, 4),
        );
        canvas.drawCircle(
          center,
          radius,
          Paint()
            ..color = color.withValues(alpha: opacity * 0.72)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        break;
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
    return oldDelegate.compact != compact || oldDelegate.motion != motion;
  }
}
