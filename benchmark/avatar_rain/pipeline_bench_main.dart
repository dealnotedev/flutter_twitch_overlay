// End-to-end alert benchmark for the software-rendered OBS engine.
//
// flutter build windows --release -t benchmark/avatar_rain/pipeline_bench_main.dart
// then run the bundle with benchmark/avatar_rain/host/avatar_bench_host.c,
// which drives the OBS plugin's flutter_engine.dll with kSoftware rendering.
//
// Each scenario mounts the real SubsWidget plus an avatar layer with the same
// timings as UserAlertWidget and reports FrameTiming statistics per phase.
// The avatar layer is either the current RainyAvatar or one of the prototype
// renderers below.
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/subs/subs_widget.dart';

enum AvatarImpl {
  /// No avatar: only SubsWidget, to separate the cost of the rest of the scene.
  none,

  /// RainyAvatar as shipped: rounded-rect atlas, bilinear, color modulate.
  current,

  /// drawRawAtlas with the avatar itself as the atlas: one texel per sprite,
  /// nearest sampling, no per-sprite colors. Exact colors.
  texelAtlas,

  /// drawRawPoints, one call per quantized color (4 bits/channel, dithered).
  points4,

  /// drawRawPoints, one call per quantized color (5 bits/channel, dithered).
  points5,

  /// points5 with every 60 fps frame's positions computed ahead of time.
  points5Frames,

  /// Every 60 fps frame pre-rasterized into a cell-resolution image which is
  /// drawn upscaled with nearest sampling.
  cellFrames,
}

class Scenario {
  final AvatarImpl impl;
  final int resolution;
  final double pixelSize;

  const Scenario(this.impl, this.resolution, this.pixelSize);

  String get name => '${impl.name}/r$resolution/p${pixelSize.toInt()}';
}

const _scenarios = [
  Scenario(AvatarImpl.none, 256, 3),
  Scenario(AvatarImpl.current, 128, 8),
  Scenario(AvatarImpl.current, 256, 3),
  Scenario(AvatarImpl.texelAtlas, 256, 3),
  Scenario(AvatarImpl.points4, 256, 3),
  Scenario(AvatarImpl.points5, 256, 3),
  Scenario(AvatarImpl.points5Frames, 256, 3),
  Scenario(AvatarImpl.cellFrames, 256, 3),
];

const _verticalOffset = -SubsWidget.bottomTextBackplatesHeight / 2.0;
const _enteringDuration = Duration(seconds: 5);
const _enteringFall = Duration(seconds: 3);
const _leavingDuration = Duration(seconds: 2);
const _leavingFall = Duration(milliseconds: 1200);
const _frameMs = 1000.0 / 60.0;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BenchApp());
}

img.Image _syntheticAvatar() {
  final image = img.Image(width: 300, height: 300);
  final rnd = Random(7);
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 300; x++) {
      image.setPixelRgba(
        x,
        y,
        (x * 255 ~/ 300) ^ rnd.nextInt(24),
        (y * 255 ~/ 300) ^ rnd.nextInt(24),
        ((x + y) * 127 ~/ 300) ^ rnd.nextInt(24),
        255,
      );
    }
  }
  return image;
}

// ---------------------------------------------------------------------------
// Benchmark driver
// ---------------------------------------------------------------------------

class _BenchApp extends StatefulWidget {
  const _BenchApp();

  @override
  State<_BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<_BenchApp> {
  final _avatar = _syntheticAvatar();
  final _results = <String>[];
  Scenario? _scenario;
  _Prepared? _prepared;
  String? _phase;
  final _timings = <FrameTiming>[];
  Completer<void>? _leavingStarted;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    unawaited(_run());
  }

  void _onTimings(List<FrameTiming> timings) {
    if (_phase != null) _timings.addAll(timings);
  }

  Future<void> _measure(String phase, Duration length) async {
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _timings.clear();
    _phase = phase;
    _log('BENCH_PHASE_BEGIN ${_scenario!.name}:$phase');
    await Future<void>.delayed(length);
    _log('BENCH_PHASE_STOP');
    final stop = SchedulerBinding.instance.currentSystemFrameTimeStamp;
    // Timings are delivered in batches; wait for the last ones.
    await Future<void>.delayed(const Duration(milliseconds: 1200));
    _phase = null;
    _timings.removeWhere(
      (t) =>
          Duration(
            microseconds: t.timestampInMicroseconds(ui.FramePhase.vsyncStart),
          ) >
          stop,
    );
    _results.add(_summary('${_scenario!.name}:$phase'));
  }

