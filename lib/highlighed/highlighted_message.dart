import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/generated/assets.dart';

class HighlightedMessage {
  final bool firstMessage;

  final Color color;
  final String title;
  final String id;
  final List<InlineSpan> text;

  final HighlightedMessageConfig config;

  HighlightedMessage({
    required this.id,
    required this.firstMessage,
    required this.text,
    required this.title,
    required this.color,
    required this.config,
  });
}

class HighlightedMessageConfig {
  final String lottie;
  final double bottomOffset;
  final double msgLeft;
  final double msgBottom;

  final double width;
  final double height;

  HighlightedMessageConfig({
    required this.lottie,
    required this.bottomOffset,
    required this.msgLeft,
    required this.msgBottom,
    required this.width,
    required this.height,
  });

  static final _random = Random();

  static HighlightedMessageConfig get() {
    switch (_random.nextInt(3)) {
      case 1:
        return HighlightedMessageConfig(
          lottie: Assets.assetsGiraffe,
          bottomOffset: -54,
          msgLeft: 300,
          msgBottom: 320,
          width: 400,
          height: 400,
        );
      case 2:
        return HighlightedMessageConfig(
          lottie: Assets.assetsBear,
          bottomOffset: -54,
          msgLeft: 256,
          msgBottom: 280,
          width: 400,
          height: 400,
        );

      case 0:
      default:
        return HighlightedMessageConfig(
          lottie: Assets.assetsRooster,
          bottomOffset: -84,
          msgLeft: 260,
          msgBottom: 280,
          width: 400,
          height: 400,
        );
    }
  }
}

class HighlightedMessageWidget extends StatelessWidget {
  final Duration duration;
  final HighlightedMessage event;
  final BoxConstraints constraints;

  const HighlightedMessageWidget({
    super.key,
    required this.event,
    required this.duration,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final config = event.config;

    return AnimatedHorizontalMover(
      alreadyInsideStack: true,
      constraints: constraints,
      duration: duration,
      size: Size(config.width, config.height),
      bottomOffset: config.bottomOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LottieBuilder.asset(
            config.lottie,
            width: config.width,
            height: config.height,
            frameRate: FrameRate(60),
          ),
          Positioned(
            left: config.msgLeft,
            bottom: config.msgBottom,
            child: Transform.rotate(
              angle: -0.25,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: BoxConstraints(maxWidth: 448),
                    decoration: BoxDecoration(
                      color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: EdgeInsets.only(
                      left: 16,
                      right: 16,
                      bottom: 12,
                      top: 12,
                    ),
                    child: RichText(
                      textWidthBasis: TextWidthBasis.longestLine,
                      text: TextSpan(
                        style: TextStyle(fontSize: 16, color: Colors.white),
                        children: event.text,
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    top: -16,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: event.color,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        event.title,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
