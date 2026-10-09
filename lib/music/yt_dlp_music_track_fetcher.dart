import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_requests.dart';

typedef MusicProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

class YtDlpException extends MusicTrackException {
  final int? exitCode;
  final String? diagnostic;

  const YtDlpException(
    super.message, {
    this.exitCode,
    this.diagnostic,
    super.errorType,
  });
}

class YtDlpMusicTrackFetcher implements MusicTrackFetcher {
  static const _filePrefix = 'YT_FILE:';
  static const _progressPrefix = 'YT_PROGRESS|';
  static const _postProcessMarker = 'YT_POSTPROCESS';

  final String executable;
  final String? ffmpegLocation;
  final String? denoPath;
  final MusicFileCache cache;
  final Duration inspectTimeout;
  final Duration downloadTimeout;
  final MusicProcessStarter _processStarter;
  final String? Function()? cookieFilePath;
  final void Function(Uri sourceUrl)? onAccessRequired;
  final void Function(Uri sourceUrl)? onDownloadBlocked;

  Process? _activeProcess;

  YtDlpMusicTrackFetcher({
    required this.executable,
    required this.ffmpegLocation,
    required this.denoPath,
    required this.cache,
    this.inspectTimeout = const Duration(seconds: 20),
    this.downloadTimeout = const Duration(minutes: 15),
    MusicProcessStarter? processStarter,
    this.cookieFilePath,
    this.onAccessRequired,
    this.onDownloadBlocked,
  }) : _processStarter = processStarter ?? _startProcess;

  @override
  Future<MusicTrackMetadata> inspect(Uri sourceUrl) async {
    final result = await _runCollectingOutput([
      '--ignore-config',
      '--no-colors',
      '--encoding',
      'utf-8',
      '--no-playlist',
      '--skip-download',
      '--dump-single-json',
      ..._runtimeArguments,
      ..._sessionArguments,
      sourceUrl.toString(),
    ], timeout: inspectTimeout);

    if (result.exitCode != 0) {
      throw _failure(sourceUrl, result.stderr, result.exitCode);
    }

    try {
      final json = jsonDecode(result.stdout);
      if (json is! Map<String, dynamic>) {
        throw const FormatException('Expected a JSON object');
      }

      if (json['is_live'] == true || json['live_status'] == 'is_live') {
        throw const YtDlpException(
          'Live streams are not supported',
          errorType: MusicQueueErrorType.trackTooLongOrLive,
        );
      }

      final seconds = json['duration'];
      if (seconds is! num || seconds <= 0) {
        throw const YtDlpException('Video duration is unavailable');
      }

      final videoId = json['id'];
      final title = json['title'];
      if (videoId is! String || title is! String) {
        throw const YtDlpException('YouTube metadata is incomplete');
      }

      final thumbnail = json['thumbnail'];

      return MusicTrackMetadata(
        videoId: videoId,
        title: title,
        author: (json['uploader'] as String?) ?? 'YouTube',
        duration: Duration(seconds: seconds.round()),
        thumbnail:
            thumbnail is String && thumbnail.isNotEmpty
                ? Uri.tryParse(thumbnail)
                : null,
        sourceUrl:
            Uri.tryParse(json['webpage_url'] as String? ?? '') ?? sourceUrl,
      );
    } on YtDlpException {
      rethrow;
    } catch (error) {
      throw YtDlpException('Invalid yt-dlp metadata: $error');
    }
  }

  @override
  Future<String> obtain({
    required MusicTrackMetadata metadata,
    required void Function(MusicDownloadProgress progress) onProgress,
  }) => cache.obtain(
    videoId: metadata.videoId,
    produce:
        (stagingDirectory) => _download(
          sourceUrl: metadata.sourceUrl,
          stagingDirectory: stagingDirectory,
          onProgress: onProgress,
        ),
  );