  String _summary(String label) {
    if (_timings.isEmpty) return '$label: no frames';
    List<double> sorted(Duration Function(FrameTiming) f) =>
        _timings.map((t) => f(t).inMicroseconds / 1000.0).toList()..sort();
    String fmt(List<double> v) =>
        'p50 ${v[v.length ~/ 2].toStringAsFixed(1)} '
        'p95 ${v[(v.length * 0.95).floor().clamp(0, v.length - 1)].toStringAsFixed(1)} '
        'max ${v.last.toStringAsFixed(1)}';
    return '${label.padRight(30)} build ${fmt(sorted((t) => t.buildDuration))}'
        ' | raster ${fmt(sorted((t) => t.rasterDuration))}';
  }

  Future<void> _run() async {
    await Future<void>.delayed(const Duration(seconds: 2));
    final view = ui.PlatformDispatcher.instance.implicitView!;
    final size = view.physicalSize / view.devicePixelRatio;
    final constraints = BoxConstraints.tight(size);
    for (final scenario in _scenarios) {
      final prepared = await _Prepared.create(scenario, _avatar, constraints);
      _log('BENCH_INFO ${scenario.name}: ${prepared.info}');
      _leavingStarted = Completer<void>();
      setState(() {
        _scenario = scenario;
        _prepared = prepared;
      });
      await _measure('enter', _enteringDuration);
      await _leavingStarted!.future;
      await _measure('leave', _leavingDuration);
      await Future<void>.delayed(const Duration(seconds: 4));
      setState(() {
        _scenario = null;
        _prepared = null;
      });
      await Future<void>.delayed(const Duration(milliseconds: 500));
      prepared.dispose();
    }
    for (final line in _results) {
      _log('BENCH_RESULT $line');
    }
    _log('BENCH_DONE');
  }

  @override
  Widget build(BuildContext context) {
    final scenario = _scenario;
    final prepared = _prepared;
    return Directionality(
      textDirection: TextDirection.ltr,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (scenario == null || prepared == null) {
            return const SizedBox.expand();
          }
          return _AlertScene(
            key: ValueKey(scenario),
            scenario: scenario,
            prepared: prepared,
            avatar: _avatar,
            constraints: constraints,
            onLeaving: () => _leavingStarted?.complete(),
          );
        },
      ),
    );
  }
}

void _log(String message) {
  // ignore: avoid_print
  print(message);
}

class _Prepared {
  final List<Pixel> entering;
  final List<Pixel> leaving;
  final AvatarRenderer? enteringRenderer;
  final AvatarRenderer? leavingRenderer;
  final String info;

  _Prepared(
    this.entering,
    this.leaving,
    this.enteringRenderer,
    this.leavingRenderer,
    this.info,
  );

  void dispose() {
    enteringRenderer?.dispose();
    leavingRenderer?.dispose();
  }

  static Future<_Prepared> create(
    Scenario s,
    img.Image avatar,
    BoxConstraints constraints,
  ) async {
    final sw = Stopwatch()..start();
    final entering = RainyAvatar.preparePixels(
      image: avatar,
      constraints: constraints,
      duration: _enteringDuration,
      fallDuration: _enteringFall,
      pixelSize: s.pixelSize,
      resolution: s.resolution,
      verticalOffset: _verticalOffset,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.entering,
    );
    final leaving = RainyAvatar.preparePixels(
      image: avatar,
      constraints: constraints,
      duration: _leavingDuration,
      fallDuration: _leavingFall,
      pixelSize: s.pixelSize,
      resolution: s.resolution,
      verticalOffset: _verticalOffset,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.leaving,
      motion: AvatarPixelMotion.horizontalWaves,
    );
    final pixelsMs = sw.elapsedMicroseconds / 1000.0;
    sw.reset();

    final grid = AvatarGrid(
      resolution: s.resolution,
      pixelSize: s.pixelSize,
      width: constraints.maxWidth,
      height: constraints.maxHeight,
    );
    AvatarRenderer? enter;
    AvatarRenderer? leave;
    switch (s.impl) {
      case AvatarImpl.none:
      case AvatarImpl.current:
        break;
      case AvatarImpl.texelAtlas:
        enter = await TexelAtlasRenderer.create(entering, grid, landed: false);
        leave = await TexelAtlasRenderer.create(leaving, grid, landed: true);
      case AvatarImpl.points4:
      case AvatarImpl.points5:
        final bits = s.impl == AvatarImpl.points4 ? 4 : 5;
        enter = PointsRenderer.create(entering, grid, bits, landed: false);
        leave = PointsRenderer.create(leaving, grid, bits, landed: true);
      case AvatarImpl.points5Frames:
        enter = PointsRenderer.create(
          entering,
          grid,
          5,
          landed: false,
          precomputeMs: _enteringDuration.inMilliseconds.toDouble(),
        );
        leave = PointsRenderer.create(
          leaving,
          grid,
          5,
          landed: true,
          precomputeMs: _leavingDuration.inMilliseconds.toDouble(),
        );
      case AvatarImpl.cellFrames:
        enter = await CellFramesRenderer.create(
          entering,
          grid,
          landed: false,
          durationMs: _enteringDuration.inMilliseconds.toDouble(),
        );
        leave = await CellFramesRenderer.create(
          leaving,
          grid,
          landed: true,
          durationMs: _leavingDuration.inMilliseconds.toDouble(),
        );
    }
    final rendererMs = sw.elapsedMicroseconds / 1000.0;
    final details = [
      '${entering.length} particles',
      'preparePixels x2 ${pixelsMs.toStringAsFixed(1)} ms',
      if (enter != null)
        'renderer prepare x2 ${rendererMs.toStringAsFixed(1)} ms',
      if (enter != null) enter.describe(),
      if (leave != null) 'leaving: ${leave.describe()}',
    ];
    return _Prepared(entering, leaving, enter, leave, details.join(', '));
  }
}

