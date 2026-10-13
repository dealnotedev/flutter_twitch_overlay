import 'package:obssource/generated/assets.dart';

class FollowBallonsConfig {
  final double width;
  final double height;

  final String lottie;

  final double msgTop;
  final double msgLeft;

  FollowBallonsConfig({
    required this.width,
    required this.height,
    required this.lottie,
    required this.msgTop,
    required this.msgLeft,
  });

  static FollowBallonsConfig get() {
    return FollowBallonsConfig(
      width: 280,
      height: 280,
      lottie: Assets.assetsBallons,
      msgTop: 48,
      msgLeft: 180,
    );
  }
}
