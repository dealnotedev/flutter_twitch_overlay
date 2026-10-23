import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obssource/music/control/music_control_server.dart';
import 'package:dart_music_player_protocol/dart_music_player_protocol.dart';

enum MusicControlServerStatus { stopped, starting, running, failed }

/// Serializes listener replacement so changing ports never creates two servers.
class MusicControlServerController extends ChangeNotifier {
  final MusicRequests requests;
  MusicControlServer? _server;
  int? _requestedPort;
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
      if (enabled &&
          _server?.isRunning == true &&
          (_requestedPort == port || _server?.port == port)) {
        _requestedPort = port;
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
        _requestedPort = null;
        if (enabled && !_closed) {
          var server = MusicControlServer(
            requests: requests,
            requestedPort: port,
          );
          _server = server;
          try {
            await server.start();
          } on SocketException {
            // Dart also rejects duplicate binds within one VM without an OS code.
            if (port == 0) rethrow;
            await server.close();
            server = MusicControlServer(requests: requests, requestedPort: 0);
            _server = server;
            await server.start();
          }
          _requestedPort = port;
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
