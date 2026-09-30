import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:obssource/tts/tts_settings.dart';
import 'package:obssource/tts/tts_status.dart';

class TtsFailure implements Exception {
  final TtsIssue code;
  const TtsFailure(this.code);
  @override
  String toString() => code.name;
}

class TtsHealth {
  final bool available;
  final int connectedAgents;
  final int healthyAgents;
  final int queueSize;
  final DateTime checkedAt;
  final TtsIssue? reason;

  const TtsHealth({
    required this.available,
    required this.connectedAgents,
    required this.healthyAgents,
    required this.queueSize,
    required this.checkedAt,
    this.reason,
  });

  factory TtsHealth.unavailable(TtsIssue reason) => TtsHealth(
    available: false,
    connectedAgents: 0,
    healthyAgents: 0,
    queueSize: 0,
    checkedAt: DateTime.now(),
    reason: reason,
  );
}

class TtsAudio {
  final File file;
  final Duration duration;
  const TtsAudio(this.file, this.duration);
  Future<void> dispose() async {
    if (await file.exists()) await file.delete();
    // This unique, empty directory belongs only to this request.
    if (await file.parent.exists()) await file.parent.delete();
  }
}

abstract interface class TtsGateway {
  Future<TtsHealth> health(String baseUrl);
  Future<TtsAudio> speech(
    TtsSettings settings,
    String text,
    String key,
    CancelToken cancel,
  );
  void close();
}

class HttpTtsGateway implements TtsGateway {
  final Dio dio;
  final Duration requestTimeout;
  static const maxAudioBytes = 64 * 1024 * 1024;

  HttpTtsGateway({Dio? dio, this.requestTimeout = const Duration(seconds: 100)})
    : dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 100),
            ),
          );

  String _url(String base, String path) =>
      '${TtsSettings.normalizeBaseUrl(base)}/$path';

  @override
  Future<TtsHealth> health(String baseUrl) async {
    try {
      final response = await dio.get<Map<String, dynamic>>(
        _url(baseUrl, 'health'),
        options: Options(
          receiveTimeout: const Duration(seconds: 10),
          validateStatus: (status) => status == 200 || status == 503,
        ),
      );
      final body = response.data!;
      int count(String key) => (body[key] as num?)?.toInt() ?? 0;
      return TtsHealth(
        available:
            response.statusCode == 200 && body['acceptingRequests'] == true,
        connectedAgents: count('connectedAgents'),
        healthyAgents: count('healthyAgents'),
        queueSize: count('queueSize'),
        checkedAt: DateTime.now(),
        reason: switch (body['reason']) {
          null => null,
          'no_agents_available' => TtsIssue.noAgentsAvailable,
          'queue_full' || 'capacity_exceeded' => TtsIssue.queueFull,
          _ => TtsIssue.serviceUnavailable,
        },
      );
    } catch (_) {
      return TtsHealth.unavailable(TtsIssue.serviceUnavailable);
    }
  }

  @override
  Future<TtsAudio> speech(
    TtsSettings settings,
    String text,
    String key,
    CancelToken cancel,
  ) async {
    final directory = await Directory.systemTemp.createTemp('obssource-tts-');
    final file = File('${directory.path}${Platform.pathSeparator}speech.wav');
    var timedOut = false;
    final timer = Timer(requestTimeout, () {
      timedOut = true;
      cancel.cancel(TtsCancellationReason.timeout);
    });
    IOSink? sink;
    var success = false;
    try {
      checkTtsCancellation(cancel);
      final response = await dio.post<ResponseBody>(
        _url(settings.baseUrl, 'audio/speech'),
        data: {
          'input': text,
          'style': settings.mood.apiValue,
          'seed': 42,
          'response_format': 'wav',
        },
        options: Options(
          responseType: ResponseType.stream,
          headers: {'Idempotency-Key': key},
          validateStatus: (_) => true,
        ),
        cancelToken: cancel,
      );
      final body = response.data!;
      if (response.statusCode != 200 ||
          !(response.headers.value('content-type') ?? '').startsWith(
            'audio/wav',
          )) {
        await body.stream.listen((_) {}).cancel();
        throw TtsFailure(
          response.statusCode == 504
              ? TtsIssue.timeout
              : response.statusCode == 429
              ? TtsIssue.queueFull
              : TtsIssue.generationFailed,
        );
      }
      final declared = int.tryParse(
        response.headers.value('content-length') ?? '',
      );
      if (declared != null && declared > maxAudioBytes) {
        await body.stream.listen((_) {}).cancel();
        throw const TtsFailure(TtsIssue.invalidAudio);
      }
      sink = file.openWrite();
      var size = 0;
      await for (final chunk in body.stream) {
        checkTtsCancellation(cancel);
        size += chunk.length;
        if (size > maxAudioBytes) throw const TtsFailure(TtsIssue.invalidAudio);
        sink.add(chunk);
      }
      await sink.flush();
      await sink.close();
      sink = null;
      checkTtsCancellation(cancel);
      if (declared != null && declared != size) {
        throw const TtsFailure(TtsIssue.invalidAudio);
      }
      final bytes = await file.readAsBytes();
      final duration = wavDuration(bytes);
      final etag =
          response.headers.value('etag')?.replaceAll('"', '').toLowerCase();
      if (etag == null || sha256.convert(bytes).toString() != etag) {
        throw const TtsFailure(TtsIssue.invalidAudio);
      }
      checkTtsCancellation(cancel);
      success = true;
      return TtsAudio(file, duration);
    } on DioException catch (error) {
      if (timedOut ||
          [
            DioExceptionType.connectionTimeout,
            DioExceptionType.receiveTimeout,
            DioExceptionType.sendTimeout,
          ].contains(error.type)) {
        throw const TtsFailure(TtsIssue.timeout);
      }
      throw TtsFailure(
        cancel.isCancelled ? TtsIssue.canceled : TtsIssue.generationFailed,
      );
    } finally {
      timer.cancel();
      await sink?.close();
      if (!success) {
        if (await file.exists()) await file.delete();
        if (await directory.exists()) await directory.delete();
      }
    }
  }

  @override
  void close() => dio.close(force: true);
}

