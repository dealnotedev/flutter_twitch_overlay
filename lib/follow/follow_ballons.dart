import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/follow/follow_ballons_config.dart';
import 'package:obssource/span_util.dart';

class FollowBallonsWidget extends StatelessWidget {
  static const _avatarPlaceholder = '{avatart_placeholder}';

  final UserFollowEvent event;
  final Duration duration;
  final BoxConstraints constraints;

  const FollowBallonsWidget({
    super.key,
    required this.event,
    required this.duration,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final config = FollowBallonsConfig.get();

    return AnimatedVerticalMover(
      duration: duration,
      size: Size(config.width, config.height),
      constraints: constraints,
      alreadyInsideStack: true,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LottieBuilder.asset(
            config.lottie,
            width: config.width,
            height: config.height,
            fit: BoxFit.cover,
            frameRate: FrameRate(60),
          ),
          Positioned(
            top: config.msgTop,
            left: config.msgLeft,
            child: Transform.rotate(
              angle: -0.15,
              child: Container(
                decoration: BoxDecoration(
                  color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(32),
                ),
                padding: EdgeInsets.all(16),
                child: RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(fontSize: 24),
                    children: SpanUtil.createSpansAdvanced(
                      context.localizations.user_now_following_title(
                        _avatarPlaceholder,
                        event.userName,
                      ),
                      [_avatarPlaceholder, event.userName],
                      (t) {
                        if (t == _avatarPlaceholder) {
                          return WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: Avatar(
                              size: 24,
                              url: event.user?.profileImageUrl,
                            ),
                          );
                        }
                        return TextSpan(
                          text: t,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
