import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:obssource/generated/assets.dart';

class LamaSubsWidget extends StatefulWidget {
  final String description;
  final String who;
  final BoxConstraints constraints;

  const LamaSubsWidget({
    super.key,
    required this.who,
    required this.constraints,
    required this.description,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<LamaSubsWidget> {
  @override
  void initState() {
    super.initState();
  }

  static const _descriptionColor = Colors.white;
  static const _twitchColor = Color(0xFF8829FF);

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.max,
          children: [
            Container(
              width: double.infinity,
              color: Colors.white.withValues(alpha: 0.9),
              padding: EdgeInsets.all(32),
              child: Text(
                widget.who,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 56,
                  color: _twitchColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Container(
              color: Color(0xFF3C3C3C).withValues(alpha: 0.9),
              padding: EdgeInsets.all(32),
              width: double.infinity,
              child: Text(
                widget.description,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 56, color: Colors.white),
              ),
            ),
          ],
        ),
        Positioned(
          bottom: -24,
          right: 0,
          child: LottieBuilder.asset(
            Assets.assetsLama,
            width: 600,
            height: 600,
            frameRate: FrameRate(60),
          ),
        ),
      ],
    );
  }
}
