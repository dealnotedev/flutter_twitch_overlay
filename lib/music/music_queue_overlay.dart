import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:obssource/music/music_requests.dart';

class MusicQueueOverlay extends StatefulWidget {
  final MusicRequests requests;
  final Duration collapseDelay;
  final Duration animationDuration;

  const MusicQueueOverlay({
    super.key,
    required this.requests,
    this.collapseDelay = const Duration(seconds: 3),
    this.animationDuration = const Duration(milliseconds: 420),
  });

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
      _snapshot.nowPlaying != null ||
      _snapshot.queue.isNotEmpty ||
      _snapshot.lastError != null;

  @override
  void initState() {
    super.initState();
    _snapshot = widget.requests.current;
    _subscribe();
    if (_hasContent) _scheduleCollapse();
  }

  @override
  void didUpdateWidget(covariant MusicQueueOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests == widget.requests) return;

    unawaited(_subscription?.cancel());
    _collapseTimer?.cancel();
    _snapshot = widget.requests.current;
    _expanded = true;
    _subscribe();
    if (_hasContent) _scheduleCollapse();
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
    _hovered = true;
    _collapseTimer?.cancel();
    if (!_expanded) setState(() => _expanded = true);
  }

  void _handlePointerExit(PointerExitEvent event) {
    _hovered = false;
    _scheduleCollapse();
  }

  void _expandFromTap() {
    if (_expanded) return;
    _collapseTimer?.cancel();
    setState(() => _expanded = true);
    _scheduleCollapse();
  }

  void _scheduleCollapse() {
    _collapseTimer?.cancel();
    if (!_hasContent || _hovered) return;

    _collapseTimer = Timer(widget.collapseDelay, () {
      if (!mounted || _hovered || !_expanded) return;
      setState(() => _expanded = false);
    });
  }

  @override
  void dispose() {
    _collapseTimer?.cancel();
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasContent) return const SizedBox.shrink();

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
                _expanded
                    ? _ExpandedMusicPlayer(
                      key: const ValueKey('music_player_expanded'),
                      state: _snapshot,
                      onPausedChanged:
                          (paused) =>
                              unawaited(widget.requests.setPaused(paused)),
                      onSeek:
                          (position) =>
                              unawaited(widget.requests.seek(position)),
                      onSkip: () => unawaited(widget.requests.skip()),
                      onRemove:
                          (itemId) => unawaited(widget.requests.remove(itemId)),
                    )
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

  const _ExpandedMusicPlayer({
    super.key,
    required this.state,
    required this.onPausedChanged,
    required this.onSeek,
    required this.onSkip,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 360,
      padding: const EdgeInsets.all(16),
      decoration: _playerDecoration(borderRadius: 16),
      child: Column(
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
            const _WaitingForTrack(),
          if (state.queue.isNotEmpty) ...[
            const Gap(8),
            const Text(
              'ДАЛІ',
              style: TextStyle(
                color: Color(0xFFBDBDBD),
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
              ),
            ),
            const Gap(6),
            ...state.queue
                .take(3)
                .map(
                  (item) =>
                      _QueueRow(item: item, onRemove: () => onRemove(item.id)),
                ),
            if (state.queue.length > 3)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  '+${state.queue.length - 3} у черзі',
                  style: const TextStyle(
                    color: Color(0xFFBDBDBD),
                    fontSize: 12,
                  ),
                ),
              ),
          ],
          if (state.lastError case final error?) ...[
            const Gap(8),
            Text(
              error,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFFF8A80), fontSize: 12),
            ),
          ],
        ],
      ),
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

    return Container(
      width: 82,
      height: 82,
      decoration: _playerDecoration(borderRadius: 16, drawBorder: false),
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (item != null)
            Padding(
              padding: const EdgeInsets.all(8),
              child: _Artwork(
                url: item.thumbnail,
                size: 64,
                borderRadius: 12,
                iconSize: 24,
              ),
            )
          else
            const Padding(
              padding: EdgeInsets.all(8),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0xFF242424),
                  borderRadius: BorderRadius.all(Radius.circular(12)),
                ),
                child: Icon(
                  Icons.error_outline,
                  color: Color(0xFFFF8A80),
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
                  color: Color(0xB3000000),
                  shape: BoxShape.circle,
                ),
                child: Padding(
                  padding: EdgeInsets.all(7),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: Colors.white,
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
          ..color = const Color(0xFF342A40)
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

    final progressPaint =
        Paint()
          ..color = const Color(0xFFB388FF)
          ..style = PaintingStyle.stroke
          ..strokeWidth = _strokeWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(progressPath, progressPaint);
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

BoxDecoration _playerDecoration({
  required double borderRadius,
  bool drawBorder = true,
}) {
  return BoxDecoration(
    color: const Color(0xE63C3C3C),
    borderRadius: BorderRadius.circular(borderRadius),
    border: drawBorder ? Border.all(color: const Color(0x668829FF)) : null,
    boxShadow: const [
      BoxShadow(color: Color(0x55000000), blurRadius: 18, offset: Offset(0, 6)),
    ],
  );
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
  return '$playback|$queue|${snapshot.lastError ?? ''}';
}

double _progressFor(Duration position, Duration duration) {
  if (duration <= Duration.zero) return 0;
  return (position.inMicroseconds / duration.inMicroseconds)
      .clamp(0.0, 1.0)
      .toDouble();
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
    final progress =
        duration <= Duration.zero
            ? 0.0
            : (position.inMicroseconds / duration.inMicroseconds).clamp(
              0.0,
              1.0,
            );
    final remaining = duration - position;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        _Artwork(url: item.thumbnail),
        const Gap(12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      playing.paused ? 'ПАУЗА' : 'ЗАРАЗ ГРАЄ',
                      style: const TextStyle(
                        height: 1,
                        color: Color(0xFFB388FF),
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      padding: EdgeInsets.zero,
                      color: const Color(0xFFB388FF),
                      iconSize: 22,
                      onPressed: () => onPausedChanged(!playing.paused),
                      icon: Icon(
                        playing.paused ? Icons.play_arrow : Icons.pause,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 30,
                    height: 30,
                    child: IconButton(
                      key: const ValueKey('music_skip_button'),
                      padding: EdgeInsets.zero,
                      color: const Color(0xFFB388FF),
                      iconSize: 22,
                      onPressed: onSkip,
                      icon: const Icon(Icons.skip_next_rounded),
                    ),
                  ),
                ],
              ),
              const Gap(2),
              Text(
                item.title ?? item.sourceUrl.toString(),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Gap(2),
              Text(
                '${item.author ?? 'YouTube'} · ${item.requestedBy}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Color(0xFFD0D0D0), fontSize: 12),
              ),
              const Gap(8),
              LayoutBuilder(
                builder:
                    (context, constraints) => MouseRegion(
                      cursor:
                          duration > Duration.zero
                              ? SystemMouseCursors.click
                              : MouseCursor.defer,
                      child: GestureDetector(
                        key: const ValueKey('music_seek_bar'),
                        behavior: HitTestBehavior.opaque,
                        onTapDown:
                            duration <= Duration.zero ||
                                    constraints.maxWidth <= 0
                                ? null
                                : (details) {
                                  final fraction = (details.localPosition.dx /
                                          constraints.maxWidth)
                                      .clamp(0.0, 1.0);
                                  onSeek(
                                    Duration(
                                      microseconds:
                                          (duration.inMicroseconds * fraction)
                                              .round(),
                                    ),
                                  );
                                },
                        child: SizedBox(
                          height: 14,
                          child: Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(3),
                              child: TweenAnimationBuilder<double>(
                                key: ValueKey(
                                  '${item.id}-${playing.paused}-'
                                  '${position.inMilliseconds}',
                                ),
                                tween: Tween(
                                  begin: progress,
                                  end: playing.paused ? progress : 1,
                                ),
                                duration:
                                    playing.paused ? Duration.zero : remaining,
                                builder:
                                    (
                                      context,
                                      value,
                                      _,
                                    ) => LinearProgressIndicator(
                                      value:
                                          duration == Duration.zero
                                              ? null
                                              : value,
                                      minHeight: 5,
                                      backgroundColor: const Color(0xFF616161),
                                      valueColor: const AlwaysStoppedAnimation(
                                        Color(0xFFB388FF),
                                      ),
                                    ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaitingForTrack extends StatelessWidget {
  const _WaitingForTrack();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: Color(0xFFB388FF),
          ),
        ),
        Gap(10),
        Text(
          'ГОТУЄМО МУЗИКУ',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
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
      MusicQueueItemPhase.resolving => 'пошук',
      MusicQueueItemPhase.downloading =>
        item.downloadProgress == null
            ? 'завантаження'
            : '${(item.downloadProgress! * 100).round()}%',
      MusicQueueItemPhase.ready => 'готово',
    };

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          const Icon(Icons.music_note, size: 15, color: Color(0xFFB388FF)),
          const Gap(7),
          Expanded(
            child: Text(
              item.title ?? item.sourceUrl.toString(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const Gap(8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 110),
            child: Text(
              '${item.requestedBy} · $status',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Color(0xFFBDBDBD), fontSize: 11),
            ),
          ),
          const Gap(2),
          SizedBox(
            width: 24,
            height: 24,
            child: IconButton(
              key: ValueKey('remove_music_${item.id}'),
              padding: EdgeInsets.zero,
              color: const Color(0xFFBDBDBD),
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

  const _Artwork({
    required this.url,
    this.size = 64,
    this.borderRadius = 12,
    this.iconSize = 28,
  });

  @override
  Widget build(BuildContext context) {
    final fallback = ColoredBox(
      color: const Color(0xFF242424),
      child: Center(
        child: Icon(
          Icons.music_note,
          color: const Color(0xFFB388FF),
          size: iconSize,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: size,
        height: size,
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
