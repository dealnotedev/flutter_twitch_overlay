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

  static final _slots = <String, int>{};

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
        jsonEncode({'cmd': 'load', 'id': id, 'absolute_path': path}),
      );
    }

    return id.$1;
  }

  static Future<void> play(
    int id, {
    double volume = 1,
    bool loop = false,
  }) async {
    await _ch.send(
      jsonEncode({'cmd': 'play', 'id': id, 'volume': volume, 'loop': loop}),
    );
  }

  static Future<void> stop(int id) =>
      _ch.send(jsonEncode({'cmd': 'stop', 'id': id}));

  static Future<void> setVolume(int id, double v) =>
      _ch.send(jsonEncode({'cmd': 'volume', 'id': id, 'volume': v}));
}
