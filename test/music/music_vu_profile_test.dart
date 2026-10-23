import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_vu_profile.dart';

void main() {
  test(
    'samples stereo levels at the current position with volume attenuation',
    () {
      final profile = MusicVuProfile(const [
        MusicVuSample(-20, -10),
        MusicVuSample(-10, -20),
      ]);
      final middle = profile.sampleAt(const Duration(milliseconds: 25));
      expect(middle.leftDb, -15);
      expect(middle.rightDb, -15);
      final quieter = profile.sampleAt(Duration.zero, volume: 0.5);
      expect(quieter.leftDb, closeTo(-26.0206, 0.001));
      expect(quieter.rightDb, closeTo(-16.0206, 0.001));
      expect(profile.sampleAt(const Duration(milliseconds: 75)).leftDb, -10);
      expect(profile.sampleAt(const Duration(milliseconds: 100)).leftDb, -90);
      expect(profile.sampleAt(const Duration(milliseconds: -1)).leftDb, -90);
      expect(profile.sampleAt(Duration.zero, volume: 0).leftDb, -90);
    },
  );

  test(
    'serialized profiles preserve stereo samples and reject corrupt data',
    () {
      final source = MusicVuProfile(const [
        MusicVuSample(-23.01, -16.99),
        MusicVuSample(-90, -90),
      ]);
      final restored = MusicVuProfile.fromJson(
        jsonDecode(jsonEncode(source.toJson())) as Map<String, dynamic>,
      );
      expect(restored.length, 2);
      expect(restored.sampleAt(Duration.zero).leftDb, closeTo(-23.01, 0.001));
      expect(restored.sampleAt(Duration.zero).rightDb, closeTo(-16.99, 0.001));
      for (final json in [
        {
          'intervalMs': 100,
          'levels': [-20, -10],
        },
        {
          'intervalMs': 50,
          'levels': [-20],
        },
        {'intervalMs': 50, 'levels': []},
        {
          'intervalMs': 50,
          'levels': [-20, 'bad'],
        },
        {
          'intervalMs': 50,
          'levels': [-20, double.nan],
        },
      ]) {
        expect(() => MusicVuProfile.fromJson(json), throwsFormatException);
      }
    },
  );

  test('needles rise independently and decay smoothly to rest on silence', () {
    final motion = MusicVuBallistics();
    motion.advance(
      const Duration(milliseconds: 20),
      const MusicVuSample(-9, -25),
    );
    expect(motion.left, inExclusiveRange(0, 1));
    expect(motion.right, inExclusiveRange(0, motion.left));
    motion.advance(const Duration(seconds: 1), const MusicVuSample(-9, -25));
    expect(motion.left, closeTo(1, 0.001));
    final loud = motion.left;
    motion.advance(const Duration(milliseconds: 20), MusicVuSample.silence);
    expect(motion.left, inExclusiveRange(0, loud));
    motion.advance(const Duration(seconds: 2), MusicVuSample.silence);
    expect(motion.left, closeTo(0, 0.001));
    motion.reset();
    expect(motion.left, 0);
    expect(motion.right, 0);
  });
}
