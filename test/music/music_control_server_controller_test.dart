import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/control/music_control_protocol.dart';
import 'package:obssource/music/control/music_control_server.dart';
import 'package:obssource/music/control/music_control_server_controller.dart';
import 'package:obssource/music/music_requests.dart';
import 'package:obssource/music/music_settings.dart';

void main() {
  late _FakeMusicRequests requests;
  late MusicControlServer server;
  late HttpClient httpClient;

  setUp(() async {
    requests = _FakeMusicRequests(_snapshot(1));
    server = MusicControlServer(requests: requests, requestedPort: 0);
    await server.start();
    httpClient = HttpClient();
  });

  tearDown(() async {
    httpClient.close(force: true);
    await server.close();
    await requests.close();
  });

  test(
    'controller changes port, stops and restarts without changing playback',
    () async {
      final controller = MusicControlServerController(requests: requests);
      addTearDown(controller.close);
      await controller.configure(enabled: true, port: 0);
      final firstPort = controller.port!;
      final firstHealth = await _requestJson(
        httpClient,
        firstPort,
        'GET',
        '/v1/health',
      );
      await controller.configure(enabled: true, port: firstPort);
      final sameHealth = await _requestJson(
        httpClient,
        firstPort,
        'GET',
        '/v1/health',
      );
      expect(sameHealth.body['serverId'], firstHealth.body['serverId']);
      final free = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final nextPort = free.port;
      await free.close(force: true);
      await controller.configure(enabled: true, port: nextPort);
      expect(controller.port, nextPort);
      expect(controller.status, MusicControlServerStatus.running);
      final response = await _requestJson(
        httpClient,
        nextPort,
        'GET',
        '/v1/player',
      );
      expect(
        MusicControlProtocol.snapshotEnvelopeFromJson(
          response.body,
        ).snapshot.nowPlaying?.item.title,
        'Track 1',
      );
      final released = await HttpServer.bind(
        InternetAddress.loopbackIPv4,
        firstPort,
      );
      await released.close(force: true);
      await controller.configure(enabled: false, port: nextPort);
      expect(controller.status, MusicControlServerStatus.stopped);
      expect(controller.port, isNull);
      await controller.configure(enabled: true, port: nextPort);
      expect(controller.status, MusicControlServerStatus.running);
      expect(requests.current.nowPlaying?.item.title, 'Track 1');
      expect(requests.skipCount, 0);
    },
  );

  test('default music servers for two sources listen independently', () async {
    final secondRequests = _FakeMusicRequests(_snapshot(2));
    final first = MusicControlServerController(requests: requests);
    final second = MusicControlServerController(requests: secondRequests);
    addTearDown(() async {
      await first.close();
      await second.close();
      await secondRequests.close();
    });
    const settings = MusicSettings();
    await Future.wait([
      first.configure(enabled: true, port: settings.controlServerPort),
      second.configure(enabled: true, port: settings.controlServerPort),
    ]);
    expect(first.status, MusicControlServerStatus.running, reason: first.error);
    expect(
      second.status,
      MusicControlServerStatus.running,
      reason: second.error,
    );
    expect(second.port, isNot(first.port));
    for (final (controller, title) in [
      (first, 'Track 1'),
      (second, 'Track 2'),
    ]) {
      final response = await _requestJson(
        httpClient,
        controller.port!,
        'GET',
        '/v1/player',
      );
      expect(
        MusicControlProtocol.snapshotEnvelopeFromJson(
          response.body,
        ).snapshot.nowPlaying?.item.title,
        title,
      );
    }
  });

  test(
    'automatic port remains stable when configuration is reapplied',
    () async {
      final controller = MusicControlServerController(requests: requests);
      addTearDown(controller.close);
      await controller.configure(enabled: true, port: 0);
      final firstPort = controller.port!;
      final firstHealth = await _requestJson(
        httpClient,
        firstPort,
        'GET',
        '/v1/health',
      );
      await controller.configure(enabled: true, port: 0);
      expect(controller.port, firstPort);
      final health = await _requestJson(
        httpClient,
        firstPort,
        'GET',
        '/v1/health',
      );
      expect(health.body['serverId'], firstHealth.body['serverId']);
    },
  );

  test(
    'controller selects a free port when the preferred port is occupied',
    () async {
      final controller = MusicControlServerController(requests: requests);
      addTearDown(controller.close);
      final port = server.port!;
      await controller.configure(enabled: true, port: port);
      expect(
        controller.status,
        MusicControlServerStatus.running,
        reason: controller.error,
      );
      expect(controller.port, isNot(port));
      expect(controller.error, isNull);
      final fallback = controller.port;
      await controller.configure(enabled: true, port: port);
      expect(controller.port, fallback);
      await server.close();
      await controller.configure(enabled: false, port: port);
      await controller.configure(enabled: true, port: port);
      expect(controller.status, MusicControlServerStatus.running);
      expect(controller.error, isNull);
    },
  );

  test('rapid changes and shutdown release all listeners', () async {
    final controller = MusicControlServerController(requests: requests);
    await Future.wait([
      controller.configure(enabled: true, port: 0),
      controller.configure(enabled: false, port: 0),
      controller.configure(enabled: true, port: 0),
    ]);
    final port = controller.port!;
    final restart = controller.configure(enabled: true, port: 0);
    await controller.close();
    await restart;
    final released = await HttpServer.bind(InternetAddress.loopbackIPv4, port);
    await released.close(force: true);
  });
}

