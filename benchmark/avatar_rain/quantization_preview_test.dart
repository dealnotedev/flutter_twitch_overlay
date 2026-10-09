// Side-by-side preview of the landed avatar with exact colors and with the
// color grouping used by the drawRawPoints prototype.
//
// flutter test benchmark/avatar_rain/quantization_preview_test.dart
// AVATAR=path/to/avatar.png flutter test benchmark/avatar_rain/quantization_preview_test.dart
//
// Writes build/avatar_bench/quantization_preview.png.
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;

const resolution = 256;
const pixelSize = 3.0;
const gap = 24.0;

/// Smooth gradients make banding from color quantization easy to see.
img.Image smoothAvatar() {
  final image = img.Image(width: 300, height: 300);
  for (var y = 0; y < 300; y++) {
    for (var x = 0; x < 300; x++) {
      final u = x / 299, v = y / 299;
      // Sky-like background.
      var r = 40 + 80 * v, g = 90 + 100 * v, b = 200 - 60 * v;
      // Shaded sphere as a stand-in for a face.
      final dx = u - 0.5, dy = v - 0.55;
      final d2 = dx * dx / 0.09 + dy * dy / 0.12;
      if (d2 < 1) {
        final light = max(
          0.0,
          1 - sqrt(pow(u - 0.4, 2) + pow(v - 0.4, 2)) * 1.6,
        );
        r = 150 + 100 * light;
        g = 105 + 90 * light;
        b = 85 + 70 * light;
      }
      image.setPixelRgba(x, y, r.round(), g.round(), b.round(), 255);
    }
  }
  return image;
}

List<(double, double, int)> landedCells(img.Image source) {
  final resized = img.copyResize(source, width: resolution, height: resolution);
  final c = resolution / 2 - 0.5;
  final radius = resolution / 2 - 0.5;
  final cells = <(double, double, int)>[];
  for (var y = 0; y < resolution; y++) {
    for (var x = 0; x < resolution; x++) {
      if ((x - c) * (x - c) + (y - c) * (y - c) > radius * radius) continue;
      final p = resized.getPixel(x, y);
      final argb =
          (p.a.toInt() << 24) |
          (p.r.toInt() << 16) |
          (p.g.toInt() << 8) |
          p.b.toInt();
      cells.add((x * pixelSize, y * pixelSize, argb));
    }
  }
  return cells;
}

const _bayer4 = [0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5];

/// Groups cells by quantized color and paints each group with its average
/// color, exactly like PointsRenderer in pipeline_bench_main.dart.
int paintGroups(
  Canvas canvas,
  List<(double, double, int)> cells,
  int bits,
  Offset origin, {
  required bool dither,
}) {
  final shift = 8 - bits;
  final step = 1 << shift;
  final groups = <int, List<int>>{};
  for (var i = 0; i < cells.length; i++) {
    final (x, y, c) = cells[i];
    final u = (x / pixelSize).round(), v = (y / pixelSize).round();
    final offset =
        dither ? ((_bayer4[(v & 3) * 4 + (u & 3)] + 0.5) / 16 - 0.5) * step : 0;
    int q(int channel) => (channel + offset).round().clamp(0, 255) >> shift;
    final key =
        ((c >>> 24) >> shift) << (bits * 3) |
        q((c >> 16) & 0xFF) << (bits * 2) |
        q((c >> 8) & 0xFF) << bits |
        q(c & 0xFF);
    (groups[key] ??= []).add(i);
  }
  final half = pixelSize / 2;
  for (final indexes in groups.values) {
    var a = 0, r = 0, g = 0, b = 0;
    final points = Float32List(indexes.length * 2);
    for (var k = 0; k < indexes.length; k++) {
      final (x, y, c) = cells[indexes[k]];
      a += c >>> 24;
      r += (c >> 16) & 0xFF;
      g += (c >> 8) & 0xFF;
      b += c & 0xFF;
      points[k * 2] = origin.dx + x + half;
      points[k * 2 + 1] = origin.dy + y + half;
    }
    final m = indexes.length;
    canvas.drawRawPoints(
      ui.PointMode.points,
      points,
      Paint()
        ..color = Color.fromARGB(a ~/ m, r ~/ m, g ~/ m, b ~/ m)
        ..strokeWidth = pixelSize
        ..strokeCap = StrokeCap.square
        ..isAntiAlias = false,
    );
  }
  return groups.length;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('quantization preview', () async {
    final path = Platform.environment['AVATAR'];
    final source =
        path != null
            ? img.decodeImage(File(path).readAsBytesSync())!
            : smoothAvatar();
    final cells = landedCells(source);

    const panel = resolution * pixelSize;
    const variants = [
      ('exact', 8, false),
      ('5-bit', 5, false),
      ('5-bit dithered', 5, true),
      ('4-bit', 4, false),
      ('4-bit dithered', 4, true),
    ];
    final width = panel * variants.length + gap * (variants.length + 1);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, width, panel + gap * 2),
      Paint()..color = const Color(0xFF101012),
    );
    final report = <String>[];
    for (final (index, (label, bits, dither)) in variants.indexed) {
      final groups = paintGroups(
        canvas,
        cells,
        bits,
        Offset(gap + index * (panel + gap), gap),
        dither: dither,
      );
      report.add('$label: $groups groups');
    }
    final image = await recorder.endRecording().toImage(
      width.toInt(),
      (panel + gap * 2).toInt(),
    );
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final out = File('build/avatar_bench/quantization_preview.png');
    out.parent.createSync(recursive: true);
    out.writeAsBytesSync(png!.buffer.asUint8List());
    // ignore: avoid_print
    print('${report.join(', ')} -> ${out.path}');
  });
}
