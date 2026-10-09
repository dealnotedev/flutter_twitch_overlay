import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';

void main() {
  test(
    'reports the captured media 403 as a download block, not a login request',
    () async {
      final root = await Directory.systemTemp.createTemp('yt_media_403_');
      addTearDown(() => root.delete(recursive: true));
      var loginRequested = false;
      Uri? blockedDownload;
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'fake-yt-dlp',
        ffmpegLocation: null,
        denoPath: null,
        cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
        onAccessRequired: (_) => loginRequested = true,
        onDownloadBlocked: (url) => blockedDownload = url,
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
      final metadata = await fetcher.inspect(
        Uri.parse('https://youtu.be/video'),
      );
      await expectLater(
        fetcher.obtain(metadata: metadata, onProgress: (_) {}),
        throwsA(
          isA<YtDlpException>().having(
            (error) => error.errorType.name,
            'reason',
            'youtubeDownloadBlocked',
          ),
        ),
      );
      expect(loginRequested, isFalse);
      expect(blockedDownload, metadata.sourceUrl);
    },
  );
  test(
    'uses the saved session for both inspection and audio download',
    () async {
      final root = await Directory.systemTemp.createTemp('yt_session_args_');
      addTearDown(() => root.delete(recursive: true));
      var cookies = '${root.path}/session with spaces.txt';
      final calls = <List<String>>[];
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'fake-yt-dlp',
        ffmpegLocation: null,
        denoPath: null,
        cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
        cookieFilePath: () => cookies,
        processStarter: (_, args) async {
          calls.add(args);
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
      cookies = '${root.path}/refreshed session.txt';
      await fetcher.obtain(metadata: metadata, onProgress: (_) {});
      expect(
        calls[0][calls[0].indexOf('--cookies') + 1],
        contains('session with spaces'),
      );
      expect(calls[1][calls[1].indexOf('--cookies') + 1], cookies);
      expect(
        calls.every((args) => !args.contains('--cookies-from-browser')),
        isTrue,
      );
    },
  );

  test(
    'notifies the connection UI when an audio download needs verification',
    () async {
      final root = await Directory.systemTemp.createTemp('yt_download_access_');
      addTearDown(() => root.delete(recursive: true));
      Uri? blocked;
      final url = Uri.parse('https://youtu.be/video');
      final fetcher = YtDlpMusicTrackFetcher(
        executable: 'fake-yt-dlp',
        ffmpegLocation: null,
        denoPath: null,
        cache: MusicFileCache(rootDirectory: root, maxBytes: 1024),
        onAccessRequired: (url) => blocked = url,
        processStarter:
            (_, args) async =>
                args.contains('--skip-download')
                    ? _FakeProcess(_metadataBytes(utf8Requested: true))
                    : const _FakeProcess(
                      [],
                      status: 1,
                      errorOutput:
                          "ERROR: [youtube] video: Sign in to confirm you’re not a bot.",
                    ),
      );
      final metadata = await fetcher.inspect(url);
      await expectLater(
        fetcher.obtain(metadata: metadata, onProgress: (_) {}),
        throwsA(
          isA<YtDlpException>().having(
            (e) => e.errorType,
            'type',
            MusicQueueErrorType.youtubeAccessRequired,
          ),
        ),
      );
      expect(blocked, url);
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
                'Use --cookies-from-browser or --cookies for authentication. '
                'See https://github.com/yt-dlp/yt-dlp/wiki/FAQ#how-do-i-pass-cookies-to-yt-dlp '
                'for instructions. Also see '
                'https://github.com/yt-dlp/yt-dlp/wiki/Extractors#exporting-youtube-cookies '
                'for tips on exporting YouTube cookies.\n',
            status: 1,
          ),
    );

    await expectLater(
      fetcher.inspect(Uri.parse('https://youtu.be/video')),
      throwsA(
        isA<YtDlpException>()
            .having(
              (error) => error.message,
              'message',
              'YouTube needs verification. Open Music settings to connect '
                  'YouTube, then try again.',
            )
            .having((error) => error.exitCode, 'exit code', 1),
      ),
    );
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
