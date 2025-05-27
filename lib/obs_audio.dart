import 'dart:convert';

import 'package:flutter/services.dart';

class ObsAudio {
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
    final int id = _idFor(asset);

    await _ch.send(jsonEncode({'cmd': 'load', 'id': id, 'asset': asset}));
    return id;
  }

  static int _idFor(String file) {
    final previous = _slots[file];

    final int id;
    if (previous != null) {
      id = previous;
    } else {
      final next = _allocSlot();
      _slots[file] = next;
      id = next;
    }

    return id;
  }

  /// Loads a file, returns a numeric handle.
  static Future<int> loadFile(String path) async {
    final int id = _idFor(path);

    await _ch.send(
      jsonEncode({'cmd': 'load', 'id': id, 'absolute_path': path}),
    );

    return id;
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
