import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:obssource/data/events.dart';

enum KillServerState { stopped, listening, failed }

/// Local HTTP endpoint for an external kill tracker:
/// `GET /kill?text=…&in_match=…&in_match_streak=…&total_streak=…`.
class KillServer {
  final _kills = StreamController<KillInfo>.broadcast();
  HttpServer? _server;
  (String, int)? _binding;
  Future<void> _updates = Future.value();

  /// Shown on the settings page; a failed bind leaves the server stopped.
  final state = ValueNotifier(KillServerState.stopped);

  Stream<KillInfo> get kills => _kills.stream;

  /// Port actually listened on, or `null` while stopped.
  int? get port => _server?.port;

  /// Starts, rebinds or stops the server. A busy port is reported and leaves
  /// the server stopped instead of failing the overlay.
  Future<void> configure({
    required bool enabled,
    required String address,
    required int port,
  }) => _updates = _updates.then((_) => _configure(enabled, address, port));

  Future<void> _configure(bool enabled, String address, int port) async {
    final binding = (address, port);
    if (enabled && _server != null && _binding == binding) return;

    await _server?.close(force: true);
    _server = null;
    _binding = null;
    if (!enabled) {
      state.value = KillServerState.stopped;
      return;
    }

    try {
      final server = await HttpServer.bind(address, port);
      _server = server;
      _binding = binding;
      server.listen(_handle);
      state.value = KillServerState.listening;
    } on SocketException catch (error) {
      debugPrint('Kill server could not listen on $address:$port: $error');
      state.value = KillServerState.failed;
    }
  }

  void _handle(HttpRequest request) {
    final response = request.response;
    final kill =
        request.uri.path == '/kill' ? parse(request.uri.queryParameters) : null;
    if (kill == null) {
      response.statusCode = HttpStatus.badRequest;
      response.write('Very bad request :(');
    } else {
      response.statusCode = HttpStatus.ok;
      response.headers.contentType = ContentType.json;
      response.write(jsonEncode({'status': 'ok'}));
      _kills.add(kill);
    }
    unawaited(response.close());
  }

  static KillInfo? parse(Map<String, String> query) {
    final text = query['text'];
    final inMatch = int.tryParse(query['in_match'] ?? '');
    final inMatchStreak = int.tryParse(query['in_match_streak'] ?? '');
    final totalStreak = int.tryParse(query['total_streak'] ?? '');
    if (text == null ||
        inMatch == null ||
        inMatchStreak == null ||
        totalStreak == null) {
      return null;
    }
    return KillInfo(
      text: text,
      inMatch: inMatch,
      inMatchStreak: inMatchStreak,
      totalStreak: totalStreak,
    );
  }

  Future<void> close() async {
    await configure(enabled: false, address: '', port: 0);
    await _kills.close();
  }
}
