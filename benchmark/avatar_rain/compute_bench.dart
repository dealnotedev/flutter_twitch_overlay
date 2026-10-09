// AOT benchmark of the Dart-side work behind the avatar pixel rain.
//
// dart compile exe benchmark/avatar_rain/compute_bench.dart -o build/avatar_bench/compute_bench.exe
// build/avatar_bench/compute_bench.exe
//
// Replicates the current implementation without dart:ui so it can run as AOT
// code, which is how the OBS plugin executes app.so.
// ignore_for_file: avoid_print

import 'dart:math';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

const canvasW = 1920.0;
const canvasH = 1080.0;
const verticalOffset = -120.0;

// Copy of Flutter's Cubic so the cost of Curves.easeOut is reproduced exactly.
class Cubic {
  final double a, b, c, d;

  const Cubic(this.a, this.b, this.c, this.d);

  static const double _cubicErrorBound = 0.001;

  double _evaluateCubic(double a, double b, double m) {
    return 3 * a * (1 - m) * (1 - m) * m + 3 * b * (1 - m) * m * m + m * m * m;
  }

  double transform(double t) {
    assert(t >= 0.0 && t <= 1.0);
    if (t == 0.0 || t == 1.0) {
      return t;
    }
    return transformInternal(t);
  }

  double transformInternal(double t) {
    if (t.isNaN) {
      throw ArgumentError.value(t, 't', 'must not be NaN');
    }
    if (t <= 0.0) {
      return 0.0;
    }
    if (t >= 1.0) {
      return 1.0;
    }
    var start = 0.0;
    var end = 1.0;
    while (true) {
      final double midpoint = (start + end) / 2;
      final double estimate = _evaluateCubic(a, c, midpoint);
      if ((t - estimate).abs() < _cubicErrorBound) {
        return _evaluateCubic(b, d, midpoint);
      }
      if (estimate < t) {
        start = midpoint;
      } else {
        end = midpoint;
      }
    }
  }
}

const easeOut = Cubic(0.0, 0.0, 0.58, 1.0);
const easeInOutSine = Cubic(0.445, 0.05, 0.55, 0.95);

// Mimics dart:ui Color, which is an object per pixel in the current code.
class Col {
  final int argb;

  const Col(this.argb);
}

class Px {
  final double x, y, startX, startY;
  final Col color;
  final int delayMs;

  Px({
    required this.x,
    required this.y,
    required this.startX,
    required this.startY,
    required this.color,
    required this.delayMs,
  });
}

