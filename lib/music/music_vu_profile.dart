import 'dart:math' as math;
import 'dart:typed_data';

import 'package:dart_music_player_protocol/dart_music_player_protocol.dart';

typedef MusicVuProfileLoader =
    Future<MusicVuProfile?> Function(MusicQueueItem item);

class MusicVuSample {
  static const floorDb = -90.0;
  static const silence = MusicVuSample(floorDb, floorDb);

  final double leftDb;
  final double rightDb;

  const MusicVuSample(this.leftDb, this.rightDb);
}

/// Stereo RMS measurements of the decoded file, in 50 ms windows.
class MusicVuProfile {
  static const interval = Duration(milliseconds: 50);
  static const maxFrames = 72000;
  final Float32List _levels;

  MusicVuProfile(Iterable<MusicVuSample> samples)
    : _levels = Float32List.fromList([
        for (final sample in samples) ...[sample.leftDb, sample.rightDb],
      ]) {
    if (_levels.isEmpty ||
        length > maxFrames ||
        _levels.any(
          (value) =>
              !value.isFinite || value < MusicVuSample.floorDb || value > 0,
        )) {
      throw ArgumentError('Invalid VU profile');
    }
  }

  int get length => _levels.length ~/ 2;
  Duration get duration => interval * length;

  MusicVuSample sampleAt(Duration position, {double volume = 1}) {
    if (position.isNegative ||
        position >= duration ||
        !volume.isFinite ||
        volume <= 0) {
      return MusicVuSample.silence;
    }
    final frame = position.inMicroseconds / interval.inMicroseconds;
    final index = frame.floor();
    final next = math.min(index + 1, length - 1);
    final fraction = frame - index;
    final gainDb = 20 * math.log(volume.clamp(0.0, 1.0)) / math.ln10;
    double channel(int offset) => (_levels[index * 2 + offset] +
            (_levels[next * 2 + offset] - _levels[index * 2 + offset]) *
                fraction +
            gainDb)
        .clamp(MusicVuSample.floorDb, 0.0);
    return MusicVuSample(channel(0), channel(1));
  }

  Map<String, Object> toJson() => {
    'intervalMs': interval.inMilliseconds,
    'levels': [for (final value in _levels) (value * 100).round() / 100],
  };

  factory MusicVuProfile.fromJson(Map<String, dynamic> json) {
    final values = json['levels'];
    if (json['intervalMs'] != interval.inMilliseconds ||
        values is! List ||
        values.isEmpty ||
        values.length.isOdd ||
        values.length > maxFrames * 2) {
      throw const FormatException('Invalid VU profile structure');
    }
    double value(int index) {
      final result = values[index];
      if (result is! num ||
          !result.isFinite ||
          result < MusicVuSample.floorDb ||
          result > 0) {
        throw const FormatException('Invalid VU level');
      }
      return result.toDouble();
    }

    return MusicVuProfile([
      for (var i = 0; i < values.length; i += 2)
        MusicVuSample(value(i), value(i + 1)),
    ]);
  }
}

/// Mechanical needle inertia; targets always come from the playback position.
class MusicVuBallistics {
  double left = 0;
  double right = 0;

  void reset() => left = right = 0;

  void advance(Duration delta, MusicVuSample sample) {
    if (delta <= Duration.zero) return;
    final seconds = delta.inMicroseconds / Duration.microsecondsPerSecond;
    double follow(double current, double db) {
      // 0 VU is calibrated to -12 dBFS; the dial spans -20 to +3 VU.
      final target = ((db + 32) / 23).clamp(0.0, 1.0);
      final timeConstant = target > current ? 0.065 : 0.17;
      return current +
          (target - current) * (1 - math.exp(-seconds / timeConstant));
    }

    left = follow(left, sample.leftDb);
    right = follow(right, sample.rightDb);
  }
}
