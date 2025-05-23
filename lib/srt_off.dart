import 'dart:ui';

import 'package:flutter/material.dart';

class CRTOffAnimation extends StatefulWidget {
  final Duration duration;
  final VoidCallback? onEnd;

  const CRTOffAnimation({
    super.key,
    this.duration = const Duration(milliseconds: 1200),
    this.onEnd,
  });

  @override
  State<CRTOffAnimation> createState() => _CRTOffAnimationState();
}

class _CRTOffAnimationState extends State<CRTOffAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progress;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);

    _progress = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);

    _controller.forward().then((_) {
      widget.onEnd?.call();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _progress,
      builder: (context, child) {
        return CustomPaint(
          painter: _CRTOffPainter(_progress.value),
          size: Size.infinite,
        );
      },
    );
  }
}

class _CRTOffPainter extends CustomPainter {
  final double progress;
  static const double minStripeHeight = 4.0;
  static const double minStripeWidth = 4.0;

  _CRTOffPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);

    final double maskTop, maskBottom;
    final double stripeHeight;
    double stripeWidth;
    double lineOpacity = 1.0;

    if (progress < 0.6) {
      double maskPhase = progress / 0.6;
      stripeHeight = lerpDouble(size.height, minStripeHeight, maskPhase)!;
      maskTop = (size.height - stripeHeight) / 2;
      maskBottom = maskTop + stripeHeight;
      stripeWidth = size.width;
      lineOpacity = lerpDouble(0.0, 1.0, maskPhase.clamp(0.0, 1.0))!;
    } else if (progress < 0.85) {
      stripeHeight = minStripeHeight;
      maskTop = (size.height - stripeHeight) / 2;
      maskBottom = maskTop + stripeHeight;
      stripeWidth = size.width;
      lineOpacity = 1.0;
    } else {
      double phase = (progress - 0.85) / 0.15;
      stripeHeight = minStripeHeight;
      maskTop = (size.height - stripeHeight) / 2;
      maskBottom = maskTop + stripeHeight;
      stripeWidth =
          lerpDouble(size.width, minStripeWidth, phase.clamp(0.0, 1.0))!;
      lineOpacity = 1.0;

      if (phase >= 1.0) {
        stripeWidth = minStripeWidth;
      }
    }

    if (maskTop > 0) {
      canvas.drawRect(
        Rect.fromLTRB(0, 0, size.width, maskTop),
        Paint()..color = Colors.black,
      );
    }

    if (maskBottom < size.height) {
      canvas.drawRect(
        Rect.fromLTRB(0, maskBottom, size.width, size.height),
        Paint()..color = Colors.black,
      );
    }

    if (stripeWidth < size.width) {
      double left = (size.width - stripeWidth) / 2;
      double right = left + stripeWidth;
      if (left > 0) {
        canvas.drawRect(
          Rect.fromLTRB(0, maskTop, left, maskBottom),
          Paint()..color = Colors.black,
        );
      }
      if (right < size.width) {
        canvas.drawRect(
          Rect.fromLTRB(right, maskTop, size.width, maskBottom),
          Paint()..color = Colors.black,
        );
      }
    }

    if (lineOpacity > 0.0) {
      final rect = Rect.fromCenter(
        center: center,
        width: stripeWidth,
        height: stripeHeight,
      );
      final paint =
          Paint()..color = Colors.white.withValues(alpha: lineOpacity);
      canvas.drawRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(_CRTOffPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
