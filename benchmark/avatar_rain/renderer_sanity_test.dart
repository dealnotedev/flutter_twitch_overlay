// Checks that every prototype renderer draws the landed avatar.
//
// flutter test benchmark/avatar_rain/renderer_sanity_test.dart
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/subs/subs_widget.dart';

import 'pipeline_bench_main.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('prototype renderers draw every landed particle', () async {
    final view = ui.PlatformDispatcher.instance.implicitView!;
    final size = view.physicalSize / view.devicePixelRatio;
    const resolution = 128;
    const pixelSize = 3.0;
    final avatar = img.Image(width: 300, height: 300)
      ..clear(img.ColorRgba8(200, 120, 60, 255));
    final pixels = RainyAvatar.preparePixels(
      image: avatar,
      constraints: BoxConstraints.tight(size),
      duration: const Duration(seconds: 5),
      fallDuration: const Duration(seconds: 3),
      pixelSize: pixelSize,
      resolution: resolution,
      verticalOffset: -SubsWidget.bottomTextBackplatesHeight / 2.0,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.entering,
    );
    final grid = AvatarGrid(
      resolution: resolution,
      pixelSize: pixelSize,
      width: size.width,
      height: size.height,
    );
    final renderers = <String, AvatarRenderer>{
      'texelAtlas': await TexelAtlasRenderer.create(
        pixels,
        grid,
        landed: false,
      ),
      'points4': PointsRenderer.create(pixels, grid, 4, landed: false),
      'vertices': VerticesRenderer.create(pixels, grid, landed: false),
      'cellTexture': CellTextureRenderer.create(pixels, grid, landed: false),
    };
    final expected = pixels.length * pixelSize * pixelSize;
    for (final MapEntry(key: name, value: renderer) in renderers.entries) {
      Future<int> paintedPixels() async {
        final recorder = ui.PictureRecorder();
        renderer.paint(Canvas(recorder), 5000);
        final image = await recorder.endRecording().toImage(
          size.width.toInt(),
          size.height.toInt(),
        );
        final bytes = await image.toByteData();
        var painted = 0;
        for (var i = 3; i < bytes!.lengthInBytes; i += 4) {
          if (bytes.getUint8(i) > 0) painted++;
        }
        return painted;
      }

      var painted = await paintedPixels();
      // cellTexture shows the upload started by the previous frame.
      if (name == 'cellTexture') {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        painted = await paintedPixels();
      }
      // ignore: avoid_print
      print('$name: $painted painted pixels, expected ~${expected.toInt()}');
      expect(painted, closeTo(expected, expected * 0.02), reason: name);
    }
  });
}
