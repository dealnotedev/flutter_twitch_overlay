import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:gap/gap.dart';
import 'package:obssource/extensions.dart';
import 'package:obssource/music/music_player_visuals.dart';
import 'package:obssource/music/music_queue_overlay.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol.dart';
import 'package:obssource/music/turntable_geometry.dart';
import 'package:obssource/music/turntable_motion.dart';
import 'package:obssource/music/turntable_track_line.dart';

class TurntableMusicPlayer extends StatefulWidget {
  final MusicRequests requests;

  const TurntableMusicPlayer({super.key, required this.requests});

  @override
  State<TurntableMusicPlayer> createState() => _TurntableMusicPlayerState();
}

class _TurntableMusicPlayerState extends State<TurntableMusicPlayer>
    with SingleTickerProviderStateMixin {
  static const _infoVerticalPadding = 10.0;
  late final TurntableMotion _motion;
  late final Ticker _ticker;
  late MusicQueueSnapshot _snapshot;
  StreamSubscription<MusicQueueSnapshot>? _subscription;
  final _items = <String, MusicQueueItem>{};
  Duration _previousElapsed = Duration.zero;
  bool _queueExpanded = false;

  @override
  void initState() {
    super.initState();
    _motion = TurntableMotion();
    _ticker = createTicker(_tick);
    _connect();
  }

  void _connect() {
    _snapshot = widget.requests.current;
    _queueExpanded = false;
    _subscription = widget.requests.states.listen((snapshot) {
      if (!mounted) return;
      setState(() {
        _snapshot = snapshot;
        if (snapshot.queue.isEmpty) _queueExpanded = false;
      });
      _syncMotion();
    });
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant TurntableMusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests) {
      unawaited(_subscription?.cancel());
      _connect();
    }
  }

  void _syncMotion() {
    final playing = _snapshot.nowPlaying;
    final item = playing?.item ?? _snapshot.queue.firstOrNull;
    if (item != null) _items[item.id] = item;
    _items.removeWhere((id, _) => id != item?.id && id != _motion.itemId);
    final duration = playing?.item.duration?.inMilliseconds ?? 0;
    _motion.update(
      itemId: item?.id,
      metadataReady:
          item != null && item.phase != MusicQueueItemPhase.resolving,
      ready: item != null && (playing != null && !playing.starting),
      paused: playing?.paused ?? false,
      progress: duration > 0 ? playing!.position.inMilliseconds / duration : 0,
    );
    if (!_ticker.isActive && _motion.phase != TurntablePhase.hidden) {
      _previousElapsed = Duration.zero;
      _ticker.start();
    }
  }

  void _toggleQueue() {
    if (_snapshot.queue.isEmpty) return;
    setState(() => _queueExpanded = !_queueExpanded);
  }

  void _tick(Duration elapsed) {
    final delta = elapsed - _previousElapsed;
    _previousElapsed = elapsed;
    final playing = _snapshot.nowPlaying;
    final duration = playing?.item.duration?.inMilliseconds ?? 0;
    if (playing != null && playing.item.id == _motion.itemId && duration > 0) {
      final elapsed =
          playing.paused || playing.starting
              ? Duration.zero
              : DateTime.now().difference(playing.positionUpdatedAt);
      _motion.setTrackProgress(
        ((playing.position + elapsed).inMilliseconds / duration).clamp(
          0.0,
          1.0,
        ),
      );
    }
    // Resume a suspended OBS source without jumping through the choreography.
    _motion.advance(
      delta > const Duration(milliseconds: 100)
          ? const Duration(milliseconds: 100)
          : delta,
    );
    if (_motion.phase == TurntablePhase.hidden) _ticker.stop();
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final playing = _snapshot.nowPlaying;
    return _PausedTurntableSlide(
      key: ObjectKey(widget.requests),
      pausedItemId: playing?.paused == true ? playing!.item.id : null,
      child: _buildTurntable(context),
    );
  }

  Widget _buildTurntable(BuildContext context) {
    return SizedBox(
      width: TurntableGeometry.deckSize.width,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.bottomRight,
        child: AnimatedBuilder(
          animation: _motion,
          child:
              _queueExpanded
                  ? MusicQueueList(
                    key: const ValueKey('turntable_inline_queue'),
                    items: _snapshot.queue,
                    held: _snapshot.hold != null,
                    onRemove: (id) => unawaited(widget.requests.remove(id)),
                    style: MusicQueueStyle.turntable,
                  )
                  : null,
          builder: (context, inlineQueue) {
            if (_motion.phase == TurntablePhase.hidden &&
                _snapshot.lastError != null) {
              return MusicQueueOverlay(
                requests: widget.requests,
                alwaysExpanded: true,
              );
            }
            final item = _items[_motion.itemId];
            final playing = _snapshot.nowPlaying;
            final active = playing != null && playing.item.id == item?.id;
            final status = switch (_motion.phase) {
              TurntablePhase.playing =>
                playing?.paused == true
                    ? context.localizations.music_playback_paused
                    : context.localizations.music_playback_now_playing,
              TurntablePhase.cueing =>
                context.localizations.music_turntable_cueing,
              _ =>
                _snapshot.hold != null
                    ? context.localizations.music_requests_paused
                    : context.localizations.music_turntable_preparing,
            };

            return IgnorePointer(
              ignoring: _motion.visibility < 0.95,
              child: FractionalTranslation(
                translation: Offset(0, 1 - _motion.visibility),
                child: Opacity(
                  opacity: _motion.visibility,
                  child: SizedBox(
                    key: const ValueKey('music_turntable'),
                    width: TurntableGeometry.deckSize.width,
                    child: CustomPaint(
                      painter: const _TurntableChassisPainter(),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            key: const ValueKey('turntable_deck'),
                            height: TurntableGeometry.deckSize.height,
                            child: Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Positioned.fill(
                                  child: RepaintBoundary(
                                    child: CustomPaint(
                                      painter: _TurntableDeckPainter(
                                        fontFamily:
                                            Theme.of(
                                              context,
                                            ).textTheme.bodyMedium?.fontFamily,
                                      ),
                                    ),
                                  ),
                                ),
                                if (_motion.recordVisible && item != null)
                                  Positioned(
                                    left:
                                        TurntableGeometry.platterCenter.dx -
                                        TurntableGeometry.recordRadius +
                                        (1 - _motion.recordPlacement) *
                                            TurntableGeometry.deckSize.width,
                                    top:
                                        TurntableGeometry.platterCenter.dy -
                                        TurntableGeometry.recordRadius,
                                    child: Transform.rotate(
                                      angle: _motion.rotation,
                                      child: VinylRecord(
                                        artwork:
                                            item.thumbnail == null
                                                ? null
                                                : CachedNetworkImageProvider(
                                                  item.thumbnail.toString(),
                                                  maxWidth: 256,
                                                  maxHeight: 256,
                                                ),
                                      ),
                                    ),
                                  ),
                                Positioned.fill(
                                  child: IgnorePointer(
                                    child: CustomPaint(
                                      painter: _TonearmPainter(
                                        angle: _motion.armAngle,
                                        lift: _motion.needleLift,
                                        spindle:
                                            _motion.recordVisible &&
                                            _motion.recordPlacement > 0.999,
                                      ),
                                    ),
                                  ),
                                ),
                                Positioned(
                                  left: 286,
                                  top: 236,
                                  child: Row(
                                    spacing: 8,
                                    children: [
                                      _TurntableDeckButton(
                                        key: const ValueKey('turntable_pause'),
                                        icon:
                                            playing?.paused == true
                                                ? Icons.play_arrow_rounded
                                                : Icons.pause_rounded,
                                        semanticLabel:
                                            playing?.paused == true
                                                ? context
                                                    .localizations
                                                    .music_action_resume
                                                : context
                                                    .localizations
                                                    .music_action_pause,
                                        selected: active && !playing.paused,
                                        onPressed:
                                            active
                                                ? () => unawaited(
                                                  widget.requests.setPaused(
                                                    !playing.paused,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      _TurntableDeckButton(
                                        key: const ValueKey('turntable_skip'),
                                        icon: Icons.skip_next_rounded,
                                        semanticLabel:
                                            context
                                                .localizations
                                                .music_action_next,
                                        onPressed:
                                            active
                                                ? () => unawaited(
                                                  widget.requests.skip(),
                                                )
                                                : null,
                                      ),
                                      Badge(
                                        key: const ValueKey('turntable_queue'),
                                        isLabelVisible:
                                            _snapshot.queue.isNotEmpty,
                                        backgroundColor: const Color(
                                          0xFFB88F68,
                                        ),
                                        textColor: const Color(0xFF211B22),
                                        label: Text(
                                          '${_snapshot.queue.length}',
                                          key: const ValueKey(
                                            'turntable_queue_count',
                                          ),
                                          textScaler: TextScaler.noScaling,
                                          style: const TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                        child: _TurntableDeckButton(
                                          icon: Icons.queue_music_rounded,
                                          semanticLabel:
                                              context
                                                  .localizations
                                                  .music_queue_next,
                                          selected: _queueExpanded,
                                          onPressed:
                                              _snapshot.queue.isEmpty
                                                  ? null
                                                  : _toggleQueue,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: TurntableGeometry.chassisOrigin.dx,
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                bottom: Radius.circular(19),
                              ),
                              child: ConstrainedBox(
                                key: const ValueKey('turntable_info_panel'),
                                constraints: const BoxConstraints(
                                  maxHeight: 480,
                                ),
                                child: SingleChildScrollView(
                                  key: const ValueKey('turntable_info_scroll'),
                                  primary: false,
                                  physics: const ClampingScrollPhysics(),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: _infoVerticalPadding,
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      Semantics(
                                        label: status,
                                        child: TurntableTrackLine(
                                          leadingInset: 16,
                                          textKey: const ValueKey(
                                            'turntable_track_text',
                                          ),
                                          viewportKey: const ValueKey(
                                            'turntable_track_marquee',
                                          ),
                                          title:
                                              item == null
                                                  ? status
                                                  : item.title ??
                                                      context
                                                          .localizations
                                                          .music_turntable_preparing,
                                          author:
                                              item == null
                                                  ? null
                                                  : item.author ??
                                                      context
                                                          .localizations
                                                          .music_source_youtube,
                                          requestedBy: item?.requestedBy,
                                        ),
                                      ),
                                      if (inlineQueue != null)
                                        Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 16,
                                          ),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            crossAxisAlignment:
                                                CrossAxisAlignment.stretch,
                                            children: [
                                              const Gap(_infoVerticalPadding),
                                              Divider(
                                                key: const ValueKey(
                                                  'turntable_queue_divider',
                                                ),
                                                height: 1,
                                                thickness: 1,
                                                color: MusicPlayerPalette
                                                    .textPrimary
                                                    .withValues(alpha: 0.12),
                                              ),
                                              const Gap(_infoVerticalPadding),
                                              inlineQueue,
                                            ],
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _TurntableDeckButton extends StatefulWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool selected;

  const _TurntableDeckButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    required this.onPressed,
    this.selected = false,
  });

  @override
  State<_TurntableDeckButton> createState() => _TurntableDeckButtonState();
}

class _TurntableDeckButtonState extends State<_TurntableDeckButton> {
  bool _hovered = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depressed = enabled && _pressed;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Listener(
        onPointerDown: enabled ? (_) => setState(() => _pressed = true) : null,
        onPointerUp: (_) => setState(() => _pressed = false),
        onPointerCancel: (_) => setState(() => _pressed = false),
        child: Container(
          width: 32,
          height: 32,
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: const Color(0xFF101018),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: const Color(0xFF090A10)),
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 80),
            transform: Matrix4.translationValues(0, depressed ? 1.5 : 0, 0),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors:
                    depressed
                        ? const [Color(0xFF36343F), Color(0xFF484550)]
                        : enabled && _hovered
                        ? const [Color(0xFF8C8490), Color(0xFF514B58)]
                        : const [Color(0xFF6A6572), Color(0xFF3E3B47)],
              ),
              border: Border.all(
                color:
                    depressed
                        ? const Color(0xFF292631)
                        : const Color(0xFF928895),
                width: 0.6,
              ),
              boxShadow:
                  depressed
                      ? null
                      : const [
                        BoxShadow(
                          color: Color(0xCC000000),
                          offset: Offset(0, 2),
                          blurRadius: 1,
                        ),
                      ],
            ),
            child: Stack(
              children: [
                Positioned.fill(
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 18,
                    color: const Color(0xFFF3E6DD),
                    disabledColor: const Color(0xFF918A96),
                    onPressed: widget.onPressed,
                    icon: Icon(
                      widget.icon,
                      semanticLabel: widget.semanticLabel,
                    ),
                  ),
                ),
                Positioned(
                  top: 3,
                  right: 3,
                  child: IgnorePointer(
                    child: Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            widget.selected
                                ? MusicPlayerPalette.neonPink
                                : const Color(0xFF282530),
                        boxShadow:
                            widget.selected
                                ? const [
                                  BoxShadow(
                                    color: MusicPlayerPalette.neonPink,
                                    blurRadius: 4,
                                  ),
                                ]
                                : null,
                      ),
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

/// Keep the screen inset inside the slide so the exposed edge reaches the screen.
class _PausedTurntableSlide extends StatefulWidget {
  final String? pausedItemId;
  final Widget child;

  const _PausedTurntableSlide({
    super.key,
    required this.pausedItemId,
    required this.child,
  });

  @override
  State<_PausedTurntableSlide> createState() => _PausedTurntableSlideState();
}

class _PausedTurntableSlideState extends State<_PausedTurntableSlide> {
  static const _rightInset = 24.0;
  static const _peekWidth = 64.0;
  Timer? _hideTimer;
  bool _delayElapsed = false;
  bool _hovered = false;

  @override
  void initState() {
    super.initState();
    _scheduleHide();
  }

  @override
  void didUpdateWidget(covariant _PausedTurntableSlide oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.pausedItemId != widget.pausedItemId) _scheduleHide();
  }

  void _scheduleHide() {
    _hideTimer?.cancel();
    _delayElapsed = false;
    if (widget.pausedItemId == null) return;
    _hideTimer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _delayElapsed = true);
    });
  }

  void _setHovered(bool hovered) {
    if (_hovered == hovered) return;
    setState(() => _hovered = hovered);
  }

  @override
  void dispose() {
    _hideTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    width: TurntableGeometry.deckSize.width + _rightInset,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale =
            math.max(0.0, constraints.maxWidth - _rightInset) /
            TurntableGeometry.deckSize.width;
        final slideDistance = math.max(
          0.0,
          constraints.maxWidth -
              _peekWidth -
              TurntableGeometry.chassisOrigin.dx * scale,
        );
        return TweenAnimationBuilder<double>(
          tween: Tween<double>(end: _delayElapsed && !_hovered ? 1 : 0),
          duration: const Duration(milliseconds: 400),
          curve: Curves.easeInOutCubic,
          child: MouseRegion(
            key: const ValueKey('turntable_hover_region'),
            onEnter: (_) => _setHovered(true),
            onExit: (_) => _setHovered(false),
            child: Padding(
              padding: const EdgeInsets.only(right: _rightInset),
              child: widget.child,
            ),
          ),
          builder:
              (context, amount, child) => Transform.translate(
                offset: Offset(slideDistance * amount, 0),
                child: child,
              ),
        );
      },
    ),
  );
}

/// The oversized circular label occupies 58% of the record's diameter.
class VinylRecord extends StatelessWidget {
  final ImageProvider? artwork;

  const VinylRecord({super.key, this.artwork});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: TurntableGeometry.recordRadius * 2,
      child: CustomPaint(
        painter: const _VinylPainter(),
        child: Center(
          child: SizedBox.square(
            dimension: TurntableGeometry.labelRadius * 2,
            child: ClipOval(
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF8D3977),
                          Color(0xFF302C64),
                          Color(0xFF11182F),
                        ],
                      ),
                    ),
                  ),
                  if (artwork != null)
                    Image(
                      image: artwork!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.fromBorderSide(
                        BorderSide(color: Color(0x55FFFFFF), width: 1.5),
                      ),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0x28FFFFFF),
                          Color(0x00000000),
                          Color(0x38000000),
                        ],
                      ),
                    ),
                  ),
                  Center(
                    child: Container(
                      width: 13,
                      height: 13,
                      decoration: BoxDecoration(
                        color: const Color(0xFF111118),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFF807C8B),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

class _VinylPainter extends CustomPainter {
  const _VinylPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawShadow(
      Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
      Colors.black,
      9,
      true,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = ui.Gradient.radial(
          center,
          radius,
          const [
            Color(0xFF292932),
            Color(0xFF101016),
            Color(0xFF22222C),
            Color(0xFF08090D),
          ],
          [0, 0.62, 0.84, 1],
        ),
    );
    for (var r = TurntableGeometry.labelRadius + 3; r < radius - 2; r += 2.2) {
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..color = const Color(
            0xFF393842,
          ).withValues(alpha: r % 3 < 1 ? 0.6 : 0.3)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.65,
      );
    }
    canvas.drawCircle(
      center,
      radius - 1,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          const [
            Color(0x00FFFFFF),
            Color(0x22FFFFFF),
            Color(0x00FFFFFF),
            Color(0x00FFFFFF),
            Color(0x18C6D5FF),
            Color(0x00FFFFFF),
          ],
          [0, 0.13, 0.27, 0.5, 0.67, 1],
        ),
    );
    canvas.drawCircle(
      center,
      radius - 0.8,
      Paint()
        ..color = const Color(0xFF555360)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
  }

  @override
  bool shouldRepaint(covariant _VinylPainter oldDelegate) => false;
}

class _TurntableChassisPainter extends CustomPainter {
  const _TurntableChassisPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      Rect.fromLTRB(
        TurntableGeometry.chassisOrigin.dx,
        TurntableGeometry.chassisOrigin.dy,
        size.width - TurntableGeometry.chassisOrigin.dx,
        size.height,
      ),
      const Radius.circular(19),
    );
    canvas.drawShadow(
      Path()..addRRect(body),
      const Color(0xFF000000),
      18,
      true,
    );
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          body.outerRect.topLeft,
          body.outerRect.bottomRight,
          const [Color(0xFF694C49), Color(0xFF30272C), Color(0xFF704E49)],
          const [0, 0.5, 1],
        ),
    );
  }

  @override
  bool shouldRepaint(covariant _TurntableChassisPainter oldDelegate) => false;
}

void _paintTurntableSpindle(Canvas canvas) {
  const center = TurntableGeometry.platterCenter;
  canvas.drawCircle(center, 3.5, Paint()..color = const Color(0xFF7F7988));
  canvas.drawCircle(center, 2.7, Paint()..color = const Color(0xFFDAD6E0));
}

class _TurntableDeckPainter extends CustomPainter {
  final String? fontFamily;

  const _TurntableDeckPainter({this.fontFamily});

  @override
  void paint(Canvas canvas, Size size) {
    final top = RRect.fromRectAndRadius(
      const Rect.fromLTWH(18, 22, 404, 259),
      const Radius.circular(16),
    );
    canvas.drawRRect(
      top,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(18, 22),
          const Offset(390, 281),
          const [Color(0xFF383744), Color(0xFF1C1C29), Color(0xFF272431)],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawRRect(
      top.deflate(0.6),
      Paint()
        ..color = const Color(0xFF65606D)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    // Subtle machining lines remain static beneath the rotating disc.
    canvas.save();
    canvas.clipRRect(top);
    for (var y = 25.0; y < 280; y += 3) {
      canvas.drawLine(
        Offset(20, y),
        Offset(420, y),
        Paint()
          ..color = const Color(0x06FFFFFF)
          ..strokeWidth = 0.5,
      );
    }
    canvas.restore();
    const center = TurntableGeometry.platterCenter;
    canvas.drawCircle(center, 117, Paint()..color = const Color(0xFF090A13));
    canvas.drawCircle(
      center,
      114,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          const [
            Color(0xFFB7B4BF),
            Color(0xFF3B3A48),
            Color(0xFFCCC5CF),
            Color(0xFF393746),
            Color(0xFFB7B4BF),
          ],
          const [0, 0.25, 0.5, 0.75, 1],
        ),
    );
    canvas.drawCircle(
      center,
      110,
      Paint()
        ..shader = ui.Gradient.radial(
          center - const Offset(18, 22),
          145,
          const [Color(0xFF24242D), Color(0xFF11121A), Color(0xFF1C1C26)],
          const [0, 0.7, 1],
        ),
    );
    // Raised rubber rings and the metal spindle seat show on the empty platter.
    for (var radius = 25.0; radius <= 100; radius += 15) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..color = const Color(0xFF070810)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
      canvas.drawCircle(
        center,
        radius - 1.2,
        Paint()
          ..color = const Color(0xFF36343F)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 0.8,
      );
    }
    canvas.drawCircle(center, 18, Paint()..color = const Color(0xFF090A11));
    canvas.drawCircle(
      center,
      14,
      Paint()
        ..shader = ui.Gradient.sweep(
          center,
          const [
            Color(0xFFB8B4C1),
            Color(0xFF595664),
            Color(0xFFE0DCE4),
            Color(0xFF64616E),
            Color(0xFFB8B4C1),
          ],
          const [0, 0.25, 0.5, 0.75, 1],
        ),
    );
    canvas.drawCircle(
      center,
      10.5,
      Paint()
        ..color = const Color(0xFF716C7B)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.7,
    );
    canvas.drawCircle(center, 6, Paint()..color = const Color(0xFF292732));
    _paintTurntableSpindle(canvas);
    for (var i = 0; i < 96; i++) {
      final angle = i * math.pi * 2 / 96;
      final p = center + Offset(math.cos(angle), math.sin(angle)) * 112;
      canvas.drawCircle(p, 0.85, Paint()..color = const Color(0xFFC1BAC7));
    }
    // Arm bearing, rest and speed selector.
    canvas.drawCircle(
      const Offset(340, 62),
      22,
      Paint()..color = const Color(0xFF0C0D17),
    );
    canvas.drawCircle(
      const Offset(340, 62),
      18,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(322, 44),
          const Offset(358, 80),
          const [Color(0xFF8D899A), Color(0xFF33323F)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(326, 207, 28, 12),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF10101A),
    );
    canvas.drawLine(
      const Offset(340, 203),
      const Offset(340, 224),
      Paint()
        ..color = const Color(0xFF8D8798)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    _text(
      canvas,
      'NEON / 01',
      const Offset(293, 116),
      10,
      const Color(0xFFAEA5B9),
      spacing: 1.7,
    );
    _text(
      canvas,
      'DIRECT DRIVE',
      const Offset(294, 132),
      6.5,
      const Color(0xFF777083),
      spacing: 1.1,
    );
    canvas.drawCircle(
      const Offset(48, 263),
      5,
      Paint()
        ..color = MusicPlayerPalette.neonPink.withValues(alpha: 0.4)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      const Offset(48, 263),
      2.4,
      Paint()..color = MusicPlayerPalette.neonPink,
    );
    _text(
      canvas,
      'VINYL',
      const Offset(61, 258),
      8,
      const Color(0xFFD9C8D7),
      spacing: 1.4,
    );
    for (final p in [
      const Offset(31, 36),
      const Offset(408, 36),
      const Offset(408, 267),
    ]) {
      canvas.drawCircle(p, 2.4, Paint()..color = const Color(0xFF11121C));
      canvas.drawLine(
        p - const Offset(1, 0),
        p + const Offset(1, 0),
        Paint()
          ..color = const Color(0xFF797381)
          ..strokeWidth = 0.7,
      );
    }
  }

  void _text(
    Canvas canvas,
    String value,
    Offset offset,
    double size,
    Color color, {
    double? spacing,
  }) {
    (TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          color: color,
          letterSpacing: spacing,
          fontWeight: FontWeight.w600,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout()).paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _TurntableDeckPainter oldDelegate) =>
      oldDelegate.fontFamily != fontFamily;
}

class _TonearmPainter extends CustomPainter {
  final double angle;
  final double lift;
  final bool spindle;

  const _TonearmPainter({
    required this.angle,
    required this.lift,
    required this.spindle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spindle) _paintTurntableSpindle(canvas);
    canvas.save();
    canvas.translate(
      TurntableGeometry.armPivot.dx,
      TurntableGeometry.armPivot.dy,
    );
    canvas.rotate(angle);
    final tube =
        Path()
          ..moveTo(0, 5)
          ..lineTo(0, 85)
          ..quadraticBezierTo(0, 101, -9, 113)
          ..lineTo(-14, 141);
    canvas.save();
    canvas.translate(3 + lift * 4, 3 + lift * 5);
    canvas.drawPath(
      tube,
      Paint()
        ..color = const Color(0x88000000)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 + lift * 3),
    );
    canvas.restore();
    canvas.drawPath(
      tube,
      Paint()
        ..color = const Color(0xFF161621)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 9
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      tube,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-5, 0),
          const Offset(5, 0),
          const [Color(0xFF827F90), Color(0xFFF0EAF3), Color(0xFF858394)],
          const [0, 0.5, 1],
        )
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(-12, -26, 24, 23),
        const Radius.circular(4),
      ),
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(-12, -26),
          const Offset(12, -3),
          const [Color(0xFFB2AABB), Color(0xFF403D4D)],
        ),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(-23, 136 - lift * 2, 17, 26),
        const Radius.circular(3),
      ),
      Paint()..color = const Color(0xFF11121C),
    );
    canvas.drawLine(
      const Offset(-18, 140),
      const Offset(-18, 155),
      Paint()
        ..color = const Color(0xFFB9B2C2)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(-11, 141),
      const Offset(-11, 154),
      Paint()
        ..color = const Color(0xFF5E586D)
        ..strokeWidth = 1,
    );
    canvas.drawLine(
      const Offset(-7, 138),
      const Offset(4, 138),
      Paint()
        ..color = const Color(0xFFBDB6CA)
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round,
    );
    canvas.restore();
    canvas.drawCircle(
      TurntableGeometry.needlePosition(angle, lift: lift),
      2,
      Paint()..color = MusicPlayerPalette.neonPinkBright,
    );
    canvas.drawCircle(
      const Offset(340, 62),
      10,
      Paint()
        ..shader = ui.Gradient.radial(
          const Offset(337, 59),
          15,
          const [Color(0xFFE4DDE8), Color(0xFF686171), Color(0xFF252331)],
          const [0, 0.5, 1],
        ),
    );
    canvas.drawCircle(
      const Offset(340, 62),
      3,
      Paint()..color = const Color(0xFF2A2836),
    );
  }

  @override
  bool shouldRepaint(covariant _TonearmPainter oldDelegate) =>
      angle != oldDelegate.angle ||
      lift != oldDelegate.lift ||
      spindle != oldDelegate.spindle;
}
