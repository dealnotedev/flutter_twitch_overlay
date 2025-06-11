import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/highlighed/highlighted_message_config.dart';

class HighlightedMessage {
  final bool firstMessage;

  final Color color;
  final String title;
  final String id;
  final List<InlineSpan> text;

  HighlightedMessage({
    required this.id,
    required this.firstMessage,
    required this.text,
    required this.title,
    required this.color,
  });
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
    final config = HighlightedMessageConfig.get(event);

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
