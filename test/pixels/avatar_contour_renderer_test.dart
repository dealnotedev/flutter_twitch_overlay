import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/avatar_contour_renderer.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    '256 groups all square particles, including the perimeter, by color',
    () {
      final data = _prepare(256, 3, 800);
      expect(data.count, 51040);
      expect(data.groupEnds.length, 1);
      expect(data.groupEnds.last, data.count);
      expect(data.edgeCount, 0);
      final rounded = _prepare(256, 3, 800, smoothContour: true);
      expect(rounded.count, 51612);
      expect(rounded.edgeCount, 1020);
    },
  );

  for (final smoothContour in [false, true]) {
    for (final pixelSize in [2.0, 2.5, 3.0, 3.5, 8.0, 16.0]) {
      for (final alpha in [255, 128]) {
        test(
          'particles have no interior seams at $pixelSize px, alpha $alpha, smoothing $smoothContour',
          () async {
            const resolution = 16;
            final size = (resolution * pixelSize + 24).ceil();
            final data = _prepare(
              resolution,
              pixelSize,
              size,
              alpha: alpha,
              smoothContour: smoothContour,
            );
            final renderer = AvatarContourRenderer(data, pixelSize);
            addTearDown(renderer.dispose);
            final bytes = await _render(renderer, size, 5000);
            final center = size / 2;
            final radius = (resolution / 2 - 0.5) * pixelSize;
            final cellMargin = smoothContour ? 1.5 : pixelSize / sqrt(2) + 0.5;
            var partialPixels = 0;
            for (var y = 0; y < size; y++) {
              for (var x = 0; x < size; x++) {
                final dx = x + 0.5 - center, dy = y + 0.5 - center;
                final distance = sqrt(dx * dx + dy * dy);
                final actual = bytes[(y * size + x) * 4 + 3];
                if (distance < radius - cellMargin) {
                  expect(
                    actual,
                    closeTo(alpha, 1),
                    reason: 'hole or overlap at ($x, $y)',
                  );
                } else if (distance > radius + cellMargin) {
                  expect(actual, 0, reason: 'outside circle at ($x, $y)');
                }
                if (actual > 0 && actual < alpha - 1) partialPixels++;
              }
            }
            expect(partialPixels, smoothContour ? greaterThan(0) : 0);
          },
        );
      }
    }

    test(
      'departure carries particles off screen with smoothing $smoothContour',
      () async {
        const size = 128;
        final entering = AvatarContourRenderer(
          _prepare(16, 3.5, size, smoothContour: smoothContour),
          3.5,
        );
        final leaving = AvatarContourRenderer(
          _prepare(16, 3.5, size, leaving: true, smoothContour: smoothContour),
          3.5,
        );
        addTearDown(entering.dispose);
        addTearDown(leaving.dispose);
        expect(
          await _render(leaving, size, 0, waves: true),
          await _render(entering, size, 5000),
        );
        final departed = await _render(leaving, size, 2000, waves: true);
        expect([
          for (var i = 3; i < departed.length; i += 4) departed[i],
        ], everyElement(0));
      },
    );

    test(
      'odd resolution and fractional placement leave no interior gaps with smoothing $smoothContour',
      () async {
        for (final (resolution, pixelSize, size) in [
          (17, 3.0, 128),
          (16, 3.0, 127),
          (17, 3.5, 128),
        ]) {
          final renderer = AvatarContourRenderer(
            _prepare(resolution, pixelSize, size, smoothContour: smoothContour),
            pixelSize,
          );
          addTearDown(renderer.dispose);
          final bytes = await _render(renderer, size, 5000);
          final radius =
              (resolution / 2 - 0.5) * pixelSize -
              (smoothContour ? 1.5 : pixelSize / sqrt(2) + 0.5);
          for (var y = 0; y < size; y++) {
            for (var x = 0; x < size; x++) {
              final dx = x + 0.5 - size / 2, dy = y + 0.5 - size / 2;
              if (dx * dx + dy * dy < radius * radius) {
                expect(
                  bytes[(y * size + x) * 4 + 3],
                  255,
                  reason: '$resolution × $pixelSize, canvas $size at ($x, $y)',
                );
              }
            }
          }
        }
      },
    );
  }

  test('empty particle data renders transparently', () async {
    final data = ContourRainData.prepare([], pixelSize: 3);
    final renderer = AvatarContourRenderer(data, 3);
    expect(await _render(renderer, 32, 0), everyElement(0));
  });
}

ContourRainData _prepare(
  int resolution,
  double pixelSize,
  int size, {
  int alpha = 255,
  bool leaving = false,
  bool smoothContour = false,
}) {
  final image = img.Image(
    width: resolution,
    height: resolution,
    numChannels: 4,
  );
  img.fill(image, color: img.ColorRgba8(255, 255, 255, alpha));
  final constraints = BoxConstraints.tightFor(
    width: size.toDouble(),
    height: size.toDouble(),
  );
  final direction =
      leaving ? RainyPixelDirection.leaving : RainyPixelDirection.entering;
  final pixels = RainyAvatar.preparePixels(
    image: image,
    constraints: constraints,
    duration: Duration(seconds: leaving ? 2 : 5),
    fallDuration: Duration(milliseconds: leaving ? 1200 : 3000),
    pixelSize: pixelSize,
    resolution: resolution,
    verticalOffset: 0,
    origin: RainyPixelOrigin.outside,
    direction: direction,
    motion:
        leaving ? AvatarPixelMotion.horizontalWaves : AvatarPixelMotion.linear,
    renderer: AvatarPixelRenderer.contourPoints,
    smoothContour: smoothContour,
    random: Random(42),
  );
  return ContourRainData.prepare(
    pixels,
    pixelSize: pixelSize,
    smoothContour: smoothContour,
    contour: RainyAvatar.contourFor(
      constraints: constraints,
      resolution: resolution,
      pixelSize: pixelSize,
      verticalOffset: 0,
      direction: direction,
    ),
  );
}

Future<Uint8List> _render(
  AvatarContourRenderer renderer,
  int size,
  double timeMs, {
  bool waves = false,
}) async {
  final recorder = ui.PictureRecorder();
  renderer.paint(Canvas(recorder), timeMs, waves ? 1200 : 3000, waves: waves);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size, size);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (Platform.environment['CONTOUR_CAPTURE'] == '1') {
    final png = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File(
      'build/test-screenshots/contour-${renderer.pixelSize}-$timeMs-$waves.png',
    );
    file.parent.createSync(recursive: true);
    file.writeAsBytesSync(png!.buffer.asUint8List());
  }
  picture.dispose();
  image.dispose();
  return rgba!.buffer.asUint8List();
}
