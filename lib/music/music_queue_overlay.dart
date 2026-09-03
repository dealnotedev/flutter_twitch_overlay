import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_requests.dart';

enum MusicQueuePresentation { floatingOverlay, controllerCanvas }

class MusicQueueOverlayController extends ChangeNotifier {
  void expand() => notifyListeners();
}

class MusicQueueOverlay extends StatefulWidget {
  final MusicRequests requests;
  final MusicQueueOverlayController? controller;
  final Duration collapseDelay;
  final Duration animationDuration;
  final bool alwaysExpanded;
  final bool showWhenEmpty;
  final int? maxVisibleQueueItems;
  final MusicQueuePresentation presentation;
  final ScrollController? scrollController;

  const MusicQueueOverlay({
    super.key,
    required this.requests,
    this.controller,
    this.collapseDelay = const Duration(seconds: 5),
    this.animationDuration = const Duration(milliseconds: 420),
    this.alwaysExpanded = false,
    this.showWhenEmpty = false,
    this.maxVisibleQueueItems = 3,
    this.presentation = MusicQueuePresentation.floatingOverlay,
    this.scrollController,
  }) : assert(maxVisibleQueueItems == null || maxVisibleQueueItems >= 0);

  @override
  State<MusicQueueOverlay> createState() => _MusicQueueOverlayState();
}

class _MusicQueueOverlayState extends State<MusicQueueOverlay> {
  late MusicQueueSnapshot _snapshot;
  StreamSubscription<MusicQueueSnapshot>? _subscription;
  Timer? _collapseTimer;
  bool _expanded = true;
  bool _hovered = false;

  bool get _hasContent =>
      widget.showWhenEmpty ||
      _snapshot.nowPlaying != null ||
      _snapshot.queue.isNotEmpty ||
      _snapshot.lastError != null;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.requests.current;
    _subscribe();
    widget.controller?.addListener(_handleExpandRequest);
    if (_hasContent && !widget.alwaysExpanded) _scheduleCollapse();
  }

  @override
  void didUpdateWidget(covariant MusicQueueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_handleExpandRequest);
      widget.controller?.addListener(_handleExpandRequest);
    }

    if (oldWidget.requests == widget.requests) return;

    unawaited(_subscription?.cancel());
    _collapseTimer?.cancel();
    _snapshot = widget.requests.current;
    _expanded = true;
    _subscribe();
    if (_hasContent && !widget.alwaysExpanded) _scheduleCollapse();
  }

  void _subscribe() {
    _subscription = widget.requests.states.listen(_handleSnapshot);
  }

  void _handleSnapshot(MusicQueueSnapshot next) {
    if (!mounted) return;

    final shouldReveal =
        _statusSignature(_snapshot) != _statusSignature(next) &&
        _hasSnapshotContent(next);
    setState(() {
      _snapshot = next;
      if (shouldReveal) _expanded = true;
    });

    if (!_hasContent) {
      _collapseTimer?.cancel();
    } else if (shouldReveal) {
      _scheduleCollapse();
    }
  }

  void _handlePointerEnter(PointerEnterEvent event) {
    if (widget.alwaysExpanded) return;
    _hovered = true;
    _collapseTimer?.cancel();
    if (!_expanded) setState(() => _expanded = true);
  }

  void _handlePointerExit(PointerExitEvent event) {
    if (widget.alwaysExpanded) return;
    _hovered = false;
    _scheduleCollapse();
  }

  void _expandFromTap() {
    if (widget.alwaysExpanded) return;
    if (_expanded) return;
    _collapseTimer?.cancel();
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  void _handleExpandRequest() {
    if (!mounted || widget.alwaysExpanded || !_hasContent) return;

    _collapseTimer?.cancel();
    if (!_expanded) setState(() => _expanded = true);
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    if (widget.alwaysExpanded || !_hasContent || _hovered) return;

    _collapseTimer = Timer(widget.collapseDelay, () {
      if (!mounted || _hovered || !_expanded) return;
      setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    widget.controller?.removeListener(_handleExpandRequest);
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

    final expandedPlayer = _ExpandedMusicPlayer(
      key: const ValueKey('music_player_expanded'),
      state: _snapshot,
      onPausedChanged: (paused) => unawaited(widget.requests.setPaused(paused)),
      onSeek: (position) => unawaited(widget.requests.seek(position)),
      onSkip: () => unawaited(widget.requests.skip()),
      onRemove: (itemId) => unawaited(widget.requests.remove(itemId)),
      maxVisibleQueueItems: widget.maxVisibleQueueItems,
      fillAvailableSpace:
          widget.presentation == MusicQueuePresentation.controllerCanvas,
      scrollController: widget.scrollController,
    );

    if (widget.presentation == MusicQueuePresentation.controllerCanvas) {
      return expandedPlayer;
    }

    return MouseRegion(
      key: const ValueKey('music_queue_overlay'),
      onEnter: _handlePointerEnter,
      onExit: _handlePointerExit,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _expandFromTap,
        child: AnimatedSize(
          alignment: Alignment.bottomRight,
          curve: Curves.easeOutCubic,
          duration: widget.animationDuration,
          child: AnimatedSwitcher(
            duration: widget.animationDuration,
            reverseDuration: widget.animationDuration,
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder:
                (currentChild, previousChildren) => Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    ...previousChildren,
                    if (currentChild != null) currentChild,
                  ],
                ),
            transitionBuilder: (child, animation) {
              final compact =
                  child.key == const ValueKey('music_player_compact');
              final scale = Tween<double>(
                begin: compact ? 0.78 : 0.16,
                end: 1,
              ).animate(animation);
              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  alignment: Alignment.bottomRight,
                  scale: scale,
                  child: child,
                ),
              );
            },
            child:
                (_expanded || widget.alwaysExpanded)
                    ? expandedPlayer
                    : _CompactMusicPlayer(
                      key: const ValueKey('music_player_compact'),
                      state: _snapshot,
                    ),
          ),
        ),
      ),
    );
  }
}