class _AlertScene extends StatefulWidget {
  final Scenario scenario;
  final _Prepared prepared;
  final img.Image avatar;
  final BoxConstraints constraints;
  final VoidCallback onLeaving;

  const _AlertScene({
    super.key,
    required this.scenario,
    required this.prepared,
    required this.avatar,
    required this.constraints,
    required this.onLeaving,
  });

  @override
  State<_AlertScene> createState() => _AlertSceneState();
}

class _AlertSceneState extends State<_AlertScene> {
  bool _leaving = false;

  void _handleLeaving() {
    if (!mounted) return;
    setState(() => _leaving = true);
    widget.onLeaving();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.scenario;
    final p = widget.prepared;
    return Stack(
      fit: StackFit.expand,
      children: [
        SubsWidget(
          who: 'BENCH_USER',
          description: 'Дякую за фолов!',
          constraints: widget.constraints,
          onLeaving: _handleLeaving,
          pixelRadius: const Radius.circular(1),
        ),
        if (s.impl == AvatarImpl.current)
          RainyAvatar(
            key: ValueKey(_leaving),
            image: widget.avatar,
            constraints: widget.constraints,
            duration: _leaving ? _leavingDuration : _enteringDuration,
            fallDuration: _leaving ? _leavingFall : _enteringFall,
            resolution: s.resolution,
            pixelSize: s.pixelSize,
            pixelPadding: 0,
            pixelRadius: const Radius.circular(1),
            randomBackground: false,
            verticalOffset: _verticalOffset,
            scaleWhenStart: false,
            origin: RainyPixelOrigin.outside,
            direction:
                _leaving
                    ? RainyPixelDirection.leaving
                    : RainyPixelDirection.entering,
            motion:
                _leaving
                    ? AvatarPixelMotion.horizontalWaves
                    : AvatarPixelMotion.linear,
            preparedPixels: _leaving ? p.leaving : p.entering,
          )
        else if (s.impl != AvatarImpl.none)
          RendererAvatar(
            key: ValueKey(_leaving),
            renderer: _leaving ? p.leavingRenderer! : p.enteringRenderer!,
            duration: _leaving ? _leavingDuration : _enteringDuration,
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared motion model
// ---------------------------------------------------------------------------

/// Placement of the avatar grid on the canvas, as in RainyAvatar._makePixels.
class AvatarGrid {
  final int resolution;
  final double pixelSize;
  final double left;
  final double top;

  AvatarGrid({
    required this.resolution,
    required this.pixelSize,
    required double width,
    required double height,
  }) : left = width / 2 - resolution * pixelSize / 2,
       top = height / 2 - resolution * pixelSize / 2 + _verticalOffset;

  /// Grid cell of a particle from its position inside the avatar.
  (int, int) cellOf(double x, double y) => (
    ((x - left) / pixelSize).round(),
    ((y - top) / pixelSize).round(),
  );
}

const _lutSize = 1024;

Float32List _lut(double Function(double) f) {
  final lut = Float32List(_lutSize + 2);
  for (var i = 0; i <= _lutSize; i++) {
    lut[i] = f(i / _lutSize);
  }
  lut[_lutSize + 1] = lut[_lutSize];
  return lut;
}

final _easeOutLut = _lut(Curves.easeOut.transform);
final _sineLut = _lut(Curves.easeInOutSine.transform);
final _waveLut = _lut((t) => sin(t * pi * 4.0) * sin(t * pi));

/// Particle motion in structure-of-arrays form with lookup-table easing.
class RainMotion {
  final int count;
  final Float32List startX, startY, deltaX, deltaY, delayMs;
  final double fallMs;
  final bool waves;

  RainMotion._(this.count, this.fallMs, this.waves)
    : startX = Float32List(count),
      startY = Float32List(count),
      deltaX = Float32List(count),
      deltaY = Float32List(count),
      delayMs = Float32List(count);

  /// Copies [pixels] in [order]; [offset] is added to the positions, for
  /// example half a pixel to address square centers.
  factory RainMotion.fromPixels(
    List<Pixel> pixels,
    List<int> order, {
    required double offset,
    required bool waves,
  }) {
    final fallMs =
        (waves ? _leavingFall : _enteringFall).inMilliseconds.toDouble();
    final motion = RainMotion._(pixels.length, fallMs, waves);
    for (var k = 0; k < order.length; k++) {
      final p = pixels[order[k]];
      motion.startX[k] = p.startX + offset;
      motion.startY[k] = p.startY + offset;
      motion.deltaX[k] = p.x - p.startX;
      motion.deltaY[k] = p.y - p.startY;
      motion.delayMs[k] = p.delayMs.toDouble();
    }
    return motion;
  }

  /// Writes x/y of every particle at [timeMs] into [out] at
  /// `out[i * stride + first]` and `out[i * stride + first + 1]`.
  void positions(double timeMs, Float32List out, int stride, int first) {
    final inv = _lutSize / fallMs;
    final ease = waves ? _sineLut : _easeOutLut;
    for (var i = 0; i < count; i++) {
      var f = (timeMs - delayMs[i]) * inv;
      if (f < 0) f = 0;
      if (f > _lutSize) f = _lutSize.toDouble();
      final k = f.toInt();
      final w = f - k;
      final e = ease[k] + (ease[k + 1] - ease[k]) * w;
      final o = i * stride + first;
      out[o] = startX[i] + deltaX[i] * e;
      if (waves) {
        final v = _waveLut[k] + (_waveLut[k + 1] - _waveLut[k]) * w;
        out[o + 1] = startY[i] + deltaY[i] * v;
      } else {
        out[o + 1] = startY[i] + deltaY[i] * e;
      }
    }
  }
}

/// Position of a particle inside the avatar (its landing spot when entering,
/// its starting spot when leaving).
(double, double) _avatarPosition(Pixel p, {required bool landed}) =>
    landed ? (p.startX, p.startY) : (p.x, p.y);

// ---------------------------------------------------------------------------
// Renderers
// ---------------------------------------------------------------------------

abstract class AvatarRenderer {
  void paint(Canvas canvas, double timeMs);

  String describe() => '';

  void dispose() {}
}

class RendererAvatar extends StatefulWidget {
  final AvatarRenderer renderer;
  final Duration duration;

  const RendererAvatar({
    super.key,
    required this.renderer,
    required this.duration,
  });

  @override
  State<RendererAvatar> createState() => _RendererAvatarState();
}

class _RendererAvatarState extends State<RendererAvatar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        size: Size.infinite,
        painter: _RendererPainter(
          widget.renderer,
          _controller,
          widget.duration.inMilliseconds.toDouble(),
        ),
      ),
    );
  }
}

class _RendererPainter extends CustomPainter {
  final AvatarRenderer renderer;
  final Animation<double> animation;
  final double durationMs;

