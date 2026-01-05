import 'dart:math';

import 'package:obssource/generated/assets.dart';
import 'package:obssource/highlighed/highlighted_message.dart';

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

  static HighlightedMessageConfig get(HighlightedMessage message) {
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