class _ExpandedMusicPlayer extends StatelessWidget {
  final MusicQueueSnapshot state;
  final ValueChanged<bool> onPausedChanged;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkip;
  final ValueChanged<String> onRemove;
  final int? maxVisibleQueueItems;
  final bool fillAvailableSpace;
  final ScrollController? scrollController;

  const _ExpandedMusicPlayer({
    super.key,
    required this.state,
    required this.onPausedChanged,
    required this.onSeek,
    required this.onSkip,
    required this.onRemove,
    required this.maxVisibleQueueItems,
    required this.fillAvailableSpace,
    this.scrollController,
  });

  @override
  Widget build(BuildContext context) {
    final visibleQueue =
        maxVisibleQueueItems == null
            ? state.queue
            : state.queue.take(maxVisibleQueueItems!).toList(growable: false);
    final hiddenQueueCount = state.queue.length - visibleQueue.length;

    final content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (state.nowPlaying case final playing?)
          _NowPlayingCard(
            playing: playing,
            onPausedChanged: onPausedChanged,
            onSeek: onSeek,
            onSkip: onSkip,
          )
        else
          _WaitingForTrack(preparing: state.queue.isNotEmpty),
        if (state.queue.isNotEmpty) ...[
          const Gap(12),
          Text(
            context.localizations.music_queue_next,
            style: const TextStyle(
              color: MusicPlayerPalette.neonPinkBright,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 2.2,
              shadows: MusicPlayerPalette.pinkTextGlow,
            ),
          ),
          const Gap(7),
          ...visibleQueue.map(
            (item) => _QueueRow(item: item, onRemove: () => onRemove(item.id)),
          ),
          if (hiddenQueueCount > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                context.localizations.music_queue_more(hiddenQueueCount),
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 11,
                ),
              ),
            ),
        ],
        if (state.lastError case final error?) ...[
          const Gap(10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: MusicPlayerPalette.neonPink.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(9),
              border: Border.all(
                color: MusicPlayerPalette.error.withValues(alpha: 0.42),
              ),
            ),
            child: Text(
              _localizedMusicError(context, error),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MusicPlayerPalette.error,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ],
    );

    if (fillAvailableSpace) {
      return CosmicMusicSurface(
        surfaceKey: const ValueKey('music_controller_player_surface'),
        backgroundKey: const ValueKey('music_cosmic_expanded_background'),
        width: double.infinity,
        height: double.infinity,
        borderRadius: 0,
        animate: false,
        drawBorder: false,
        drawShadow: false,
        child: Scrollbar(
          controller: scrollController,
          thumbVisibility: scrollController != null,
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: content,
          ),
        ),
      );
    }

    return CosmicMusicSurface(
      backgroundKey: const ValueKey('music_cosmic_expanded_background'),
      width: 380,
      padding: const EdgeInsets.all(18),
      child: content,
    );
  }
}