  _RendererPainter(this.renderer, this.animation, this.durationMs)
    : super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) =>
      renderer.paint(canvas, animation.value * durationMs);

  @override
  bool shouldRepaint(covariant _RendererPainter old) =>
      old.renderer != renderer || old.animation != animation;
}

Future<ui.Image> _imageFromPixels(Uint8List rgba, int width, int height) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    width,
    height,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

void _putRgba(Uint8List rgba, int offset, int argb) {
  rgba[offset] = (argb >> 16) & 0xFF;
  rgba[offset + 1] = (argb >> 8) & 0xFF;
  rgba[offset + 2] = argb & 0xFF;
  rgba[offset + 3] = argb >>> 24;
}

/// drawRawAtlas where the atlas is the avatar: exact colors, no modulate,
/// nearest sampling, square pixels.
class TexelAtlasRenderer extends AvatarRenderer {
  final RainMotion motion;
  final ui.Image texture;
  final Float32List transforms;
  final Float32List rects;
  final Paint _paint =
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;

  TexelAtlasRenderer._(this.motion, this.texture, this.transforms, this.rects);

  static Future<TexelAtlasRenderer> create(
    List<Pixel> pixels,
    AvatarGrid grid, {
    required bool landed,
  }) async {
    final n = pixels.length;
    final res = grid.resolution;
    final rgba = Uint8List(res * res * 4);
    final transforms = Float32List(n * 4);
    final rects = Float32List(n * 4);
    for (var i = 0; i < n; i++) {
      final (x, y) = _avatarPosition(pixels[i], landed: landed);
      final (u, v) = grid.cellOf(x, y);
      _putRgba(rgba, (v * res + u) * 4, pixels[i].color.toARGB32());
      transforms[i * 4] = grid.pixelSize;
      rects[i * 4] = u.toDouble();
      rects[i * 4 + 1] = v.toDouble();
      rects[i * 4 + 2] = u + 1.0;
      rects[i * 4 + 3] = v + 1.0;
    }
    final texture = await _imageFromPixels(rgba, res, res);
    final motion = RainMotion.fromPixels(
      pixels,
      List<int>.generate(n, (i) => i),
      offset: 0,
      waves: landed,
    );
    return TexelAtlasRenderer._(motion, texture, transforms, rects);
  }

