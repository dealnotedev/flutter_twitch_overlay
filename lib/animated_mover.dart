import 'package:flutter/material.dart';

class AnimatedHorizontalMover extends StatefulWidget {
  final Size size;
  final Widget child;
  final Duration duration;
  final bool alreadyInsideStack;
  final BoxConstraints constraints;
  final double bottomOffset;

  const AnimatedHorizontalMover({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    required this.size,
    this.bottomOffset = 0,
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
        return Positioned(left: x, bottom: widget.bottomOffset, child: widget.child);
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

class AnimatedVerticalMover extends StatefulWidget {
  final Size size;
  final Widget child;
  final Duration duration;
  final bool alreadyInsideStack;
  final BoxConstraints constraints;

  const AnimatedVerticalMover({
    super.key,
    required this.child,
    this.duration = const Duration(seconds: 10),
    required this.size,
    required this.constraints, required this.alreadyInsideStack,
  });

  @override
  State<AnimatedVerticalMover> createState() => _AnimatedVerticalMoverState();
}

class _AnimatedVerticalMoverState extends State<AnimatedVerticalMover>
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
    final startY = -widget.size.height;
    final endY = widget.constraints.maxHeight;

    final child = AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final y = startY + ((endY - startY).toDouble() * _controller.value);
        final x = (widget.constraints.maxWidth / 2.0) -
            (widget.size.width / 2.0);
        return Positioned(top: y, left: x, child: widget.child);
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
