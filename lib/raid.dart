import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/pixel_rain_avatar.dart';
import 'package:obssource/twitch/twitch_api.dart';

class RaidWidget extends StatefulWidget {
  final img.Image avatar;
  final UserDto? who;
  final BoxConstraints constraints;

  const RaidWidget({
    super.key,
    required this.constraints,
    required this.who,
    required this.avatar,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<RaidWidget> {
  static const _duration = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child: Stack(
        children: [
          RainyAvatar(
            image: widget.avatar,
            constraints: widget.constraints,
            duration: Duration(seconds: 5),
            resolution: 64,
            pixelSize: 8,
            randomBackground: false,
            verticalOffset: -128,
          ),
          ..._raiders.map(
            (r) => _RaiderWidget(
              key: ValueKey(r.id),
              raider: r.raider,
              duration: _duration,
              constraints: widget.constraints,
            ),
          ),
        ],
      ),
    );
  }

  final _raiders = <_UniqueRaider>[];
  final _random = Random();

  @override
  void initState() {
    for (int i = 0; i < 10; i++) {
      final next = _all[_random.nextInt(_all.length)];

      //final additionalDelay = Duration(milliseconds: _random.nextInt(250));
      //final delay =
      //    _random.nextBool()
      //        ? Duration(seconds: i) - additionalDelay
      //        : Duration(seconds: i) + additionalDelay;

      _spawnRaider(next, delay: Duration(seconds: i), id: i.toString());
    }
    super.initState();
  }

  void _spawnRaider(
    _Raider raider, {
    required Duration delay,
    required String id,
  }) async {
    await Future.delayed(delay);

    final unique = _UniqueRaider(id, raider: raider);

    setState(() {
      _raiders.add(unique);
    });

    await Future.delayed(_duration);

    setState(() {
      _raiders.remove(unique);
    });
  }

  static const _raider1 = _Raider(
    lottie: Assets.assetsRunningDogOrange,
    width: 256,
    height: 256,
    bottomOffset: -60,
  );
  static const _raider2 = _Raider(
    lottie: Assets.assetsRunningDogBrown,
    width: 256,
    height: 256,
    bottomOffset: -56,
  );
  static const _raider3 = _Raider(
    lottie: Assets.assetsRunningDogBlue,
    width: 256,
    height: 256,
    bottomOffset: -64,
  );
  static const _raider4 = _Raider(
    lottie: Assets.assetsRunningSomething,
    width: 256,
    height: 256,
    bottomOffset: -50,
  );

  static const _all = [_raider1, _raider2, _raider3, _raider4];
}

class _UniqueRaider {
  final String id;
  final _Raider raider;

  _UniqueRaider(this.id, {required this.raider});
}

class _Raider {
  final String lottie;
  final double width;
  final double height;
  final double bottomOffset;

  const _Raider({
    required this.lottie,
    required this.width,
    required this.height,
    required this.bottomOffset,
  });
}

class _RaiderWidget extends StatelessWidget {
  final Duration duration;
  final _Raider raider;
  final BoxConstraints constraints;

  const _RaiderWidget({
    super.key,
    required this.raider,
    required this.duration,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedHorizontalMover(
      alreadyInsideStack: true,
      constraints: constraints,
      bottomOffset: raider.bottomOffset,
      duration: duration,
      size: Size(raider.width, raider.height),
      child: LottieBuilder.asset(
        raider.lottie,
        width: raider.width,
        height: raider.height,
        frameRate: FrameRate(60),
      ),
    );
  }
}
