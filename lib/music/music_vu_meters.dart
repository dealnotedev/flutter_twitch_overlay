import 'dart:math' as math;

import 'package:flutter/material.dart';

class MusicVuMeters extends StatelessWidget {
  final double left;
  final double right;

  const MusicVuMeters({super.key, required this.left, required this.right});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(12, 4, 12, 6),
    child: SizedBox(
      height: 66,
      child: Row(
        children: [
          Expanded(
            child: AnalogVuMeter(
              key: const ValueKey('turntable_vu_left'),
              channel: 'L',
              level: left,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: AnalogVuMeter(
              key: const ValueKey('turntable_vu_right'),
              channel: 'R',
              level: right,
            ),
          ),
        ],
      ),
    ),
  );
}

class AnalogVuMeter extends StatelessWidget {
  final String channel;
  final double level;

  const AnalogVuMeter({super.key, required this.channel, required this.level});

  @override
  Widget build(BuildContext context) => Semantics(
    label: 'VU $channel',
    value: '${(level * 100).round()}%',
    child: RepaintBoundary(
      child: SizedBox.expand(
        child: Stack(
          fit: StackFit.expand,
          children: [
            RepaintBoundary(
              child: CustomPaint(
                painter: _VuFacePainter(
                  channel: channel,
                  fontFamily:
                      Theme.of(context).textTheme.bodyMedium?.fontFamily,
                ),
              ),
            ),
            CustomPaint(painter: _VuNeedlePainter(level)),
          ],
        ),
      ),
    ),
  );
}

class _VuFacePainter extends CustomPainter {
  final String channel;
  final String? fontFamily;

  const _VuFacePainter({required this.channel, this.fontFamily});

  static const _start = -math.pi * 0.88;
  static const _sweep = math.pi * 0.76;

  @override
  void paint(Canvas canvas, Size size) {
    final frame = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    );
    canvas.drawRRect(frame, Paint()..color = const Color(0xFF17131B));
    final face = frame.deflate(3);
    canvas.drawRRect(
      face,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF5DEAC), Color(0xFFE9C78C), Color(0xFFBA955F)],
        ).createShader(Offset.zero & size),
    );
    canvas.save();
    canvas.clipRRect(face);
    final pivot = Offset(size.width / 2, size.height - 7);
    final radius = math.min(size.height - 19, size.width * 0.43);
    Offset point(double value, double r) {
      final angle = _start + value * _sweep;
      return pivot + Offset(math.cos(angle), math.sin(angle)) * r;
    }

    final scale = Rect.fromCircle(center: pivot, radius: radius);
    canvas.drawArc(
      scale,
      _start,
      _sweep * 20 / 23,
      false,
      Paint()
        ..color = const Color(0xFF5F4430)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
    canvas.drawArc(
      scale,
      _start + _sweep * 20 / 23,
      _sweep * 3 / 23,
      false,
      Paint()
        ..color = const Color(0xFFAF463A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    for (var vu = -20; vu <= 3; vu++) {
      final value = (vu + 20) / 23;
      final major = const [-20, -10, -5, 0, 3].contains(vu);
      canvas.drawLine(
        point(value, radius - (major ? 5 : 2.5)),
        point(value, radius),
        Paint()
          ..color = vu > 0 ? const Color(0xFF9A3D32) : const Color(0xFF644934)
          ..strokeWidth = major ? 0.9 : 0.5,
      );
      if (major) {
        _text(
          canvas,
          vu > 0 ? '+$vu' : '$vu',
          point(value, radius + 7),
          7,
          vu > 0 ? const Color(0xFF9A3D32) : const Color(0xFF644934),
        );
      }
    }
    _text(
      canvas,
      channel,
      Offset(17, size.height - 15),
      9,
      const Color(0xFF614632),
      weight: FontWeight.w600,
    );
    _text(
      canvas,
      'VU',
      Offset(size.width - 21, size.height - 15),
      8,
      const Color(0xFF614632),
      weight: FontWeight.w600,
    );
    canvas.restore();
    canvas.drawRRect(
      face,
      Paint()
        ..color = const Color(0x557A665A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.8,
    );
  }

  void _text(
    Canvas canvas,
    String text,
    Offset center,
    double size,
    Color color, {
    FontWeight weight = FontWeight.w500,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: fontFamily,
          fontSize: size,
          fontWeight: weight,
          color: color,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    painter.paint(
      canvas,
      center - Offset(painter.width / 2, painter.height / 2),
    );
    painter.dispose();
  }

  @override
  bool shouldRepaint(covariant _VuFacePainter oldDelegate) =>
      oldDelegate.channel != channel || oldDelegate.fontFamily != fontFamily;
}

class _VuNeedlePainter extends CustomPainter {
  final double level;

  const _VuNeedlePainter(this.level);

  @override
  void paint(Canvas canvas, Size size) {
    final face = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(7),
    ).deflate(3);
    canvas.save();
    canvas.clipRRect(face);
    final pivot = Offset(size.width / 2, size.height - 7);
    final radius = math.min(size.height - 19, size.width * 0.43);
    final angle =
        _VuFacePainter._start + level.clamp(0.0, 1.0) * _VuFacePainter._sweep;
    final tip = pivot + Offset(math.cos(angle), math.sin(angle)) * (radius - 4);
    canvas.drawLine(
      pivot + const Offset(1, 1),
      tip + const Offset(1, 1),
      Paint()
        ..color = const Color(0x55412721)
        ..strokeWidth = 1.8
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      pivot,
      tip,
      Paint()
        ..color = const Color(0xFFAD352F)
        ..strokeWidth = 1.25
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(pivot, 3.5, Paint()..color = const Color(0xFF503A30));
    canvas.drawCircle(pivot, 1.5, Paint()..color = const Color(0xFFCEB794));
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _VuNeedlePainter oldDelegate) =>
      oldDelegate.level != level;
}
