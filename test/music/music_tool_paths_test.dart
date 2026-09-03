import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_tool_paths.dart';

void main() {
  final separator = Platform.pathSeparator;
  final appDirectory = Directory('${separator}app');
  final bundledDirectory = '${appDirectory.path}${separator}tools';

  test('prefers the OBS plugin tools directory', () {
    final obsExecutableDirectory = Directory(
      '${separator}obs${separator}bin${separator}64bit',
    );
    final pluginDirectory =
        '${separator}obs${separator}obs-plugins${separator}64bit'
        '${separator}flutter_obs_tools';
    final pluginFiles = {
      '$pluginDirectory${separator}yt-dlp.exe',
      '$pluginDirectory${separator}ffmpeg.exe',
      '$pluginDirectory${separator}ffprobe.exe',
      '$pluginDirectory${separator}deno.exe',
    };

    final paths = MusicToolPaths.resolve(
      executableDirectory: obsExecutableDirectory,
      fileExists: pluginFiles.contains,
    );

    expect(paths.ytDlpExecutable, '$pluginDirectory${separator}yt-dlp.exe');
    expect(paths.ffmpegLocation, pluginDirectory);
    expect(paths.denoPath, '$pluginDirectory${separator}deno.exe');
  });

  test('explicit configuration overrides bundled tools', () {
    final paths = MusicToolPaths.resolve(
      executableDirectory: appDirectory,
      ytDlpOverride: '${separator}custom${separator}yt-dlp.exe',
      ffmpegOverride: '${separator}custom${separator}ffmpeg',
      denoOverride: '${separator}custom${separator}deno.exe',
      fileExists: (_) => true,
    );

    expect(paths.ytDlpExecutable, '${separator}custom${separator}yt-dlp.exe');
    expect(paths.ffmpegLocation, '${separator}custom${separator}ffmpeg');
    expect(paths.denoPath, '${separator}custom${separator}deno.exe');
  });

  test('uses complete tools directory beside the application', () {
    final bundledFiles = {
      '$bundledDirectory${separator}yt-dlp.exe',
      '$bundledDirectory${separator}ffmpeg.exe',
      '$bundledDirectory${separator}ffprobe.exe',
      '$bundledDirectory${separator}deno.exe',
    };

    final paths = MusicToolPaths.resolve(
      executableDirectory: appDirectory,
      fileExists: bundledFiles.contains,
    );

    expect(paths.ytDlpExecutable, '$bundledDirectory${separator}yt-dlp.exe');
    expect(paths.ffmpegLocation, bundledDirectory);
    expect(paths.denoPath, '$bundledDirectory${separator}deno.exe');
  });

  test('falls back to PATH when bundled tools are absent', () {
    final pathDirectory = '${separator}runtime';
    final paths = MusicToolPaths.resolve(
      executableDirectory: appDirectory,
      environment: {'PATH': pathDirectory},
      fileExists: (path) => path == '$pathDirectory${separator}deno.exe',
    );

    expect(paths.ytDlpExecutable, 'yt-dlp.exe');
    expect(paths.ffmpegLocation, isNull);
    expect(paths.denoPath, 'deno.exe');
  });
}