img.Image syntheticAvatar() {
  // Twitch profile images are 300x300.
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
// Current preparation (RainyAvatar.preparePixels), entering + outside origin.
// ---------------------------------------------------------------------------

List<List<Col?>> currentMatrix(img.Image image, int res) {
  final resized = img.copyResize(image, width: res, height: res);
  return List.generate(
    res,
    (y) => List.generate(res, (x) {
      final p = resized.getPixel(x, y);
      return Col(
        (p.a.toInt() << 24) |
            (p.r.toInt() << 16) |
            (p.g.toInt() << 8) |
            p.b.toInt(),
      );
    }),
  );
}

List<Px> currentMakePixels(
  List<List<Col?>> matrix,
  double pixelSize,
  int durationMs,
  int fallDurationMs,
  Random random, {
  required bool leaving,
}) {
  final pixels = <Px>[];
  final h = matrix.length;
  final w = matrix[0].length;
  final cx = w / 2 - 0.5;
  final cy = h / 2 - 0.5;
  final radius = (w < h ? w : h) / 2 - 0.5;
  final width = w * pixelSize;
  final height = h * pixelSize;
  final startX = canvasW / 2.0 - width / 2.0;
  final startY = canvasH / 2.0 - height / 2.0 + verticalOffset;

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final color = matrix[y][x];
      if (color != null) {
        final dx = x - cx;
        final dy = y - cy;
        if (dx * dx + dy * dy <= radius * radius) {
          pixels.add(
            Px(
              x: startX + x * pixelSize,
              y: startY + y * pixelSize,
              startX: 0,
              startY: 0,
              color: color,
              delayMs: 0,
            ),
          );
        }
      }
    }
  }

  final starts = <Point<double>>[];
  if (leaving) {
    // _generateHorizontalWaveOffscreenPoints
    final indexes = List.generate(pixels.length, (i) => i)
      ..sort((a, b) => pixels[a].x.compareTo(pixels[b].x));
    final goesLeft = List.filled(pixels.length, false);
    for (final i in indexes.take(pixels.length ~/ 2)) {
      goesLeft[i] = true;
    }
    for (var i = 0; i < pixels.length; i++) {
      final over = random.nextDouble() * canvasW * 0.5;
      final amp = (random.nextDouble() * 2.0 - 1.0) * canvasH * 0.08;
      starts.add(
        Point(
          goesLeft[i] ? -pixelSize - over : canvasW + over,
          pixels[i].y + amp,
        ),
      );
    }
  } else {
    // _generateEnoughPerimeterPoints2
    final verticalCount = (canvasH / pixelSize).toInt();
    final top = (canvasH - verticalCount * pixelSize) / 2.0;
    var row = 0;
    while (starts.length < pixels.length) {
      final left = -pixelSize - row * pixelSize;
      final right = canvasW + row * pixelSize;
      for (var y = 0; y < verticalCount; y++) {
        if (starts.length >= pixels.length) break;
        starts.add(Point(right, top + y * pixelSize));
      }
      for (var y = 0; y < verticalCount; y++) {
        if (starts.length >= pixels.length) break;
        starts.add(Point(left, top + y * pixelSize));
      }
      row++;
    }
  }

  for (var i = 0; i < pixels.length; i++) {
    final p = pixels[i];
    final s = starts[i];
    pixels[i] =
        leaving
            ? Px(
              x: s.x,
              y: s.y,
              startX: p.x,
              startY: p.y,
              color: p.color,
              delayMs: 0,
            )
            : Px(
              x: p.x,
              y: p.y,
              startX: s.x,
              startY: s.y,
              color: p.color,
              delayMs: 0,
            );
  }

  pixels.shuffle(random);

  final totalSpan = (durationMs - fallDurationMs).toDouble();
  final step = totalSpan / pixels.length;
  const waveCount = 8;
  final avatarCenterX = canvasW / 2.0;
  final avatarHalfWidth = width / 2.0;
  for (var i = 0; i < pixels.length; i++) {
    final p = pixels[i];
    final int delayMs;
    if (leaving) {
      final dist = (p.startX + pixelSize / 2.0 - avatarCenterX).abs();
      final norm = (dist / avatarHalfWidth).clamp(0.0, 1.0);
      final wave = min(waveCount - 1, (norm * waveCount).floor());
      delayMs = (wave * totalSpan / (waveCount - 1)).round();
    } else {
      delayMs = (i * step).round();
    }
    pixels[i] = Px(
      x: p.x,
      y: p.y,
      startX: p.startX,
      startY: p.startY,
      color: p.color,
      delayMs: delayMs,
    );
  }
  return pixels;
}

// ---------------------------------------------------------------------------
// Current per-frame loop (_AtlasAvatarRainPainter.paint without drawRawAtlas).
// ---------------------------------------------------------------------------

void currentFrame(
  List<Px> pixels,
  Float32List transforms,
  double currentMs,
  int fallDurationMs, {
  required bool waves,
}) {
  final verticalWaveFactors = <int, double>{};
  for (var index = 0; index < pixels.length; index++) {
    final pixel = pixels[index];
    final startMs = pixel.delayMs;
    final endMs = startMs + fallDurationMs;
    final double raw;
    if (currentMs < startMs) {
      raw = 0.0;
    } else if (currentMs >= endMs) {
      raw = 1.0;
    } else {
      raw = (currentMs - startMs) / fallDurationMs;
    }
    final normalized = raw.clamp(0.0, 1.0);
    final progress =
        waves
            ? easeInOutSine.transform(normalized)
            : easeOut.transform(normalized);
    final double x;
    final double y;
    if (!waves) {
      x = pixel.startX + (pixel.x - pixel.startX) * progress;
      y = pixel.startY + (pixel.y - pixel.startY) * progress;
    } else {
      final f = verticalWaveFactors.putIfAbsent(
        pixel.delayMs,
        () => sin(normalized * pi * 4.0) * sin(normalized * pi),
      );
      x = pixel.startX + (pixel.x - pixel.startX) * progress;
      y = pixel.startY + (pixel.y - pixel.startY) * f;
    }
    final o = index * 4;
    transforms[o + 2] = x;
    transforms[o + 3] = y;
  }
}

// ---------------------------------------------------------------------------
// Optimized data layout: structure of arrays + easing lookup table.
// ---------------------------------------------------------------------------

class SoA {
  final int count;
  final Float32List startX, startY, deltaX, deltaY, delayMs;
  final Uint32List rgba; // little-endian RGBA8888 for decodeImageFromPixels
  final Int32List cellX, cellY; // landing cell in avatar grid

