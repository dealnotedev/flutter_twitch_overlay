import 'package:flutter/material.dart';
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';

class PixelRainText extends StatefulWidget {
  final BoxConstraints constraints;

  final double pixelSize;
  final List<Pixel> pixels;
  final Duration duration;
  final Duration fallDuration;
  final double pixelPadding;
  final Radius pixelRadius;

  const PixelRainText({
    super.key,
    this.pixelRadius = const Radius.circular(2),
    required this.constraints,
    required this.pixels,
    required this.duration,
    required this.fallDuration,
    required this.pixelSize,
    this.pixelPadding = 1.0,
  });

  @override
  State<StatefulWidget> createState() => _State();
}

class _State extends State<PixelRainText> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late final List<Pixel> _pixels;

  @override
  void initState() {
    _pixels = widget.pixels;
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _controller.forward();
    super.initState();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pixels = _pixels;
    final animation = _controller;

    return SizedBox(
      width: widget.constraints.maxWidth,
      height: widget.constraints.maxHeight,
      child: AvatarPixelRain(
        widgetWidth: widget.constraints.maxWidth,
        widgetHeight: widget.constraints.maxHeight,
        pixelSize: widget.pixelSize,
        durationMs: widget.duration.inMilliseconds,
        fallDurationMs: widget.fallDuration.inMilliseconds,
        pixels: pixels,
        animation: animation,
        pixelPadding: widget.pixelPadding,
        pixelRadius: widget.pixelRadius,
      ),
    );
  }
}
