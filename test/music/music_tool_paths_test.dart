import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/music_tool_paths.dart';

void main() {
  final separator = Platform.pathSeparator;
  final appDirectory = Directory('${separator}app');
  final bundledDirectory = '${appDirectory.path}${separator}tools';

  test('prefers OBS plugin tools without requiring ffprobe', () {
    final obsExecutableDirectory = Directory(
      '${separator}obs${separator}bin${separator}64bit',
    );
    final pluginDirectory =
        '${separator}obs${separator}obs-plugins${separator}64bit'
        '${separator}flutter_obs_tools';
    final pluginFiles = {
      '$pluginDirectory${separator}yt-dlp.exe',
      '$pluginDirectory${separator}ffmpeg.exe',
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

  test('uses bundled ffmpeg without requiring ffprobe', () {
    final bundledFiles = {
      '$bundledDirectory${separator}yt-dlp.exe',
      '$bundledDirectory${separator}ffmpeg.exe',
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

  test('does not mistake a leftover ffprobe for ffmpeg', () {
    final paths = MusicToolPaths.resolve(
      executableDirectory: appDirectory,
      environment: const {},
      fileExists: (path) => path == '$bundledDirectory${separator}ffprobe.exe',
    );

    expect(paths.ffmpegLocation, isNull);
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
