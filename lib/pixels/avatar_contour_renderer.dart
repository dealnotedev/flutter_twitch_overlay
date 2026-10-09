import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/animation.dart';
import 'package:flutter/painting.dart';
import 'package:obssource/pixels/pixel.dart';

/// The assembled avatar's circle, in canvas coordinates. During departure the
/// particle's starting position identifies its cell; during arrival, its target.
class AvatarContour {
  final double centerX, centerY, radius, pixelSize;
  final bool fromStart;

  const AvatarContour({
    required this.centerX,
    required this.centerY,
    required this.radius,
    required this.pixelSize,
    required this.fromStart,
  });
}

const _bayer4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

/// Only Dart data: particle preparation and color grouping can run in an
/// isolate. Interior particles are ordered by color, followed by boundary cells.
class ContourRainData {
  final Float32List startX, startY, endX, endY, delayMs;
  final Int32List groupEnds, groupColors, edgeColors;
  // Circle center relative to each boundary cell, and radius, in cell units.
  final Float32List edgeCircles;

  ContourRainData._(
    this.startX,
    this.startY,
    this.endX,
    this.endY,
    this.delayMs,
    this.groupEnds,
    this.groupColors,
    this.edgeColors,
    this.edgeCircles,
  );

  int get count => startX.length;
  int get edgeCount => edgeColors.length;
  int get interiorCount => count - edgeCount;

  factory ContourRainData.prepare(
    List<Pixel> pixels, {
    required double pixelSize,
    AvatarContour? contour,
  }) {
    final groups = <int, List<int>>{};
    final boundary = List<bool>.filled(pixels.length, false);
    for (var i = 0; i < pixels.length; i++) {
      final p = pixels[i];
      final x = contour?.fromStart == true ? p.startX : p.x;
      final y = contour?.fromStart == true ? p.startY : p.y;
      var u = (x / pixelSize).round();
      var v = (y / pixelSize).round();
      if (contour != null) {
        final half = pixelSize / 2;
        final dx = (x + half - contour.centerX).abs() + half;
        final dy = (y + half - contour.centerY).abs() + half;
        boundary[i] = dx * dx + dy * dy > contour.radius * contour.radius;
        final left = contour.centerX - contour.radius - half;
        final top = contour.centerY - contour.radius - half;
        u = ((x - left) / pixelSize).round();
        v = ((y - top) / pixelSize).round();
      }
      final dither = _bayer4[(v & 3) * 4 + (u & 3)] - 7.5;
      int q(int channel) => (channel + dither).round().clamp(0, 255) >> 4;
      final c = p.color.toARGB32();
      final key =
          ((c >>> 24) >> 4) << 12 |
          q((c >> 16) & 255) << 8 |
          q((c >> 8) & 255) << 4 |
          q(c & 255);
      (groups[key] ??= []).add(i);
    }

    final order = <int>[];
    final edges = <int>[];
    final ends = <int>[];
    final colors = <int>[];
    final edgeColors = <int>[];
    for (final indexes in groups.values) {
      var a = 0, r = 0, g = 0, b = 0;
      for (final i in indexes) {
        final c = pixels[i].color.toARGB32();
        a += c >>> 24;
        r += (c >> 16) & 255;
        g += (c >> 8) & 255;
        b += c & 255;
      }
      final n = indexes.length;
      final color = (a ~/ n) << 24 | (r ~/ n) << 16 | (g ~/ n) << 8 | b ~/ n;
      final start = order.length;
      for (final i in indexes) {
        if (boundary[i]) {
          edges.add(i);
          edgeColors.add(color);
        } else {
          order.add(i);
        }
      }
      if (order.length > start) {
        ends.add(order.length);
        colors.add(color);
      }
    }
    final circles = Float32List(edges.length * 3);
    if (contour != null) {
      for (var i = 0; i < edges.length; i++) {
        final p = pixels[edges[i]];
        final x = contour.fromStart ? p.startX : p.x;
        final y = contour.fromStart ? p.startY : p.y;
        circles[i * 3] = (contour.centerX - x) / pixelSize;
        circles[i * 3 + 1] = (contour.centerY - y) / pixelSize;
        circles[i * 3 + 2] = contour.radius / pixelSize;
      }
    }
    order.addAll(edges);
    final n = order.length;
    final sx = Float32List(n), sy = Float32List(n);
    final dx = Float32List(n), dy = Float32List(n), delay = Float32List(n);
    for (var i = 0; i < n; i++) {
      final p = pixels[order[i]];
      sx[i] = p.startX;
      sy[i] = p.startY;
      dx[i] = p.x;
      dy[i] = p.y;
      delay[i] = p.delayMs.toDouble();
    }
    return ContourRainData._(
      sx,
      sy,
      dx,
      dy,
      delay,
      Int32List.fromList(ends),
      Int32List.fromList(colors),
      Int32List.fromList(edgeColors),
      circles,
    );
  }
}

const _lutSize = 1024;

Float32List _lookup(double Function(double) transform) => Float32List.fromList(
  List.generate(_lutSize + 1, (i) => transform(i / _lutSize)),
);

final _easeOut = _lookup(Curves.easeOut.transform);
final _sine = _lookup(Curves.easeInOutSine.transform);
final _wave = _lookup((t) => sin(t * pi * 4) * sin(t * pi));

