import 'package:obssource/constants.dart';
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
    switch (Constants.broadcaster) {
      case Broadcaster.daria:
        return FollowBallonsConfig(
          width: 400,
          height: 400,
          lottie: Assets.assetsFox,
          msgTop: 48,
          msgLeft: 280,
        );

      case Broadcaster.dealnotedev:
        return FollowBallonsConfig(
          width: 280,
          height: 280,
          lottie: Assets.assetsBallons,
          msgTop: 48,
          msgLeft: 180,
        );
    }
  }
}
