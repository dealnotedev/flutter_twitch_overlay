import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/raid/raid_audio.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'all exact-count and overflow MP3s are present in the Flutter bundle',
    () async {
      final paths = <String>{};
      for (var viewers = 1; viewers <= 100; viewers++) {
        final path = RaidAudio.assetForViewers(viewers);
        expect(
          path,
          'assets/raid/raid_${viewers.toString().padLeft(3, '0')}.mp3',
        );
        paths.add(path);
      }
      expect(RaidAudio.assetForViewers(101), 'assets/raid/raid_over_100.mp3');
      expect(RaidAudio.assetForViewers(10000), RaidAudio.assetForViewers(101));
      paths.add(RaidAudio.assetForViewers(101));
      expect(paths, hasLength(101));

      for (final path in paths) {
        final data = await rootBundle.load(path);
        expect(data.lengthInBytes, greaterThan(10), reason: path);
        final bytes = data.buffer.asUint8List(data.offsetInBytes, 3);
        final hasId3 = String.fromCharCodes(bytes) == 'ID3';
        final hasFrame = bytes[0] == 0xff && bytes[1] & 0xe0 == 0xe0;
        expect(hasId3 || hasFrame, isTrue, reason: path);
      }
      final files = Directory('assets/raid').listSync();
      expect(files, hasLength(101));
      expect(
        files.every((file) => file is File && file.path.endsWith('.mp3')),
        isTrue,
      );
    },
  );

  test('invalid viewer counts cannot select a misleading audio clip', () {
    expect(() => RaidAudio.assetForViewers(0), throwsArgumentError);
    expect(() => RaidAudio.assetForViewers(-1), throwsArgumentError);
  });
}
