import 'package:flutter_test/flutter_test.dart';
import 'package:obssource/music/turntable_motion.dart';
import 'package:obssource/music/turntable_geometry.dart';

void main() {
  late List<String> cued;
  late TurntableMotion motion;

  setUp(() {
    cued = [];
    motion = TurntableMotion(onNeedlePlaced: cued.add);
  });
  tearDown(() => motion.dispose());

  test('waits with an empty deck until metadata arrives, then places', () {
    motion.update(
      itemId: 'one',
      metadataReady: false,
      ready: false,
      paused: false,
    );
    motion.advance(const Duration(seconds: 20));
    expect(motion.phase, TurntablePhase.awaitingMetadata);
    expect(motion.visibility, 1);
    expect(motion.recordVisible, isFalse);
    expect(motion.recordPlacement, 0);
    expect(motion.rpm, 0);
    expect(cued, isEmpty);

    motion.update(
      itemId: 'one',
      metadataReady: true,
      ready: false,
      paused: false,
    );
    expect(motion.phase, TurntablePhase.placing);
    motion.advance(const Duration(milliseconds: 500));
    expect(motion.recordVisible, isTrue);
    expect(motion.recordPlacement, inExclusiveRange(0, 1));
    motion.advance(const Duration(seconds: 3));
    expect(motion.phase, TurntablePhase.waiting);
    expect(motion.arm, 0);
    expect(cued, isEmpty);
  });

  test('changing tracks waits for the next metadata after removal', () {
    motion.update(
      itemId: 'one',
      metadataReady: true,
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 5));
    motion.update(
      itemId: 'two',
      metadataReady: false,
      ready: false,
      paused: false,
    );
    expect(motion.phase, TurntablePhase.lifting);
    expect(motion.itemId, 'one');
    expect(motion.recordVisible, isTrue);
    motion.advance(const Duration(seconds: 5));
    expect(motion.phase, TurntablePhase.awaitingMetadata);
    expect(motion.itemId, 'two');
    expect(motion.recordVisible, isFalse);
    expect(motion.recordPlacement, 0);

    motion.update(
      itemId: 'two',
      metadataReady: true,
      ready: false,
      paused: false,
    );
    expect(motion.phase, TurntablePhase.placing);
    motion.advance(const Duration(milliseconds: 500));
    expect(motion.recordPlacement, inExclusiveRange(0, 1));
    expect(cued, ['one']);
  });

  test('replacing or cancelling an unresolved track keeps the deck empty', () {
    motion.update(
      itemId: 'one',
      metadataReady: false,
      ready: false,
      paused: false,
    );
    motion.advance(const Duration(seconds: 1));
    motion.update(
      itemId: 'two',
      metadataReady: false,
      ready: false,
      paused: false,
    );
    expect(motion.phase, TurntablePhase.awaitingMetadata);
    expect(motion.itemId, 'two');
    expect(motion.recordVisible, isFalse);
    motion.update(
      itemId: null,
      metadataReady: false,
      ready: false,
      paused: false,
    );
    expect(motion.phase, TurntablePhase.exiting);
    expect(motion.recordVisible, isFalse);
    motion.advance(const Duration(seconds: 1));
    expect(motion.phase, TurntablePhase.hidden);
    expect(motion.visibility, 0);
    expect(cued, isEmpty);
  });

  test(
    'needle tracks from the outer groove to the inner groove, clear of the cover',
    () {
      motion.update(
        metadataReady: true,
        itemId: 'one',
        ready: true,
        paused: false,
      );
      motion.advance(const Duration(seconds: 5));
      double radius() =>
          (TurntableGeometry.needlePosition(motion.armAngle) -
                  TurntableGeometry.platterCenter)
              .distance;
      expect(radius(), closeTo(105, 0.001));
      var previousRadius = radius();
      for (final progress in [0.25, 0.5, 0.75, 1.0]) {
        motion.setTrackProgress(progress);
        motion.advance(const Duration(seconds: 1));
        final currentRadius = radius();
        expect(currentRadius, lessThan(previousRadius));
        expect(currentRadius, greaterThan(TurntableGeometry.labelRadius));
        previousRadius = currentRadius;
      }
      expect(radius(), closeTo(72, 0.01));
      expect(cued, ['one']);
    },
  );

  test(
    'seeking glides both ways and changing tracks lifts from the current groove',
    () {
      motion.update(
        metadataReady: true,
        itemId: 'one',
        ready: true,
        paused: false,
      );
      motion.advance(const Duration(seconds: 5));
      final outerAngle = motion.armAngle;
      motion.setTrackProgress(1);
      expect(motion.armAngle, outerAngle);
      motion.advance(const Duration(milliseconds: 50));
      expect(motion.trackProgress, inExclusiveRange(0, 1));
      motion.advance(const Duration(seconds: 1));
      final innerAngle = motion.armAngle;
      expect(innerAngle, greaterThan(outerAngle));
      motion.setTrackProgress(0.5);
      motion.advance(const Duration(seconds: 1));
      expect(motion.armAngle, inExclusiveRange(outerAngle, innerAngle));
      final beforeChange = motion.armAngle;
      motion.update(
        metadataReady: true,
        itemId: 'two',
        ready: false,
        paused: false,
      );
      expect(motion.armAngle, beforeChange);
      motion.advance(const Duration(milliseconds: 100));
      expect(motion.armAngle, beforeChange);
      motion.advance(const Duration(milliseconds: 600));
      expect(motion.armAngle, 0);
      expect(cued, ['one']);
    },
  );

  test('spins indefinitely at standard speed while audio is not ready', () {
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: false,
      paused: false,
    );
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.waiting);
    expect(motion.recordPlacement, 1);
    expect(motion.rpm, closeTo(100 / 3, 0.001));
    final rotation = motion.rotation;
    motion.advance(const Duration(seconds: 20));
    expect(motion.rotation, isNot(closeTo(rotation, 0.01)));
    expect(motion.arm, 0);
    expect(cued, isEmpty);

    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(milliseconds: 700));
    expect(motion.phase, TurntablePhase.cueing);
    expect(motion.arm, inExclusiveRange(0, 1));
    expect(cued, isEmpty);
    motion.advance(const Duration(milliseconds: 600));
    expect(motion.phase, TurntablePhase.playing);
    expect(motion.needleLift, 0);
    expect(cued, ['one']);
    motion.advance(const Duration(seconds: 5));
    expect(cued, ['one']);
  });

  test('a cached track still waits for placement and full spin-up', () {
    motion.update(
      metadataReady: true,
      itemId: 'cached',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(milliseconds: 2900));
    expect(motion.phase, TurntablePhase.spinningUp);
    expect(motion.rpm, inExclusiveRange(0, TurntableMotion.standardRpm));
    expect(motion.arm, 0);
    expect(cued, isEmpty);
    motion.advance(const Duration(seconds: 2));
    expect(cued, ['cached']);
  });

  test('pause during cueing prevents audio start until resumed', () {
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.cueing);
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: true,
    );
    final arm = motion.arm;
    motion.advance(const Duration(seconds: 10));
    expect(motion.arm, arm);
    expect(cued, isEmpty);
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 1));
    expect(cued, ['one']);
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: true,
    );
    motion.advance(const Duration(seconds: 3));
    expect(motion.rpm, lessThan(0.01));
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 3));
    expect(motion.rpm, closeTo(TurntableMotion.standardRpm, 0.01));
    expect(cued, ['one']);
  });

  test('a skip during cueing returns the arm before changing records', () {
    motion.update(
      metadataReady: true,
      itemId: 'one',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 4));
    motion.update(
      metadataReady: true,
      itemId: 'two',
      ready: false,
      paused: false,
    );
    motion.advance(const Duration(milliseconds: 400));
    expect(motion.phase, TurntablePhase.lifting);
    expect(motion.itemId, 'one');
    expect(cued, isEmpty);
    motion.advance(const Duration(milliseconds: 1200));
    expect(motion.itemId, 'two');
    expect(motion.arm, 0);
    motion.advance(const Duration(seconds: 4));
    expect(motion.phase, TurntablePhase.waiting);
    expect(cued, isEmpty);
    motion.update(
      metadataReady: true,
      itemId: 'two',
      ready: true,
      paused: false,
    );
    motion.advance(const Duration(seconds: 2));
    expect(cued, ['two']);
    motion.update(
      metadataReady: true,
      itemId: null,
      ready: false,
      paused: false,
    );
    motion.advance(const Duration(seconds: 3));
    expect(motion.phase, TurntablePhase.hidden);
    expect(motion.visibility, 0);
    expect(motion.itemId, isNull);
  });
}