  Future<File> _download({
    required Uri sourceUrl,
    required Directory stagingDirectory,
    required void Function(MusicDownloadProgress progress) onProgress,
  }) async {
    final expectedFile = File(
      '${stagingDirectory.path}${Platform.pathSeparator}audio.mp3',
    );

    final args = <String>[
      '--ignore-config',
      '--no-colors',
      '--encoding',
      'utf-8',
      '--no-playlist',
      '--format',
      'ba/b',
      '--extract-audio',
      '--audio-format',
      'mp3',
      '--audio-quality',
      '0',
      if (ffmpegLocation case final String location) ...[
        '--ffmpeg-location',
        location,
      ],
      '--paths',
      stagingDirectory.path,
      '--output',
      'audio.%(ext)s',
      '--newline',
      '--progress',
      '--progress-delta',
      '0.5',
      '--progress-template',
      'download:$_progressPrefix%(progress.downloaded_bytes)s|'
          '%(progress.total_bytes)s|%(progress.total_bytes_estimate)s|'
          '%(progress.eta)s',
      '--progress-template',
      'postprocess:$_postProcessMarker',
      '--print',
      'after_move:$_filePrefix%(filepath)s',
      ..._runtimeArguments,
      ..._sessionArguments,
      sourceUrl.toString(),
    ];

    final stderr = StringBuffer();
    String? finalPath;
    final process = await _start(args);

    void handleLine(String line, {required bool isErrorOutput}) {
      if (line.startsWith(_progressPrefix)) {
        final values = line.substring(_progressPrefix.length).split('|');
        if (values.length >= 4) {
          final downloaded = _parseInt(values[0]) ?? 0;
          final total = _parseInt(values[1]) ?? _parseInt(values[2]);
          final etaSeconds = _parseInt(values[3]);
          onProgress(
            MusicDownloadProgress(
              downloadedBytes: downloaded,
              totalBytes: total,
              eta: etaSeconds == null ? null : Duration(seconds: etaSeconds),
            ),
          );
        }
        return;
      }

      if (line == _postProcessMarker) {
        return;
      }

      if (line.startsWith(_filePrefix)) {
        finalPath = line.substring(_filePrefix.length).trim();
        return;
      }

      if (isErrorOutput && line.trim().isNotEmpty) {
        stderr.writeln(line);
      }
    }

    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => handleLine(line, isErrorOutput: false));
    final stderrDone = process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach((line) => handleLine(line, isErrorOutput: true));

