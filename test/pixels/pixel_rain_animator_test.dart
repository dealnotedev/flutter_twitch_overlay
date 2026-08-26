import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel.dart';
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';
import 'package:obssource/pixels/pixel_rain_text.dart';

void main() {
  testWidgets('animation ticks repaint without replacing the painter', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );

    await tester.pumpWidget(
      _TestSurface(animation: animation, pixels: [_pixel(color: Colors.red)]),
    );
    final firstPainter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;

    animation.forward();
    await tester.pump(const Duration(milliseconds: 100));

    final secondPainter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
    expect(secondPainter, same(firstPainter));
    expect(find.byType(AnimatedBuilder), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    animation.dispose();
  });

  testWidgets('legacy renderer keeps the previous per-frame painter', (
    tester,
  ) async {
    final animation = AnimationController(
      vsync: tester,
      duration: const Duration(seconds: 1),
    );

    await tester.pumpWidget(
      _TestSurface(
        animation: animation,
        pixels: [_pixel(color: Colors.red)],
        renderer: AvatarPixelRenderer.legacyCanvas,
      ),
    );
    final firstPainter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;

    animation.forward();
    await tester.pump(const Duration(milliseconds: 100));

    final secondPainter =
        tester.widget<CustomPaint>(find.byType(CustomPaint)).painter;
    expect(secondPainter, isNot(same(firstPainter)));
    expect(find.byType(AnimatedBuilder), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    animation.dispose();
  });

  testWidgets('renderer can switch between legacy and atlas at runtime', (
    tester,
  ) async {
    const animation = AlwaysStoppedAnimation(0.5);
    final pixels = [_pixel(color: Colors.red)];

    await tester.pumpWidget(
      _TestSurface(
        animation: animation,
        pixels: pixels,
        renderer: AvatarPixelRenderer.legacyCanvas,
      ),
    );
    await tester.pumpWidget(_TestSurface(animation: animation, pixels: pixels));
    await tester.pumpWidget(
      _TestSurface(
        animation: animation,
        pixels: pixels,
        renderer: AvatarPixelRenderer.legacyCanvas,
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.byType(AnimatedBuilder), findsOneWidget);
  });

  testWidgets('public pixel widgets expose the renderer selection', (
    tester,
  ) async {
    final image = img.Image(width: 4, height: 4);
    const constraints = BoxConstraints.tightFor(width: 32, height: 32);

    final defaultAvatar = RainyAvatar(
      image: image,
      constraints: constraints,
      duration: const Duration(seconds: 1),
      fallDuration: const Duration(seconds: 1),
      resolution: 4,
      pixelSize: 8,
      randomBackground: false,
      scaleWhenStart: false,
    );
    expect(defaultAvatar.renderer, AvatarPixelRenderer.rawAtlas);

    await tester.pumpWidget(defaultAvatar);
    expect(
      tester.widget<AvatarPixelRain>(find.byType(AvatarPixelRain)).renderer,
      AvatarPixelRenderer.rawAtlas,
    );

    await tester.pumpWidget(
      RainyAvatar(
        image: image,
        constraints: constraints,
        duration: const Duration(seconds: 1),
        fallDuration: const Duration(seconds: 1),
        resolution: 4,
        pixelSize: 8,
        randomBackground: false,
        scaleWhenStart: false,
        renderer: AvatarPixelRenderer.legacyCanvas,
      ),
    );
    expect(
      tester.widget<AvatarPixelRain>(find.byType(AvatarPixelRain)).renderer,
      AvatarPixelRenderer.legacyCanvas,
    );

    await tester.pumpWidget(
      PixelRainText(
        constraints: constraints,
        pixels: [_pixel(color: Colors.red)],
        duration: const Duration(seconds: 1),
        fallDuration: const Duration(seconds: 1),
        pixelSize: 8,
        renderer: AvatarPixelRenderer.legacyCanvas,
      ),
    );
    expect(
      tester.widget<AvatarPixelRain>(find.byType(AvatarPixelRain)).renderer,
      AvatarPixelRenderer.legacyCanvas,
    );

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('atlas paints rounded wave pixels in one CustomPaint', (
    tester,
  ) async {
    await tester.pumpWidget(
      _TestSurface(
        animation: const AlwaysStoppedAnimation(0.5),
        pixels: [
          _pixel(color: const Color(0xFFEF3340)),
          Pixel(
            x: 16,
            y: 16,
            startX: 24,
            startY: 0,
            color: const Color(0xFF32A852),
            delayMs: 250,
          ),
        ],
        pixelRadius: const Radius.circular(4),
        motion: AvatarPixelMotion.horizontalWaves,
      ),
    );

    await tester.pump();
    expect(tester.takeException(), isNull);
    expect(find.byType(CustomPaint), findsOneWidget);
  });

  testWidgets('atlas preserves pixel tint and rounded corners', (tester) async {
    final boundaryKey = GlobalKey();
    await tester.pumpWidget(
      _TestSurface(
        boundaryKey: boundaryKey,
        animation: const AlwaysStoppedAnimation(1),
        pixels: [_pixel(color: const Color(0xFFEF3340))],
        pixelRadius: const Radius.circular(4),
      ),
    );

    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    ByteData? bytes;
    var imageWidth = 0;
    await tester.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 1);
      imageWidth = image.width;
      bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
      image.dispose();
    });

    expect(bytes, isNotNull);
    final center = _rgbaAt(bytes!, imageWidth, 12, 12);
    expect(center.r, greaterThan(220));
    expect(center.g, lessThan(80));
    expect(center.b, lessThan(90));
    expect(center.a, greaterThan(220));

    final corner = _rgbaAt(bytes!, imageWidth, 8, 8);
    expect(corner.a, lessThan(32));
  });

  testWidgets('empty pixel lists remain a no-op', (tester) async {
    await tester.pumpWidget(
      const _TestSurface(animation: AlwaysStoppedAnimation(0.5), pixels: []),
    );

    expect(tester.takeException(), isNull);
  });
}

Pixel _pixel({required Color color}) {
  return Pixel(x: 8, y: 8, startX: 0, startY: 0, color: color, delayMs: 0);
}

({int r, int g, int b, int a}) _rgbaAt(
  ByteData bytes,
  int width,
  int x,
  int y,
) {
  final offset = (y * width + x) * 4;
  return (
    r: bytes.getUint8(offset),
    g: bytes.getUint8(offset + 1),
    b: bytes.getUint8(offset + 2),
    a: bytes.getUint8(offset + 3),
  );
}

class _TestSurface extends StatelessWidget {
  const _TestSurface({
    this.boundaryKey,
    required this.animation,
    required this.pixels,
    this.pixelRadius = Radius.zero,
    this.motion = AvatarPixelMotion.linear,
    this.renderer = AvatarPixelRenderer.rawAtlas,
  });

  final Key? boundaryKey;
  final Animation<double> animation;
  final List<Pixel> pixels;
  final Radius pixelRadius;
  final AvatarPixelMotion motion;
  final AvatarPixelRenderer renderer;

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(
          key: boundaryKey,
          child: AvatarPixelRain(
            pixels: pixels,
            pixelSize: 8,
            animation: animation,
            durationMs: 1000,
            fallDurationMs: 1000,
            widgetWidth: 32,
            widgetHeight: 32,
            pixelPadding: 0,
            pixelRadius: pixelRadius,
            motion: motion,
            renderer: renderer,
          ),
        ),
      ),
    );
  }
}