Future<_JsonResponse> _requestJson(
  HttpClient client,
  int port,
  String method,
  String path, [
  Object? body,
]) async {
  final request = await client.openUrl(
    method,
    Uri.parse('http://127.0.0.1:$port$path'),
  );
  request.headers.contentType = ContentType.json;
  if (body != null) request.write(jsonEncode(body));
  final response = await request.close();
  final text = await utf8.decoder.bind(response).join();
  return _JsonResponse(
    response.statusCode,
    jsonDecode(text) as Map<String, dynamic>,
  );
}

class _JsonResponse {
  final int statusCode;
  final Map<String, dynamic> body;

  const _JsonResponse(this.statusCode, this.body);
}

class _FakeMusicRequests implements MusicRequests {
  final _states = StreamController<MusicQueueSnapshot>.broadcast();
  final List<bool> pauseChanges = [];
  final List<Duration> seekPositions = [];
  final List<String> removedItemIds = [];
  MusicQueueSnapshot _current;
  int skipCount = 0;

  _FakeMusicRequests(this._current);

  @override
  MusicQueueSnapshot get current => _current;

  @override
  Stream<MusicQueueSnapshot> get states async* {
    yield _current;
    yield* _states.stream;
  }

  void emit(MusicQueueSnapshot snapshot) {
    _current = snapshot;
    _states.add(snapshot);
  }

  @override
  Future<bool> setPaused(bool paused) async {
    pauseChanges.add(paused);
    return true;
  }

  @override
  Future<bool> seek(Duration position) async {
    seekPositions.add(position);
    return true;
  }

  @override
  Future<bool> skip() async {
    skipCount++;
    return true;
  }

  @override
  Future<bool> remove(String itemId) async {
    removedItemIds.add(itemId);
    return true;
  }

  @override
  Future<void> close() => _states.close();
}

MusicQueueSnapshot _snapshot(int revision) {
  final item = MusicQueueItem(
    id: 'track-$revision',
    requestedBy: 'viewer',
    sourceUrl: Uri.parse('https://youtu.be/track-$revision'),
    phase: MusicQueueItemPhase.ready,
    title: 'Track $revision',
    author: 'Artist',
    duration: const Duration(minutes: 3),
    thumbnail: null,
    downloadProgress: 1,
  );
  return MusicQueueSnapshot(
    revision: revision,
    nowPlaying: MusicNowPlaying(
      item: item,
      startedAt: DateTime(2026, 9, 3, 12),
      position: const Duration(seconds: 10),
      positionUpdatedAt: DateTime.now(),
      paused: false,
    ),
    queue: const [],
    lastError: null,
  );
}
