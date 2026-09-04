import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:win32/win32.dart';

class ObsAudio {
  static const _nativeEventTimeout = Duration(seconds: 10);

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

  /// Loads an asset, returns a numeric handle.
  static Future<int> loadAsset(String asset, {String? sessionId}) async {
    final id = _idFor(asset);
    if (id.$2) return id.$1;

    return _load(
      slotKey: asset,
      id: id.$1,
      command: {
        'cmd': 'load',
        'id': id.$1,
        'asset': asset,
        if (sessionId != null) 'session_id': sessionId,
      },
      sessionId: sessionId,
    );
  }

  /// Loads a file, returns a numeric handle.
  static Future<int> loadFile(String path, {String? sessionId}) async {
    final id = _idFor(path);
    if (id.$2) return id.$1;

    return _load(
      slotKey: path,
      id: id.$1,
      command: {
        'cmd': 'load',
        'id': id.$1,
        'absolute_path': path,
        if (sessionId != null) 'session_id': sessionId,
      },
      sessionId: sessionId,
    );
  }

  static Future<int> _load({
    required String slotKey,
    required int id,
    required Map<String, Object?> command,
    required String? sessionId,
  }) async {
    final eventCompleter = Completer<ObsAudioEvent>();
    final subscription = events.listen((event) {
      final matchingSession =
          sessionId == null ||
          event.sessionId == null ||
          event.sessionId == sessionId;
      if (event.id == id &&
          matchingSession &&
          (event.type == ObsAudioEventType.loaded ||
              event.type == ObsAudioEventType.error) &&
          !eventCompleter.isCompleted) {
        eventCompleter.complete(event);
      }
    }, onError: eventCompleter.completeError);

    try {
      final result = await _sendCommand(command);
      if (!result.eventsSupported) return id;

      final event = await eventCompleter.future.timeout(
        _nativeEventTimeout,
        onTimeout:
            () => throw StateError('Native audio load confirmation timed out'),
      );
      if (event.type == ObsAudioEventType.error) {
        throw StateError(event.message ?? 'Native audio load failed');
      }
      return id;
    } catch (_) {
      if (_slots[slotKey] == id) _slots.remove(slotKey);
      rethrow;
    } finally {
      await subscription.cancel();
    }
  }

  /// Returns whether the native host promises lifecycle events for this play.
  static Future<bool> play(
    int id, {
    double volume = 1,
    bool loop = false,
    String? sessionId,
  }) async {
    final result = await _sendCommand({
      'cmd': 'play',
      'id': id,
      'volume': volume,
      'loop': loop,
      if (sessionId != null) 'session_id': sessionId,
    });
    return result.eventsSupported;
  }

  static Future<void> stop(int id) async {
    await _sendCommand({'cmd': 'stop', 'id': id});
  }

  static Future<void> pause(int id) async {
    await _sendCommand({'cmd': 'pause', 'id': id});
  }

  static Future<void> resume(int id) async {
    await _sendCommand({'cmd': 'resume', 'id': id});
  }

  static Future<void> seek(int id, Duration position) async {
    await _sendCommand({
      'cmd': 'seek',
      'id': id,
      'position_ms': position.inMilliseconds,
    });
  }

  static Future<void> setVolume(int id, double volume) async {
    await _sendCommand({'cmd': 'volume', 'id': id, 'volume': volume});
  }

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
      await _sendCommand({'cmd': 'release', 'id': id});
    } on PlatformException {
      // Older native hosts do not implement release yet. The Dart slot is
      // already free, so playback can continue with the next file.
    } on MissingPluginException {
      // Keeps the Flutter-only queue usable with the duration fallback.
    } on StateError {
      // Release is best-effort with older hosts that reject this command.
      // A later load into the same numeric slot replaces the native sound.
    }
  }

  static Future<_ObsAudioCommandResult> _sendCommand(
    Map<String, Object?> command,
  ) async {
    final response = await _ch.send(jsonEncode(command));
    if (response == null || response.isEmpty) {
      return const _ObsAudioCommandResult(eventsSupported: false);
    }

    final decoded = jsonDecode(response);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('Native audio returned an invalid response');
    }
    if (decoded['ok'] != true) {
      final message = decoded['error'];
      throw StateError(
        message is String && message.isNotEmpty
            ? 'Native audio command failed: $message'
            : 'Native audio command failed',
      );
    }
    return _ObsAudioCommandResult(eventsSupported: decoded['events'] == true);
  }
}

class _ObsAudioCommandResult {
  final bool eventsSupported;

  const _ObsAudioCommandResult({required this.eventsSupported});
}

enum ObsAudioEventType { loaded, started, progress, ended, error }

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
      'loaded' => ObsAudioEventType.loaded,
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
