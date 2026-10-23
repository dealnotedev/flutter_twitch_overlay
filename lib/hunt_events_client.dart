import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:obssource/data/events.dart';

/// Receives live Hunt events without opening a listener in the OBS source.
class HuntEventsClient {
  final Uri endpoint;
  final Duration reconnectDelay;
  final _kills = StreamController<KillInfo>.broadcast();
  WebSocket? _socket;
  Future<void>? _running;
  Future<void>? _closing;
  Completer<void>? _reconnectWait;
  Timer? _retry;
  bool _closed = false;
  int _attempt = 0;

  HuntEventsClient({
    Uri? endpoint,
    this.reconnectDelay = const Duration(seconds: 2),
  }) : endpoint = endpoint ?? Uri.parse('ws://127.0.0.1:4080/v1/events');

  Stream<KillInfo> get kills => _kills.stream;

  void start() {
    if (_closed || _running != null) return;
    _running = _run();
  }

  Future<void> _run() async {
    while (!_closed) {
      WebSocket? socket;
      final attempt = ++_attempt;
      try {
        final connecting = WebSocket.connect(endpoint.toString());
        // Future.timeout cannot cancel a pending connection. Close late results.
        unawaited(
          connecting.then<void>((connected) {
            if (_closed || attempt != _attempt) unawaited(connected.close());
          }, onError: (Object _) {}),
        );
        socket = await connecting.timeout(const Duration(seconds: 3));
        if (_closed) break;
        _socket = socket;
        socket.pingInterval = const Duration(seconds: 20);
        await for (final message in socket) {
          if (_closed) break;
          final kill = _decode(message);
          if (kill != null) _kills.add(kill);
        }
      } on SocketException {
        // Hunt Stats may start later than OBS or restart while OBS is running.
      } on WebSocketException {
        // Reconnect after the peer closes or rejects the handshake.
      } on HttpException {
        // Another listener may temporarily own the configured endpoint.
      } on TimeoutException {
        // Retry without keeping the source's startup waiting.
      } finally {
        _attempt++;
        _socket = null;
        await socket?.close();
      }
      if (_closed) break;
      final wait = Completer<void>();
      _reconnectWait = wait;
      _retry = Timer(reconnectDelay, wait.complete);
      await wait.future;
      _reconnectWait = null;
    }
  }

  static KillInfo? _decode(dynamic message) {
    if (message is! String || message.length > 65536) return null;
    try {
      final value = jsonDecode(message);
      if (value is! Map<String, dynamic> ||
          value['version'] != 1 ||
          value['type'] != 'kill') {
        return null;
      }
      final text = value['text'];
      final inMatch = value['in_match'];
      final streak = value['in_match_streak'];
      final total = value['total_streak'];
      if (text is! String ||
          inMatch is! int ||
          streak is! int ||
          total is! int ||
          inMatch < 0 ||
          streak < 0 ||
          total < 0) {
        return null;
      }
      return KillInfo(
        text: text,
        inMatch: inMatch,
        inMatchStreak: streak,
        totalStreak: total,
      );
    } on FormatException {
      return null;
    }
  }

  Future<void> close() =>
      _closing ??= () async {
        _closed = true;
        _attempt++;
        _retry?.cancel();
        final wait = _reconnectWait;
        if (wait != null && !wait.isCompleted) wait.complete();
        await _socket?.close();
        await _running;
        await _kills.close();
      }();
}
