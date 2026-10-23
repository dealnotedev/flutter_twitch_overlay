import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol.dart';
import 'package:obssource/music/ffmpeg_vu_analyzer.dart';
import 'package:obssource/music/music_file_cache.dart';
import 'package:obssource/music/music_tool_paths.dart';
import 'package:obssource/music/music_vu_profile.dart';

typedef MusicVuAnalysis = Future<MusicVuProfile> Function(String audioPath);

/// Optional, non-blocking analysis. Missing tools or profiles never stop music.
class MusicVuProfiles {
  final MusicFileCache cache;
  final FfmpegVuAnalyzer _analyzer;
  late final MusicVuAnalysis _analyze;
  final _pending = <String, Future<MusicVuProfile?>>{};
  Future<void> _tail = Future.value();
  bool _closed = false;

  MusicVuProfiles({
    required this.cache,
    required String ffmpegExecutable,
    MusicVuAnalysis? analyze,
  }) : _analyzer = FfmpegVuAnalyzer(executable: ffmpegExecutable) {
    _analyze = analyze ?? _analyzer.analyze;
  }

  factory MusicVuProfiles.defaultCache() {
    final tools = MusicToolPaths.resolve(
      executableDirectory: File(Platform.resolvedExecutable).parent,
    );
    return MusicVuProfiles(
      cache: MusicFileCache(
        rootDirectory: defaultMusicCacheDirectory(),
        maxBytes: 0,
      ),
      ffmpegExecutable: tools.ffmpegExecutable,
    );
  }

  Future<MusicVuProfile?> loadFor(MusicQueueItem item) async {
    if (_closed) return null;
    final videoId = _videoId(item.sourceUrl);
    if (videoId == null) return null;
    final audioPath = await cache.findExisting(videoId);
    return audioPath == null ? null : prepare(audioPath);
  }

  Future<MusicVuProfile?> prepare(String audioPath) {
    if (_closed) return Future.value(null);
    final path = File(audioPath).absolute.path;
    final key = Platform.isWindows ? path.toLowerCase() : path;
    return _pending.putIfAbsent(key, () {
      final result = _tail
          .then((_) => _obtain(path))
          .catchError((Object error) {
            if (!_closed) debugPrint('Music VU analysis unavailable: $error');
            return null;
          })
          .whenComplete(() {
            _pending.remove(key);
          });
      // Serialize analysis so a prepared queue cannot start many FFmpeg jobs.
      _tail = result.then<void>((_) {});
      return result;
    });
  }

  Future<String> _digest(File file) async =>
      (await sha256.bind(file.openRead()).first).toString();

  Future<MusicVuProfile?> _obtain(String path) async {
    if (_closed) return null;
    final audio = File(path);
    final digest = await _digest(audio);
    if (_closed) return null;
    final sidecar = File('$path${MusicFileCache.vuProfileSuffix}');
    try {
      if (await sidecar.exists() && await sidecar.length() <= 8 * 1024 * 1024) {
        final json = jsonDecode(await sidecar.readAsString());
        if (json is Map<String, dynamic> &&
            json['version'] == 1 &&
            json['audioSha256'] == digest) {
          return MusicVuProfile.fromJson(json);
        }
      }
    } on FormatException {
      // Corrupt or outdated profiles are regenerated from the audio.
    } on FileSystemException {
      // Another process may replace or evict a cache entry.
    }
    if (_closed) return null;
    final profile = await _analyze(path);
    if (_closed || await _digest(audio) != digest) return null;
    final temporary = File(
      '${audio.parent.path}${Platform.pathSeparator}.staging${Platform.pathSeparator}'
      '${audio.uri.pathSegments.last}${MusicFileCache.vuProfileSuffix}.$pid.${DateTime.now().microsecondsSinceEpoch}.tmp',
    );
    try {
      await temporary.parent.create(recursive: true);
      await temporary.writeAsString(
        jsonEncode({'version': 1, 'audioSha256': digest, ...profile.toJson()}),
        flush: true,
      );
      if (!_closed) await temporary.rename(sidecar.path);
    } on FileSystemException {
      // The measured profile remains usable if the cache is read-only.
    } finally {
      try {
        if (await temporary.exists()) await temporary.delete();
      } on FileSystemException {
        /* best effort */
      }
    }
    return _closed ? null : profile;
  }

  Future<void> close() async {
    _closed = true;
    await _analyzer.close();
    await _tail;
  }

  static String? _videoId(Uri url) {
    final host = url.host.toLowerCase();
    String? id;
    if (host == 'youtu.be') {
      id = url.pathSegments.firstOrNull;
    } else if (host == 'youtube.com' || host.endsWith('.youtube.com')) {
      id = url.queryParameters['v'];
      if (id == null &&
          url.pathSegments.length >= 2 &&
          const [
            'shorts',
            'embed',
            'live',
            'v',
          ].contains(url.pathSegments.first)) {
        id = url.pathSegments[1];
      }
    }
    return id != null && RegExp(r'^[A-Za-z0-9_-]{1,128}$').hasMatch(id)
        ? id
        : null;
  }
}