  @override
  void paint(Canvas canvas, double timeMs) {
    motion.positions(timeMs, transforms, 4, 2);
    canvas.drawRawAtlas(texture, transforms, rects, null, null, null, _paint);
  }

  @override
  void dispose() => texture.dispose();
}

const _bayer4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

/// Particles sorted by quantized color, one drawRawPoints call per color with
/// square caps. Skia's CPU backend fills such points with a solid-color rect
/// blitter instead of sampling a texture per sprite.
class PointsRenderer extends AvatarRenderer {
  final RainMotion motion;
  final Int32List groupEnd;
  final List<Paint> paints;
  final Float32List points;

  /// Positions of every 60 fps frame, when computed ahead of time.
  final List<Float32List>? frames;

  PointsRenderer._(
    this.motion,
    this.groupEnd,
    this.paints,
    this.points,
    this.frames,
  );

  factory PointsRenderer.create(
    List<Pixel> pixels,
    AvatarGrid grid,
    int bits, {
    required bool landed,
    double? precomputeMs,
  }) {
    final shift = 8 - bits;
    final step = 1 << shift;
    final n = pixels.length;
    final keys = Int32List(n);
    for (var i = 0; i < n; i++) {
      final (x, y) = _avatarPosition(pixels[i], landed: landed);
      final (u, v) = grid.cellOf(x, y);
      // Ordered dithering hides the banding of the reduced palette.
      final dither = ((_bayer4[(v & 3) * 4 + (u & 3)] + 0.5) / 16 - 0.5) * step;
      int q(int channel) => (channel + dither).round().clamp(0, 255) >> shift;
      final c = pixels[i].color.toARGB32();
      keys[i] =
          ((c >>> 24) >> shift) << (bits * 3) |
          q((c >> 16) & 0xFF) << (bits * 2) |
          q((c >> 8) & 0xFF) << bits |
          q(c & 0xFF);
    }
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) => keys[a] - keys[b]);

    final ends = <int>[];
    final paints = <Paint>[];
    var start = 0;
    for (var k = 1; k <= n; k++) {
      if (k == n || keys[order[k]] != keys[order[start]]) {
        var a = 0, r = 0, g = 0, b = 0;
        for (var j = start; j < k; j++) {
          final c = pixels[order[j]].color.toARGB32();
          a += c >>> 24;
          r += (c >> 16) & 0xFF;
          g += (c >> 8) & 0xFF;
          b += c & 0xFF;
        }
        final m = k - start;
        paints.add(
          Paint()
            ..color = Color.fromARGB(a ~/ m, r ~/ m, g ~/ m, b ~/ m)
            ..strokeWidth = grid.pixelSize
            ..strokeCap = StrokeCap.square
            ..isAntiAlias = false,
        );
        ends.add(k);
        start = k;
      }
    }

    final motion = RainMotion.fromPixels(
      pixels,
      order,
      offset: grid.pixelSize / 2,
      waves: landed,
    );
    List<Float32List>? frames;
    if (precomputeMs != null) {
      final count = (precomputeMs / _frameMs).ceil() + 1;
      frames = List.generate(count, (f) {
        final out = Float32List(n * 2);
        motion.positions(f * _frameMs, out, 2, 0);
        return out;
      });
    }
    return PointsRenderer._(
      motion,
      Int32List.fromList(ends),
      paints,
      Float32List(n * 2),
      frames,
    );
  }

  @override
  String describe() {
    final frames = this.frames;
    final memory =
        frames == null
            ? ''
            : ', ${frames.length} precomputed frames '
                '${(frames.length * motion.count * 8 / 1048576).toStringAsFixed(0)} MiB';
    return '${groupEnd.length} color groups$memory';
  }

  @override
  void paint(Canvas canvas, double timeMs) {
    final frames = this.frames;
    final Float32List source;
    if (frames != null) {
      source = frames[(timeMs / _frameMs).round().clamp(0, frames.length - 1)];
    } else {
      motion.positions(timeMs, points, 2, 0);
      source = points;
    }
    var start = 0;
    for (var g = 0; g < groupEnd.length; g++) {
      final end = groupEnd[g];
      canvas.drawRawPoints(
        ui.PointMode.points,
        Float32List.sublistView(source, start * 2, end * 2),
        paints[g],
      );
      start = end;
    }
  }
}

