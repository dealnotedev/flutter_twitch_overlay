import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:obssource/music/music_vu_profile.dart';

typedef VuProcessStarter =
    Future<Process> Function(String executable, List<String> arguments);

class FfmpegVuAnalyzer {
  final String executable;
  final Duration timeout;
  final VuProcessStarter _start;
  final _processes = <Process>{};
  bool _closed = false;

  FfmpegVuAnalyzer({
    required this.executable,
    this.timeout = const Duration(minutes: 2),
    VuProcessStarter? processStarter,
  }) : _start = processStarter ?? _startProcess;

  static Future<Process> _startProcess(
    String executable,
    List<String> arguments,
  ) => Process.start(executable, arguments, runInShell: false);

  Future<MusicVuProfile> analyze(String audioPath) async {
    if (_closed) throw StateError('VU analyzer is closed');
    final process = await _start(executable, [
      '-nostdin',
      '-hide_banner',
      '-loglevel',
      'error',
      '-i',
      audioPath,
      '-map',
      '0:a:0',
      '-vn',
      '-threads',
      '1',
      '-af',
      'aresample=48000,asetpts=N/SR/TB,asetnsamples=n=2400:p=1,'
          'astats=metadata=1:reset=1:measure_perchannel=RMS_level:measure_overall=none,'
          'ametadata=mode=print:file=-',
      '-c:a',
      'pcm_s16le',
      '-f',
      'null',
      '-',
    ]);
    _processes.add(process);
    if (_closed) process.kill();
    final output = _VuOutput();
    final diagnostic = StringBuffer();
    final stdoutDone = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .forEach(output.add);
    final stderrDone = process.stderr.transform(utf8.decoder).forEach((text) {
      if (diagnostic.length < 8192) {
        diagnostic.write(
          text.substring(0, text.length.clamp(0, 8192 - diagnostic.length)),
        );
      }
    });
    // Attach all stream error handlers before waiting on the process.
    final completed = Future.wait<Object?>([
      process.exitCode,
      stdoutDone.then<Object?>((_) => null),
      stderrDone.then<Object?>((_) => null),
    ]);
    try {
      final result = await completed.timeout(
        timeout,
        onTimeout: () {
          process.kill();
          throw TimeoutException('FFmpeg VU analysis timed out', timeout);
        },
      );
      if (_closed) throw StateError('VU analyzer is closed');
      if (result.first != 0) {
        throw StateError('FFmpeg VU analysis failed: $diagnostic');
      }
      return output.finish();
    } finally {
      _processes.remove(process);
      process.kill();
    }
  }

  Future<void> close() async {
    _closed = true;
    for (final process in _processes.toList()) {
      process.kill();
    }
  }
}

class _VuOutput {
  final _samples = <MusicVuSample>[];
  double? _left;
  double? _right;
  bool _frame = false;
  bool _invalid = false;

  void add(String line) {
    if (_invalid) return;
    if (line.startsWith('frame:')) {
      _flush();
      _frame = true;
    } else if (line.startsWith('lavfi.astats.1.RMS_level=')) {
      _left = _db(line.split('=').last);
    } else if (line.startsWith('lavfi.astats.2.RMS_level=')) {
      _right = _db(line.split('=').last);
    }
  }

  double? _db(String text) {
    if (text == '-inf') return MusicVuSample.floorDb;
    final value = double.tryParse(text);
    if (value == null || !value.isFinite) {
      _invalid = true;
      return null;
    }
    return value.clamp(MusicVuSample.floorDb, 0.0);
  }

  void _flush() {
    if (!_frame) return;
    if (_left == null || _samples.length >= MusicVuProfile.maxFrames) {
      _invalid = true;
      return;
    }
    // Mono files drive both needles with the same measured channel.
    _samples.add(MusicVuSample(_left!, _right ?? _left!));
    _left = _right = null;
  }

  MusicVuProfile finish() {
    _flush();
    if (_invalid || _samples.isEmpty) {
      throw const FormatException('FFmpeg returned no valid VU profile');
    }
    return MusicVuProfile(_samples);
  }
}
