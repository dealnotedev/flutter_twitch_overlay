import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:obssource/observable_value.dart';

class ObsConfig {
  static const BasicMessageChannel<String> _configCh = BasicMessageChannel(
    'obs_config',
    StringCodec(),
  );

  ObsConfig() {
    _configCh.setMessageHandler((msg) async {
      print('Config Update $msg');
      if (msg != null) {
        _updateConfig(msg);
      }
      return Future.value('ok');
    });
  }

  final config = ObservableValue(current: Config(valid: false, json: {}));

  bool getBool(String name, {bool fallback = false}) {
    try {
      final value = config.current.json[name];
      return value ?? fallback;
    } catch (_) {
      return false;
    }
  }

  Future<void> init() async {
    final json = await _configCh.send('get_dart_config');
    _updateConfig(json);
  }

  void _updateConfig(String? json) {
    if (json == null) {
      config.set(Config(valid: false, json: {}));
      return;
    }

    try {
      final data = jsonDecode(json);
      config.set(Config(valid: true, json: data));
    } catch (_) {
      config.set(Config(valid: false, json: {}));
    }
  }
}

class Config {
  final bool valid;
  final dynamic json;

  Config({required this.valid, required this.json});
}
