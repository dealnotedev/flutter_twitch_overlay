import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';

void main() {
  late HttpServer server;
  late HttpTtsGateway api;
  late String base;
  late List<HttpRequest> requests;
  late Future<void> Function(HttpRequest) handler;
  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    base = 'http://127.0.0.1:${server.port}/tts/v1';
    api = HttpTtsGateway();
    requests = [];
    handler = (request) async {
      request.response.statusCode = 500;
      await request.response.close();
    };
    server.listen((request) async {
      requests.add(request);
      try {
        await handler(request);
      } catch (_) {}
    });
  });
  tearDown(() async {
    api.close();
    await server.close(force: true);
  });

  test('base URL preserves the full API path and version', () {
    expect(
      TtsSettings.normalizeBaseUrl('https://example.test/'),
      'https://example.test',
    );
    expect(
      TtsSettings.normalizeBaseUrl('https://example.test/tts/v1/'),
      'https://example.test/tts/v1',
    );
    expect(
      TtsSettings.normalizeBaseUrl('https://example.test/proxy/tts/v2/'),
      'https://example.test/proxy/tts/v2',
    );
    expect(
      () => TtsSettings.normalizeBaseUrl('file:///tmp'),
      throwsFormatException,
    );
    expect(
      () => TtsSettings.normalizeBaseUrl('https://example.test/tts?key=1'),
      throwsFormatException,
    );
  });

  test('health preserves agent counts even when service returns 503', () async {
    handler = (request) async {
      request.response
        ..statusCode = 503
        ..headers.contentType = ContentType.json
        ..write(
          jsonEncode({
            'acceptingRequests': false,
            'connectedAgents': 2,
            'healthyAgents': 0,
            'queueSize': 0,
            'reason': 'no_agents_available',
          }),
        );
      await request.response.close();
    };
    final health = await api.health(
      base.replaceFirst('/tts/v1', '/proxy/tts/v2'),
    );
    expect(requests.single.uri.path, '/proxy/tts/v2/health');
    expect(health.available, isFalse);
    expect(health.connectedAgents, 2);
    expect(health.reason, TtsIssue.noAgentsAvailable);
  });

  test('health maps capacity and unknown reasons to typed issues', () async {
    for (final (reason, expected) in [
      ('capacity_exceeded', TtsIssue.queueFull),
      ('queue_full', TtsIssue.queueFull),
      ('new_server_reason', TtsIssue.serviceUnavailable),
    ]) {
      handler = (request) async {
        request.response
          ..statusCode = 503
          ..headers.contentType = ContentType.json
          ..write(jsonEncode({'acceptingRequests': false, 'reason': reason}));
        await request.response.close();
      };
      final health = await api.health(base);
      expect(health.available, isFalse);
      expect(health.reason, expected);
    }
  });

  test(
    'sync request returns a verified WAV and sends mood without voice/language',
    () async {
      final wav = sampleWav();
      Map<String, dynamic>? sent;
      handler = (request) async {
        sent = jsonDecode(await utf8.decoder.bind(request).join());
        request.response.headers.contentType = ContentType('audio', 'wav');
        request.response.headers.set('etag', '"${sha256.convert(wav)}"');
        request.response.contentLength = wav.length;
        request.response.add(wav);
        await request.response.close();
      };
      final key = newTtsRequestKey();
      final audio = await api.speech(
        TtsSettings(baseUrl: base, mood: TtsMood.calm),
        'Привіт!',
        key,
        CancelToken(),
      );
      expect(requests.single.uri.path, '/tts/v1/audio/speech');
      expect(requests.single.headers.value('idempotency-key'), key);
      expect(sent, {
        'input': 'Привіт!',
        'style': 'calm',
        'seed': 42,
        'response_format': 'wav',
      });
      expect(audio.duration, const Duration(milliseconds: 10));
      expect(await audio.file.readAsBytes(), wav);
      await audio.dispose();
      expect(await audio.file.exists(), isFalse);
    },
  );

  test('504 is terminal: no polling, retry or audio playback result', () async {
    handler = (request) async {
      request.response
        ..statusCode = 504
        ..headers.contentType = ContentType.json
        ..write('{"error":"wait_timeout","details":{"jobId":"still-running"}}');
      await request.response.close();
    };
    await expectLater(
      api.speech(
        TtsSettings(baseUrl: base),
        'Hello',
        newTtsRequestKey(),
        CancelToken(),
      ),
      throwsA(
        isA<TtsFailure>().having((e) => e.code, 'code', TtsIssue.timeout),
      ),
    );
    expect(requests.length, 1);
  });

  test('transport timeout cancels the request and never retries', () async {
    api.close();
    api = HttpTtsGateway(requestTimeout: const Duration(milliseconds: 60));
    handler = (request) async {
      await Future<void>.delayed(const Duration(milliseconds: 250));
      await request.response.close();
    };
    await expectLater(
      api.speech(
        TtsSettings(baseUrl: base),
        'Hello',
        newTtsRequestKey(),
        CancelToken(),
      ),
      throwsA(
        isA<TtsFailure>().having((e) => e.code, 'code', TtsIssue.timeout),
      ),
    );
    expect(requests.length, 1);
  });

  test('a stalled audio body is canceled after the overall deadline', () async {
    api.close();
    api = HttpTtsGateway(requestTimeout: const Duration(milliseconds: 100));
    handler = (request) async {
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.headers.set('etag', '"unused"');
      request.response.add(sampleWav().sublist(0, 12));
      await request.response.flush();
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await request.response.close();
    };
    await expectLater(
      api
          .speech(
            TtsSettings(baseUrl: base),
            'Hello',
            newTtsRequestKey(),
            CancelToken(),
          )
          .timeout(const Duration(seconds: 2)),
      throwsA(
        isA<TtsFailure>().having((e) => e.code, 'code', TtsIssue.timeout),
      ),
    );
    expect(requests.length, 1);
  });

  test('corrupt checksum is rejected', () async {
    handler = (request) async {
      request.response.headers.contentType = ContentType('audio', 'wav');
      request.response.headers.set('etag', '"invalid"');
      request.response.add(sampleWav());
      await request.response.close();
    };
    await expectLater(
      api.speech(
        TtsSettings(baseUrl: base),
        'Hello',
        newTtsRequestKey(),
        CancelToken(),
      ),
      throwsA(
        isA<TtsFailure>().having((e) => e.code, 'code', TtsIssue.invalidAudio),
      ),
    );
  });
}

Uint8List sampleWav() {
  final bytes = Uint8List(44 + 720);
  final data = ByteData.sublistView(bytes);
  bytes.setAll(0, ascii.encode('RIFF'));
  data.setUint32(4, bytes.length - 8, Endian.little);
  bytes.setAll(8, ascii.encode('WAVEfmt '));
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, 24000, Endian.little);
  data.setUint32(28, 72000, Endian.little);
  data.setUint16(32, 3, Endian.little);
  data.setUint16(34, 24, Endian.little);
  bytes.setAll(36, ascii.encode('data'));
  data.setUint32(40, 720, Endian.little);
  return bytes;
}
