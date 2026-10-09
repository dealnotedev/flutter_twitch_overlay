// Raster-thread cost of drawing the avatar pixel rain with Skia's CPU backend.
//
// flutter test benchmark/avatar_rain/raster_bench_test.dart
//
// flutter_tester has no GPU, so Picture.toImage rasterizes with the same
// software Skia path that the OBS plugin uses (FlutterSoftwareRendererConfig).
import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

const canvasW = 1920;
const canvasH = 1080;
const verticalOffset = -120.0;

class Scene {
  final int res;
  final double pixelSize;
  final Float32List x, y; // top-left of each particle
  final Int32List argb;
  final Int32List cellU, cellV;

  Scene(this.res, this.pixelSize, int n)
    : x = Float32List(n),
      y = Float32List(n),
      argb = Int32List(n),
      cellU = Int32List(n),
      cellV = Int32List(n);

  int get count => x.length;
}

int avatarColor(int u, int v, int res, Random rnd) {
  final r = (u * 255 ~/ res) ^ rnd.nextInt(24);
  final g = (v * 255 ~/ res) ^ rnd.nextInt(24);
  final b = ((u + v) * 127 ~/ res) ^ rnd.nextInt(24);
  return 0xFF000000 | (r << 16) | (g << 8) | b;
}

/// [progress] null means every particle is at a random point of its flight,
/// which is the peak load of the entering animation.
Scene buildScene(int res, double pixelSize, {double? progress}) {
  final rnd = Random(42);
  final cells = <(int, int)>[];
  final c = res / 2 - 0.5;
  final radius = res / 2 - 0.5;
  for (var v = 0; v < res; v++) {
    for (var u = 0; u < res; u++) {
      if ((u - c) * (u - c) + (v - c) * (v - c) <= radius * radius) {
        cells.add((u, v));
      }
    }
  }
  final scene = Scene(res, pixelSize, cells.length);
  final size = res * pixelSize;
  final originX = canvasW / 2 - size / 2;
  final originY = canvasH / 2 - size / 2 + verticalOffset;

  // Outside perimeter columns, as in _generateEnoughPerimeterPoints2.
  final verticalCount = canvasH ~/ pixelSize;
  final top = (canvasH - verticalCount * pixelSize) / 2;
  final order = List.generate(cells.length, (i) => i)..shuffle(rnd);
  for (var k = 0; k < cells.length; k++) {
    final i = order[k];
    final (u, v) = cells[i];
    final column = k ~/ verticalCount;
    final row = k % verticalCount;
    final ring = column ~/ 2;
    final startX =
        column.isEven
            ? canvasW + ring * pixelSize
            : -pixelSize - ring * pixelSize;
    final startY = top + row * pixelSize;
    final targetX = originX + u * pixelSize;
    final targetY = originY + v * pixelSize;
    final t = progress ?? rnd.nextDouble();
    final e = 1 - (1 - t) * (1 - t) * (1 - t);
    scene.x[i] = startX + (targetX - startX) * e;
    scene.y[i] = startY + (targetY - startY) * e;
    scene.argb[i] = avatarColor(u, v, res, rnd);
    scene.cellU[i] = u;
    scene.cellV[i] = v;
  }
  return scene;
}

Future<ui.Image> imageFromPixels(Uint8List rgba, int w, int h) {
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    rgba,
    w,
    h,
    ui.PixelFormat.rgba8888,
    completer.complete,
  );
  return completer.future;
}

Future<ui.Image> whiteAtlas({required double radius}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  final paint =
      Paint()
        ..color = const Color(0xFFFFFFFF)
        ..isAntiAlias = radius > 0;
  const rect = Rect.fromLTWH(0, 0, 64, 64);
  if (radius > 0) {
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(radius)),
      paint,
    );
  } else {
    canvas.drawRect(rect, paint);
  }
  return recorder.endRecording().toImage(64, 64);
}

Future<ui.Image> avatarAtlas(Scene s) {
  final rgba = Uint8List(s.res * s.res * 4);
  for (var i = 0; i < s.count; i++) {
    final o = (s.cellV[i] * s.res + s.cellU[i]) * 4;
    final c = s.argb[i];
    rgba[o] = (c >> 16) & 0xFF;
    rgba[o + 1] = (c >> 8) & 0xFF;
    rgba[o + 2] = c & 0xFF;
    rgba[o + 3] = (c >> 24) & 0xFF;
  }
  return imageFromPixels(rgba, s.res, s.res);
}

typedef Painter = void Function(Canvas canvas);

ui.Picture record(Painter painter) {
  final recorder = ui.PictureRecorder();
  painter(Canvas(recorder));
  return recorder.endRecording();
}

