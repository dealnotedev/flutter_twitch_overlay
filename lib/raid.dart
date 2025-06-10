import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/twitch/twitch_api.dart';

class RaidWidget extends StatefulWidget {
  final UserDto? who;
  final BoxConstraints constraints;

  const RaidWidget({super.key, required this.constraints, required this.who});

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

  static const _all = [_raider1, _raider2, _raider3];
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
