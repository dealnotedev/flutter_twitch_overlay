import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:obssource/music/control/music_control_server.dart';
import 'package:obssource/music/music_requests.dart';

enum MusicControlServerStatus { stopped, starting, running, failed }

/// Serializes listener replacement so changing ports never creates two servers.
class MusicControlServerController extends ChangeNotifier {
  final MusicRequests requests;
  MusicControlServer? _server;
  Future<void> _pending = Future.value();
  bool _closed = false;
  MusicControlServerStatus status = MusicControlServerStatus.stopped;
  String? error;

  MusicControlServerController({required this.requests});

  int? get port => _server?.port;

  Future<void> configure({required bool enabled, required int port}) {
    if (_closed) return Future.value();
    return _pending = _pending.then((_) async {
      if (_closed) return;
      if (enabled && _server?.isRunning == true && _server?.port == port) {
        return;
      }
      error = null;
      status =
          enabled
              ? MusicControlServerStatus.starting
              : MusicControlServerStatus.stopped;
      notifyListeners();
      try {
        await _server?.close();
        _server = null;
        if (enabled && !_closed) {
          final server = MusicControlServer(
            requests: requests,
            requestedPort: port,
          );
          _server = server;
          await server.start();
          status = MusicControlServerStatus.running;
        }
      } catch (failure) {
        error = failure.toString();
        status = MusicControlServerStatus.failed;
      }
      if (!_closed) notifyListeners();
    });
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    await _server?.close();
    _server = null;
    dispose();
  }
}
