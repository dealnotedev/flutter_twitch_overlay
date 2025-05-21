import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';

class ObsAudioBridge {
  static Future<void> inspectWav(String path) async {
    final bytes = await File(path).readAsBytes();
    final riff  = String.fromCharCodes(bytes.sublist(0, 4)); // "RIFF"
    final wave  = String.fromCharCodes(bytes.sublist(8, 12)); // "WAVE"
    final fmtOfs = bytes.indexOf('fmt '.codeUnitAt(0));

    final b = ByteData.sublistView(bytes);
    final channels   = b.getUint16(fmtOfs + 10, Endian.little);  // 2
    final sampleRate = b.getUint32(fmtOfs + 12, Endian.little);  // 48000
    final bits       = b.getUint16(fmtOfs + 22, Endian.little);  // 16

    print('riff=$riff wave=$wave ch=$channels sr=$sampleRate bits=$bits');
  }

  /// Отправить аудиофайл в OBS через methodChannel.
  /// [path] — путь к файлу (например, WAV, raw PCM).
  /// [chunkSize] — размер чанка (по умолчанию 4096).
  static Future<void> playAudioFileForObs(String path, {int chunkSize = 4096}) async {
    final start = DateTime.now();

    await inspectWav(path);

    final file = File(path);
    if (!await file.exists()) throw Exception("File not found: $path");

    // ------ 1. Load file ------
    final bytes = await File(path).readAsBytes();
    final dataStart = _findWaveDataOffset(bytes);
    final pcm = bytes.sublist(dataStart);           // pure PCM, little-endian

    // ------ 2. Push 20 ms chunks ------
    const samplesPerChunk = 960;                    // 20 ms @ 48 kHz
    const bytesPerChunk   = samplesPerChunk * 2 /*ch*/ * 2 /*bytes*/;

    for (int off = 0; off < pcm.length; off += bytesPerChunk) {
      final end   = (off + bytesPerChunk).clamp(0, pcm.length);
      final chunk = pcm.sublist(off, end);

      await ServicesBinding.instance.defaultBinaryMessenger.send(
        "obs_channel",
        chunk.buffer.asByteData(),
      );

      // maintain real-time pacing
      await Future.delayed(const Duration(milliseconds: 20));
    }

    print('Sound DONE ${DateTime.now().difference(start).inMilliseconds} ms');
  }

  /// naïve RIFF scanner – stops on the first 'data' chunk
  static int _findWaveDataOffset(Uint8List wav) {
    final b = ByteData.sublistView(wav);
    for (int p = 12; p + 8 < wav.length; p += 2) {
      if (b.getUint32(p, Endian.little) == 0x61746164 /* 'data' */) {
        return p + 8;                               // chunk header + size
      }
    }
    throw FormatException('invalid WAV');
  }
}