  SoA(this.count)
    : startX = Float32List(count),
      startY = Float32List(count),
      deltaX = Float32List(count),
      deltaY = Float32List(count),
      delayMs = Float32List(count),
      rgba = Uint32List(count),
      cellX = Int32List(count),
      cellY = Int32List(count);
}

const lutSize = 1024;

Float32List buildLut(Cubic curve) {
  final lut = Float32List(lutSize + 1);
  for (var i = 0; i <= lutSize; i++) {
    lut[i] = curve.transform(i / lutSize);
  }
  return lut;
}

SoA toSoA(List<Px> pixels) {
  final s = SoA(pixels.length);
  for (var i = 0; i < pixels.length; i++) {
    final p = pixels[i];
    s.startX[i] = p.startX;
    s.startY[i] = p.startY;
    s.deltaX[i] = p.x - p.startX;
    s.deltaY[i] = p.y - p.startY;
    s.delayMs[i] = p.delayMs.toDouble();
    final c = p.color.argb;
    s.rgba[i] =
        (c & 0xFF000000) |
        ((c & 0xFF) << 16) |
        (c & 0xFF00) |
        ((c >> 16) & 0xFF);
  }
  return s;
}

/// Writes positions straight into the RSTransform array (same output as now).
void optimizedFrame(
  SoA s,
  Float32List transforms,
  Float32List lut,
  double currentMs,
  double fallMs,
) {
  final invFall = 1.0 / fallMs;
  final n = s.count;
  final sx = s.startX, sy = s.startY, dx = s.deltaX, dy = s.deltaY;
  final delay = s.delayMs;
  for (var i = 0; i < n; i++) {
    var p = (currentMs - delay[i]) * invFall;
    double e;
    if (p <= 0.0) {
      e = 0.0;
    } else if (p >= 1.0) {
      e = 1.0;
    } else {
      final f = p * lutSize;
      final k = f.toInt();
      e = lut[k] + (lut[k + 1] - lut[k]) * (f - k);
    }
    final o = i * 4;
    transforms[o + 2] = sx[i] + dx[i] * e;
    transforms[o + 3] = sy[i] + dy[i] * e;
  }
}

/// Software-rasterizes the frame into a buffer with one texel per avatar cell.
/// The buffer is drawn upscaled with FilterQuality.none.
void cellBufferFrame(
  SoA s,
  Uint32List buffer,
  int bufferW,
  int bufferH,
  double originX,
  double originY,
  double pixelSize,
  Float32List lut,
  double currentMs,
  double fallMs,
) {
  buffer.fillRange(0, buffer.length, 0);
  final invFall = 1.0 / fallMs;
  final invCell = 1.0 / pixelSize;
  final n = s.count;
  final sx = s.startX, sy = s.startY, dx = s.deltaX, dy = s.deltaY;
  final delay = s.delayMs, rgba = s.rgba;
  for (var i = 0; i < n; i++) {
    var p = (currentMs - delay[i]) * invFall;
    double e;
    if (p <= 0.0) {
      e = 0.0;
    } else if (p >= 1.0) {
      e = 1.0;
    } else {
      final f = p * lutSize;
      final k = f.toInt();
      e = lut[k] + (lut[k + 1] - lut[k]) * (f - k);
    }
    final cx = ((sx[i] + dx[i] * e - originX) * invCell + 0.5).floor();
    final cy = ((sy[i] + dy[i] * e - originY) * invCell + 0.5).floor();
    if (cx >= 0 && cy >= 0 && cx < bufferW && cy < bufferH) {
      buffer[cy * bufferW + cx] = rgba[i];
    }
  }
}

/// Software-rasterizes the frame at screen resolution (pixelSize squares).
void fullBufferFrame(
  SoA s,
  Uint32List buffer,
  int bufferW,
  int bufferH,
  int pixelSize,
  Float32List lut,
  double currentMs,
  double fallMs,
) {
  buffer.fillRange(0, buffer.length, 0);
  final invFall = 1.0 / fallMs;
  final n = s.count;
  final sx = s.startX, sy = s.startY, dx = s.deltaX, dy = s.deltaY;
  final delay = s.delayMs, rgba = s.rgba;
  for (var i = 0; i < n; i++) {
    var p = (currentMs - delay[i]) * invFall;
    double e;
    if (p <= 0.0) {
      e = 0.0;
    } else if (p >= 1.0) {
      e = 1.0;
    } else {
      final f = p * lutSize;
      final k = f.toInt();
      e = lut[k] + (lut[k + 1] - lut[k]) * (f - k);
    }
    final left = (sx[i] + dx[i] * e).round();
    final top = (sy[i] + dy[i] * e).round();
    final x0 = max(0, left), x1 = min(bufferW, left + pixelSize);
    final y0 = max(0, top), y1 = min(bufferH, top + pixelSize);
    if (x0 >= x1 || y0 >= y1) continue;
    final color = rgba[i];
    for (var y = y0; y < y1; y++) {
      buffer.fillRange(y * bufferW + x0, y * bufferW + x1, color);
    }
  }
}

