import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/pixels/pixel_rain_letters.dart';

void main() {
  const ukrainianAlphabet = 'АБВГҐДЕЄЖЗИІЇЙКЛМНОПРСТУФХЦЧШЩЬЮЯ';

  test('contains every Ukrainian uppercase letter', () {
    final glyphs = PixelRainLetter.all;

    for (final rune in ukrainianAlphabet.runes) {
      final letter = String.fromCharCode(rune);
      expect(glyphs, contains(letter), reason: 'Missing glyph for $letter');
    }
  });

  test('Ukrainian glyphs are rectangular seven-row masks', () {
    final glyphs = PixelRainLetter.all;

    for (final rune in ukrainianAlphabet.runes) {
      final letter = String.fromCharCode(rune);
      final glyph = glyphs[letter]!;
      final width = glyph.first.length;

      expect(glyph, hasLength(7), reason: 'Unexpected height for $letter');
      expect(
        width,
        inInclusiveRange(3, 8),
        reason: 'Unexpected width for $letter',
      );
      expect(
        glyph.every((row) => row.length == width),
        isTrue,
        reason: 'Ragged rows in $letter',
      );
      expect(
        glyph.expand((row) => row).every((cell) => cell == 0 || cell == 1),
        isTrue,
        reason: 'Invalid cell value in $letter',
      );
    }
  });

  test('complex Ukrainian glyphs use roomier proportions', () {
    final glyphs = PixelRainLetter.all;

    expect(glyphs['І']!.first.length, 3);
    expect(glyphs['О']!.first.length, 6);
    expect(glyphs['Д']!.first.length, 7);
    expect(glyphs['Ж']!.first.length, 7);
    expect(glyphs['Ф']!.first.length, 7);
    expect(glyphs['Ш']!.first.length, 7);
    expect(glyphs['Щ']!.first.length, 8);
  });

  test('covers Ukrainian phrases rendered by pixel widgets', () {
    const phrases = [
      'ДЯКУЮ ЗА ФОЛОВ!',
      'ТЕПЕР ПІДПИСНИК 3-ГО РІВНЯ',
      'ПІДПИСНИК 3-ГО РІВНЯ ВЖЕ 12 МІС.',
      'НЕПРАВИЛЬНА КОНФІГУРАЦІЯ OBS',
      'АНОНІМ',
    ];
    final glyphs = PixelRainLetter.all;

    for (final phrase in phrases) {
      for (final rune in phrase.runes) {
        final character = String.fromCharCode(rune);
        expect(
          glyphs,
          contains(character),
          reason: 'Missing glyph for "$character" in "$phrase"',
        );
      }
    }
  });
}
