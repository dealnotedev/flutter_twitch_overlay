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

  final paintBlack = Paint()..color = Colors.black;

  final paintWhite = Paint()..color = Colors.white;

  @override
  void paint(Canvas canvas, Size size) {
    final double width = size.width;
    final double height = size.height;

    final double maskTop, maskBottom;
    final double stripeHeight;
    final double stripeWidth;
    final double opacity;

    if (progress < 0.6) {
      final maskPhase = progress / 0.6;

      stripeHeight = lerpDouble(height, minStripeHeight, maskPhase)!;
      maskTop = (height - stripeHeight) / 2;
      maskBottom = maskTop + stripeHeight;
      stripeWidth = width;
      opacity = maskPhase.clamp(0.0, 1.0);
    } else {
      final linePhase = (progress - 0.6) / 0.4;

      stripeHeight = minStripeHeight;
      maskTop = (height - stripeHeight) / 2;
      maskBottom = maskTop + stripeHeight;
      stripeWidth =
          lerpDouble(width, minStripeWidth, linePhase.clamp(0.0, 1.0))!;
      opacity = 1.0;
    }

    if (progress >= 0.6) {
      canvas.drawRect(Rect.fromLTRB(0, 0, width, height), paintBlack);
    } else {
      canvas.drawRect(Rect.fromLTRB(0, 0, width, maskTop), paintBlack);
      canvas.drawRect(Rect.fromLTRB(0, maskBottom, width, height), paintBlack);
    }

    final stripeLeft = (width - stripeWidth) / 2;
    final stripeRight = stripeLeft + stripeWidth;

    final whiteRect = Rect.fromLTRB(
      stripeLeft,
      maskTop,
      stripeRight,
      maskBottom,
    );

    canvas.drawRect(
      whiteRect,
      paintWhite..color = Colors.white.withValues(alpha: opacity),
    );
  }

  @override
  bool shouldRepaint(_CRTOffPainter oldDelegate) =>
      progress != oldDelegate.progress;
}
