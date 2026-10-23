import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show OverflowBoxFit;
import 'package:gap/gap.dart';

/// Shared track typography with a choice of natural wrapping or overflow scrolling.
class TurntableTrackLine extends StatefulWidget {
  final String title;
  final String? author;
  final String? requestedBy;
  final double fontSize;
  final double leadingInset;
  final bool wrap;
  final Key? textKey;
  final Key? viewportKey;

  const TurntableTrackLine({
    super.key,
    required this.title,
    this.author,
    this.requestedBy,
    this.fontSize = 13,
    this.leadingInset = 0,
    this.wrap = false,
    this.textKey,
    this.viewportKey,
  });

  @override
  State<TurntableTrackLine> createState() => _TurntableTrackLineState();
}

class _TurntableTrackLineState extends State<TurntableTrackLine>
    with SingleTickerProviderStateMixin {
  static const _gap = 36.0;
  static const _speed = 28.0;
  static const _pauseSeconds = 1.5;
  AnimationController? _controller;
  Duration? _cycleDuration;

  @override
  void didUpdateWidget(covariant TurntableTrackLine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.author != widget.author ||
        oldWidget.requestedBy != widget.requestedBy) {
      _cycleDuration = null;
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final style = DefaultTextStyle.of(context).style.merge(
      TextStyle(
        color: const Color(0xFFF3E0D2),
        fontSize: widget.fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.2,
      ),
    );
    const separator = TextSpan(
      text: ' • ',
      style: TextStyle(color: Color(0xFFBD9380), fontWeight: FontWeight.w900),
    );
    final content = TextSpan(
      style: style,
      children: [
        TextSpan(
          text: widget.title,
          style: const TextStyle(
            color: Color(0xFFF8EBE1),
            fontWeight: FontWeight.w700,
          ),
        ),
        if (widget.author != null) ...[
          separator,
          TextSpan(
            text: widget.author,
            style: const TextStyle(color: Color(0xFFD0C0CA)),
          ),
        ],
        if (widget.requestedBy != null) ...[
          separator,
          TextSpan(
            text: widget.requestedBy,
            style: const TextStyle(
              color: Color(0xFFE7BA95),
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ],
    );
    final textScaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    Widget title({bool copy = false}) => Text.rich(
      content,
      key: copy ? null : widget.textKey,
      style: style,
      textScaler: textScaler,
      textDirection: direction,
      maxLines: widget.wrap ? null : 1,
      softWrap: widget.wrap,
      overflow: TextOverflow.visible,
    );

    if (widget.wrap) {
      _controller?.stop();
      _cycleDuration = null;
      return Padding(
        padding: EdgeInsets.only(left: widget.leadingInset),
        child: title(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final controller = _controller ??= AnimationController(vsync: this);
        final painter = TextPainter(
          text: content,
          textDirection: direction,
          textScaler: textScaler,
          maxLines: 1,
        )..layout();
        final textWidth = painter.width;
        painter.dispose();
        final overflowing =
            textWidth > constraints.maxWidth - widget.leadingInset;
        final scrolling =
            overflowing && !MediaQuery.disableAnimationsOf(context);
        final distance = textWidth + _gap;
        final cycleSeconds = _pauseSeconds + distance / _speed;
        final duration = Duration(milliseconds: (cycleSeconds * 1000).ceil());
        if (scrolling) {
          if (_cycleDuration != duration || !controller.isAnimating) {
            _cycleDuration = duration;
            controller
              ..duration = duration
              ..value = 0
              ..repeat();
          }
        } else {
          _cycleDuration = null;
          controller.stop();
          if (controller.value != 0) controller.value = 0;
        }

        // The padded chassis clips painting; font glyphs may exceed line bounds.
        return Semantics(
          label: content.toPlainText(),
          child: ExcludeSemantics(
            child: SizedBox(
              key: widget.viewportKey,
              width: double.infinity,
              child:
                  scrolling
                      ? OverflowBox(
                        fit: OverflowBoxFit.deferToChild,
                        alignment: Alignment.centerLeft,
                        minWidth: 0,
                        maxWidth: double.infinity,
                        child: AnimatedBuilder(
                          animation: controller,
                          child: Padding(
                            padding: EdgeInsets.only(left: widget.leadingInset),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              textDirection: TextDirection.ltr,
                              children: [
                                title(),
                                const Gap(_gap),
                                title(copy: true),
                              ],
                            ),
                          ),
                          builder:
                              (context, child) => Transform.translate(
                                offset: Offset(
                                  -math.max(
                                        0.0,
                                        controller.value * cycleSeconds -
                                            _pauseSeconds,
                                      ) *
                                      _speed,
                                  0,
                                ),
                                child: child,
                              ),
                        ),
                      )
                      : Padding(
                        padding: EdgeInsets.only(left: widget.leadingInset),
                        child: title(),
                      ),
            ),
          ),
        );
      },
    );
  }
}