// ---------------------------------------------------------------------------

class Stats {
  final List<int> us = [];

  void add(int v) => us.add(v);

  String format() {
    final s = List.of(us)..sort();
    final mean = s.reduce((a, b) => a + b) / s.length;
    final p95 = s[(s.length * 0.95).floor().clamp(0, s.length - 1)];
    return 'mean ${(mean / 1000).toStringAsFixed(2)} ms, '
        'p95 ${(p95 / 1000).toStringAsFixed(2)} ms, '
        'max ${(s.last / 1000).toStringAsFixed(2)} ms';
  }
}

void runAnimation(
  String label,
  int frames,
  int durationMs,
  void Function(double currentMs) frame,
) {
  // Warm up the code paths before measuring.
  for (var i = 0; i < 30; i++) {
    frame(durationMs * i / 30);
  }
  final stats = Stats();
  final sw = Stopwatch();
  for (var f = 0; f < frames; f++) {
    final currentMs = durationMs * f / (frames - 1);
    sw
      ..reset()
      ..start();
    frame(currentMs);
    sw.stop();
    stats.add(sw.elapsedMicroseconds);
  }
  print('  $label: ${stats.format()}');
}

void main() {
  final avatar = syntheticAvatar();
  const configs = [(48, 8.0), (128, 8.0), (256, 3.0), (256, 8.0)];

  for (final (res, pixelSize) in configs) {
    print('\n=== resolution $res, pixelSize $pixelSize ===');

    // Preparation as done in UserAlertWidget._prepareAvatarPixels (twice).
    final prepStats = Stats();
    late List<Px> entering;
    late List<Px> leaving;
    for (var r = 0; r < 6; r++) {
      final sw = Stopwatch()..start();
      final m1 = currentMatrix(avatar, res);
      entering = currentMakePixels(
        m1,
        pixelSize,
        5000,
        3000,
        Random(r),
        leaving: false,
      );
      final m2 = currentMatrix(avatar, res);
      leaving = currentMakePixels(
        m2,
        pixelSize,
        2000,
        1200,
        Random(r),
        leaving: true,
      );
      sw.stop();
      if (r > 0) prepStats.add(sw.elapsedMicroseconds);
    }
    print(
      '  particles ${entering.length}; current prepare (entering+leaving): '
      '${prepStats.format()}',
    );

    final transforms = Float32List(entering.length * 4);

    runAnimation(
      'current frame loop, entering (5s/3s easeOut)',
      300,
      5000,
      (ms) => currentFrame(entering, transforms, ms, 3000, waves: false),
    );
    runAnimation(
      'current frame loop, leaving waves (2s/1.2s)',
      120,
      2000,
      (ms) => currentFrame(leaving, transforms, ms, 1200, waves: true),
    );

    final soa = toSoA(entering);
    final lut = buildLut(easeOut);
    runAnimation(
      'SoA + LUT -> RSTransform array',
      300,
      5000,
      (ms) => optimizedFrame(soa, transforms, lut, ms, 3000),
    );

    final cellW = (canvasW / pixelSize).ceil() + 1;
    final cellH = (canvasH / pixelSize).ceil() + 1;
    final cellBuffer = Uint32List(cellW * cellH);
    runAnimation(
      'SoA + LUT -> cell buffer ${cellW}x$cellH',
      300,
      5000,
      (ms) => cellBufferFrame(
        soa,
        cellBuffer,
        cellW,
        cellH,
        0,
        0,
        pixelSize,
        lut,
        ms,
        3000,
      ),
    );

    final fullBuffer = Uint32List(canvasW.toInt() * canvasH.toInt());
    runAnimation(
      'SoA + LUT -> full-res buffer 1920x1080',
      300,
      5000,
      (ms) => fullBufferFrame(
        soa,
        fullBuffer,
        canvasW.toInt(),
        canvasH.toInt(),
        pixelSize.round(),
        lut,
        ms,
        3000,
      ),
    );

    final precomputedBytes = 300 * entering.length * 2 * 4;
    print(
      '  precomputed x/y for 300 frames: '
      '${(precomputedBytes / 1024 / 1024).toStringAsFixed(1)} MiB (Float32), '
      'pre-rendered cell frames: '
      '${(300 * cellW * cellH * 4 / 1024 / 1024).toStringAsFixed(1)} MiB',
    );
  }
}
