import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/hunt_events_client.dart';

const _kill = {
  'version': 1,
  'type': 'kill',
  'text': 'Double Kill',
  'in_match': 2,
  'in_match_streak': 2,
  'total_streak': 4,
};

void main() {
  late HttpServer server;
  late List<WebSocket> peers;
  late List<HuntEventsClient> clients;

  Future<void> listen(int port) async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    server.listen((request) async {
      expect(request.uri.path, '/v1/events');
      final peer = await WebSocketTransformer.upgrade(request);
      peers.add(peer);
      peer.listen((_) {}, onError: (Object _) {});
    });
  }

  setUp(() async {
    peers = [];
    clients = [];
    await listen(0);
  });

  tearDown(() async {
    for (final client in clients) {
      await client.close();
    }
    for (final peer in peers) {
      await peer.close();
    }
    await server.close(force: true);
  });

  HuntEventsClient start() {
    final client = HuntEventsClient(
      endpoint: Uri.parse('ws://127.0.0.1:${server.port}/v1/events'),
      reconnectDelay: const Duration(milliseconds: 10),
    );
    clients.add(client);
    client.start();
    return client;
  }

  test('two source clients receive the same live kill independently', () async {
    final a = start();
    final b = start();
    await _until(() => peers.length == 2);
    final results = Future.wait([a.kills.first, b.kills.first]);
    for (final peer in peers) {
      peer.add(jsonEncode(_kill));
    }
    for (final event in await results.timeout(const Duration(seconds: 2))) {
      expect(event.text, 'Double Kill');
      expect(event.inMatch, 2);
      expect(event.inMatchStreak, 2);
      expect(event.totalStreak, 4);
    }
  });

  test(
    'malformed and unrelated events are ignored without disconnecting',
    () async {
      final client = start();
      await _until(() => peers.length == 1);
      final next = client.kills.first;
      for (final bad in [
        '{broken',
        '[]',
        'null',
        jsonEncode({'version': 1, 'type': 'ready'}),
        jsonEncode({..._kill, 'version': 2}),
        jsonEncode({..._kill, 'in_match': '2'}),
        jsonEncode({..._kill, 'total_streak': -1}),
      ]) {
        peers.single.add(bad);
      }
      peers.single.add(jsonEncode(_kill));
      expect(
        (await next.timeout(const Duration(seconds: 2))).text,
        'Double Kill',
      );
      expect(peers, hasLength(1));
    },
  );

  test(
    'a source reconnects after Hunt restarts and closes its retry loop',
    () async {
      final client = start();
      client.start();
      await _until(() => peers.length == 1);
      final port = server.port;
      await peers.single.close();
      await server.close(force: true);
      peers.clear();
      await listen(port);
      await _until(() => peers.length == 1);
      final next = client.kills.first;
      peers.single.add(jsonEncode(_kill));
      expect((await next.timeout(const Duration(seconds: 2))).inMatch, 2);
      await client.close();
      await client.close();
      peers.clear();
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(peers, isEmpty);
    },
  );
}

Future<void> _until(bool Function() condition) async {
  final end = DateTime.now().add(const Duration(seconds: 3));
  while (!condition()) {
    if (DateTime.now().isAfter(end)) {
      fail('The source did not connect to Hunt Stats');
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}