class _CompactMusicPlayer extends StatelessWidget {
  final MusicQueueSnapshot state;

  const _CompactMusicPlayer({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final playing = state.nowPlaying;
    final item =
        playing?.item ?? (state.queue.isEmpty ? null : state.queue.first);

    return CosmicMusicSurface(
      backgroundKey: const ValueKey('music_cosmic_compact_background'),
      width: 82,
      height: 82,
      borderRadius: 18,
      compact: true,
      drawBorder: false,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _Artwork(
                url: item.thumbnail,
                size: 66,
                borderRadius: 12,
                iconSize: 24,
                glow: false,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: MusicPlayerPalette.panelSoft,
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: MusicPlayerPalette.error,
                  size: 26,
                ),
              ),
            ),
          if (playing != null)
            Positioned.fill(child: _RoundedRectTrackProgress(playing: playing))
          else if (item != null)
            const Positioned.fill(child: _RoundedRectLoadingBorder()),
          if (playing?.paused ?? false)
            const Center(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xC0030518),
                  shape: BoxShape.circle,
                  border: Border.fromBorderSide(
                    BorderSide(color: MusicPlayerPalette.neonPink, width: 1),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: MusicPlayerPalette.neonPink,
                      blurRadius: 12,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: MusicPlayerPalette.neonPinkBright,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RoundedRectTrackProgress extends StatelessWidget {
  final MusicNowPlaying playing;

  const _RoundedRectTrackProgress({required this.playing});

  @override
  Widget build(BuildContext context) {
    final duration = playing.item.duration ?? Duration.zero;
    final position = _currentPosition(playing, duration);
    final progress = _progressFor(position, duration);
    final remaining = duration - position;

    return TweenAnimationBuilder<double>(
      key: ValueKey(
        '${playing.item.id}-${playing.paused}-${position.inMilliseconds}',
      ),
      tween: Tween(begin: progress, end: playing.paused ? progress : 1),
      duration: playing.paused ? Duration.zero : remaining,
      builder:
          (context, value, _) => CustomPaint(
            key: const ValueKey('music_compact_border_progress'),
            painter: _RoundedRectProgressPainter(progress: value),
          ),
    );
  }
}

class _RoundedRectLoadingBorder extends StatefulWidget {
  const _RoundedRectLoadingBorder();

  @override
  State<_RoundedRectLoadingBorder> createState() =>
      _RoundedRectLoadingBorderState();
}

class _RoundedRectLoadingBorderState extends State<_RoundedRectLoadingBorder>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder:
          (context, _) => CustomPaint(
            key: const ValueKey('music_compact_border_loading'),
            painter: _RoundedRectProgressPainter(
              progress: 0.24,
              start: _controller.value,
            ),
          ),
    );
  }
}

class _RoundedRectProgressPainter extends CustomPainter {
  static const _strokeWidth = 9.0;
  static const _cornerRadius = 19.0;

  final double progress;
  final double start;

  const _RoundedRectProgressPainter({required this.progress, this.start = 0});

  @override
  void paint(Canvas canvas, Size size) {
    final path = _framePath(size);
    final trackPaint =
        Paint()
          ..color = const Color(0xFF3D1738)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, trackPaint);

    final metrics = path.computeMetrics().iterator;
    if (!metrics.moveNext()) return;
    final metric = metrics.current;
    final length = metric.length;
    final extent = length * progress.clamp(0.0, 1.0);
    if (extent <= 0) return;

