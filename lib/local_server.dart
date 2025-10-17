import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:obssource/data/events.dart';

class LocalServer {
  final _kills = StreamController<KillInfo>.broadcast();

  Stream<KillInfo> get kills => _kills.stream;

  void run() async {
    final server = await HttpServer.bind(InternetAddress.anyIPv4, 4080);
    await server.forEach((HttpRequest request) {
      final uri = request.uri;

      if (uri.path == '/kill') {
        request.response.statusCode == HttpStatus.ok;
        request.response.write(jsonEncode({'status': 'ok'}));

        _kills.add(
          KillInfo(
            text: uri.queryParameters['text'] as String,
            inMatch: int.parse(uri.queryParameters['in_match'] as String),
            inMatchStreak: int.parse(
              uri.queryParameters['in_match_streak'] as String,
            ),
            totalStreak: int.parse(
              uri.queryParameters['total_streak'] as String,
            ),
          ),
        );
      } else {
        request.response.statusCode == HttpStatus.badRequest;
        request.response.write('Very bad request :(');
      }

      request.response.close();
    });
  }
}