    try {
      final exitCode = await process.exitCode.timeout(
        downloadTimeout,
        onTimeout: () {
          process.kill();
          throw const YtDlpException(
            'Unable to reach YouTube. Check your internet connection.',
            errorType: MusicQueueErrorType.networkUnavailable,
          );
        },
      );
      await Future.wait([stdoutDone, stderrDone]);

      if (exitCode != 0) {
        throw _failure(sourceUrl, stderr.toString(), exitCode);
      }

      final path = finalPath ?? expectedFile.path;
      final file = File(path);
      if (!await file.exists() || await file.length() == 0) {
        throw const YtDlpException('yt-dlp did not produce an audio file');
      }

      if (!_isInside(file, stagingDirectory)) {
        throw const YtDlpException(
          'yt-dlp returned a file outside the staging directory',
        );
      }

      return file;
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  List<String> get _runtimeArguments {
    final path = denoPath;
    if (path == null || path.isEmpty) return const [];
    return ['--js-runtimes', 'deno:$path'];
  }

  List<String> get _sessionArguments {
    final path = cookieFilePath?.call();
    return path == null || path.isEmpty ? const [] : ['--cookies', path];
  }

  YtDlpException _failure(Uri sourceUrl, String stderr, int exitCode) {
    final text = stderr.toLowerCase();
    var type = MusicQueueErrorType.operationFailed;
    var message = 'Unable to prepare this track. Please try again later.';
    if (text.contains('unable to download video data') &&
        text.contains('http error 403')) {
      type = MusicQueueErrorType.youtubeDownloadBlocked;
      message =
          'YouTube blocked this audio download (403). Reconnect YouTube '
          'in Music settings. If the video plays but the check still fails, '
          'try signing in in the opened browser and check again.';
      onDownloadBlocked?.call(sourceUrl);
    } else if (text.contains('sign in to confirm') ||
        text.contains('not a bot') ||
        text.contains('use --cookies') ||
        text.contains('cookies are no longer valid') ||
        text.contains('login required')) {
      type = MusicQueueErrorType.youtubeAccessRequired;
      message =
          'YouTube needs verification. Open Music settings to connect '
          'YouTube, then try again.';
      onAccessRequired?.call(sourceUrl);
    } else if (text.contains('private video') ||
        text.contains('video unavailable') ||
        text.contains('video has been removed') ||
        text.contains('not available in your country')) {
      type = MusicQueueErrorType.youtubeUnavailable;
      message = 'This YouTube video is unavailable. Please choose another.';
    } else if (text.contains('timed out') ||
        text.contains('unable to download webpage') ||
        text.contains('name resolution') ||
        text.contains('failed to resolve') ||
        text.contains('network is unreachable')) {
      type = MusicQueueErrorType.networkUnavailable;
      message = 'Unable to reach YouTube. Check your internet connection.';
    } else if (text.contains('ffmpeg not found') ||
        text.contains('ffprobe and ffmpeg not found') ||
        text.contains('no supported javascript runtime')) {
      type = MusicQueueErrorType.musicToolsUnavailable;
      message = 'Music components are unavailable. Reinstall the application.';
    }
    return YtDlpException(
      message,
      errorType: type,
      exitCode: exitCode,
      diagnostic: _errorMessage('yt-dlp', stderr),
    );
  }

  Future<_ProcessOutput> _runCollectingOutput(
    List<String> args, {
    required Duration timeout,
  }) async {
    final process = await _start(args);
    final stdoutFuture = process.stdout.transform(utf8.decoder).join();
    final stderrFuture = process.stderr.transform(utf8.decoder).join();

    try {
      final exitCode = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          throw const YtDlpException(
            'Unable to reach YouTube. Check your internet connection.',
            errorType: MusicQueueErrorType.networkUnavailable,
          );
        },
      );
      return _ProcessOutput(
        exitCode: exitCode,
        stdout: await stdoutFuture,
        stderr: await stderrFuture,
      );
    } finally {
      if (identical(_activeProcess, process)) {
        _activeProcess = null;
      }
    }
  }

  Future<Process> _start(List<String> args) async {
    if (_activeProcess != null) {
      throw const YtDlpException('Another yt-dlp operation is already running');
    }

    try {
      final process = await _processStarter(executable, args);
      _activeProcess = process;
      return process;
    } on ProcessException catch (error) {
      throw YtDlpException(
        'Music components are unavailable. Reinstall the application.',
        errorType: MusicQueueErrorType.musicToolsUnavailable,
        diagnostic: 'Unable to start $executable: ${error.message}',
      );
    }
  }

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments,
  ) => Process.start(executable, arguments, runInShell: false);

  static bool _isInside(File file, Directory directory) {
    String normalize(String path) {
      final absolute = File(path).absolute.path.replaceAll('\\', '/');
      return Platform.isWindows ? absolute.toLowerCase() : absolute;
    }

    final staging = normalize(directory.path);
    final candidate = normalize(file.path);
    return candidate.startsWith('$staging/');
  }

  static int? _parseInt(String value) {
    if (value == 'NA' || value.isEmpty) return null;
    return num.tryParse(value)?.round();
  }

  static String _errorMessage(String prefix, String stderr) {
    final detail = stderr.trim();
    if (detail.isEmpty) return prefix;
    // Warnings may precede the failure, and long help URLs may follow it.
    // Keep the actual error and its beginning so the reason stays visible.
    final errorStart = RegExp(
      r'^\s*ERROR:',
      multiLine: true,
    ).firstMatch(detail);
    final relevant =
        errorStart == null ? detail : detail.substring(errorStart.start);
    final compact = relevant.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (compact.length <= 240) return '$prefix: $compact';
    return '$prefix: ${compact.substring(0, 237)}...';
  }

  @override
  Future<void> cancel() async {
    final process = _activeProcess;
    _activeProcess = null;
    process?.kill();
  }
}

class _ProcessOutput {
  final int exitCode;
  final String stdout;
  final String stderr;

  const _ProcessOutput({
    required this.exitCode,
    required this.stdout,
    required this.stderr,
  });
}
