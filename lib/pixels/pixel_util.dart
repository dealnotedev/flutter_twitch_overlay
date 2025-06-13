import 'dart:math';
import 'dart:ui';

import 'package:image/image.dart' as img;
import 'package:obssource/pixels/pixel.dart';

class PixelUtil {
  PixelUtil._();

  static List<List<int>> generateMatrixFromImage({required img.Image image}) {
    return List.generate(
      image.height,
      (y) => List.generate(image.width, (x) {
        final pixel = image.getPixel(x, y);
        return pixel.a == 0.0 ? 0 : 1;
      }),
    );
  }

  static List<Pixel> generateTextPixels({
    required String text,
    required Map<String, List<List<int>>> letters,
    required Offset startOffset,
    required double pixelSize,
    required double letterSpacing,
    required Color color,
    int minDelayMs = 0,
    int maxDelayMs = 1600,
  }) {
    final rnd = Random();
    final List<Pixel> result = [];

    double xOffset = 0.0;

    for (int charIndex = 0; charIndex < text.length; charIndex++) {
      final char = text[charIndex];
      final mask = letters[char]!;

      for (int y = 0; y < mask.length; y++) {
        for (int x = 0; x < mask[y].length; x++) {
          if (mask[y][x] == 1) {
            final double targetX = startOffset.dx + xOffset + (x * pixelSize);
            final double targetY = startOffset.dy + y * pixelSize;

            result.add(
              Pixel(
                x: targetX,
                y: targetY,
                startX: 0,
                startY: 0,
                color: color,
                delayMs:
                    minDelayMs +
                    rnd.nextInt((maxDelayMs - minDelayMs).clamp(0, 10000)),
              ),
            );
          }
        }
      }

      xOffset += pixelSize * mask[0].length + letterSpacing;
    }

    return result;
  }

  static List<Pixel> generatePixels({
    required List<List<int>> mask,
    required Offset startOffset,
    required double pixelSize,
    required Color color,
    int minDelayMs = 0,
    int maxDelayMs = 1600,
  }) {
    final rnd = Random();
    final List<Pixel> result = [];

    for (int y = 0; y < mask.length; y++) {
      for (int x = 0; x < mask[y].length; x++) {
        if (mask[y][x] == 1) {
          final double targetX = startOffset.dx + (x * pixelSize);
          final double targetY = startOffset.dy + y * pixelSize;

          result.add(
            Pixel(
              x: targetX,
              y: targetY,
              startX: 0,
              startY: 0,
              color: color,
              delayMs:
                  minDelayMs +
                  rnd.nextInt((maxDelayMs - minDelayMs).clamp(0, 10000)),
            ),
          );
        }
      }
    }

    return result;
  }

  static Size calculateSize({
    required List<List<int>> mask,
    required double pixelSize,
  }) {
    return Size(mask[0].length * pixelSize, mask.length * pixelSize);
  }

  static Size calculatePixelTextSize({
    required String word,
    required Map<String, List<List<int>>> letters,
    required double pixelSize,
    required double letterSpacing,
  }) {
    double w = 0.0;
    double h = 0.0;

    for (int charIndex = 0; charIndex < word.length; charIndex++) {
      if (charIndex > 0) {
        w += letterSpacing;
      }

      final char = word[charIndex];
      final mask = letters[char]!;

      w += mask[0].length * pixelSize;

      final height = mask.length * pixelSize;
      if (h < height) {
        h = height;
      }
    }

    return Size(w, h);
  }
}
