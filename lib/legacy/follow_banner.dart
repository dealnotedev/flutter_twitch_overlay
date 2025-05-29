import 'package:cool_background_animation/cool_background_animation.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/data/events.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/span_util.dart';

class _FollowWidget extends StatelessWidget {
  final UserFollowEvent event;

  const _FollowWidget({super.key, required this.event});

  static const _avatarPlaceholder = '{avatart_placeholder}';

  @override
  Widget build(BuildContext context) {
    final userName = event.userName;
    final user = event.user;

    return Stack(
      children: [
        Positioned(
          top: 0,
          bottom: 0,
          right: 0,
          left: 0,
          child: BubbleBackground(
            bubbleColors: [
              Color(0xFFFCE9B9),
              Color(0xFFF58A1F),
              Color(0xFFFFB000),
              Color(0xFFFFCC59),
            ],
            numberOfBubbles: 16,
          ),
        ),
        Container(
          padding: EdgeInsets.all(16),
          constraints: BoxConstraints(maxWidth: 512),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(128),
            color: Color(0xFF3C3C3C).withValues(alpha: 0.75),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              LottieBuilder.asset(
                Assets.assetsFollowAnimation,
                width: 306,
                height: 189,
                repeat: false,
                frameRate: FrameRate.max,
              ),
              Gap(16),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(fontSize: 40),
                  children: SpanUtil.createSpansAdvanced(
                    context.localizations.user_now_following_title(
                      _avatarPlaceholder,
                      userName,
                    ),
                    [_avatarPlaceholder, userName],
                    (t) {
                      if (t == _avatarPlaceholder) {
                        return WidgetSpan(
                          alignment: PlaceholderAlignment.middle,
                          child: Avatar(size: 40, url: user?.profileImageUrl),
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
              Gap(16),
            ],
          ),
        ),
      ],
    );
  }
}