double _sample(Float32List lut, double t) {
  final k = t.toInt();
  if (k >= _lutSize) return lut[_lutSize];
  return lut[k] + (lut[k + 1] - lut[k]) * (t - k);
}

/// Batched solid squares for the interior, and one small masked atlas draw for
/// the contour. The mask travels with its particle rather than clipping the
/// whole animation to a stationary circle.
class AvatarContourRenderer {
  final ContourRainData data;
  final double pixelSize;
  final Float32List _positions;
  final List<Float32List> _groups = [];
  final List<Paint> _paints = [];
  final List<Paint> _edgePaints = [];
  final Float32List _edgeTransforms, _edgeRects;
  final Paint _edgePaint =
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;
  ui.Image? _atlas;

  AvatarContourRenderer(this.data, this.pixelSize)
    : _positions = Float32List(data.count * 2),
      _edgeTransforms = Float32List(data.edgeCount * 4),
      _edgeRects = Float32List(data.edgeCount * 4) {
    var start = 0;
    for (var i = 0; i < data.groupEnds.length; i++) {
      final end = data.groupEnds[i];
      _groups.add(Float32List.sublistView(_positions, start * 2, end * 2));
      _paints.add(
        Paint()
          ..color = Color(data.groupColors[i])
          ..strokeWidth = pixelSize
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false,
      );
      start = end;
    }
    if (data.edgeCount > 0) {
      if (pixelSize == pixelSize.roundToDouble()) {
        _createAtlas();
      } else {
        for (final color in data.edgeColors) {
          _edgePaints.add(Paint()..color = Color(color));
        }
      }
    }
  }

  void _createAtlas() {
    // Bake coverage at approximately the displayed size. Nearest sampling
    // avoids transparent seams on the three straight sides of a boundary cell.
    final extent = pixelSize.ceil();
    final stride = extent + 2;
    final columns = min(32, data.edgeCount);
    final rows = (data.edgeCount / columns).ceil();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = Paint()..color = const Color(0xFFFFFFFF);
    for (var i = 0; i < data.edgeCount; i++) {
      final x = (i % columns) * stride + 1.0;
      final y = (i ~/ columns) * stride + 1.0;
      final rect = Rect.fromLTWH(x, y, extent.toDouble(), extent.toDouble());
      canvas.save();
      canvas.clipRect(rect, doAntiAlias: false);
      canvas.drawCircle(
        Offset(
          x + data.edgeCircles[i * 3] * extent,
          y + data.edgeCircles[i * 3 + 1] * extent,
        ),
        data.edgeCircles[i * 3 + 2] * extent,
        paint,
      );
      canvas.restore();
      _edgeRects.setRange(i * 4, i * 4 + 4, [
        rect.left,
        rect.top,
        rect.right,
        rect.bottom,
      ]);
      _edgeTransforms[i * 4] = pixelSize / extent;
    }
    final picture = recorder.endRecording();
    _atlas = picture.toImageSync(columns * stride, rows * stride);
    picture.dispose();
  }

  void paint(
    Canvas canvas,
    double timeMs,
    int fallDurationMs, {
    required bool waves,
  }) {
    final ease = waves ? _sine : _easeOut;
    final half = pixelSize / 2;
    for (var i = 0; i < data.count; i++) {
      final t =
          fallDurationMs <= 0
              ? (timeMs >= data.delayMs[i] ? _lutSize.toDouble() : 0.0)
              : ((timeMs - data.delayMs[i]) * _lutSize / fallDurationMs).clamp(
                0.0,
                _lutSize.toDouble(),
              );
      final e = _sample(ease, t);
      _positions[i * 2] =
          data.startX[i] + (data.endX[i] - data.startX[i]) * e + half;
      _positions[i * 2 + 1] =
          data.startY[i] +
          (data.endY[i] - data.startY[i]) * (waves ? _sample(_wave, t) : e) +
          half;
    }
    for (var i = 0; i < _groups.length; i++) {
      canvas.drawRawPoints(ui.PointMode.points, _groups[i], _paints[i]);
    }
    // Fractional atlas quads and solid points have different half-pixel edge
    // coverage in software Skia. Clip vector circles only for the small boundary
    // subset so adjacent cells share the same device-pixel boundary.
    for (var i = 0; i < _edgePaints.length; i++) {
      final point = (data.interiorCount + i) * 2;
      final x = _positions[point] - half;
      final y = _positions[point + 1] - half;
      canvas.save();
      canvas.clipRect(
        Rect.fromLTWH(x, y, pixelSize, pixelSize),
        doAntiAlias: false,
      );
      canvas.drawCircle(
        Offset(
          x + data.edgeCircles[i * 3] * pixelSize,
          y + data.edgeCircles[i * 3 + 1] * pixelSize,
        ),
        data.edgeCircles[i * 3 + 2] * pixelSize,
        _edgePaints[i],
      );
      canvas.restore();
    }
    final atlas = _atlas;
    if (atlas != null) {
      for (var i = 0; i < data.edgeCount; i++) {
        final point = (data.interiorCount + i) * 2;
        _edgeTransforms[i * 4 + 2] = _positions[point] - half;
        _edgeTransforms[i * 4 + 3] = _positions[point + 1] - half;
      }
      canvas.drawRawAtlas(
        atlas,
        _edgeTransforms,
        _edgeRects,
        data.edgeColors,
        BlendMode.modulate,
        null,
        _edgePaint,
      );
    }
  }

  void dispose() => _atlas?.dispose();
}