    final startDistance = length * (start % 1);
    final endDistance = startDistance + extent;
    final progressPath = Path();
    if (endDistance <= length) {
      progressPath.addPath(
        metric.extractPath(startDistance, endDistance),
        Offset.zero,
      );
    } else {
      progressPath
        ..addPath(metric.extractPath(startDistance, length), Offset.zero)
        ..addPath(metric.extractPath(0, endDistance - length), Offset.zero);
    }

    final glowPaint =
        Paint()
          ..color = MusicPlayerPalette.neonPink.withValues(alpha: 0.62)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 11
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    final progressPaint =
        Paint()
          ..shader = const LinearGradient(
            colors: [
              MusicPlayerPalette.neonPink,
              MusicPlayerPalette.neonPinkBright,
              MusicPlayerPalette.neonPink,
            ],
          ).createShader(Offset.zero & size)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    final highlightPaint =
        Paint()
          ..color = const Color(0xE6FFFFFF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;

    canvas
      ..drawPath(progressPath, glowPaint)
      ..drawPath(progressPath, progressPaint)
      ..drawPath(progressPath, highlightPaint);
  }

  Path _framePath(Size size) {
    const inset = _strokeWidth / 2;
    final left = inset;
    final top = inset;
    final right = size.width - inset;
    final bottom = size.height - inset;
    final radius = _cornerRadius - inset;

    return Path()
      ..moveTo(size.width / 2, top)
      ..lineTo(right - radius, top)
      ..arcToPoint(Offset(right, top + radius), radius: Radius.circular(radius))
      ..lineTo(right, bottom - radius)
      ..arcToPoint(
        Offset(right - radius, bottom),
        radius: Radius.circular(radius),
      )
      ..lineTo(left + radius, bottom)
      ..arcToPoint(
        Offset(left, bottom - radius),
        radius: Radius.circular(radius),
      )
      ..lineTo(left, top + radius)
      ..arcToPoint(Offset(left + radius, top), radius: Radius.circular(radius))
      ..lineTo(size.width / 2, top);
  }

  @override
  bool shouldRepaint(covariant _RoundedRectProgressPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.start != start;
  }
}

bool _hasSnapshotContent(MusicQueueSnapshot snapshot) {
  return snapshot.nowPlaying != null ||
      snapshot.queue.isNotEmpty ||
      snapshot.lastError != null;
}

String _statusSignature(MusicQueueSnapshot snapshot) {
  final playing = snapshot.nowPlaying;
  final playback =
      playing == null ? 'stopped' : '${playing.item.id}:${playing.paused}';
  final queue = snapshot.queue.map((item) => item.id).join(',');
  return '$playback|$queue|${snapshot.lastError?.signature ?? ''}';
}

String _localizedMusicError(BuildContext context, MusicQueueError error) {
  final localizations = context.localizations;
  return switch (error.type) {
    MusicQueueErrorType.missingYoutubeUrl => localizations
        .music_error_missing_youtube_url(error.requester),
    MusicQueueErrorType.invalidYoutubeUrl => localizations
        .music_error_invalid_youtube_url(error.requester),
    MusicQueueErrorType.queueFull => localizations.music_error_queue_full(
      error.requester,
    ),
    MusicQueueErrorType.trackTooLongOrLive => localizations
        .music_error_track_too_long_or_live(error.requester),
    MusicQueueErrorType.operationFailed => localizations
        .music_error_operation_failed(error.requester, error.details ?? ''),
  };
}

double _progressFor(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMicroseconds / duration.inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.isNegative ? 0 : duration.inSeconds;
  final minutes = totalSeconds ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}

Duration _currentPosition(MusicNowPlaying playing, Duration duration) {
  var position = playing.position;
  if (!playing.paused) {
    position += DateTime.now().difference(playing.positionUpdatedAt);
  }
  if (position.isNegative) return Duration.zero;
  return position > duration ? duration : position;
}

class _NowPlayingCard extends StatelessWidget {
  final MusicNowPlaying playing;
  final ValueChanged<bool> onPausedChanged;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onSkip;

