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
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/turntable_motion.dart';
import 'package:obssource/music/turntable_playback_controller.dart';

class TurntableMusicPlayer extends StatefulWidget {
  final MusicRequests requests;
  final TurntablePlaybackController playback;
  final VoidCallback? onShowQueue;

  const TurntableMusicPlayer({
    super.key,
    required this.requests,
    required this.playback,
    this.onShowQueue,
  });

  @override
  State<TurntableMusicPlayer> createState() => _TurntableMusicPlayerState();
}

class _TurntableMusicPlayerState extends State<TurntableMusicPlayer>
    with SingleTickerProviderStateMixin {
  late final TurntableMotion _motion;
  late final Ticker _ticker;
  late MusicQueueSnapshot _snapshot;
  StreamSubscription<MusicQueueSnapshot>? _subscription;
  final _items = <String, MusicQueueItem>{};
  Duration _previousElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _motion = TurntableMotion(
      onNeedlePlaced: (id) => widget.playback.needlePlaced(id),
    );
    _ticker = createTicker(_tick);
    _connect();
  }

  void _connect() {
    widget.playback.attach();
    widget.playback.addListener(_syncMotion);
    _snapshot = widget.requests.current;
    _subscription = widget.requests.states.listen((snapshot) {
      if (!mounted) return;
      setState(() => _snapshot = snapshot);
      _syncMotion();
    });
    _syncMotion();
  }

  @override
  void didUpdateWidget(covariant TurntableMusicPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.requests != widget.requests ||
        oldWidget.playback != widget.playback) {
      oldWidget.playback.removeListener(_syncMotion);
      oldWidget.playback.detach();
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
      ready:
          item != null &&
          (widget.playback.readyItemId == item.id ||
              (playing != null && !playing.starting)),
      paused: playing?.paused ?? false,
      progress: duration > 0 ? playing!.position.inMilliseconds / duration : 0,
    );
    if (!_ticker.isActive && _motion.phase != TurntablePhase.hidden) {
      _previousElapsed = Duration.zero;
      _ticker.start();
    }
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
      _motion.trackProgress = ((playing.position + elapsed).inMilliseconds /
              duration)
          .clamp(0.0, 1.0);
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
    widget.playback.removeListener(_syncMotion);
    widget.playback.detach();
    unawaited(_subscription?.cancel());
    _ticker.dispose();
    _motion.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 440,
      height: 364,
      child: FittedBox(
        fit: BoxFit.contain,
        alignment: Alignment.bottomRight,
        child: AnimatedBuilder(
          animation: _motion,
          builder: (context, _) {
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
              child: Transform.translate(
                offset: Offset(0, (1 - _motion.visibility) * 390),
                child: Opacity(
                  opacity: _motion.visibility,
                  child: SizedBox(
                    key: const ValueKey('music_turntable'),
                    width: 440,
                    height: 364,
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
                            left: 48 + (1 - _motion.recordPlacement) * 440,
                            top:
                                37 -
                                math.sin(
                                      (1 - _motion.recordPlacement) *
                                          math.pi /
                                          2,
                                    ) *
                                    40,
                            child: Transform.scale(
                              scale: 1 + (1 - _motion.recordPlacement) * 0.13,
                              child: Transform.rotate(
                                angle:
                                    _motion.rotation -
                                    (1 - _motion.recordPlacement) * 0.35,
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
                          ),
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: _TonearmPainter(
                                arm: _motion.arm,
                                lift: _motion.needleLift,
                                progress: _motion.trackProgress,
                                spindle:
                                    _motion.recordVisible &&
                                    _motion.recordPlacement > 0.999,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          left: 28,
                          right: 25,
                          top: 310,
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      status.toUpperCase(),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MusicPlayerPalette.neonPink,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 1.8,
                                      ),
                                    ),
                                    const Gap(4),
                                    Text(
                                      item?.title ??
                                          context
                                              .localizations
                                              .music_turntable_preparing,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MusicPlayerPalette.textPrimary,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const Gap(2),
                                    Text(
                                      item == null
                                          ? ''
                                          : '${item.author ?? context.localizations.music_source_youtube} · ${item.requestedBy}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        color: MusicPlayerPalette.textSecondary,
                                        fontSize: 10,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Gap(8),
                              if (active) ...[
                                NeonMusicIconButton(
                                  key: const ValueKey('turntable_pause'),
                                  icon:
                                      playing.paused
                                          ? Icons.play_arrow_rounded
                                          : Icons.pause_rounded,
                                  onPressed:
                                      () => unawaited(
                                        widget.requests.setPaused(
                                          !playing.paused,
                                        ),
                                      ),
                                ),
                                const Gap(6),
                                NeonMusicIconButton(
                                  key: const ValueKey('turntable_skip'),
                                  icon: Icons.skip_next_rounded,
                                  onPressed:
                                      () => unawaited(widget.requests.skip()),
                                ),
                                const Gap(6),
                              ],
                              NeonMusicIconButton(
                                key: const ValueKey('turntable_queue'),
                                icon: Icons.queue_music_rounded,
                                onPressed: widget.onShowQueue,
                              ),
                            ],
                          ),
                        ),
                      ],
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

/// The oversized circular label occupies 58% of the record's diameter.
class VinylRecord extends StatelessWidget {
  final ImageProvider? artwork;

  const VinylRecord({super.key, this.artwork});

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: SizedBox.square(
      dimension: 220,
      child: CustomPaint(
        painter: const _VinylPainter(),
        child: Center(
          child: SizedBox.square(
            dimension: 128,
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
                    child: Icon(
                      Icons.music_note_rounded,
                      color: Color(0xFFD9B3D5),
                      size: 42,
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
    for (var r = 67.0; r < radius - 2; r += 2.2) {
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

class _TurntableDeckPainter extends CustomPainter {
  final String? fontFamily;

  const _TurntableDeckPainter({this.fontFamily});

  @override
  void paint(Canvas canvas, Size size) {
    final body = RRect.fromRectAndRadius(
      const Rect.fromLTWH(14, 22, 412, 272),
      const Radius.circular(19),
    );
    canvas.drawShadow(
      Path()..addRRect(body),
      const Color(0xFF000000),
      18,
      true,
    );
    for (final x in [40.0, 360.0]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x, 283, 39, 16),
          const Radius.circular(6),
        ),
        Paint()..color = const Color(0xFF0A0910),
      );
    }
    canvas.drawRRect(
      body,
      Paint()
        ..shader = ui.Gradient.linear(
          const Offset(14, 22),
          const Offset(426, 294),
          const [Color(0xFF694C49), Color(0xFF30272C), Color(0xFF704E49)],
          const [0, 0.5, 1],
        ),
    );
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
    const center = Offset(158, 147);
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
    canvas.drawCircle(center, 110, Paint()..color = const Color(0xFF15151F));
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
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        const Rect.fromLTWH(295, 248, 91, 17),
        const Radius.circular(4),
      ),
      Paint()..color = const Color(0xFF0B0C16),
    );
    _text(
      canvas,
      '33 ⅓',
      const Offset(305, 250),
      10,
      const Color(0xFFF8BBDD),
      spacing: 1,
    );
    _text(canvas, 'RPM', const Offset(354, 252), 7, const Color(0xFF8D8798));
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
    canvas.drawLine(
      const Offset(34, 286),
      const Offset(405, 286),
      Paint()
        ..color = MusicPlayerPalette.neonPink.withValues(alpha: 0.55)
        ..strokeWidth = 1,
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
  final double arm;
  final double lift;
  final double progress;
  final bool spindle;

  const _TonearmPainter({
    required this.arm,
    required this.lift,
    required this.progress,
    required this.spindle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spindle) {
      canvas.drawCircle(
        const Offset(158, 147),
        3.5,
        Paint()
          ..shader = ui.Gradient.linear(
            const Offset(155, 144),
            const Offset(161, 150),
            const [Color(0xFFFFFFFF), Color(0xFF777483)],
          ),
      );
    }
    canvas.save();
    canvas.translate(340, 62);
    canvas.rotate(arm * (0.60 + progress * 0.20));
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
    canvas.drawCircle(
      Offset(-15, 162 - lift * 2),
      2,
      Paint()..color = MusicPlayerPalette.neonPinkBright,
    );
    canvas.restore();
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
      arm != oldDelegate.arm ||
      lift != oldDelegate.lift ||
      progress != oldDelegate.progress ||
      spindle != oldDelegate.spindle;
}
