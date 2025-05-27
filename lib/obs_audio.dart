import 'dart:convert';

import 'package:flutter/services.dart';

class ObsAudio {
  static const _ch = BasicMessageChannel<String>('obs_audio', StringCodec());
  static int _nextId = 1;

  /// Loads an asset, returns a numeric handle.
  static Future<int> load(String asset) async {
    final id = _nextId++;
    await _ch.send(jsonEncode({'cmd': 'load', 'id': id, 'asset': asset}));
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
