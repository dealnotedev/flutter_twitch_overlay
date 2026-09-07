import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/raid/raid_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all exact-count and overflow WAVs are present in the Flutter bundle',
    () async {
      final paths = <String>{};
      for (var viewers = 1; viewers <= 100; viewers++) {
        final path = RaidAudio.assetForViewers(viewers);
        expect(
          path,
          'assets/raid/raid_${viewers.toString().padLeft(3, '0')}.wav',
        );
        paths.add(path);
      }
      expect(RaidAudio.assetForViewers(101), 'assets/raid/raid_over_100.wav');
      expect(RaidAudio.assetForViewers(10000), RaidAudio.assetForViewers(101));
      paths.add(RaidAudio.assetForViewers(101));
      expect(paths, hasLength(101));

      for (final path in paths) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(44), reason: path);
        expect(
          String.fromCharCodes(data.buffer.asUint8List(data.offsetInBytes, 4)),
          'RIFF',
        );
        expect(
          String.fromCharCodes(
            data.buffer.asUint8List(data.offsetInBytes + 8, 4),
          ),
          'WAVE',
        );
      }
      final files = Directory('assets/raid').listSync();
      expect(files, hasLength(101));
      expect(
        files.every((file) => file is File && file.path.endsWith('.wav')),
        isTrue,
      );
    },
  );

  test('invalid viewer counts cannot select a misleading audio clip', () {
    expect(() => RaidAudio.assetForViewers(0), throwsArgumentError);
    expect(() => RaidAudio.assetForViewers(-1), throwsArgumentError);
  });
}
