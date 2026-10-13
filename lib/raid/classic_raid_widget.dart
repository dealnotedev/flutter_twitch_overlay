import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/twitch/twitch_api.dart';

class ClassicRaid {
  final img.Image? avatar;
  final UserDto who;
  final int raiders;

  const ClassicRaid({
    required this.avatar,
    required this.who,
    required this.raiders,
  });
}

/// Raid of the old master build: pixel avatar, a text plate and animals
/// running across the bottom, one per raider up to [maxAnimals].
class ClassicRaidWidget extends StatefulWidget {
  final ClassicRaid raid;
  final BoxConstraints constraints;
  final int maxAnimals;
  final AvatarPixelRenderer renderer;
  final int avatarResolution;
  final VoidCallback? onDone;

  const ClassicRaidWidget({
    super.key,
    required this.raid,
    required this.constraints,
    this.maxAnimals = 30,
    this.renderer = AvatarPixelRenderer.rawAtlas,
    this.avatarResolution = 64,
    this.onDone,
  });

  /// Time the animation needs for [animals] running animals.
  static Duration durationFor(int animals) =>
      _spawnDelay + _spawnInterval * animals + _runDuration + _tail;

  static const _spawnDelay = Duration(seconds: 1);
  static const _spawnInterval = Duration(milliseconds: 750);
  static const _runDuration = Duration(seconds: 6);
  static const _avatarDuration = Duration(seconds: 10);
  static const _tail = Duration(seconds: 5);

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<ClassicRaidWidget> {
  final _raiders = <_UniqueRaider>[];
  final _random = Random();

  @override
  void initState() {
    super.initState();
    unawaited(_startAnimation());
  }

  Future<void> _startAnimation() async {
    final avatarDone = Future<void>.delayed(ClassicRaidWidget._avatarDuration);
    await _spawnAll(min(widget.raid.raiders, widget.maxAnimals));
    await avatarDone;
    await Future<void>.delayed(ClassicRaidWidget._tail);
    if (mounted) widget.onDone?.call();
  }

  Future<void> _spawnAll(int count) async {
    await Future<void>.delayed(ClassicRaidWidget._spawnDelay);

    final runs = <Future<void>>[];
    for (var i = 0; i < count; i++) {
      await Future<void>.delayed(ClassicRaidWidget._spawnInterval);
      if (!mounted) return;
      runs.add(_run(_UniqueRaider(i, _all[_random.nextInt(_all.length)])));
    }
    await Future.wait(runs);
  }

  Future<void> _run(_UniqueRaider raider) async {
    setState(() => _raiders.add(raider));
    await Future<void>.delayed(ClassicRaidWidget._runDuration);
    if (mounted) setState(() => _raiders.remove(raider));
  }

  @override
  Widget build(BuildContext context) {
    final avatar = widget.raid.avatar;
    final who = widget.raid.who.displayName ?? widget.raid.who.login;

    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child: Stack(
        children: [
          if (avatar != null)
            RainyAvatar(
              image: avatar,
              constraints: widget.constraints,
              duration: ClassicRaidWidget._avatarDuration,
              resolution: widget.avatarResolution,
              renderer: widget.renderer,
              pixelSize: 8,
              randomBackground: false,
              verticalOffset: -144,
              scaleWhenStart: false,
              initialDelay: const Duration(milliseconds: 1000),
              origin: RainyPixelOrigin.outside,
            ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFF3C3C3C).withValues(alpha: 0.9),
              ),
              padding: const EdgeInsets.only(
                left: 128,
                right: 128,
                bottom: 180,
                top: 32,
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 32),
                  children: SpanUtil.createSpans(
                    context.localizations.raid_text(who, widget.raid.raiders),
                    who,
                    (text) => TextSpan(
                      text: text,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF8829FF),
                        fontSize: 48,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          ..._raiders.map(
            (raider) => _RaiderWidget(
              key: ValueKey(raider.id),
              raider: raider.raider,
              duration: ClassicRaidWidget._runDuration,
              constraints: widget.constraints,
            ),
          ),
        ],
      ),
    );
  }

  static const _all = [
    _Raider(
      lottie: Assets.assetsRunningDogOrange,
      width: 256,
      height: 256,
      bottomOffset: -60,
    ),
    _Raider(
      lottie: Assets.assetsRunningDogBrown,
      width: 256,
      height: 256,
      bottomOffset: -56,
    ),
    _Raider(
      lottie: Assets.assetsRunningDogBlue,
      width: 256,
      height: 256,
      bottomOffset: -64,
    ),
    _Raider(
      lottie: Assets.assetsRunningSomething,
      width: 256,
      height: 256,
      bottomOffset: -50,
    ),
    _Raider(
      lottie: Assets.assetsLion,
      width: 300,
      height: 300,
      bottomOffset: -48,
    ),
    _Raider(lottie: Assets.assetsBee, width: 128, height: 128, bottomOffset: 0),
  ];
}

class _UniqueRaider {
  final int id;
  final _Raider raider;

  _UniqueRaider(this.id, this.raider);
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
        frameRate: const FrameRate(60),
      ),
    );
  }
}
