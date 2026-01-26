import 'package:flutter/material.dart';
import 'package:obssource/animated_mover.dart';
import 'package:obssource/generated/assets.dart';
import 'package:obssource/obs_audio.dart';

class FlashbangWidget extends StatefulWidget {

  final Flashbang flashbang;
  final BoxConstraints constraints;

  const FlashbangWidget(
      {super.key, required this.constraints, required this.flashbang});

  @override
  State<StatefulWidget> createState() => _State();
}

class Flashbang {
  final String id;

  Flashbang({required this.id});
}

class _State extends State<FlashbangWidget>
    with SingleTickerProviderStateMixin {

  late final AnimationController _controller;
  late final Animation<double> _turns;

  @override
  void initState() {
    super.initState();

    _controller =
    AnimationController(vsync: this, duration: Duration(milliseconds: 500))
      ..repeat();

    _turns = CurvedAnimation(parent: _controller, curve: Curves.linear);

    _startAnimation();
  }

  Future<void> _startAnimation() async {
    await Future.delayed(Duration(milliseconds: 500));

    ObsAudio.loadAsset(Assets.assetsWavFlashbang).then((id) {
      ObsAudio.play(id);
    });

    await Future.delayed(Duration(milliseconds: 250));

    _stopAtAngle(270);

    await Future.delayed(Duration(milliseconds: 250));

    setState(() {
      _flashed = true;
      _alpha = 1.0;
    });

    await Future.delayed(Duration(milliseconds: 2000));

    setState(() {
      _alpha = 0.0;
    });
  }

  bool _flashed = false;
  double _alpha = 1.0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _stopAtAngle(double degrees) {
    final turns = (degrees % 360) / 360.0;
    _controller
      ..stop()
      ..value = turns;
  }

  @override
  Widget build(BuildContext context) {
    if (_flashed) {
      return AnimatedOpacity(opacity: _alpha,
          duration: Duration(milliseconds: 1000),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            color: Colors.white,
          ));
    }
    return AnimatedVerticalMover(
      toOffset: -100,
      curve: Curves.bounceOut,
      duration: Duration(milliseconds: 750),
      size: Size(128, 128),
      constraints: widget.constraints,
      alreadyInsideStack: true,
      child: RotationTransition(turns: _turns,
        child: Image.asset(Assets.assetsFlashBomb, width: 128, height: 128),),
    );
  }
}
