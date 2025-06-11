import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:lottie/lottie.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/pixel_rain_avatar.dart';
import 'package:obssource/span_util.dart';
import 'package:obssource/twitch/twitch_api.dart';

class RaidWidget extends StatefulWidget {
  final Raid raid;
  final BoxConstraints constraints;

  final void Function(Raid onDone)? onDone;

  const RaidWidget({
    super.key,
    required this.raid,
    required this.constraints,
    this.onDone,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class Raid {
  final String id;
  final img.Image? avatar;
  final UserDto who;
  final int raiders;

  Raid({
    required this.id,
    required this.avatar,
    required this.who,
    required this.raiders,
  });
}

class _State extends State<RaidWidget> {
  static const _avatarDuration = Duration(seconds: 10);
  static const _duration = Duration(seconds: 5);

  @override
  Widget build(BuildContext context) {
    final avatar = widget.raid.avatar;
    final who = widget.raid.who.displayName ?? widget.raid.who.login;
    final raiders = widget.raid.raiders;

    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child: Stack(
        children: [
          if (avatar != null) ...[
            RainyAvatar(
              image: avatar,
              constraints: widget.constraints,
              duration: _avatarDuration,
              resolution: 64,
              pixelSize: 8,
              randomBackground: false,
              verticalOffset: -128,
              scaleWhenStart: false,
              initialDelay: Duration(milliseconds: 1000),
              origin: RainyPixelOrigin.outside,
            ),
          ],
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
              ),
              padding: EdgeInsets.only(
                left: 128,
                right: 128,
                bottom: 180,
                top: 32,
              ),
              child: RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: TextStyle(color: Colors.white, fontSize: 32),
                  children: SpanUtil.createSpans(
                    context.localizations.raid_text(who, raiders),
                    who,
                    (t) => TextSpan(
                      text: t,
                      style: TextStyle(
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
    _startAnimation();
    super.initState();
  }

  void _startAnimation() async {
    _runAvatarAnimation();

    final raid = widget.raid;

    await _spawnAll(raid);
    await _avatarCompleter.future;

    await Future.delayed(Duration(seconds: 5));

    widget.onDone?.call(raid);
  }

  final _avatarCompleter = Completer<void>();

  void _runAvatarAnimation() async {
    await Future.delayed(_avatarDuration);
    _avatarCompleter.complete();
  }

  Future<void> _spawnAll(Raid raid) async {
    await Future.delayed(Duration(seconds: 1));

    final completers = <Completer<void>>[];

    for (int i = 0; i < raid.raiders; i++) {
      final next = _all[_random.nextInt(_all.length)];

      final completer = Completer<void>();
      completers.add(completer);

      await Future.delayed(Duration(milliseconds: 500 + _random.nextInt(500)));

      _spawnRaider(next, id: i.toString(), completer: completer);
    }

    await Future.wait(completers.map((c) => c.future));
  }

  void _spawnRaider(
    _Raider raider, {
    required String id,
    required Completer<void> completer,
  }) async {
    final unique = _UniqueRaider(id, raider: raider);

    setState(() {
      _raiders.add(unique);
    });

    await Future.delayed(_duration);

    setState(() {
      _raiders.remove(unique);
    });

    completer.complete();
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
