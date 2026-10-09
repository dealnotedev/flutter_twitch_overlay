import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/music/youtube_browser_session.dart';
import 'package:obssource/music/youtube_connection_controller.dart';

const _cookies = [
  {
    'domain': '.youtube.com',
    'name': 'test_session',
    'value': 'fake-value',
    'path': '/',
    'httpOnly': true,
    'secure': true,
    'expires': -1,
  },
  {'domain': '.google.com', 'name': 'other-site', 'value': 'must-not-save'},
];

void main() {
  late Directory directory;
  late _Browser browser;
  YoutubeConnectionController? controller;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('youtube_connection_');
    browser = _Browser();
  });
  tearDown(() async {
    await controller?.close();
    await directory.delete(recursive: true);
  });

  test('checks the video selected in the browser after restart', () async {
    final selected = Uri.parse('https://www.youtube.com/watch?v=selected123');
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, url) async {
        if (url != selected) {
          // Actual output of the formerly hardcoded public test clip.
          throw const YtDlpException(
            'This YouTube video is unavailable. Please choose another.',
            errorType: MusicQueueErrorType.youtubeUnavailable,
            diagnostic:
                'yt-dlp: ERROR: [youtube] BaW_jenozKc: This video is unavailable',
          );
        }
      },
    );
    await controller!.connect();
    browser.selectedUrl = selected;
    await controller!.verify();
    expect(
      controller!.status,
      YoutubeConnectionStatus.connected,
      reason: 'A removed test clip must not reject the playable browser video',
    );
  });

  for (final failure
      in {
        MusicQueueErrorType.youtubeUnavailable: 'videoUnavailable',
        MusicQueueErrorType.youtubeDownloadBlocked: 'downloadBlocked',
        MusicQueueErrorType.trackTooLongOrLive: 'videoTooLongOrLive',
        MusicQueueErrorType.networkUnavailable: 'networkUnavailable',
        MusicQueueErrorType.musicToolsUnavailable: 'toolsUnavailable',
      }.entries) {
    test('keeps the actionable reason ${failure.key.name}', () async {
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess:
            (_, __) async =>
                throw YtDlpException(
                  'failure',
                  errorType: failure.key,
                  exitCode: 1,
                  diagnostic:
                      'ERROR: preparation failed https://media.test/file?token=secret token=secret',
                ),
      );
      await controller!.connect();
      await controller!.verify();
      expect(controller!.issue?.name, failure.value);
      expect(controller!.checkedVideoUrl, browser.selectedUrl);
      expect(controller!.diagnostic, contains('ERROR: preparation failed'));
      expect(controller!.diagnostic, isNot(contains('secret')));
      expect(controller!.cookieFilePath, isNull);
      await controller!.disconnect();
      expect(controller!.diagnostic, isNull);
    });
  }

  test(
    'saves only YouTube after verification and restores it on restart',
    () async {
      final blockedUrl = Uri.parse('https://youtu.be/blocked');
      var checked = false;
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (file, url) async {
          expect(url, blockedUrl);
          expect(
            await File(file).readAsString(),
            contains('test_session\tfake-value'),
          );
          expect(
            await File(file).readAsString(),
            isNot(contains('google.com')),
          );
          expect(controller!.cookieFilePath, isNull);
          checked = true;
        },
      );
      controller!.requireVerification(blockedUrl);
      await controller!.connect();
      expect(browser.url, blockedUrl);
      expect(controller!.status, YoutubeConnectionStatus.awaitingVerification);
      await controller!.verify();
      expect(checked, isTrue);
      expect(controller!.status, YoutubeConnectionStatus.connected);
      expect(browser.closed, isTrue);
      final saved = controller!.cookieFilePath!;
      expect(await File('$saved.pending').exists(), isFalse);
      await controller!.close();
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (_, __) async {},
      );
      expect(controller!.cookieFilePath, saved);
      expect(controller!.status, YoutubeConnectionStatus.connected);
      final profile = Directory('${directory.path}/browser');
      await profile.create();
      await File('${profile.path}/app-session').writeAsString('test');
      await controller!.disconnect();
      expect(controller!.cookieFilePath, isNull);
      expect(await profile.exists(), isFalse);
    },
  );

  test(
    'failed verification does not save a session or falsely show connected',
    () async {
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess:
            (_, __) async =>
                throw const MusicTrackException(
                  'challenge',
                  errorType: MusicQueueErrorType.youtubeAccessRequired,
                ),
      );
      await controller!.connect();
      await controller!.verify();
      expect(controller!.status, YoutubeConnectionStatus.awaitingVerification);
      expect(controller!.issue, YoutubeConnectionIssue.verificationRequired);
      expect(controller!.cookieFilePath, isNull);
      expect(await directory.list().toList(), isEmpty);
      expect(browser.closed, isFalse);
    },
  );

  test('closed browser offers reconnection', () async {
    browser.error = const YoutubeConnectionException(
      YoutubeConnectionIssue.browserClosed,
    );
    controller = YoutubeConnectionController(
      directory: directory,
      browser: browser,
      verifyAccess: (_, __) async {},
    );
    await controller!.connect();
    await controller!.verify();
    expect(controller!.issue, YoutubeConnectionIssue.browserClosed);
    browser.error = null;
    await controller!.connect();
    await controller!.verify();
    expect(controller!.status, YoutubeConnectionStatus.connected);
  });

  test(
    'shutdown cancels an in-flight check and never saves its cookies',
    () async {
      final entered = Completer<void>();
      final result = Completer<void>();
      controller = YoutubeConnectionController(
        directory: directory,
        browser: browser,
        verifyAccess: (_, __) {
          entered.complete();
          return result.future;
        },
        cancelVerification: () async {
          if (!result.isCompleted) result.complete();
        },
      );
      await controller!.connect();
      final verification = controller!.verify();
      await entered.future;
      await controller!.close();
      await verification;
      expect(controller!.cookieFilePath, isNull);
      expect(await directory.list().toList(), isEmpty);
    },
  );

  test('cookie export rejects unrelated and injected domains', () {
    final output = youtubeCookiesToNetscape([
      ..._cookies,
      {'domain': '.youtube.com.evil.test', 'name': 'wrong', 'value': 'x'},
      {
        'domain': '.youtube.com',
        'name': 'injection',
        'value': 'x\n.evil.test\tTRUE',
      },
    ]);
    expect(
      output,
      '# Netscape HTTP Cookie File\r\n'
      '#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t0\ttest_session\tfake-value\r\n',
    );
    expect(
      () => youtubeCookiesToNetscape([_cookies.last]),
      throwsA(isA<YoutubeConnectionException>()),
    );
  });
}

class _Browser implements YoutubeBrowserSession {
  Uri? url;
  Uri? selectedUrl;
  bool closed = false;
  Object? error;

  @override
  Future<void> open(Uri value) async {
    url = value;
    selectedUrl =
        value.path == '/watch' || value.host == 'youtu.be'
            ? value
            : Uri.parse('https://www.youtube.com/watch?v=4YFu4dvMHHY');
    closed = false;
  }

  @override
  Future<Uri> readYoutubeVideoUrl() async {
    if (error != null) throw error!;
    return selectedUrl!;
  }

  @override
  Future<List<Map<String, dynamic>>> readYoutubeCookies() async {
    if (error != null) throw error!;
    return _cookies;
  }

  @override
  Future<void> close() async {
    closed = true;
  }
}
