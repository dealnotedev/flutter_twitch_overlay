import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/ffmpeg_vu_analyzer.dart';

void main() {
  test(
    'parses frame windows, silence and mono without mixing channels',
    () async {
      final analyzer = FfmpegVuAnalyzer(
        executable: 'ffmpeg',
        processStarter: (_, arguments) async {
          expect(arguments, contains(r'C:\Music\a b.mp3'));
          return _Process(
            'frame:0 pts:0 pts_time:0\n'
            'lavfi.astats.1.RMS_level=-inf\n'
            'lavfi.astats.2.RMS_level=-20\n'
            'frame:1 pts:2400 pts_time:0.05\n'
            'lavfi.astats.1.RMS_level=-14\n',
          );
        },
      );
      final profile = await analyzer.analyze(r'C:\Music\a b.mp3');
      expect(profile.length, 2);
      expect(profile.sampleAt(Duration.zero).leftDb, -90);
      expect(profile.sampleAt(Duration.zero).rightDb, -20);
      expect(profile.sampleAt(const Duration(milliseconds: 50)).leftDb, -14);
      expect(profile.sampleAt(const Duration(milliseconds: 50)).rightDb, -14);
      await analyzer.close();
    },
  );

  test(
    'failed FFmpeg and malformed output cannot become usable profiles',
    () async {
      for (final process in [
        _Process('', status: 1),
        _Process(''),
        _Process('frame:0\nlavfi.astats.1.RMS_level=NaN\n'),
      ]) {
        final analyzer = FfmpegVuAnalyzer(
          executable: 'ffmpeg',
          processStarter: (_, _) async => process,
        );
        await expectLater(
          analyzer.analyze('file.mp3'),
          throwsA(anyOf(isA<StateError>(), isA<FormatException>())),
        );
        await analyzer.close();
      }
    },
  );

  test('analysis timeout terminates the process', () async {
    final process = _HangingProcess();
    final analyzer = FfmpegVuAnalyzer(
      executable: 'ffmpeg',
      timeout: const Duration(milliseconds: 20),
      processStarter: (_, _) async => process,
    );
    await expectLater(
      analyzer.analyze('file.mp3'),
      throwsA(isA<TimeoutException>()),
    );
    expect(process.killed, isTrue);
    await analyzer.close();
  });

  test('closing cancels an active analysis', () async {
    final process = _HangingProcess();
    final started = Completer<void>();
    final analyzer = FfmpegVuAnalyzer(
      executable: 'ffmpeg',
      processStarter: (_, _) async {
        started.complete();
        return process;
      },
    );
    final result = expectLater(analyzer.analyze('file.mp3'), throwsStateError);
    await started.future;
    await analyzer.close();
    await result;
    expect(process.killed, isTrue);
  });

  final ffmpeg = File('tools/ffmpeg.exe').absolute;
  test('bundled FFmpeg measures the real stereo MP3 fixture', () async {
    final analyzer = FfmpegVuAnalyzer(executable: ffmpeg.path);
    addTearDown(analyzer.close);
    final profile = await analyzer.analyze(
      File('test/fixtures/music/vu-stereo.mp3').absolute.path,
    );
    expect(profile.length, inInclusiveRange(10, 11));
    final sample = profile.sampleAt(const Duration(milliseconds: 200));
    expect(sample.leftDb, closeTo(-23.01, 1));
    expect(sample.rightDb, closeTo(-10.97, 1));
    expect(sample.rightDb - sample.leftDb, closeTo(12.04, 1));
  }, skip: !ffmpeg.existsSync());

  test('bundled FFmpeg duplicates a mono fixture for both needles', () async {
    final analyzer = FfmpegVuAnalyzer(executable: ffmpeg.path);
    addTearDown(analyzer.close);
    final profile = await analyzer.analyze(
      File('test/fixtures/music/vu-mono.mp3').absolute.path,
    );
    final sample = profile.sampleAt(const Duration(milliseconds: 200));
    expect(sample.leftDb, closeTo(-16.99, 1));
    expect(sample.rightDb, sample.leftDb);
  }, skip: !ffmpeg.existsSync());
}

class _Process implements Process {
  final String output;
  final int status;
  _Process(this.output, {this.status = 0});
  @override
  Future<int> get exitCode async => status;
  @override
  int get pid => 1;
  @override
  Stream<List<int>> get stdout =>
      Stream.fromIterable(utf8.encode(output).map((byte) => [byte]));
  @override
  Stream<List<int>> get stderr => const Stream.empty();
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;
}

class _HangingProcess implements Process {
  final _exit = Completer<int>();
  final _output = StreamController<List<int>>();
  final _error = StreamController<List<int>>();
  bool killed = false;
  @override
  Future<int> get exitCode => _exit.future;
  @override
  int get pid => 1;
  @override
  Stream<List<int>> get stdout => _output.stream;
  @override
  Stream<List<int>> get stderr => _error.stream;
  @override
  IOSink get stdin => throw UnimplementedError();
  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (killed) return false;
    killed = true;
    _exit.complete(143);
    unawaited(_output.close());
    unawaited(_error.close());
    return true;
  }
}
