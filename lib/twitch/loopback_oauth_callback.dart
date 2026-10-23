import 'dart:async';
import 'dart:io';
import 'dart:math';

/// Uses ownership of the callback socket to serialize logins across engines.
class LoopbackOAuthCallback {
  final Uri callback;
  final Future<void> Function(Uri) openBrowser;
  final Duration timeout;
  final Duration retryDelay;
  HttpServer? _server;
  Future<String?>? _pending;
  Future<void>? _closing;
  Timer? _retry;
  Completer<void>? _waiting;
  bool _closed = false;

  LoopbackOAuthCallback({
    required this.openBrowser,
    Uri? callback,
    this.timeout = const Duration(minutes: 3),
    this.retryDelay = const Duration(milliseconds: 100),
  }) : callback = callback ?? Uri.parse('http://localhost:3000');

  Future<String?> request(Uri authorization) {
    if (_closed) return Future.value();
    return _pending ??= _request(
      authorization,
    ).whenComplete(() => _pending = null);
  }

  Future<String?> _request(Uri authorization) async {
    final random = Random.secure();
    final state =
        List.generate(
          24,
          (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
        ).join();
    final deadline = DateTime.now().add(timeout);
    Duration remaining() {
      final value = deadline.difference(DateTime.now());
      if (value <= Duration.zero) {
        throw TimeoutException('Twitch sign-in timed out');
      }
      return value;
    }

    HttpServer? server;
    try {
      while (!_closed && server == null) {
        remaining();
        try {
          server = await HttpServer.bind(callback.host, callback.port);
        } on SocketException {
          final wait = Completer<void>();
          _waiting = wait;
          final left = remaining();
          _retry = Timer(left < retryDelay ? left : retryDelay, wait.complete);
          await wait.future;
          _waiting = null;
        }
      }
      if (_closed || server == null) return null;
      _server = server;
      await openBrowser(
        authorization.replace(
          queryParameters: {...authorization.queryParameters, 'state': state},
        ),
      );
      if (_closed) return null;
      final requests = StreamIterator<HttpRequest>(server);
      while (!_closed && await requests.moveNext().timeout(remaining())) {
        final request = requests.current;
        final code = request.uri.queryParameters['code'];
        final denied = request.uri.queryParameters.containsKey('error');
        if (request.method != 'GET' ||
            request.uri.path != (callback.path.isEmpty ? '/' : callback.path) ||
            (!denied && (code == null || code.isEmpty))) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
          continue;
        }
        if (request.uri.queryParameters['state'] != state) {
          request.response.statusCode = HttpStatus.badRequest;
          await request.response.close();
          continue;
        }
        request.response.headers.contentType = ContentType.html;
        request.response.write(
          denied
              ? '<!doctype html><title>Twitch sign-in</title><p>Sign-in was cancelled. You can close this window.</p>'
              : '<!doctype html><title>Twitch sign-in</title><p>Sign-in received. You can close this window.</p>',
        );
        await request.response.close();
        return denied ? null : code;
      }
      return null;
    } finally {
      _retry?.cancel();
      _waiting = null;
      _server = null;
      await server?.close(force: true);
    }
  }

  Future<void> close() =>
      _closing ??= () async {
        _closed = true;
        _retry?.cancel();
        final waiting = _waiting;
        if (waiting != null && !waiting.isCompleted) waiting.complete();
        await _server?.close(force: true);
        try {
          await _pending;
        } catch (_) {
          // The sign-in caller receives errors; disposal only releases resources.
        }
      }();
}
