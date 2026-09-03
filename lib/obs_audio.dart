import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

class ObsAudio {
  static void playWavAssetsDebug(String asset) {
    final file =
        '${File(Platform.resolvedExecutable).parent.path}\\data\\flutter_assets\\$asset';

    PlaySound(TEXT(file), NULL, SND_FILENAME | SND_ASYNC);
  }

  static const _ch = BasicMessageChannel<String>('obs_audio', StringCodec());
  static const _eventsCh = BasicMessageChannel<String>(
    'obs_audio_events',
    StringCodec(),
  );

  static final _slots = <String, int>{};
  static final _events = StreamController<ObsAudioEvent>.broadcast();
  static bool _eventsInitialized = false;

  static Stream<ObsAudioEvent> get events {
    _ensureEventsInitialized();
    return _events.stream;
  }

  static void _ensureEventsInitialized() {
    if (_eventsInitialized) return;
    _eventsInitialized = true;

    _eventsCh.setMessageHandler((message) async {
      if (message == null) return 'ignored';

      try {
        final json = jsonDecode(message);
        if (json is Map<String, dynamic>) {
          final event = ObsAudioEvent.fromJson(json);
          if (event != null) {
            _events.add(event);
          }
        }
      } catch (_) {
        // Native audio diagnostics must not break playback state handling.
      }

      return 'ok';
    });
  }

  static int _allocSlot() {
    for (var id = 0; id < 256; id++) {
      if (_slots.containsValue(id)) {
        continue;
      }
      return id;
    }
    throw StateError('All 256 audio slots are in use!');
  }

  /// Loads an asset, returns a numeric handle.
  static Future<int> loadAsset(String asset) async {
    final id = _idFor(asset);

    if (!id.$2) {
      await _ch.send(jsonEncode({'cmd': 'load', 'id': id.$1, 'asset': asset}));
    }

    return id.$1;
  }

  static (int, bool) _idFor(String file) {
    final previous = _slots[file];

    final bool reuse;
    final int id;

    if (previous != null) {
      id = previous;
      reuse = true;
    } else {
      final next = _allocSlot();
      _slots[file] = next;
      id = next;
      reuse = false;
    }

    return (id, reuse);
  }

  /// Loads a file, returns a numeric handle.
  static Future<int> loadFile(String path) async {
    final id = _idFor(path);

    if (!id.$2) {
      await _ch.send(
        jsonEncode({'cmd': 'load', 'id': id.$1, 'absolute_path': path}),
      );
    }

    return id.$1;
  }

  static Future<void> play(
    int id, {
    double volume = 1,
    bool loop = false,
    String? sessionId,
  }) async {
    await _ch.send(
      jsonEncode({
        'cmd': 'play',
        'id': id,
        'volume': volume,
        'loop': loop,
        if (sessionId != null) 'session_id': sessionId,
      }),
    );
  }

  static Future<void> stop(int id) =>
      _ch.send(jsonEncode({'cmd': 'stop', 'id': id}));

  static Future<void> pause(int id) =>
      _ch.send(jsonEncode({'cmd': 'pause', 'id': id}));

  static Future<void> resume(int id) =>
      _ch.send(jsonEncode({'cmd': 'resume', 'id': id}));

  static Future<void> seek(int id, Duration position) => _ch.send(
    jsonEncode({
      'cmd': 'seek',
      'id': id,
      'position_ms': position.inMilliseconds,
    }),
  );

  static Future<void> setVolume(int id, double v) =>
      _ch.send(jsonEncode({'cmd': 'volume', 'id': id, 'volume': v}));

  static Future<void> release(int id) async {
    String? slotKey;
    for (final entry in _slots.entries) {
      if (entry.value == id) {
        slotKey = entry.key;
        break;
      }
    }

    if (slotKey != null) {
      _slots.remove(slotKey);
    }

    try {
      await _ch.send(jsonEncode({'cmd': 'release', 'id': id}));
    } on PlatformException {
      // Older native hosts do not implement release yet. The Dart slot is
      // already free, so playback can continue with the next file.
    } on MissingPluginException {
      // Keeps the Flutter-only queue usable with the duration fallback.
    }
  }
}

enum ObsAudioEventType { started, progress, ended, error }

class ObsAudioEvent {
  final ObsAudioEventType type;
  final int id;
  final String? sessionId;
  final Duration? position;
  final Duration? duration;
  final String? message;

  const ObsAudioEvent({
    required this.type,
    required this.id,
    required this.sessionId,
    required this.position,
    required this.duration,
    required this.message,
  });

  static ObsAudioEvent? fromJson(Map<String, dynamic> json) {
    final id = json['id'];
    final type = switch (json['event']) {
      'started' => ObsAudioEventType.started,
      'progress' => ObsAudioEventType.progress,
      'ended' => ObsAudioEventType.ended,
      'error' => ObsAudioEventType.error,
      _ => null,
    };

    if (id is! int || type == null) return null;

    Duration? milliseconds(dynamic value) {
      return value is num ? Duration(milliseconds: value.round()) : null;
    }

    return ObsAudioEvent(
      type: type,
      id: id,
      sessionId: json['session_id'] as String?,
      position: milliseconds(json['position_ms']),
      duration: milliseconds(json['duration_ms']),
      message: json['message'] as String?,
    );
  }
}
