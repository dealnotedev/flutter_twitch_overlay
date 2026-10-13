import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/avatar_widget.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/twitch/ws_event.dart';

/// Animal carrying a chat card across the screen.
enum ChatAnimal {
  rooster(
    lottie: Assets.assetsRooster,
    bottomOffset: -84,
    messageLeft: 260,
    messageBottom: 280,
  ),
  giraffe(
    lottie: Assets.assetsGiraffe,
    bottomOffset: -54,
    messageLeft: 300,
    messageBottom: 320,
  ),
  bear(
    lottie: Assets.assetsBear,
    bottomOffset: -54,
    messageLeft: 256,
    messageBottom: 280,
  );

  static const size = Size(400, 400);

  final String lottie;
  final double bottomOffset;
  final double messageLeft;
  final double messageBottom;

  const ChatAnimal({
    required this.lottie,
    required this.bottomOffset,
    required this.messageLeft,
    required this.messageBottom,
  });
}

/// Highlighted message or first message of a viewer in this session.
class ChatCard {
  final String id;
  final bool firstMessage;
  final String userName;
  final String? avatarUrl;
  final List<WsChatMessageFragment> fragments;
  final ChatAnimal animal;
  final Duration duration;

  const ChatCard({
    required this.id,
    required this.firstMessage,
    required this.userName,
    required this.avatarUrl,
    required this.fragments,
    required this.animal,
    required this.duration,
  });
}

class ChatCardWidget extends StatelessWidget {
  static const _highlightedColor = Color(0xFFFF6905);
  static const _firstMessageColor = Color(0xFF8829FF);

  final ChatCard card;
  final BoxConstraints constraints;

  const ChatCardWidget({
    super.key,
    required this.card,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    final animal = card.animal;

    return AnimatedHorizontalMover(
      alreadyInsideStack: true,
      constraints: constraints,
      duration: card.duration,
      size: ChatAnimal.size,
      bottomOffset: animal.bottomOffset,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          LottieBuilder.asset(
            animal.lottie,
            width: ChatAnimal.size.width,
            height: ChatAnimal.size.height,
            frameRate: const FrameRate(60),
          ),
          Positioned(
            left: animal.messageLeft,
            bottom: animal.messageBottom,
            child: Transform.rotate(
              angle: -0.25,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    constraints: const BoxConstraints(maxWidth: 448),
                    decoration: BoxDecoration(
                      color: const Color(0xFF3C3C3C).withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: RichText(
                      textWidthBasis: TextWidthBasis.longestLine,
                      text: TextSpan(
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                        children: _message(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 24,
                    top: -16,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color:
                            card.firstMessage
                                ? _firstMessageColor
                                : _highlightedColor,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        card.firstMessage
                            ? context.localizations.chat_message_first
                            : context.localizations.chat_message_highlighted,
                        style: const TextStyle(
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

  List<InlineSpan> _message() => [
    WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: Avatar(size: 24, url: card.avatarUrl),
    ),
    const TextSpan(text: '  '),
    TextSpan(
      text: '${card.userName}: ',
      style: const TextStyle(fontWeight: FontWeight.bold),
    ),
    for (final fragment in card.fragments) _fragment(fragment),
  ];

  static InlineSpan _fragment(WsChatMessageFragment fragment) {
    final emote = fragment.emote;
    if (fragment.type != WsFragmentType.emote || emote == null) {
      return TextSpan(text: fragment.text);
    }

    final format = emote.animated ? 'animated' : 'static';
    return WidgetSpan(
      alignment: PlaceholderAlignment.middle,
      child: CachedNetworkImage(
        filterQuality: FilterQuality.high,
        imageUrl:
            'https://static-cdn.jtvnw.net/emoticons/v2/${emote.id}/$format/dark/2.0',
        width: 24,
        height: 24,
        errorWidget: (_, _, _) => Text(fragment.text ?? ''),
      ),
    );
  }
}
