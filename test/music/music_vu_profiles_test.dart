import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_vu_profile.dart';
import 'package:obssource/music/music_vu_profiles.dart';

void main() {
  late Directory root;
  late MusicFileCache cache;
  late String audio;
  final profile = MusicVuProfile(const [
    MusicVuSample(-20, -10),
    MusicVuSample(-30, -40),
  ]);
  setUp(() async {
    root = await Directory.systemTemp.createTemp('music-vu-test-');
    cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    audio = await cache.obtain(
      videoId: 'video',
      produce:
          (dir) async =>
              File('${dir.path}/audio.mp3')..writeAsBytesSync([1, 2, 3]),
    );
  });
  tearDown(() async {
    await root.delete(recursive: true);
  });

  final ffmpeg = File('tools/ffmpeg.exe').absolute;
  test(
    'measures a cached MP3 with real FFmpeg and reopens its persisted profile',
    () async {
      await File(audio).writeAsBytes(
        await File('test/fixtures/music/vu-stereo.mp3').readAsBytes(),
      );
      final profiles = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: ffmpeg.path,
      );
      final measured = await profiles.loadFor(_item('https://youtu.be/video'));
      expect(measured, isNotNull);
      expect(
        measured!.sampleAt(const Duration(milliseconds: 200)).rightDb,
        greaterThan(
          measured.sampleAt(const Duration(milliseconds: 200)).leftDb + 10,
        ),
      );
      await profiles.close();
      var repeatedAnalysis = false;
      final reopened = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) async {
          repeatedAnalysis = true;
          throw StateError('cached profile should be reused');
        },
      );
      addTearDown(reopened.close);
      expect(
        await reopened.loadFor(_item('https://youtube.com/watch?v=video')),
        isNotNull,
      );
      expect(repeatedAnalysis, isFalse);
    },
    skip: !ffmpeg.existsSync(),
  );

  test(
    'deduplicates concurrent requests and reuses disk cache after LRU touches',
    () async {
      var calls = 0;
      final gate = Completer<MusicVuProfile>();
      final first = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) {
          calls++;
          return gate.future;
        },
      );
      final pending = first.prepare(audio);
      expect(identical(first.prepare(audio), pending), isTrue);
      gate.complete(profile);
      expect(await pending, profile);
      await first.close();
      await cache.obtain(
        videoId: 'video',
        produce: (_) => throw StateError('unexpected cache miss'),
      );
      final second = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) async {
          calls++;
          return profile;
        },
      );
      addTearDown(second.close);
      final cached = await second.prepare(audio);
      expect(cached!.sampleAt(Duration.zero).rightDb, -10);
      expect(calls, 1);
    },
  );

  test(
    'regenerates a profile when audio bytes change without a size change',
    () async {
      var calls = 0;
      final profiles = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) async {
          calls++;
          return profile;
        },
      );
      addTearDown(profiles.close);
      await profiles.prepare(audio);
      await File(audio).writeAsBytes([3, 2, 1]);
      await profiles.prepare(audio);
      await profiles.prepare(audio);
      expect(calls, 2);
    },
  );

  test('replaces corrupt cached metadata with a valid profile', () async {
    final sidecar = File('$audio${MusicFileCache.vuProfileSuffix}');
    await sidecar.writeAsString('{invalid');
    final profiles = MusicVuProfiles(
      cache: cache,
      ffmpegExecutable: 'unused',
      analyze: (_) async => profile,
    );
    addTearDown(profiles.close);
    expect(await profiles.prepare(audio), profile);
    final json =
        jsonDecode(await sidecar.readAsString()) as Map<String, dynamic>;
    expect(json['audioSha256'], isA<String>());
    expect(json['version'], 1);
  });

  test('only analyzes an existing cached YouTube track', () async {
    var calls = 0;
    final profiles = MusicVuProfiles(
      cache: cache,
      ffmpegExecutable: 'unused',
      analyze: (_) async {
        calls++;
        return profile;
      },
    );
    addTearDown(profiles.close);
    for (final url in [
      'https://youtu.be/video?t=1',
      'https://www.youtube.com/watch?v=video',
      'https://m.youtube.com/shorts/video',
      'https://www.youtube.com/embed/video',
    ]) {
      expect(await profiles.loadFor(_item(url)), isNotNull);
    }
    expect(calls, 1);
    expect(await profiles.loadFor(_item('https://youtu.be/missing')), isNull);
    expect(
      await profiles.loadFor(_item('https://example.com/watch?v=video')),
      isNull,
    );
    expect(await profiles.loadFor(_item('https://youtu.be/..')), isNull);
    expect(calls, 1);
  });

  test(
    'unavailable analysis is optional and does not write a profile',
    () async {
      final profiles = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) async => throw StateError('missing FFmpeg'),
      );
      addTearDown(profiles.close);
      expect(await profiles.prepare(audio), isNull);
      expect(
        await File('$audio${MusicFileCache.vuProfileSuffix}').exists(),
        isFalse,
      );
    },
  );

  test(
    'serializes jobs and does not publish or run queued work after close',
    () async {
      var calls = 0;
      final started = Completer<void>();
      final gate = Completer<MusicVuProfile>();
      final profiles = MusicVuProfiles(
        cache: cache,
        ffmpegExecutable: 'unused',
        analyze: (_) {
          calls++;
          started.complete();
          return gate.future;
        },
      );
      final first = profiles.prepare(audio);
      await started.future;
      final second = profiles.prepare('$audio.other');
      final closing = profiles.close();
      gate.complete(profile);
      await closing;
      expect(await first, isNull);
      expect(await second, isNull);
      expect(calls, 1);
      expect(
        await File('$audio${MusicFileCache.vuProfileSuffix}').exists(),
        isFalse,
      );
    },
  );
}

MusicQueueItem _item(String url) => MusicQueueItem(
  id: 'one',
  requestedBy: 'Viewer',
  sourceUrl: Uri.parse(url),
  phase: MusicQueueItemPhase.ready,
  title: 'Song',
  author: 'Artist',
  duration: const Duration(minutes: 1),
  thumbnail: null,
);
