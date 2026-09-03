import 'dart:io';

class MusicToolPaths {
  final String ytDlpExecutable;
  final String? ffmpegLocation;
  final String? denoPath;

  const MusicToolPaths({
    required this.ytDlpExecutable,
    required this.ffmpegLocation,
    required this.denoPath,
  });

  factory MusicToolPaths.resolve({
    required Directory executableDirectory,
    String ytDlpOverride = '',
    String ffmpegOverride = '',
    String denoOverride = '',
    Map<String, String>? environment,
    bool Function(String path)? fileExists,
  }) {
    final exists = fileExists ?? (path) => File(path).existsSync();
    final toolDirectories = [
      _obsPluginToolsDirectory(executableDirectory),
      _join(executableDirectory.path, 'tools'),
    ];
    final bundledYtDlp = _firstExistingFile(
      toolDirectories,
      'yt-dlp.exe',
      exists,
    );
    final bundledFfmpegDirectory = _firstDirectoryContaining(
      toolDirectories,
      const ['ffmpeg.exe', 'ffprobe.exe'],
      exists,
    );
    final bundledDeno = _firstExistingFile(toolDirectories, 'deno.exe', exists);
    final processEnvironment = environment ?? Platform.environment;

    return MusicToolPaths(
      ytDlpExecutable: _override(ytDlpOverride) ?? bundledYtDlp ?? 'yt-dlp.exe',
      ffmpegLocation: _override(ffmpegOverride) ?? bundledFfmpegDirectory,
      denoPath:
          _override(denoOverride) ??
          (bundledDeno ??
              (_isOnPath('deno.exe', processEnvironment, exists)
                  ? 'deno.exe'
                  : null)),
    );
  }

  static String? _override(String value) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static String _obsPluginToolsDirectory(Directory executableDirectory) {
    final architecture =
        executableDirectory.path
            .split(Platform.pathSeparator)
            .where((segment) => segment.isNotEmpty)
            .last;
    final obsRoot = executableDirectory.parent.parent.path;
    return _join(
      _join(_join(obsRoot, 'obs-plugins'), architecture),
      'flutter_obs_tools',
    );
  }

  static String? _firstExistingFile(
    List<String> directories,
    String fileName,
    bool Function(String path) exists,
  ) {
    for (final directory in directories) {
      final candidate = _join(directory, fileName);
      if (exists(candidate)) return candidate;
    }
    return null;
  }

  static String? _firstDirectoryContaining(
    List<String> directories,
    List<String> fileNames,
    bool Function(String path) exists,
  ) {
    for (final directory in directories) {
      if (fileNames.every((fileName) => exists(_join(directory, fileName)))) {
        return directory;
      }
    }
    return null;
  }

  static bool _isOnPath(
    String executable,
    Map<String, String> environment,
    bool Function(String path) exists,
  ) {
    final path = environment['PATH'] ?? environment['Path'] ?? '';
    return path
        .split(Platform.isWindows ? ';' : ':')
        .where((directory) => directory.trim().isNotEmpty)
        .any((directory) => exists(_join(directory.trim(), executable)));
  }

  static String _join(String parent, String child) {
    if (parent.endsWith(Platform.pathSeparator)) return '$parent$child';
    return '$parent${Platform.pathSeparator}$child';
  }
}
