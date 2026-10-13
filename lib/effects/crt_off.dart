import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/span_util.dart';

/// The screen is switched off by a viewer for a while.
class CrtEffect {
  /// Stays the same while repeated redemptions extend the effect, so the
  /// switch-off animation is not replayed.
  final int session;
  final String userName;
  final String? avatarUrl;

  const CrtEffect({
    required this.session,
    required this.userName,
    required this.avatarUrl,
  });
}

/// Old TV switch-off, then the "dulya" picture and who redeemed it.
class CrtOffEffectWidget extends StatefulWidget {
  final CrtEffect effect;

  const CrtOffEffectWidget({super.key, required this.effect});

  @override
  State<CrtOffEffectWidget> createState() => _CrtOffEffectWidgetState();
}

class _CrtOffEffectWidgetState extends State<CrtOffEffectWidget> {
  static const _avatarPlaceholder = '{user_avatar}';

  bool _off = false;

  @override
  Widget build(BuildContext context) {
    final effect = widget.effect;
    return Stack(
      children: [
        CRTOffAnimation(onEnd: () => setState(() => _off = true)),
        if (_off) ...[
          Center(
            child: Image.asset(Assets.assetsIcDulya, width: 200, height: 200),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: RichText(
                text: TextSpan(
                  style: const TextStyle(fontSize: 20, color: Colors.white),
                  children: SpanUtil.createSpansAdvanced(
                    context.localizations.by_user(
                      _avatarPlaceholder,
                      effect.userName,
                    ),
                    [_avatarPlaceholder, effect.userName],
                    (text) {
                      if (text == _avatarPlaceholder) {
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Avatar(size: 24, url: effect.avatarUrl),
                        );
                      }
                      return TextSpan(
                        text: text,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

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
