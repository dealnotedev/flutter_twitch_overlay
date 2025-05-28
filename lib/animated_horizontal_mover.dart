import 'package:flutter/material.dart';

class AnimatedHorizontalMover extends StatefulWidget {
  final Size size;
  final Widget child;
  final Duration duration;

  const AnimatedHorizontalMover({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    required this.size,
  });

  @override
  State<AnimatedHorizontalMover> createState() =>
      _AnimatedHorizontalMoverState();
}

class _AnimatedHorizontalMoverState extends State<AnimatedHorizontalMover>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this)
      ..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (cntx, sizes) {
        final startX = -widget.size.width;
        final endX = sizes.maxWidth;

        return AnimatedBuilder(
          animation: _controller,
          builder: (context, _) {
            final x = startX + ((endX - startX).toDouble() * _controller.value);
            return Stack(
              children: [Positioned(left: x, bottom: 0, child: widget.child)],
            );
          },
        );
      },
    );
  }
}
