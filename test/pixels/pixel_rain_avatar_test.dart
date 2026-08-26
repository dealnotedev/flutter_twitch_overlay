import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel_rain_animator.dart';
import 'package:obssource/pixels/pixel_rain_avatar.dart';

void main() {
  test('precomputes every exploding pixel beyond the screen', () {
    const width = 320.0;
    const height = 180.0;
    const pixelSize = 4.0;

    final pixels = RainyAvatar.preparePixels(
      image: img.Image(width: 8, height: 8),
      constraints: const BoxConstraints.tightFor(width: width, height: height),
      duration: const Duration(seconds: 2),
      fallDuration: const Duration(seconds: 2),
      pixelSize: pixelSize,
      resolution: 8,
      verticalOffset: -20,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.leaving,
      random: Random(42),
    );

    expect(pixels, isNotEmpty);
    expect(
      pixels.every(
        (pixel) =>
            pixel.x <= -pixelSize ||
            pixel.x >= width ||
            pixel.y <= -pixelSize ||
            pixel.y >= height,
      ),
      isTrue,
    );
    expect(pixels.every((pixel) => pixel.delayMs == 0), isTrue);
    expect(
      pixels.map((pixel) => (pixel.x, pixel.y)).toSet().length,
      greaterThan(1),
    );
  });

  test('precomputes balanced horizontal waves with random amplitudes', () {
    const width = 320.0;
    const height = 180.0;
    const pixelSize = 4.0;

    final pixels = RainyAvatar.preparePixels(
      image: img.Image(width: 8, height: 8),
      constraints: const BoxConstraints.tightFor(width: width, height: height),
      duration: const Duration(seconds: 2),
      fallDuration: const Duration(milliseconds: 1200),
      pixelSize: pixelSize,
      resolution: 8,
      verticalOffset: -20,
      origin: RainyPixelOrigin.outside,
      direction: RainyPixelDirection.leaving,
      motion: AvatarPixelMotion.horizontalWaves,
      random: Random(42),
    );

    expect(pixels, isNotEmpty);
    final left = pixels.where((pixel) => pixel.x <= -pixelSize).length;
    final right = pixels.where((pixel) => pixel.x >= width).length;
    expect(left + right, pixels.length);
    expect((left - right).abs(), lessThanOrEqualTo(1));
    final delays = pixels.map((pixel) => pixel.delayMs).toSet();
    expect(delays.length, greaterThan(1));
    for (final delay in delays) {
      final wave = pixels.where((pixel) => pixel.delayMs == delay);
      final waveLeft = wave.where((pixel) => pixel.x <= -pixelSize).length;
      final waveRight = wave.where((pixel) => pixel.x >= width).length;
      expect((waveLeft - waveRight).abs(), lessThanOrEqualTo(1));
    }
    final amplitudes = pixels.map(
      (pixel) => pixel.x < 0 ? -pixel.x - pixelSize : pixel.x - width,
    );
    expect(amplitudes.toSet().length, greaterThan(1));
    final verticalAmplitudes = pixels.map((pixel) => pixel.y - pixel.startY);
    expect(verticalAmplitudes.any((amplitude) => amplitude < 0), isTrue);
    expect(verticalAmplitudes.any((amplitude) => amplitude > 0), isTrue);
    expect(
      pixels.map((pixel) => (pixel.x, pixel.y)).toSet().length,
      greaterThan(1),
    );
  });
}
