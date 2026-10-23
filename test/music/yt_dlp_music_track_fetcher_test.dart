import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';

// Abbreviated yt-dlp 2026.08.19 output. yt-dlp appends this hint to every
// YouTube reason that mentions signing in.
const _loginHint =
    'Use --cookies-from-browser or --cookies for the authentication. '
    'See  https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp  '
    'for how to manually pass cookies. Also see  '
    'https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies  '
    'for tips on effectively exporting YouTube cookies';

void main() {
  test(
    'notifies optional analysis on a cache hit without waiting for it',
    () async {
      final root = await Directory.systemTemp.createTemp('music-vu-fetcher-');
      addTearDown(() => root.delete(recursive: true));
      final cache = MusicFileCache(rootDirectory: root, maxBytes: 0);
      final path = await cache.obtain(
        videoId: 'video',
        produce:
            (dir) async =>
                File('${dir.path}/audio.mp3')..writeAsBytesSync([1, 2, 3]),
      );
      String? prepared;
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'unused',
        ffmpegLocation: null,
        denoPath: null,
        cache: cache,
        onFileObtained: (file) {
          prepared = file;
        },
      );
      final metadata = MusicTrackMetadata(
        videoId: 'video',
        title: 'Track',
        author: 'Artist',
        duration: const Duration(minutes: 1),
        thumbnail: null,
        sourceUrl: Uri.parse('https://youtu.be/video'),
      );
      expect(
        await fetcher.obtain(metadata: metadata, onProgress: (_) {}),
        path,
      );
      expect(prepared, path);
    },
  );

  group('classifies yt-dlp failures', () {
    for (final (name, stderr, expected) in [
      (
        'bot check',
        'ERROR: [youtube] abc: Sign in to confirm you’re not a bot. $_loginHint',
        MusicQueueErrorType.youtubeAccessRequired,
      ),
      (
        'captcha',
        'ERROR: [youtube] abc: Video unavailable. '
            'YouTube is requiring a captcha challenge before playback',
        MusicQueueErrorType.youtubeAccessRequired,
      ),
      (
        'private video despite the cookies hint',
        "ERROR: [youtube] abc: Private video. Sign in if you've been granted "
            'access to this video. $_loginHint',
        MusicQueueErrorType.youtubeUnavailable,
      ),
      (
        'age restriction despite the cookies hint',
        'ERROR: [youtube] abc: Sign in to confirm your age. This video may be '
            'inappropriate for some users. $_loginHint',
        MusicQueueErrorType.youtubeUnavailable,
      ),
      (
        'geo restriction',
        'ERROR: [youtube] abc: The uploader has not made this video available '
            'in your country. You might want to use a VPN or a proxy server',
        MusicQueueErrorType.youtubeUnavailable,
      ),
      (
        'session rate limit',
        "ERROR: [youtube] abc: Video unavailable. This content isn't "
            'available, try again later. The current session has been '
            'rate-limited by YouTube for up to an hour.',
        MusicQueueErrorType.youtubeRateLimited,
      ),
      (
        'HTTP 429',
        'ERROR: [youtube] abc: Unable to download API page: '
            'HTTP Error 429: Too Many Requests',
        MusicQueueErrorType.youtubeRateLimited,
      ),
      (
        'media 403',
        'ERROR: unable to download video data: HTTP Error 403: Forbidden',
        MusicQueueErrorType.youtubeDownloadBlocked,
      ),
      (
        'network error after a stale cookies warning',
        'WARNING: [youtube] The provided YouTube account cookies are no '
            'longer valid. They have likely been rotated in the browser.\n'
            'ERROR: [youtube] abc: Unable to download webpage: '
            '<urlopen error [Errno 11001] getaddrinfo failed>',
        MusicQueueErrorType.networkUnavailable,
      ),
      (
        'unknown error after a stale cookies warning',
        'WARNING: [youtube] The provided YouTube account cookies are no '
            'longer valid.\n'
            'ERROR: [youtube] abc: Requested format is not available.',
        MusicQueueErrorType.youtubeAccessRequired,
      ),
      (
        'missing JavaScript runtime',
        'WARNING: [youtube] No supported JavaScript runtime could be found.\n'
            'ERROR: [youtube] abc: Requested format is not available.',
        MusicQueueErrorType.musicToolsUnavailable,
      ),
      (
        'unknown error',
        'ERROR: [youtube] abc: Something unexpected happened.',
        MusicQueueErrorType.operationFailed,
      ),
    ]) {
      test(name, () {
        expect(YtDlpMusicTrackFetcher.classifyFailure(stderr), expected);
      });
    }
  });

  test('reports the captured media 403 as a download block', () async {
    final root = await Directory.systemTemp.createTemp('yt_media_403_');
    addTearDown(() => root.delete(recursive: true));
    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      ffmpegLocation: null,
      denoPath: null,
      cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
      processStarter:
          (_, args) async =>
              args.contains('--skip-download')
                  ? _FakeProcess(_metadataBytes(utf8Requested: true))
                  : const _FakeProcess(
                    [],
                    status: 1,
                    errorOutput:
                        'ERROR: unable to download video data: HTTP Error 403: Forbidden',
                  ),
    );
    final metadata = await fetcher.inspect(Uri.parse('https://youtu.be/video'));
    await expectLater(
      fetcher.obtain(metadata: metadata, onProgress: (_) {}),
      throwsA(
        isA<YtDlpException>().having(
          (error) => error.errorType,
          'type',
          MusicQueueErrorType.youtubeDownloadBlocked,
        ),
      ),
    );
  });

  test(
    'gives every yt-dlp run its own cookie copy and releases it after exit',
    () async {
      final root = await Directory.systemTemp.createTemp('yt_session_args_');
      addTearDown(() => root.delete(recursive: true));
      final events = <String>[];
      final calls = <List<String>>[];
      var leases = 0;
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'fake-yt-dlp',
        ffmpegLocation: null,
        denoPath: null,
        cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
        cookies: () async {
          final id = ++leases;
          return _Lease('${root.path}/run $id.txt', events, id);
        },
        processStarter: (_, args) async {
          calls.add(args);
          events.add('start');
          if (args.contains('--skip-download')) {
            return _FakeProcess(_metadataBytes(utf8Requested: true));
          }
          final output = File('${args[args.indexOf('--paths') + 1]}/audio.mp3');
          await output.writeAsBytes([1, 2, 3]);
          return _FakeProcess(utf8.encode('YT_FILE:${output.path}\n'));
        },
      );
      final metadata = await fetcher.inspect(
        Uri.parse('https://youtu.be/video'),
      );
      await fetcher.obtain(metadata: metadata, onProgress: (_) {});
      expect(
        calls[0][calls[0].indexOf('--cookies') + 1],
        endsWith('run 1.txt'),
      );
      expect(
        calls[1][calls[1].indexOf('--cookies') + 1],
        endsWith('run 2.txt'),
      );
      expect(events, [
        'start',
        'release 1 succeeded',
        'start',
        'release 2 succeeded',
      ]);
      expect(
        calls.every((args) => !args.contains('--cookies-from-browser')),
        isTrue,
      );
    },
  );

  test('a failed run releases its cookie copy as unsuccessful', () async {
    final events = <String>[];
    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      ffmpegLocation: null,
      denoPath: null,
      cache: MusicFileCache(rootDirectory: Directory.systemTemp, maxBytes: 0),
      cookies: () async => _Lease('cookies.txt', events, 1),
      processStarter:
          (_, __) async => const _FakeProcess(
            [],
            status: 1,
            errorOutput:
                'ERROR: [youtube] abc: Sign in to confirm you’re not a bot.',
          ),
    );
    await expectLater(
      fetcher.inspect(Uri.parse('https://youtu.be/video')),
      throwsA(isA<YtDlpException>()),
    );
    expect(events, ['release 1 failed']);
  });

  test(
    'downloads from the inspected info instead of extracting again',
    () async {
      final root = await Directory.systemTemp.createTemp('yt_info_json_');
      addTearDown(() => root.delete(recursive: true));
      final calls = <List<String>>[];
      String? loadedInfo;
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'fake-yt-dlp',
        ffmpegLocation: null,
        denoPath: null,
        cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
        processStarter: (_, args) async {
          calls.add(args);
          if (args.contains('--skip-download')) {
            return _FakeProcess(_metadataBytes(utf8Requested: true));
          }
          final info = args.indexOf('--load-info-json');
          if (info >= 0) loadedInfo = await File(args[info + 1]).readAsString();
          final output = File('${args[args.indexOf('--paths') + 1]}/audio.mp3');
          await output.writeAsBytes([1, 2, 3]);
          return _FakeProcess(utf8.encode('YT_FILE:${output.path}\n'));
        },
      );
      final url = Uri.parse('https://youtu.be/video');
      final metadata = await fetcher.inspect(url);
      await fetcher.obtain(metadata: metadata, onProgress: (_) {});
      expect(calls[1], isNot(contains(url.toString())));
      expect(jsonDecode(loadedInfo!), containsPair('id', 'video'));

      // Info from another inspection is never reused for a different video.
      await fetcher.obtain(
        metadata: MusicTrackMetadata(
          videoId: 'other',
          title: 'Other',
          author: 'Artist',
          duration: const Duration(minutes: 1),
          thumbnail: null,
          sourceUrl: Uri.parse('https://youtu.be/other'),
        ),
        onProgress: (_) {},
      );
      expect(calls[2], contains('https://youtu.be/other'));
      expect(calls[2], isNot(contains('--load-info-json')));
    },
  );

  test('turns the YouTube bot challenge into an actionable message', () async {
    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      ffmpegLocation: null,
      denoPath: null,
      cache: MusicFileCache(rootDirectory: Directory.systemTemp, maxBytes: 0),
      processStarter:
          (_, __) async => _FakeProcess(
            const [],
            errorOutput:
                'WARNING: preliminary diagnostic\n'
                'ERROR: [youtube] video: Sign in to confirm you are not a bot. '
                '$_loginHint\n',
            status: 1,
          ),
    );

    await expectLater(
      fetcher.inspect(Uri.parse('https://youtu.be/video')),
      throwsA(
        isA<YtDlpException>()
            .having(
              (error) => error.errorType,
              'type',
              MusicQueueErrorType.youtubeAccessRequired,
            )
            .having((error) => error.exitCode, 'exit code', 1)
            .having(
              (error) => error.diagnostic,
              'diagnostic',
              startsWith('yt-dlp: ERROR: [youtube] video: Sign in'),
            ),
      ),
    );
  });

  test('reads and caches the yt-dlp version', () async {
    var starts = 0;
    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      ffmpegLocation: null,
      denoPath: null,
      cache: MusicFileCache(rootDirectory: Directory.systemTemp, maxBytes: 0),
      processStarter: (_, args) async {
        starts++;
        expect(args, contains('--version'));
        return _FakeProcess(utf8.encode('2026.08.19\r\n'));
      },
    );
    expect(await fetcher.readVersion(), '2026.08.19');
    expect(await fetcher.readVersion(), '2026.08.19');
    expect(starts, 1);
  });

  test('requests UTF-8 output from yt-dlp', () async {
    final cacheDirectory = await Directory.systemTemp.createTemp(
      'yt_dlp_encoding_test_',
    );
    addTearDown(() async {
      if (await cacheDirectory.exists()) {
        await cacheDirectory.delete(recursive: true);
      }
    });

    final fetcher = YtDlpMusicTrackFetcher(
      executable: 'fake-yt-dlp',
      ffmpegLocation: null,
      denoPath: null,
      cache: MusicFileCache(rootDirectory: cacheDirectory, maxBytes: 0),
      processStarter: (_, arguments) async {
        final encodingIndex = arguments.indexOf('--encoding');
        final utf8Requested =
            encodingIndex >= 0 &&
            encodingIndex + 1 < arguments.length &&
            arguments[encodingIndex + 1].toLowerCase() == 'utf-8';
        return _FakeProcess(_metadataBytes(utf8Requested: utf8Requested));
      },
    );

    final metadata = await fetcher.inspect(Uri.parse('https://youtu.be/video'));

    expect(metadata.title, 'A–B');
  });
}

List<int> _metadataBytes({required bool utf8Requested}) {
  const prefix = '{"id":"video","title":"A';
  const suffix =
      'B","uploader":"Artist","duration":60,'
      '"webpage_url":"https://youtu.be/video"}';
  return [
    ...ascii.encode(prefix),
    ...(utf8Requested ? utf8.encode('–') : const [0x96]),
    ...ascii.encode(suffix),
  ];
}

class _Lease implements YtDlpCookieLease {
  @override
  final String path;
  final List<String> events;
  final int id;

  _Lease(this.path, this.events, this.id);

  @override
  Future<void> release({required bool succeeded}) async {
    events.add('release $id ${succeeded ? 'succeeded' : 'failed'}');
  }
}

class _FakeProcess implements Process {
  final List<int> output;

  final String errorOutput;
  final int status;

  const _FakeProcess(this.output, {this.errorOutput = '', this.status = 0});

  @override
  Future<int> get exitCode async => status;

  @override
  int get pid => 1;

  @override
  Stream<List<int>> get stderr => Stream.value(utf8.encode(errorOutput));

  @override
  IOSink get stdin => throw UnsupportedError('stdin is unused');

  @override
  Stream<List<int>> get stdout => Stream.value(output);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}
