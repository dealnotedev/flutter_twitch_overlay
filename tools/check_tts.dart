import 'dart:io';
import 'package:dio/dio.dart';
import 'package:obssource/tts/tts_api.dart';
import 'package:obssource/tts/tts_settings.dart';

/// Explicit smoke check: one health request and one synthesis, no Twitch changes.
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln(
      'Usage: dart run tools/check_tts.dart https://host/tts/v1 [text]',
    );
    exitCode = 64;
    return;
  }
  final api = HttpTtsGateway();
  try {
    final options = TtsSettings(
      baseUrl: TtsSettings.normalizeBaseUrl(arguments.first),
    );
    final health = await api.health(options.baseUrl);
    stdout.writeln(
      'available: ${health.available}, agents: ${health.healthyAgents}/${health.connectedAgents}',
    );
    if (!health.available) {
      exitCode = 2;
      return;
    }
    final watch = Stopwatch()..start();
    final audio = await api.speech(
      options,
      arguments.length > 1 ? arguments[1] : 'Привіт! Це перевірка озвучення.',
      newTtsRequestKey(),
      CancelToken(),
    );
    try {
      stdout.writeln(
        'Verified WAV: ${await audio.file.length()} bytes, ${audio.duration.inMilliseconds} ms audio, request ${watch.elapsedMilliseconds} ms',
      );
    } finally {
      await audio.dispose();
    }
  } finally {
    api.close();
  }
}
