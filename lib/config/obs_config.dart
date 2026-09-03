import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:obssource/observable_value.dart';

class ObsConfig {
  static const BasicMessageChannel<String> _configCh = BasicMessageChannel(
    'obs_config',
    StringCodec(),
  );

  static const Map<String, Object> _fallbackJson = {
    'music_enabled': true,
    'music_reward_title': 'Play Music',
    'music_max_queue': 10,
    'music_max_duration_seconds': 600,
    'music_cache_max_mb': 2048,
    'music_volume_percent': 70,
    'followers': true,
    'follow_animation_renderer': 'optimized',
    'follow_avatar_resolution': 48,
  };

  ObsConfig() {
    _configCh.setMessageHandler((msg) async {
      if (msg != null) {
        _updateConfig(msg);
      }
      return Future.value('ok');
    });
  }

  final config = ObservableValue(
    current: Config(valid: false, json: _fallbackJson),
  );

  bool getBool(String name, {bool fallback = false}) {
    final value = _value(name);
    return value is bool ? value : fallback;
  }

  String getString(String name, {required String fallback}) {
    final value = _value(name);
    return value is String ? value : fallback;
  }

  int getInt(String name, {required int fallback}) {
    final value = _value(name);
    return value is int ? value : fallback;
  }

  dynamic _value(String name) {
    final current = config.current;
    final json = current.valid ? current.json : _fallbackJson;
    return json is Map<String, dynamic> ? json[name] : null;
  }

  Future<void> init() async {
    final json = await _configCh.send('get_dart_config');
    _updateConfig(json);
  }

  void _updateConfig(String? json) {
    if (json == null) {
      config.set(Config(valid: false, json: _fallbackJson));
      return;
    }

    try {
      final data = jsonDecode(json);
      if (data is! Map<String, dynamic>) {
        config.set(Config(valid: false, json: _fallbackJson));
        return;
      }
      config.set(Config(valid: true, json: data));
    } catch (_) {
      config.set(Config(valid: false, json: _fallbackJson));
    }
  }
}

class Config {
  final bool valid;
  final dynamic json;

  Config({required this.valid, required this.json});
}
