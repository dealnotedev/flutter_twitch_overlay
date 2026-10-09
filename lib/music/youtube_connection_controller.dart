import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/yt_dlp_music_track_fetcher.dart';
import 'package:obssource/music/youtube_browser_session.dart';

enum YoutubeConnectionStatus {
  disconnected,
  opening,
  awaitingVerification,
  checking,
  connected,
}

typedef YoutubeAccessVerifier =
    Future<void> Function(String cookieFile, Uri url);

class YoutubeConnectionController extends ChangeNotifier {
  static final _youtubeUrl = Uri.parse('https://www.youtube.com/');
  final Directory directory;
  final YoutubeBrowserSession browser;
  final YoutubeAccessVerifier verifyAccess;
  final Future<void> Function()? cancelVerification;
  YoutubeConnectionStatus status;
  YoutubeConnectionIssue? issue;
  Uri? checkedVideoUrl;
  String? diagnostic;
  Uri? _verificationUrl;
  bool _closed = false;
  bool _cancelRequested = false;
  Future<void>? _opening;
  Future<void>? _verification;

  YoutubeConnectionController({
    required this.directory,
    required this.browser,
    required this.verifyAccess,
    this.cancelVerification,
  }) : status =
           File(
                 '${directory.path}${Platform.pathSeparator}cookies.txt',
               ).existsSync()
               ? YoutubeConnectionStatus.connected
               : YoutubeConnectionStatus.disconnected;

  File get _cookies =>
      File('${directory.path}${Platform.pathSeparator}cookies.txt');

  String? get cookieFilePath => _cookies.existsSync() ? _cookies.path : null;

  bool get busy =>
      status == YoutubeConnectionStatus.opening ||
      status == YoutubeConnectionStatus.checking;

  void requireVerification(Uri url) =>
      _requireCheck(url, YoutubeConnectionIssue.verificationRequired);

  void requireDownloadCheck(Uri url) =>
      _requireCheck(url, YoutubeConnectionIssue.downloadBlocked);

  void _requireCheck(Uri url, YoutubeConnectionIssue reason) {
    if (_closed) return;
    _verificationUrl = url;
    issue = reason;
    if (!busy && status != YoutubeConnectionStatus.awaitingVerification) {
      status = YoutubeConnectionStatus.disconnected;
    }
    notifyListeners();
  }

  Future<void> connect() {
    if (!_closed && status == YoutubeConnectionStatus.opening) {
      return _opening ?? Future.value();
    }
    if (_closed || busy) return Future.value();
    return _opening = _connect();
  }

  Future<void> _connect() async {
    status = YoutubeConnectionStatus.opening;
    issue = null;
    checkedVideoUrl = null;
    diagnostic = null;
    notifyListeners();
    try {
      await browser.open(_verificationUrl ?? _youtubeUrl);
      if (_closed) return;
      status = YoutubeConnectionStatus.awaitingVerification;
    } catch (error) {
      if (_closed) return;
      issue = _issueFor(error);
      status = YoutubeConnectionStatus.disconnected;
    }
    if (!_closed) notifyListeners();
  }

  Future<void> verify() {
    if (!_closed && status == YoutubeConnectionStatus.checking) {
      return _verification ?? Future.value();
    }
    if (_closed || status != YoutubeConnectionStatus.awaitingVerification) {
      return Future.value();
    }
    _cancelRequested = false;
    return _verification = _verify();
  }

