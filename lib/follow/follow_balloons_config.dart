import 'package:obssource/generated/assets.dart';

class FollowBalloonsConfig {
  final double width;
  final double height;

  final String lottie;

  final double msgTop;
  final double msgLeft;

  FollowBalloonsConfig({
    required this.width,
    required this.height,
    required this.lottie,
    required this.msgTop,
    required this.msgLeft,
  });

  static FollowBalloonsConfig get() {
    return FollowBalloonsConfig(
      width: 280,
      height: 280,
      lottie: Assets.assetsBallons,
      msgTop: 48,
      msgLeft: 180,
    );
  }
}