void checkTtsCancellation(CancelToken token) {
  if (token.isCancelled) throw const TtsFailure(TtsIssue.canceled);
}

/// Validate RIFF chunks instead of assuming every WAV has a 44-byte header.
Duration wavDuration(Uint8List bytes) {
  const invalid = TtsFailure(TtsIssue.invalidAudio);
  if (bytes.length < 44 ||
      String.fromCharCodes(bytes.sublist(0, 4)) != 'RIFF' ||
      String.fromCharCodes(bytes.sublist(8, 12)) != 'WAVE') {
    throw invalid;
  }
  final data = ByteData.sublistView(bytes);
  if (data.getUint32(4, Endian.little) + 8 != bytes.length) throw invalid;
  int? rate, alignment;
  var audioBytes = 0;
  var offset = 12;
  while (offset + 8 <= bytes.length) {
    final kind = String.fromCharCodes(bytes.sublist(offset, offset + 4));
    final length = data.getUint32(offset + 4, Endian.little);
    final start = offset + 8;
    if (start + length > bytes.length) throw invalid;
    if (kind == 'fmt ') {
      if (length < 16 || data.getUint16(start, Endian.little) != 1) {
        throw invalid;
      }
      final channels = data.getUint16(start + 2, Endian.little);
      final frequency = data.getUint32(start + 4, Endian.little);
      final bits = data.getUint16(start + 14, Endian.little);
      rate = data.getUint32(start + 8, Endian.little);
      alignment = data.getUint16(start + 12, Endian.little);
      if (channels < 1 ||
          frequency < 1 ||
          ![8, 16, 24, 32].contains(bits) ||
          alignment != channels * bits ~/ 8 ||
          rate != frequency * alignment) {
        throw invalid;
      }
    } else if (kind == 'data') {
      audioBytes += length;
    }
    offset = start + length + (length.isOdd ? 1 : 0);
  }
  if (rate == null ||
      rate == 0 ||
      alignment == null ||
      audioBytes == 0 ||
      audioBytes % alignment != 0) {
    throw invalid;
  }
  return Duration(microseconds: (audioBytes * 1000000 / rate).ceil());
}

String newTtsRequestKey() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return [
    hex.substring(0, 8),
    hex.substring(8, 12),
    hex.substring(12, 16),
    hex.substring(16, 20),
    hex.substring(20),
  ].join('-');
}
