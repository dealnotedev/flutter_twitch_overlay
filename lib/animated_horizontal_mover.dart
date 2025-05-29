import 'package:flutter/material.dart';

class AnimatedHorizontalMover extends StatefulWidget {
  final Size size;
  final Widget child;
  final Duration duration;
  final bool alreadyInsideStack;
  final BoxConstraints constraints;

  const AnimatedHorizontalMover({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    required this.size,
    required this.constraints, required this.alreadyInsideStack,
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
    final startX = -widget.size.width;
    final endX = widget.constraints.maxWidth;

    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = startX + ((endX - startX).toDouble() * _controller.value);
        return Positioned(left: x, bottom: 0, child: widget.child);
      },
    );

    if (widget.alreadyInsideStack) {
      return child;
    } else {
      return Stack(
        children: [
          child
        ],
      );
    }
  }
}