Future<double> rasterMs(Painter painter, {int warmup = 2, int runs = 7}) async {
  final samples = <int>[];
  final picture = record(painter);
  for (var i = 0; i < warmup + runs; i++) {
    final sw = Stopwatch()..start();
    final image = await picture.toImage(canvasW, canvasH);
    sw.stop();
    image.dispose();
    if (i >= warmup) samples.add(sw.elapsedMicroseconds);
  }
  picture.dispose();
  samples.sort();
  return samples[samples.length ~/ 2] / 1000.0;
}

Painter atlasPainter(
  Scene s,
  ui.Image atlas, {
  required FilterQuality quality,
  double padding = 0,
}) {
  final transforms = Float32List(s.count * 4);
  final rects = Float32List(s.count * 4);
  final scale = (s.pixelSize - padding * 2) / 64;
  for (var i = 0; i < s.count; i++) {
    transforms[i * 4] = scale;
    transforms[i * 4 + 2] = s.x[i] + padding;
    transforms[i * 4 + 3] = s.y[i] + padding;
    rects[i * 4 + 2] = 64;
    rects[i * 4 + 3] = 64;
  }
  final paint =
      Paint()
        ..isAntiAlias = false
        ..filterQuality = quality;
  return (canvas) => canvas.drawRawAtlas(
    atlas,
    transforms,
    rects,
    s.argb,
    BlendMode.modulate,
    null,
    paint,
  );
}

Painter avatarTexelAtlasPainter(Scene s, ui.Image avatar) {
  final transforms = Float32List(s.count * 4);
  final rects = Float32List(s.count * 4);
  for (var i = 0; i < s.count; i++) {
    transforms[i * 4] = s.pixelSize;
    transforms[i * 4 + 2] = s.x[i];
    transforms[i * 4 + 3] = s.y[i];
    rects[i * 4] = s.cellU[i].toDouble();
    rects[i * 4 + 1] = s.cellV[i].toDouble();
    rects[i * 4 + 2] = s.cellU[i] + 1.0;
    rects[i * 4 + 3] = s.cellV[i] + 1.0;
  }
  final paint =
      Paint()
        ..isAntiAlias = false
        ..filterQuality = FilterQuality.none;
  return (canvas) =>
      canvas.drawRawAtlas(avatar, transforms, rects, null, null, null, paint);
}

/// One drawRawPoints call per quantized color, square caps.
(Painter, int) pointsByColorPainter(Scene s, {required int bits}) {
  final shift = 8 - bits;
  final groups = <int, List<int>>{};
  for (var i = 0; i < s.count; i++) {
    final c = s.argb[i];
    final key =
        (((c >> 16) & 0xFF) >> shift) << (bits * 2) |
        (((c >> 8) & 0xFF) >> shift) << bits |
        ((c & 0xFF) >> shift);
    (groups[key] ??= []).add(i);
  }
  final batches = <(Paint, Float32List)>[];
  final half = s.pixelSize / 2;
  groups.forEach((key, indexes) {
    final points = Float32List(indexes.length * 2);
    for (var k = 0; k < indexes.length; k++) {
      points[k * 2] = s.x[indexes[k]] + half;
      points[k * 2 + 1] = s.y[indexes[k]] + half;
    }
    final paint =
        Paint()
          ..color = Color(s.argb[indexes.first])
          ..strokeWidth = s.pixelSize
          ..strokeCap = StrokeCap.square
          ..isAntiAlias = false;
    batches.add((paint, points));
  });
  return (
    (canvas) {
      for (final (paint, points) in batches) {
        canvas.drawRawPoints(ui.PointMode.points, points, paint);
      }
    },
    groups.length,
  );
}

Painter rectsPainter(Scene s) {
  final paint = Paint()..isAntiAlias = false;
  return (canvas) {
    for (var i = 0; i < s.count; i++) {
      paint.color = Color(s.argb[i]);
      canvas.drawRect(
        Rect.fromLTWH(s.x[i], s.y[i], s.pixelSize, s.pixelSize),
        paint,
      );
    }
  };
}

Future<(Painter, ui.Image)> cellBufferPainter(Scene s) async {
  final w = (canvasW / s.pixelSize).ceil();
  final h = (canvasH / s.pixelSize).ceil();
  final rgba = Uint8List(w * h * 4);
  for (var i = 0; i < s.count; i++) {
    final cx = (s.x[i] / s.pixelSize).round();
    final cy = (s.y[i] / s.pixelSize).round();
    if (cx < 0 || cy < 0 || cx >= w || cy >= h) continue;
    final o = (cy * w + cx) * 4;
    final c = s.argb[i];
    rgba[o] = (c >> 16) & 0xFF;
    rgba[o + 1] = (c >> 8) & 0xFF;
    rgba[o + 2] = c & 0xFF;
    rgba[o + 3] = 0xFF;
  }
  final image = await imageFromPixels(rgba, w, h);
  final paint = Paint()..filterQuality = FilterQuality.none;
  final src = Rect.fromLTWH(0, 0, w.toDouble(), h.toDouble());
  final dst = Rect.fromLTWH(0, 0, w * s.pixelSize, h * s.pixelSize);
  return (
    (Canvas canvas) => canvas.drawImageRect(image, src, dst, paint),
    image,
  );
}

