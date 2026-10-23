import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_file_cache.dart';

void main() {
  late Directory root;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('music_file_cache_test_');
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  test('evicts VU profiles with their audio and counts their size', () async {
    final seed = MusicFileCache(rootDirectory: root, maxBytes: 0);
    final older = await seed.obtain(
      videoId: 'older',
      produce: (dir) => _writeFile(dir, [1, 2, 3]),
    );
    final current = await seed.obtain(
      videoId: 'current',
      produce: (dir) => _writeFile(dir, [4, 5, 6]),
    );
    final profile = File('$older${MusicFileCache.vuProfileSuffix}');
    await profile.writeAsString('a cached stereo VU profile');
    await File(older).setLastModified(DateTime(2026));
    final limited = MusicFileCache(rootDirectory: root, maxBytes: 0);
    await limited.obtain(
      videoId: 'current',
      produce: (_) => throw StateError('cache miss'),
    );
    await limited.updateLimit(6);
    expect(await File(older).exists(), isFalse);
    expect(await profile.exists(), isFalse);
    expect(await File(current).exists(), isTrue);
  });

  test('cache lookup does not download or create missing entries', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    expect(await cache.findExisting('missing'), isNull);
    expect(await root.list().toList(), isEmpty);
  });

  test(
    'changing the limit prunes old files but keeps tracks used this session',
    () async {
      final seed = MusicFileCache(rootDirectory: root, maxBytes: 0);
      final old = await seed.obtain(
        videoId: 'old',
        produce: (dir) => _writeFile(dir, [1, 2, 3]),
      );
      final playing = await seed.obtain(
        videoId: 'playing',
        produce: (dir) => _writeFile(dir, [4, 5, 6]),
      );
      final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
      await Future.wait([
        cache.updateLimit(1),
        cache.obtain(
          videoId: 'playing',
          produce: (_) => throw StateError('cache miss'),
        ),
      ]);
      expect(await File(old).exists(), isFalse);
      expect(await File(playing).exists(), isTrue);
      await cache.updateLimit(0);
      final added = await cache.obtain(
        videoId: 'added',
        produce: (dir) => _writeFile(dir, [7, 8, 9]),
      );
      expect(await File(added).exists(), isTrue);
      expect(await File(playing).exists(), isTrue);
    },
  );

  test('reuses a completed file for the same YouTube video ID', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    var producerCalls = 0;

    Future<File> produce(Directory stagingDirectory) async {
      producerCalls++;
      return _writeFile(stagingDirectory, [1, 2, 3]);
    }

    final first = await cache.obtain(videoId: 'same-video', produce: produce);
    final second = await cache.obtain(videoId: 'same-video', produce: produce);

    expect(second, first);
    expect(producerCalls, 1);
    expect(await File(first).readAsBytes(), [1, 2, 3]);
    expect(first, endsWith('${Platform.pathSeparator}same-video.mp3'));
  });

  test('does not publish a failed production attempt', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);

    await expectLater(
      cache.obtain(
        videoId: 'retry-video',
        produce: (stagingDirectory) async {
          await _writeFile(stagingDirectory, [1]);
          throw StateError('download failed');
        },
      ),
      throwsStateError,
    );

    var retryCalls = 0;
    final path = await cache.obtain(
      videoId: 'retry-video',
      produce: (stagingDirectory) async {
        retryCalls++;
        return _writeFile(stagingDirectory, [4, 5]);
      },
    );

    expect(retryCalls, 1);
    expect(await File(path).readAsBytes(), [4, 5]);
  });

  test('prunes the least recently used entry on the next session', () async {
    final seedCache = MusicFileCache(rootDirectory: root, maxBytes: 0);
    final olderPath = await seedCache.obtain(
      videoId: 'older-video',
      produce: (directory) => _writeFile(directory, [1, 2, 3]),
    );
    final newerPath = await seedCache.obtain(
      videoId: 'newer-video',
      produce: (directory) => _writeFile(directory, [4, 5, 6]),
    );
    await File(olderPath).setLastModified(DateTime(2026));
    await File(newerPath).setLastModified(DateTime(2026, 1, 2));

    final limitedCache = MusicFileCache(rootDirectory: root, maxBytes: 3);
    var producerCalls = 0;
    final cachedPath = await limitedCache.obtain(
      videoId: 'newer-video',
      produce: (directory) async {
        producerCalls++;
        return _writeFile(directory, [7, 8, 9]);
      },
    );

    expect(cachedPath, newerPath);
    expect(producerCalls, 0);
    expect(await File(olderPath).exists(), isFalse);
    expect(await File(newerPath).exists(), isTrue);
  });

  test('rejects a video ID that is unsafe for a file name', () async {
    final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);

    await expectLater(
      cache.obtain(
        videoId: '../outside',
        produce: (directory) => _writeFile(directory, [1]),
      ),
      throwsArgumentError,
    );
  });
}

Future<File> _writeFile(Directory directory, List<int> bytes) async {
  final file = File('${directory.path}${Platform.pathSeparator}produced.mp3');
  await file.writeAsBytes(bytes);
  return file;
}