  const _NowPlayingCard({
    required this.playing,
    required this.onPausedChanged,
    required this.onSeek,
    required this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    final item = playing.item;
    final duration = item.duration ?? Duration.zero;
    final position = _currentPosition(playing, duration);
    final progress = _progressFor(position, duration);
    final remaining = duration - position;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Artwork(url: item.thumbnail, size: 78, borderRadius: 15),
        const Gap(15),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      playing.paused
                          ? context.localizations.music_playback_paused
                          : context.localizations.music_playback_now_playing,
                      style: const TextStyle(
                        height: 1.05,
                        color: MusicPlayerPalette.neonPinkBright,
                        fontFamily: 'Segoe Script',
                        fontSize: 17,
                        fontStyle: FontStyle.italic,
                        shadows: MusicPlayerPalette.pinkTextGlow,
                      ),
                    ),
                  ),
                  NeonMusicIconButton(
                    icon:
                        playing.paused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                    onPressed: () => onPausedChanged(!playing.paused),
                  ),
                  const Gap(6),
                  NeonMusicIconButton(
                    key: const ValueKey('music_skip_button'),
                    icon: Icons.skip_next_rounded,
                    onPressed: onSkip,
                  ),
                ],
              ),
              const Gap(5),
              Text(
                item.title ?? item.sourceUrl.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MusicPlayerPalette.textPrimary,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.1,
                ),
              ),
              const Gap(3),
              Text(
                '${item.author ?? context.localizations.music_source_youtube}'
                ' · ${item.requestedBy}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: MusicPlayerPalette.textSecondary,
                  fontSize: 11,
                ),
              ),
              const Gap(7),
              _PlaybackProgress(
                animationKey: ValueKey(
                  '${item.id}-${playing.paused}-${position.inMilliseconds}',
                ),
                progress: progress,
                endProgress: playing.paused ? progress : 1,
                animationDuration: playing.paused ? Duration.zero : remaining,
                duration: duration,
                enabled: duration > Duration.zero,
                onSeekFraction: (fraction) {
                  onSeek(
                    Duration(
                      microseconds:
                          (duration.inMicroseconds * fraction).round(),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaybackProgress extends StatelessWidget {
  final Key animationKey;
  final double progress;
  final double endProgress;
  final Duration animationDuration;
  final Duration duration;
  final bool enabled;
  final ValueChanged<double> onSeekFraction;

  const _PlaybackProgress({
    required this.animationKey,
    required this.progress,
    required this.endProgress,
    required this.animationDuration,
    required this.duration,
    required this.enabled,
    required this.onSeekFraction,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: animationKey,
      tween: Tween(begin: progress, end: endProgress),
      duration: animationDuration,
      builder: (context, value, _) {
        final normalized = value.clamp(0.0, 1.0).toDouble();
        final position = Duration(
          microseconds: (duration.inMicroseconds * normalized).round(),
        );
        return Column(
          children: [
            _NeonSeekBar(
              progress: normalized,
              enabled: enabled,
              onSeekFraction: onSeekFraction,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(position),
                  style: const TextStyle(
                    color: MusicPlayerPalette.textSecondary,
                    fontSize: 9,
                  ),
                ),
                Text(
                  _formatDuration(duration),
                  style: const TextStyle(
                    color: MusicPlayerPalette.textSecondary,
                    fontSize: 9,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _NeonSeekBar extends StatelessWidget {
  final double progress;
  final bool enabled;
  final ValueChanged<double> onSeekFraction;

  const _NeonSeekBar({
    required this.progress,
    required this.enabled,
    required this.onSeekFraction,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder:
          (context, constraints) => MouseRegion(
            cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
            child: GestureDetector(
              key: const ValueKey('music_seek_bar'),
              behavior: HitTestBehavior.opaque,
              onTapDown:
                  !enabled || constraints.maxWidth <= 0
                      ? null
                      : (details) {
                        final fraction =
                            (details.localPosition.dx / constraints.maxWidth)
                                .clamp(0.0, 1.0)
                                .toDouble();
                        onSeekFraction(fraction);
                      },
              child: SizedBox(
                height: 13,
                child: Stack(
                  alignment: Alignment.centerLeft,
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      height: 3,
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A2447),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    FractionallySizedBox(
                      widthFactor: progress,
                      child: Container(
                        height: 4,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [
                              MusicPlayerPalette.neonPink,
                              MusicPlayerPalette.neonPinkBright,
                            ],
                          ),
                          borderRadius: BorderRadius.circular(2),
                          boxShadow: [
                            BoxShadow(
                              color: MusicPlayerPalette.neonPink.withValues(
                                alpha: 0.72,
                              ),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment(progress * 2 - 1, 0),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: MusicPlayerPalette.neonPinkBright,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: MusicPlayerPalette.neonPink,
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _WaitingForTrack extends StatelessWidget {
  final bool preparing;

  const _WaitingForTrack({required this.preparing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
      decoration: BoxDecoration(
        color: MusicPlayerPalette.panelSoft,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: MusicPlayerPalette.neonPink.withValues(alpha: 0.30),
        ),
      ),
      child: Row(
        children: [
          if (preparing)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: MusicPlayerPalette.neonPink,
              ),
            )
          else
            const Icon(
              Icons.music_note_rounded,
              color: MusicPlayerPalette.neonPink,
              size: 18,
            ),
          const Gap(10),
          Expanded(
            child: Text(
              preparing
                  ? context.localizations.music_preparing
                  : context.localizations.music_waiting_for_requests,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MusicPlayerPalette.neonPinkBright,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.1,
                shadows: MusicPlayerPalette.pinkTextGlow,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueRow extends StatelessWidget {
  final MusicQueueItem item;
  final VoidCallback onRemove;

  const _QueueRow({required this.item, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final status = switch (item.phase) {
      MusicQueueItemPhase.resolving =>
        context.localizations.music_queue_status_resolving,
      MusicQueueItemPhase.downloading =>
        item.downloadProgress == null
            ? context.localizations.music_queue_status_downloading
            : '${(item.downloadProgress! * 100).round()}%',
      MusicQueueItemPhase.ready =>
        context.localizations.music_queue_status_ready,
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.only(left: 9, right: 3, top: 4, bottom: 4),
      decoration: BoxDecoration(
        color: MusicPlayerPalette.panelSoft,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(
          color: MusicPlayerPalette.neonPink.withValues(alpha: 0.18),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: const BoxDecoration(
              color: MusicPlayerPalette.neonPink,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: MusicPlayerPalette.neonPink,
                  blurRadius: 7,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const Gap(9),
          Expanded(
            child: Text(
              item.title ?? item.sourceUrl.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MusicPlayerPalette.textPrimary,
                fontSize: 12,
              ),
            ),
          ),
          const Gap(8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              '${item.requestedBy} · $status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: MusicPlayerPalette.textSecondary,
                fontSize: 10,
              ),
            ),
          ),
          const Gap(2),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              key: ValueKey('remove_music_${item.id}'),
              padding: EdgeInsets.zero,
              color: MusicPlayerPalette.textSecondary,
              hoverColor: MusicPlayerPalette.neonPink.withValues(alpha: 0.14),
              iconSize: 17,
              onPressed: onRemove,
              icon: const Icon(Icons.close_rounded),
            ),
          ),
        ],
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  final Uri? url;
  final double size;
  final double borderRadius;
  final double iconSize;
  final bool glow;

  const _Artwork({
    required this.url,
    this.size = 64,
    this.borderRadius = 12,
    this.iconSize = 28,
    this.glow = true,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [MusicPlayerPalette.deepPurple, MusicPlayerPalette.midnight],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.music_note_rounded,
          color: MusicPlayerPalette.neonPinkBright,
          shadows: MusicPlayerPalette.pinkTextGlow,
          size: iconSize,
        ),
      ),
    );

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(glow ? 1.5 : 0),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius + 1.5),
        border:
            glow
                ? Border.all(
                  color: MusicPlayerPalette.neonPink.withValues(alpha: 0.78),
                )
                : null,
        boxShadow:
            glow
                ? [
                  BoxShadow(
                    color: MusicPlayerPalette.neonPink.withValues(alpha: 0.35),
                    blurRadius: 14,
                    spreadRadius: 1,
                  ),
                ]
                : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child:
            url == null
                ? fallback
                : CachedNetworkImage(
                  imageUrl: url.toString(),
                  fit: BoxFit.cover,
                  placeholder: (_, _) => fallback,
                  errorWidget: (_, _, _) => fallback,
                ),
      ),
    );
  }
}