  Future<void> _verify() async {
    status = YoutubeConnectionStatus.checking;
    issue = null;
    diagnostic = null;
    notifyListeners();
    final pending = File('${_cookies.path}.pending');
    try {
      // Use the video the user actually played, including after a restart.
      // A fixed external test video can be removed or region-restricted.
      final url = await browser.readYoutubeVideoUrl();
      checkedVideoUrl = url;
      if (_closed || _cancelRequested) return;
      final cookies = await browser.readYoutubeCookies();
      if (_closed || _cancelRequested) return;
      await directory.create(recursive: true);
      await pending.writeAsString(
        youtubeCookiesToNetscape(cookies),
        flush: true,
      );
      // Do not show success merely because a browser has supplied cookies.
      if (_closed || _cancelRequested) return;
      await verifyAccess(pending.path, url);
      if (_closed || _cancelRequested) return;
      // Close the dedicated browser so YouTube stops rotating this session.
      await browser.close();
      if (_closed || _cancelRequested) return;
      await pending.copy(_cookies.path);
      if (_closed) return;
      status = YoutubeConnectionStatus.connected;
      _verificationUrl = null;
    } catch (error) {
      if (_closed) return;
      issue = _issueFor(error);
      if (error is YtDlpException) {
        // Settings-only support details. Never publish these on the overlay or
        // control protocol. Strip URLs (which may carry media tokens) and paths.
        final detail = (error.diagnostic ?? error.message)
            .replaceAll(RegExp(r'https?://\S+'), '[URL]')
            .replaceAll(RegExp(r'[a-zA-Z]:[\\/][^\r\n]+'), '[local path]')
            .replaceAllMapped(
              RegExp(
                r'(cookie|authorization|token|password)\s*[:=]\s*\S+',
                caseSensitive: false,
              ),
              (match) => '${match[1]}=[redacted]',
            );
        diagnostic =
            '${error.errorType.name}'
            '${error.exitCode == null ? '' : ' (exit ${error.exitCode})'}\n$detail';
      }
      status = YoutubeConnectionStatus.awaitingVerification;
    } finally {
      try {
        if (await pending.exists()) await pending.delete();
      } on FileSystemException {
        issue = YoutubeConnectionIssue.storageUnavailable;
      }
      if (!_closed) notifyListeners();
    }
  }

  Future<void> disconnect() async {
    if (_closed || status == YoutubeConnectionStatus.opening) return;
    if (status == YoutubeConnectionStatus.checking) {
      _cancelRequested = true;
      await cancelVerification?.call();
      await _verification;
    }
    if (_closed) return;
    status = YoutubeConnectionStatus.opening;
    issue = null;
    checkedVideoUrl = null;
    diagnostic = null;
    notifyListeners();
    try {
      await browser.close();
      if (await _cookies.exists()) await _cookies.delete();
      // This is exclusively our profile, under the app's session directory.
      final profile = Directory(
        '${directory.path}${Platform.pathSeparator}browser',
      );
      // Chromium's child processes may release profile files just after the
      // main process exits. Give them a short grace period before reporting an
      // actionable storage error.
      for (var attempt = 0; attempt < 12; attempt++) {
        try {
          if (await profile.exists()) await profile.delete(recursive: true);
          break;
        } on FileSystemException {
          if (attempt == 11) rethrow;
          await Future<void>.delayed(const Duration(milliseconds: 250));
        }
      }
      status = YoutubeConnectionStatus.disconnected;
    } catch (error) {
      issue = _issueFor(error);
      status =
          cookieFilePath == null
              ? YoutubeConnectionStatus.disconnected
              : YoutubeConnectionStatus.connected;
    }
    if (!_closed) notifyListeners();
  }

  static YoutubeConnectionIssue _issueFor(Object error) {
    if (error is YoutubeConnectionException) return error.issue;
    if (error is FileSystemException) {
      return YoutubeConnectionIssue.storageUnavailable;
    }
    if (error is MusicTrackException) {
      return switch (error.errorType) {
        MusicQueueErrorType.youtubeAccessRequired =>
          YoutubeConnectionIssue.verificationRequired,
        MusicQueueErrorType.youtubeDownloadBlocked =>
          YoutubeConnectionIssue.downloadBlocked,
        MusicQueueErrorType.youtubeUnavailable =>
          YoutubeConnectionIssue.videoUnavailable,
        MusicQueueErrorType.trackTooLongOrLive =>
          YoutubeConnectionIssue.videoTooLongOrLive,
        MusicQueueErrorType.networkUnavailable =>
          YoutubeConnectionIssue.networkUnavailable,
        MusicQueueErrorType.musicToolsUnavailable =>
          YoutubeConnectionIssue.toolsUnavailable,
        _ => YoutubeConnectionIssue.checkFailed,
      };
    }
    return YoutubeConnectionIssue.checkFailed;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await cancelVerification?.call();
    await _opening;
    await _verification;
    await browser.close();
    dispose();
  }
}