Future<(Painter, ui.Image)> fullFramePainter(Scene s) async {
  final rgba = Uint8List(canvasW * canvasH * 4);
  final ps = s.pixelSize.round();
  for (var i = 0; i < s.count; i++) {
    final left = s.x[i].round(), top = s.y[i].round();
    final c = s.argb[i];
    for (var y = max(0, top); y < min(canvasH, top + ps); y++) {
      for (var x = max(0, left); x < min(canvasW, left + ps); x++) {
        final o = (y * canvasW + x) * 4;
        rgba[o] = (c >> 16) & 0xFF;
        rgba[o + 1] = (c >> 8) & 0xFF;
        rgba[o + 2] = c & 0xFF;
        rgba[o + 3] = 0xFF;
      }
    }
  }
  final image = await imageFromPixels(rgba, canvasW, canvasH);
  final paint = Paint()..filterQuality = FilterQuality.none;
  return (
    (Canvas canvas) => canvas.drawImage(image, Offset.zero, paint),
    image,
  );
}

Future<double> decodeMs(int w, int h) async {
  final rgba = Uint8List(w * h * 4);
  final samples = <int>[];
  for (var i = 0; i < 9; i++) {
    final sw = Stopwatch()..start();
    final image = await imageFromPixels(rgba, w, h);
    sw.stop();
    image.dispose();
    if (i >= 2) samples.add(sw.elapsedMicroseconds);
  }
  samples.sort();
  return samples[samples.length ~/ 2] / 1000.0;
}

String ms(double v) => v.toStringAsFixed(2).padLeft(8);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('avatar rain raster cost', () async {
    final out = StringBuffer();
    final empty = await rasterMs((_) {});
    out.writeln('canvas ${canvasW}x$canvasH, empty frame: ${ms(empty)} ms');
    out.writeln('(numbers below already have the empty frame subtracted)');

    final rrectAtlas = await whiteAtlas(radius: 8);
    final squareAtlas = await whiteAtlas(radius: 0);

    const configs = [(48, 8.0), (128, 8.0), (256, 3.0), (256, 4.0), (256, 8.0)];
    for (final (res, pixelSize) in configs) {
      for (final landed in [false, true]) {
        final s = buildScene(res, pixelSize, progress: landed ? 1.0 : null);
        out.writeln(
          '\nres $res, pixelSize $pixelSize, ${s.count} particles, '
          '${landed ? 'landed' : 'in flight'}',
        );
        Future<void> row(String name, Painter p) async {
          final v = await rasterMs(p) - empty;
          out.writeln('  ${name.padRight(46)}${ms(v)} ms');
        }

        await row(
          'current: atlas rrect, low, modulate',
          atlasPainter(s, rrectAtlas, quality: FilterQuality.low),
        );
        await row(
          'atlas square, none, modulate',
          atlasPainter(s, squareAtlas, quality: FilterQuality.none),
        );
        final avatar = await avatarAtlas(s);
        await row(
          'atlas = avatar texels, none, no colors',
          avatarTexelAtlasPainter(s, avatar),
        );
        final (points4, groups4) = pointsByColorPainter(s, bits: 4);
        await row('drawRawPoints per color, 4-4-4 ($groups4 calls)', points4);
        final (points3, groups3) = pointsByColorPainter(s, bits: 3);
        await row('drawRawPoints per color, 3-3-3 ($groups3 calls)', points3);
        if (s.count < 20000) {
          await row('legacy: drawRect per pixel', rectsPainter(s));
        }
        final (cell, cellImage) = await cellBufferPainter(s);
        await row('cell buffer, one drawImageRect upscale', cell);
        final (full, fullImage) = await fullFramePainter(s);
        await row('full-res buffer, one drawImage', full);
        avatar.dispose();
        cellImage.dispose();
        fullImage.dispose();
      }
    }

    out.writeln('\ndecodeImageFromPixels (Dart -> ui.Image) cost:');
    for (final (w, h) in [
      (48, 48),
      (256, 256),
      (480, 270),
      (640, 360),
      (1920, 1080),
    ]) {
      out.writeln('  ${'${w}x$h'.padRight(12)}${ms(await decodeMs(w, h))} ms');
    }

    // ignore: avoid_print
    print(out);
  }, timeout: const Timeout(Duration(minutes: 20)));
}