/// Pre-rendered frames: each 60 fps frame is rasterized ahead of time into an
/// image with one texel per avatar cell, aligned to the avatar grid, and drawn
/// upscaled with nearest sampling.
class CellFramesRenderer extends AvatarRenderer {
  final List<ui.Image> frames;
  final Rect source;
  final Rect destination;
  final Paint _paint = Paint()..filterQuality = FilterQuality.none;

  CellFramesRenderer._(this.frames, this.source, this.destination);

  static Future<CellFramesRenderer> create(
    List<Pixel> pixels,
    AvatarGrid grid, {
    required bool landed,
    required double durationMs,
  }) async {
    final ps = grid.pixelSize;
    final originX = grid.left - (grid.left / ps).ceil() * ps;
    final originY = grid.top - (grid.top / ps).ceil() * ps;
    final view = ui.PlatformDispatcher.instance.implicitView!;
    final size = view.physicalSize / view.devicePixelRatio;
    final width = ((size.width - originX) / ps).ceil();
    final height = ((size.height - originY) / ps).ceil();

    final n = pixels.length;
    final motion = RainMotion.fromPixels(
      pixels,
      List<int>.generate(n, (i) => i),
      offset: 0,
      waves: landed,
    );
    final colors = Uint32List(n);
    for (var i = 0; i < n; i++) {
      final c = pixels[i].color.toARGB32();
      // Little-endian RGBA8888.
      colors[i] =
          (c & 0xFF000000) |
          ((c & 0xFF) << 16) |
          (c & 0xFF00) |
          ((c >> 16) & 0xFF);
    }
    final positions = Float32List(n * 2);
    final count = (durationMs / _frameMs).ceil() + 1;
    final pending = <Future<ui.Image>>[];
    for (var f = 0; f < count; f++) {
      motion.positions(f * _frameMs, positions, 2, 0);
      final buffer = Uint32List(width * height);
      for (var i = 0; i < n; i++) {
        final cx = ((positions[i * 2] - originX) / ps).round();
        final cy = ((positions[i * 2 + 1] - originY) / ps).round();
        if (cx >= 0 && cy >= 0 && cx < width && cy < height) {
          buffer[cy * width + cx] = colors[i];
        }
      }
      pending.add(_imageFromPixels(buffer.buffer.asUint8List(), width, height));
    }
    final frames = await Future.wait(pending);
    return CellFramesRenderer._(
      frames,
      Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      Rect.fromLTWH(originX, originY, width * ps, height * ps),
    );
  }

  @override
  String describe() {
    final w = source.width.toInt(), h = source.height.toInt();
    return '${frames.length} frames of ${w}x$h '
        '(${(frames.length * w * h * 4 / 1048576).toStringAsFixed(0)} MiB)';
  }

  @override
  void paint(Canvas canvas, double timeMs) {
    final index = (timeMs / _frameMs).round().clamp(0, frames.length - 1);
    canvas.drawImageRect(frames[index], source, destination, _paint);
  }

  @override
  void dispose() {
    for (final frame in frames) {
      frame.dispose();
    }
  }
}
